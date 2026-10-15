import 'package:flutter/material.dart';

import '../../agenda/data/agenda_repository.dart';
import '../../agenda/presentation/agenda_event_form_sheet.dart';
import '../../agenda/presentation/agenda_screen.dart';
import '../../applications/data/applications_repository.dart';
import '../../applications/data/job_application.dart';
import '../../applications/presentation/application_form_sheet.dart';
import '../../applications/presentation/applications_screen.dart';
import '../../auth/data/app_lock_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../goals/data/goal.dart';
import '../../goals/data/goals_repository.dart';
import '../../goals/presentation/goal_form_sheet.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../settings/presentation/account_sheet.dart';
import '../data/workspace_controller.dart';
import 'widgets/floating_nav_bar.dart';
import 'widgets/quick_add_sheet.dart';

enum _Tab { home, jobs, agenda, goals }

/// Signed-in app: the four tabs, the floating nav bar and the "+" button.
class AppShell extends StatefulWidget {
  AppShell({
    super.key,
    required this.authRepository,
    required this.appLock,
    ApplicationsRepository? applications,
    AgendaRepository? agenda,
    GoalsRepository? goals,
  })  : applications = applications ?? ApplicationsRepository(),
        agenda = agenda ?? AgendaRepository(),
        goals = goals ?? GoalsRepository();

  final AuthRepository authRepository;
  final AppLockRepository appLock;
  final ApplicationsRepository applications;
  final AgendaRepository agenda;
  final GoalsRepository goals;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _navItems = [
    FloatingNavItem(
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      label: 'Home',
    ),
    FloatingNavItem(
      icon: Icons.work_outline_rounded,
      selectedIcon: Icons.work_rounded,
      label: 'Jobs',
    ),
    FloatingNavItem(
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note_rounded,
      label: 'Agenda',
    ),
    FloatingNavItem(
      icon: Icons.flag_outlined,
      selectedIcon: Icons.flag_rounded,
      label: 'Goals',
    ),
  ];

  late final _workspace = WorkspaceController(
    applications: widget.applications,
    agenda: widget.agenda,
    goals: widget.goals,
  )..load();

  _Tab _tab = _Tab.home;
  ApplicationStatus? _jobsFilter;

  @override
  void dispose() {
    _workspace.dispose();
    super.dispose();
  }

  void _select(_Tab tab) => setState(() => _tab = tab);

  void _openJobs(ApplicationStatus? filter) => setState(() {
        _jobsFilter = filter;
        _tab = _Tab.jobs;
      });

  void _showMessage(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// The "+" button adapts to the current tab.
  Future<void> _onAdd() async {
    switch (_tab) {
      case _Tab.home:
        final action = await showQuickAddSheet(context);
        if (!mounted) return;
        switch (action) {
          case QuickAddAction.application:
            await _addApplication();
          case QuickAddAction.agendaEvent:
            await _addAgendaEvent();
          case QuickAddAction.goal:
            await _addGoal();
          case null:
            break;
        }
      case _Tab.jobs:
        await _addApplication();
      case _Tab.agenda:
        await _addAgendaEvent();
      case _Tab.goals:
        await _addGoal();
    }
  }

  String get _addTooltip => switch (_tab) {
        _Tab.home => 'Add',
        _Tab.jobs => 'New application',
        _Tab.agenda => 'New interview or reminder',
        _Tab.goals => 'New goal',
      };

  Future<void> _addApplication() async {
    final created = await showApplicationFormSheet(
      context,
      repository: widget.applications,
    );
    if (created == null) return;
    _showMessage('Added ${created.role} at ${created.company}');
    await _workspace.load();
  }

  Future<void> _addAgendaEvent() async {
    final created = await showAgendaEventFormSheet(
      context,
      repository: widget.agenda,
      applications: _workspace.data?.applications ?? const [],
    );
    if (created == null) return;
    _showMessage('Added to your agenda');
    await _workspace.load();
  }

  Future<void> _addGoal() async {
    final created = await showGoalFormSheet(context, repository: widget.goals);
    if (created == null) return;
    _showMessage("Goal created. You've got this.");
    await _workspace.load();
  }

  Future<void> _setEventDone(String id, bool isDone) async {
    _showMessage(await _workspace.setEventDone(id, isDone: isDone));
  }

  Future<void> _incrementGoal(Goal goal) async {
    final error = await _workspace.incrementGoal(goal);
    if (error != null) {
      _showMessage(error);
    } else if (goal.progress + 1 == goal.target) {
      _showMessage('Goal complete: ${goal.title}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.authRepository.currentUserName;
    final email = widget.authRepository.currentUserEmail ?? '';

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab.index,
        children: [
          DashboardScreen(
            controller: _workspace,
            firstName: name?.split(RegExp(r'\s+')).first,
            initial:
                (name ?? email).characters.firstOrNull?.toUpperCase() ?? '?',
            onAccountTap: () => showAccountSheet(
              context,
              authRepository: widget.authRepository,
              appLock: widget.appLock,
            ),
            onAddApplication: _addApplication,
            onAddAgendaEvent: _addAgendaEvent,
            onAddGoal: _addGoal,
            onEventDone: (id) => _setEventDone(id, true),
            onGoalIncrement: _incrementGoal,
            onOpenApplications: _openJobs,
            onOpenAgenda: () => _select(_Tab.agenda),
          ),
          ApplicationsScreen(
            controller: _workspace,
            filter: _jobsFilter,
            onFilterChanged: (filter) => setState(() => _jobsFilter = filter),
            onAdd: _addApplication,
          ),
          AgendaScreen(
            controller: _workspace,
            onAdd: _addAgendaEvent,
            onToggleDone: _setEventDone,
          ),
          GoalsScreen(
            controller: _workspace,
            onAdd: _addGoal,
            onIncrement: _incrementGoal,
          ),
        ],
      ),
      bottomNavigationBar: FloatingNavBar(
        items: _navItems,
        selectedIndex: _tab.index,
        onSelected: (index) => _select(_Tab.values[index]),
        onAdd: _onAdd,
        addTooltip: _addTooltip,
      ),
    );
  }
}
