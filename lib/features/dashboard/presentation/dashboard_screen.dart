import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../agenda/data/agenda_repository.dart';
import '../../agenda/presentation/agenda_event_form_sheet.dart';
import '../../applications/data/applications_repository.dart';
import '../../applications/data/job_application.dart';
import '../../applications/presentation/application_form_sheet.dart';
import '../../auth/data/app_lock_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../goals/data/goal.dart';
import '../../goals/data/goals_repository.dart';
import '../../goals/presentation/goal_form_sheet.dart';
import '../../settings/presentation/account_sheet.dart';
import '../data/dashboard_data.dart';
import 'widgets/agenda_tile.dart';
import 'widgets/ai_tools_row.dart';
import 'widgets/application_tile.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_skeleton.dart';
import 'widgets/goal_tile.dart';
import 'widgets/pipeline_card.dart';
import 'widgets/quick_add_sheet.dart';
import 'widgets/week_summary_card.dart';

class DashboardScreen extends StatefulWidget {
  DashboardScreen({
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
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _agendaPreview = 4;
  static const _recentPreview = 5;

  DashboardData? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (applications, upcoming, goals) = await (
        widget.applications.fetchAll(),
        widget.agenda.fetchUpcoming(),
        widget.goals.fetchAll(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _error = null;
        _data = DashboardData(
          applications: applications,
          upcoming: upcoming,
          goals: goals,
        );
      });
    } on ParallelWaitError<dynamic, dynamic> catch (e) {
      final errors = e.errors as (AsyncError?, AsyncError?, AsyncError?);
      final first = errors.$1 ?? errors.$2 ?? errors.$3;
      if (mounted) setState(() => _error = first?.error ?? e);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openQuickAdd() async {
    final action = await showQuickAddSheet(context);
    if (!mounted || action == null) return;
    switch (action) {
      case QuickAddAction.application:
        await _addApplication();
      case QuickAddAction.agendaEvent:
        await _addAgendaEvent();
      case QuickAddAction.goal:
        await _addGoal();
    }
  }

  Future<void> _addApplication() async {
    final created = await showApplicationFormSheet(
      context,
      repository: widget.applications,
    );
    if (created == null || !mounted) return;
    _showMessage('Added ${created.role} at ${created.company}');
    await _load();
  }

  Future<void> _addAgendaEvent() async {
    final created = await showAgendaEventFormSheet(
      context,
      repository: widget.agenda,
      applications: _data?.applications ?? const [],
    );
    if (created == null || !mounted) return;
    _showMessage('Added to your agenda');
    await _load();
  }

  Future<void> _addGoal() async {
    final created = await showGoalFormSheet(context, repository: widget.goals);
    if (created == null || !mounted) return;
    _showMessage('Goal created. You\'ve got this.');
    await _load();
  }

  /// Optimistically marks an event done; it drops off "Up next" on reload.
  Future<void> _toggleEventDone(String id, bool isDone) async {
    final data = _data;
    if (data == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _data = data.copyWith(
        upcoming: [
          for (final e in data.upcoming)
            e.id == id ? e.copyWith(isDone: isDone) : e,
        ],
      );
    });
    try {
      await widget.agenda.setDone(id, isDone: isDone);
    } catch (error) {
      if (!mounted) return;
      setState(() => _data = data);
      _showMessage(friendlyErrorMessage(error));
    }
  }

  Future<void> _incrementGoal(Goal goal) async {
    final data = _data;
    if (data == null) return;
    final updated = goal.copyWith(progress: goal.progress + 1);
    HapticFeedback.lightImpact();
    setState(() {
      _data = data.copyWith(
        goals: [for (final g in data.goals) g.id == goal.id ? updated : g],
      );
    });
    try {
      await widget.goals.setProgress(goal.id, updated.progress);
      if (updated.isComplete && mounted) {
        _showMessage('Goal complete: ${goal.title}');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _data = data);
      _showMessage(friendlyErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.authRepository.currentUserName;
    final email = widget.authRepository.currentUserEmail ?? '';
    final firstName = name?.split(RegExp(r'\s+')).first;
    final initial =
        (name ?? email).characters.firstOrNull?.toUpperCase() ?? '?';

    return Scaffold(
      floatingActionButton: _data == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openQuickAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                MediaQuery.paddingOf(context).top + AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xxl * 2,
              ),
              children: [
                DashboardHeader(
                  firstName: firstName,
                  initial: initial,
                  onAccountTap: () => showAccountSheet(
                    context,
                    authRepository: widget.authRepository,
                    appLock: widget.appLock,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final error = _error;
    final data = _data;

    if (data == null && error != null) {
      return Padding(
        key: const ValueKey('error'),
        padding: const EdgeInsets.only(top: AppSpacing.xl),
        child: EmptyState(
          icon: isMissingSchemaError(error)
              ? Icons.storage_rounded
              : Icons.cloud_off_rounded,
          title: isMissingSchemaError(error)
              ? 'One setup step left'
              : "Couldn't load your dashboard",
          message: friendlyErrorMessage(error),
          actionLabel: 'Try again',
          onAction: () {
            setState(() => _error = null);
            _load();
          },
        ),
      );
    }
    if (data == null) {
      return const DashboardSkeleton(key: ValueKey('loading'));
    }
    return _DashboardContent(
      key: const ValueKey('content'),
      data: data,
      agendaPreview: _agendaPreview,
      recentPreview: _recentPreview,
      onAddApplication: _addApplication,
      onAddAgendaEvent: _addAgendaEvent,
      onAddGoal: _addGoal,
      onToggleEventDone: _toggleEventDone,
      onIncrementGoal: _incrementGoal,
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    super.key,
    required this.data,
    required this.agendaPreview,
    required this.recentPreview,
    required this.onAddApplication,
    required this.onAddAgendaEvent,
    required this.onAddGoal,
    required this.onToggleEventDone,
    required this.onIncrementGoal,
  });

  final DashboardData data;
  final int agendaPreview;
  final int recentPreview;
  final VoidCallback onAddApplication;
  final VoidCallback onAddAgendaEvent;
  final VoidCallback onAddGoal;
  final void Function(String id, bool isDone) onToggleEventDone;
  final ValueChanged<Goal> onIncrementGoal;

  static const _sectionGap = SizedBox(height: AppSpacing.xl);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeekSummaryCard(
          appliedThisWeek: data.appliedThisWeek(),
          interviewsNextWeek: data.interviewsNextWeek(),
          offers: data.countWith(ApplicationStatus.offer),
        ),
        _sectionGap,
        SectionHeader(
          title: 'Up next',
          actionLabel: 'Add',
          onAction: onAddAgendaEvent,
        ),
        AppCard(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: data.upcoming.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'Nothing scheduled',
                    message: 'Add interviews, follow-ups and deadlines so '
                        'nothing slips.',
                    actionLabel: 'Add to agenda',
                    onAction: onAddAgendaEvent,
                  ),
                )
              : Column(
                  children: [
                    for (final event in data.upcoming.take(agendaPreview))
                      AgendaTile(
                        event: event,
                        onToggleDone: (done) =>
                            onToggleEventDone(event.id, done),
                      ),
                  ],
                ),
        ),
        _sectionGap,
        const SectionHeader(title: 'Pipeline'),
        PipelineCard(countOf: data.countWith),
        _sectionGap,
        SectionHeader(title: 'Goals', actionLabel: 'Add', onAction: onAddGoal),
        AppCard(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: data.goals.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: EmptyState(
                    icon: Icons.flag_outlined,
                    title: 'Set your first goal',
                    message: 'A small weekly target, like 5 applications, '
                        'keeps the momentum going.',
                    actionLabel: 'Create goal',
                    onAction: onAddGoal,
                  ),
                )
              : Column(
                  children: [
                    for (final goal in data.goals)
                      GoalTile(
                        goal: goal,
                        onIncrement: () => onIncrementGoal(goal),
                      ),
                  ],
                ),
        ),
        _sectionGap,
        const SectionHeader(title: 'AI tools'),
        const AiToolsRow(),
        _sectionGap,
        SectionHeader(
          title: 'Recent applications',
          actionLabel: 'Add',
          onAction: onAddApplication,
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: data.applications.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: EmptyState(
                    icon: Icons.work_outline_rounded,
                    title: 'No applications yet',
                    message: 'Track every role you save or apply for, all in '
                        'one place.',
                    actionLabel: 'Add application',
                    onAction: onAddApplication,
                  ),
                )
              : Column(
                  children: [
                    for (final application
                        in data.applications.take(recentPreview))
                      ApplicationTile(application: application),
                  ],
                ),
        ),
      ],
    );
  }
}
