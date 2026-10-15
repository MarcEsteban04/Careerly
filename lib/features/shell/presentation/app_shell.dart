import 'dart:typed_data';

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
import '../../documents/data/career_document.dart';
import '../../documents/data/documents_repository.dart';
import '../../goals/data/goal.dart';
import '../../goals/data/goals_repository.dart';
import '../../goals/presentation/goal_form_sheet.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../profile/data/career_profile_repository.dart';
import '../../profile/presentation/career_profile_sheet.dart';
import '../../resume/data/resume_insights.dart';
import '../../resume/data/resume_reader.dart';
import '../../settings/presentation/account_sheet.dart';
import '../../studio/data/career_writer.dart';
import '../../studio/data/studio_controller.dart';
import '../../studio/presentation/cover_letter_screen.dart';
import '../../studio/presentation/document_screen.dart';
import '../../studio/presentation/resume_enhance_screen.dart';
import '../../studio/presentation/studio_screen.dart';
import '../data/workspace_controller.dart';
import 'widgets/floating_nav_bar.dart';
import 'widgets/quick_add_sheet.dart';

enum _Tab { home, jobs, agenda, goals, studio }

/// Signed-in app: the tabs, the floating nav bar and the "+" button.
class AppShell extends StatefulWidget {
  AppShell({
    super.key,
    required this.authRepository,
    required this.appLock,
    ApplicationsRepository? applications,
    AgendaRepository? agenda,
    GoalsRepository? goals,
    this.discover,
    this.studio,
  })  : applications = applications ?? ApplicationsRepository(),
        agenda = agenda ?? AgendaRepository(),
        goals = goals ?? GoalsRepository();

  final AuthRepository authRepository;
  final AppLockRepository appLock;
  final ApplicationsRepository applications;
  final AgendaRepository agenda;
  final GoalsRepository goals;

  /// Overrides for tests; built from the app config when null.
  final DiscoverController? discover;
  final StudioController? studio;

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
    FloatingNavItem(
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      label: 'Studio',
    ),
  ];

  /// AI for every feature: Gemini, then Groq, then OpenAI as a last resort.
  late final _ai = AiChain([
    GeminiProvider(apiKey: Env.geminiApiKey),
    GroqProvider(apiKey: Env.groqApiKey),
    OpenAiProvider(apiKey: Env.openAiApiKey),
  ]);

  late final _workspace = WorkspaceController(
    applications: widget.applications,
    agenda: widget.agenda,
    goals: widget.goals,
  )..load();

  late final DiscoverController _discover = widget.discover ??
      DiscoverController(
        jsearch: JSearchClient(apiKey: Env.jsearchApiKey),
        jooble: JoobleClient(apiKey: Env.joobleApiKey),
        profiles: CareerProfileRepository(),
        aiSearch: AiJobSearchClient(_ai),
        aiRanker: AiJobRanker(_ai),
        resumeReader: ResumeReader(_ai),
      );

  late final StudioController _studio = (widget.studio ??
      StudioController(
        documents: DocumentsRepository(),
        writer: CareerWriter(_ai),
        profile: () => _discover.profile,
      ))
    ..load();

  _Tab _tab = _Tab.home;
  ApplicationStatus? _jobsFilter;
  final _jobsSearch = TextEditingController();
  final _jobsSearchFocus = FocusNode();
  final _discoverSearch = TextEditingController();
  JobsSection _jobsSection = JobsSection.tracked;

  @override
  void dispose() {
    _workspace.dispose();
    _discover.dispose();
    _studio.dispose();
    _jobsSearch.dispose();
    _jobsSearchFocus.dispose();
    _discoverSearch.dispose();
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

  void _showMessage(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<T?> _push<T>(Widget screen) => Navigator.of(context).push<T>(
        MaterialPageRoute<T>(builder: (_) => screen),
      );

  // Job discovery -----------------------------------------------------------

  JobApplication? _trackedFor(RankedListing ranked) {
    for (final a in _workspace.data?.applications ?? const <JobApplication>[]) {
      if (a.jobUrl == ranked.listing.applyUrl) return a;
    }
    return null;
  }

  bool _isListingSaved(RankedListing ranked) => _trackedFor(ranked) != null;

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

  JobContext _contextForListing(RankedListing ranked) {
    final job = ranked.listing;
    return JobContext(
      title: job.title,
      company: job.company,
      location: job.isRemote ? 'Remote' : job.location,
      description: [
        job.description,
        if (job.qualifications.isNotEmpty)
          'Qualifications:\n- ${job.qualifications.join('\n- ')}',
        if (job.responsibilities.isNotEmpty)
          'Responsibilities:\n- ${job.responsibilities.join('\n- ')}',
      ].where((s) => s.trim().isNotEmpty).join('\n\n'),
      applicationId: _trackedFor(ranked)?.id,
    );
  }

  void _openListing(RankedListing ranked) {
    _push<void>(
      JobListingScreen(
        ranked: ranked,
        isSaved: _isListingSaved(ranked),
        onSave: () => _saveListing(ranked),
        onWriteCoverLetter: () => _writeCoverLetter(_contextForListing(ranked)),
        onTailorResume: () => _enhanceResume(_contextForListing(ranked)),
      ),
    );
  }

  /// Reads a resume and keeps its full text for AI writing.
  Future<ResumeInsights> _readResume(Uint8List bytes, String fileName) async {
    final read = await _discover.readResume(bytes, fileName);
    final text = read.text;
    if (text == null) return read.insights;
    final id = await _studio.saveResumeText(fileName, text);
    return read.insights.withTextDocument(id);
  }

  Future<void> _editCareerProfile() async {
    final saved = await showCareerProfileSheet(
      context,
      initial: _discover.profile,
      onSave: _discover.saveProfile,
      canReadResumes: _discover.canReadResumes,
      onReadResume: _readResume,
    );
    if (saved) {
      _showMessage('Profile saved. Matches updated.');
      setState(() {});
    }
  }

  // Studio ------------------------------------------------------------------

  void _enhanceResume([JobContext? job]) {
    _push<void>(
      ResumeEnhanceScreen(
        studio: _studio,
        suggestedRoles: _discover.suggestions,
        onUploadResume: _editCareerProfile,
        job: job,
      ),
    );
  }

  void _writeCoverLetter([JobContext? job]) {
    _push<void>(
      CoverLetterScreen(
        studio: _studio,
        onUploadResume: _editCareerProfile,
        job: job,
        trackedApplications: _workspace.data?.applications ?? const [],
      ),
    );
  }

  void _openDocument(CareerDocument document) {
    _push<void>(DocumentScreen.saved(studio: _studio, document: document));
  }

  // Tracker -----------------------------------------------------------------

  JobContext _contextForApplication(JobApplication application) => JobContext(
        title: application.role,
        company: application.company,
        location: application.location,
        applicationId: application.id,
      );

  void _openApplication(String id) {
    _push<void>(
      ApplicationDetailScreen(
        applicationId: id,
        controller: _workspace,
        agenda: widget.agenda,
        onWriteCoverLetter: (a) => _writeCoverLetter(_contextForApplication(a)),
        onTailorResume: (a) => _enhanceResume(_contextForApplication(a)),
      ),
    );
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
      case _Tab.studio:
        _writeCoverLetter();
    }
  }

  String get _addTooltip => switch (_tab) {
        _Tab.home => 'Add',
        _Tab.jobs => 'New application',
        _Tab.agenda => 'New interview or reminder',
        _Tab.goals => 'New goal',
        _Tab.studio => 'New cover letter',
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
            discover: _discover,
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
          StudioScreen(
            studio: _studio,
            onUploadResume: _editCareerProfile,
            onEnhanceResume: _enhanceResume,
            onWriteCoverLetter: _writeCoverLetter,
            onOpenDocument: _openDocument,
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
