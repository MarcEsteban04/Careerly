import 'package:flutter/material.dart';

import '../../../core/ai/ai_chain.dart';
import '../../../core/ai/providers.dart';
import '../../../core/config/env.dart';
import '../../../core/utils/error_message.dart';
import '../../agenda/data/agenda_repository.dart';
import '../../agenda/presentation/agenda_event_form_sheet.dart';
import '../../agenda/presentation/agenda_screen.dart';
import '../../applications/data/applications_repository.dart';
import '../../applications/data/job_application.dart';
import '../../applications/presentation/application_detail_screen.dart';
import '../../applications/presentation/application_form_sheet.dart';
import '../../applications/presentation/applications_screen.dart';
import '../../auth/data/app_lock_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../discover/data/ai_job_ranker.dart';
import '../../discover/data/ai_job_search_client.dart';
import '../../discover/data/discover_controller.dart';
import '../../discover/data/jooble_client.dart';
import '../../discover/data/jsearch_client.dart';
import '../../discover/presentation/job_listing_screen.dart';
import '../../goals/data/goal.dart';
import '../../goals/data/goals_repository.dart';
import '../../goals/presentation/goal_form_sheet.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../profile/data/career_profile_repository.dart';
import '../../profile/presentation/career_profile_sheet.dart';
import '../../resume/data/resume_reader.dart';
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
    DiscoverController? discover,
  })  : applications = applications ?? ApplicationsRepository(),
        agenda = agenda ?? AgendaRepository(),
        goals = goals ?? GoalsRepository(),
        discover = discover ?? _defaultDiscover();

  /// Job search wired to the configured APIs, with AI (Gemini, then Groq,
  /// then OpenAI as a last resort) for resumes, ranking and backup search.
  static DiscoverController _defaultDiscover() {
    final ai = AiChain([
      GeminiProvider(apiKey: Env.geminiApiKey),
      GroqProvider(apiKey: Env.groqApiKey),
      OpenAiProvider(apiKey: Env.openAiApiKey),
    ]);
    return DiscoverController(
      jsearch: JSearchClient(apiKey: Env.jsearchApiKey),
      jooble: JoobleClient(apiKey: Env.joobleApiKey),
      profiles: CareerProfileRepository(),
      aiSearch: AiJobSearchClient(ai),
      aiRanker: AiJobRanker(ai),
      resumeReader: ResumeReader(ai),
    );
  }

  final AuthRepository authRepository;
  final AppLockRepository appLock;
  final ApplicationsRepository applications;
  final AgendaRepository agenda;
  final GoalsRepository goals;
  final DiscoverController discover;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _navItems = [
    FloatingNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
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
  final _jobsSearch = TextEditingController();
  final _jobsSearchFocus = FocusNode();
  final _discoverSearch = TextEditingController();
  JobsSection _jobsSection = JobsSection.tracked;

  @override
  void dispose() {
    _workspace.dispose();
    _jobsSearch.dispose();
    _jobsSearchFocus.dispose();
    _discoverSearch.dispose();
    widget.discover.dispose();
    super.dispose();
  }

  void _select(_Tab tab) => setState(() => _tab = tab);

  void _openJobs(ApplicationStatus? filter) => setState(() {
        _jobsFilter = filter;
        _tab = _Tab.jobs;
      });

  /// From the dashboard's search pill: jump to Jobs with the search focused.
  void _openJobsSearch() {
    setState(() => _tab = _Tab.jobs);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _jobsSearchFocus.requestFocus(),
    );
  }

  bool _isListingSaved(RankedListing ranked) =>
      _workspace.data?.applications
          .any((a) => a.jobUrl == ranked.listing.applyUrl) ??
      false;

  /// Adds a found job to the tracker as "Saved".
  Future<bool> _saveListing(RankedListing ranked) async {
    final job = ranked.listing;
    try {
      await widget.applications.create(
        company: job.company,
        role: job.title,
        status: ApplicationStatus.saved,
        location: job.isRemote && job.location == null ? 'Remote' : job.location,
        jobUrl: job.applyUrl,
        salary: job.salary,
      );
      await _workspace.load();
      _showMessage('Saved to your tracker');
      return true;
    } catch (error) {
      _showMessage(friendlyErrorMessage(error));
      return false;
    }
  }

  void _openListing(RankedListing ranked) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JobListingScreen(
          ranked: ranked,
          isSaved: _isListingSaved(ranked),
          onSave: () => _saveListing(ranked),
        ),
      ),
    );
  }

  Future<void> _editCareerProfile() async {
    final saved = await showCareerProfileSheet(
      context,
      initial: widget.discover.profile,
      onSave: widget.discover.saveProfile,
      canReadResumes: widget.discover.canReadResumes,
      onReadResume: widget.discover.readResume,
    );
    if (saved) _showMessage('Profile saved. Matches updated.');
  }

  void _openApplication(String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ApplicationDetailScreen(
          applicationId: id,
          controller: _workspace,
          agenda: widget.agenda,
        ),
      ),
    );
  }

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
            name: name,
            initial:
                (name ?? email).characters.firstOrNull?.toUpperCase() ?? '?',
            onAccountTap: () => showAccountSheet(
              context,
              authRepository: widget.authRepository,
              appLock: widget.appLock,
            ),
            onSearchTap: _openJobsSearch,
            onOpenApplication: _openApplication,
            onSeeAllApplications: _openJobs,
            onAddApplication: _addApplication,
            onAddAgendaEvent: _addAgendaEvent,
            onEventDone: (id) => _setEventDone(id, true),
            onOpenAgenda: () => _select(_Tab.agenda),
          ),
          ApplicationsScreen(
            controller: _workspace,
            filter: _jobsFilter,
            onFilterChanged: (filter) => setState(() => _jobsFilter = filter),
            searchController: _jobsSearch,
            searchFocusNode: _jobsSearchFocus,
            onOpenApplication: _openApplication,
            onAdd: _addApplication,
            section: _jobsSection,
            onSectionChanged: (section) =>
                setState(() => _jobsSection = section),
            discover: widget.discover,
            discoverSearchController: _discoverSearch,
            isListingSaved: _isListingSaved,
            onOpenListing: _openListing,
            onEditProfile: _editCareerProfile,
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
