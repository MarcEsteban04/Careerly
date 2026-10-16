import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ai/ai_chain.dart';
import '../../../core/ai/providers.dart';
import '../../../core/config/env.dart';
import '../../../core/theme/app_accents.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/island_toast.dart';
import '../../agenda/data/agenda_event.dart';
import '../../agenda/data/agenda_repository.dart';
import '../../agenda/presentation/agenda_event_form_sheet.dart';
import '../../agenda/presentation/agenda_screen.dart';
import '../../applications/data/application_event.dart';
import '../../applications/data/applications_repository.dart';
import '../../applications/data/job_application.dart';
import '../../applications/data/stale_applications.dart';
import '../../applications/data/tracked_view.dart';
import '../../applications/presentation/application_detail_screen.dart';
import '../../applications/presentation/application_form_sheet.dart';
import '../../applications/presentation/applications_screen.dart';
import '../../applications/presentation/pick_application_sheet.dart';
import '../../applications/presentation/stale_applications_sheet.dart';
import '../../apply/data/answer_library.dart';
import '../../apply/data/applicant_details.dart';
import '../../apply/data/application_email.dart';
import '../../apply/data/form_filler.dart';
import '../../apply/presentation/applicant_details_sheet.dart';
import '../../apply/presentation/apply_browser_screen.dart';
import '../../apply/presentation/apply_confirm_dialog.dart';
import '../../apply/presentation/apply_kit_sheet.dart';
import '../../apply/presentation/email_apply_screen.dart';
import '../../ats/presentation/ats_screen.dart';
import '../../auth/data/app_lock_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../career_coach/data/career_coach.dart';
import '../../career_coach/data/coach_history_store.dart';
import '../../career_coach/presentation/coach_screen.dart';
import '../../company_research/data/company_researcher.dart';
import '../../company_research/presentation/company_research_card.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../discover/data/ai_job_search_client.dart';
import '../../discover/data/discover_controller.dart';
import '../../discover/data/discover_settings_store.dart';
import '../../discover/data/jooble_client.dart';
import '../../discover/data/jsearch_client.dart';
import '../../discover/data/search_preferences_repository.dart';
import '../../discover/presentation/job_listing_screen.dart';
import '../../documents/data/career_document.dart';
import '../../documents/data/document_markup.dart';
import '../../documents/data/document_pdf.dart';
import '../../documents/data/documents_repository.dart';
import '../../documents/data/resume_design.dart';
import '../../documents/presentation/resume_design_screen.dart';
import '../../goals/data/goal.dart';
import '../../goals/data/goals_repository.dart';
import '../../goals/presentation/goal_form_sheet.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../interview_prep/data/interview_coach.dart';
import '../../interview_prep/data/interview_prep_repository.dart';
import '../../interview_prep/presentation/interview_prep_screen.dart';
import '../../interview_prep/presentation/mock_interview_screen.dart';
import '../../job_alerts/data/job_alert_checker.dart';
import '../../job_alerts/data/job_alert_store.dart';
import '../../job_import/data/job_post_reader.dart';
import '../../job_import/data/job_share_inbox.dart';
import '../../job_import/presentation/import_job_flow.dart';
import '../../messages/data/message_writer.dart';
import '../../messages/presentation/message_composer_screen.dart';
import '../../negotiation/data/negotiation_coach.dart';
import '../../negotiation/presentation/negotiation_screen.dart';
import '../../notifications/data/local_notifications.dart';
import '../../notifications/data/notification_settings.dart';
import '../../notifications/data/notifications.dart';
import '../../notifications/presentation/notification_center_sheet.dart';
import '../../onboarding/presentation/get_started_screen.dart';
import '../../profile/data/career_profile_repository.dart';
import '../../profile/presentation/career_profile_sheet.dart';
import '../../reminders/data/reminder_scheduler.dart';
import '../../resume/data/resume_insights.dart';
import '../../resume/data/resume_reader.dart';
import '../../settings/data/avatar_repository.dart';
import '../../settings/presentation/profile_screen.dart';
import '../../studio/data/career_writer.dart';
import '../../studio/data/resume_versions.dart';
import '../../studio/data/studio_controller.dart';
import '../../studio/presentation/cover_letter_screen.dart';
import '../../studio/presentation/document_screen.dart';
import '../../studio/presentation/resume_enhance_screen.dart';
import '../../studio/presentation/studio_screen.dart';
import '../../studio/presentation/studio_tool.dart';
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
    ApplicationEventsRepository? events,
    Future<bool> Function(Uri url)? openUrl,
    Notifications? notifications,
    NotificationSettings? notificationSettings,
    this.interviewCoach,
    this.interviewPreps,
    this.avatars,
    this.jobPostReader,
    this.messageWriter,
    this.companyResearcher,
    this.negotiationCoach,
    this.careerCoach,
    this.coachHistory,
    this.formFiller,
    this.applicantDetails,
    this.answerLibrary,
    this.applyPage,
    JobShareInbox? shareInbox,
    this.afterSignIn,
  })  : shareInbox = shareInbox ?? const PlatformJobShareInbox(),
        events = events ?? ApplicationEventsRepository(),
        openUrl = openUrl ?? _openExternally,
        applications = applications ?? ApplicationsRepository(),
        agenda = agenda ?? AgendaRepository(),
        goals = goals ?? GoalsRepository(),
        notifications = notifications ?? LocalNotifications.instance,
        notificationSettings = notificationSettings ?? NotificationSettings();

  final AuthRepository authRepository;
  final AppLockRepository appLock;
  final Notifications notifications;
  final NotificationSettings notificationSettings;

  /// Runs once the app is showing after a fresh sign-in (e.g. to offer
  /// biometric unlock), unless Get started is shown instead.
  final VoidCallback? afterSignIn;
  final ApplicationsRepository applications;
  final AgendaRepository agenda;
  final GoalsRepository goals;
  final ApplicationEventsRepository events;

  /// Opens job application pages; replaceable in tests.
  final Future<bool> Function(Uri url) openUrl;

  static Future<bool> _openExternally(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  /// Overrides for tests; built from the app config when null.
  final DiscoverController? discover;
  final StudioController? studio;
  final InterviewCoach? interviewCoach;
  final InterviewPrepRepository? interviewPreps;
  final AvatarRepository? avatars;
  final JobPostReader? jobPostReader;
  final MessageWriter? messageWriter;
  final CompanyResearcher? companyResearcher;
  final NegotiationCoach? negotiationCoach;
  final CareerCoach? careerCoach;
  final CoachHistoryStore? coachHistory;
  final FormFiller? formFiller;
  final ApplicantDetailsStore? applicantDetails;
  final AnswerLibrary? answerLibrary;

  /// Opens an application page; defaults to Careerly's own browser with
  /// form filling. Replaceable in tests, which can't host a web view.
  final Future<ApplyPageExit> Function(Uri url)? applyPage;

  /// Jobs shared into the app from other apps.
  final JobShareInbox shareInbox;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
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
        resumeReader: ResumeReader(_ai),
        preferences: SearchPreferencesRepository(),
        settings: DiscoverSettingsStore(),
        alerts: _alertStore,
      );

  final _alertStore = JobAlertStore();

  late final _reminders = ReminderScheduler(
    notifications: widget.notifications,
    settings: widget.notificationSettings,
  );

  late final _jobAlerts = JobAlertChecker(
    store: _alertStore,
    settings: widget.notificationSettings,
    notifications: widget.notifications,
    jsearch: _discover.jsearch,
    jooble: _discover.jooble,
  );

  late final _coach = widget.interviewCoach ?? InterviewCoach(_ai);
  late final _interviewPreps =
      widget.interviewPreps ?? InterviewPrepRepository();
  late final _avatars = widget.avatars ?? AvatarRepository();

  /// Tracked list or board, sort, filters and bulk selection.
  final _trackedView = TrackedViewController(prefs: SharedPreferencesAsync());
  late final _jobPostReader = widget.jobPostReader ?? JobPostReader(_ai);
  late final _messageWriter = widget.messageWriter ?? MessageWriter(_ai);
  late final _companyResearcher =
      widget.companyResearcher ?? CompanyResearcher(_ai);
  late final _negotiationCoach =
      widget.negotiationCoach ?? NegotiationCoach(_ai);
  late final _careerCoach = widget.careerCoach ?? CareerCoach(_ai);
  late final _coachHistory = widget.coachHistory ?? CoachHistoryStore();
  late final _formFiller = widget.formFiller ?? FormFiller(_ai);
  late final _applicantDetails =
      widget.applicantDetails ?? ApplicantDetailsStore();
  final _resumeDesigns = ResumeDesignStore();
  late final _answerLibrary = widget.answerLibrary ?? AnswerLibrary();

  /// True while an application page is open in Careerly, so returning
  /// from a file picker doesn't ask "Did you apply?" too early.
  bool _applyPageOpen = false;

  StreamSubscription<String>? _notificationTaps;
  StreamSubscription<String>? _shares;

  /// Agenda state last sent to the reminder scheduler.
  String? _remindersKey;

  /// A saved search a notification asked for before searches had loaded.
  String? _pendingSearchId;

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

  /// Set while the user is on a job's application page, so we can ask
  /// whether they applied when they come back.
  _PendingApply? _pendingApply;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _workspace.addListener(_syncReminders);
    _discover.addListener(_runPendingSearch);
    _notificationTaps = widget.notifications.taps.listen(_openNotification);
    _shares = widget.shareInbox.shares.listen(_importJob);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startUp());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_applyPageOpen) _confirmPendingApply();
      // The background check may have found jobs while we were away.
      _discover.refreshAlerts();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTaps?.cancel();
    _shares?.cancel();
    _workspace.removeListener(_syncReminders);
    _discover.removeListener(_runPendingSearch);
    _workspace.dispose();
    _discover.dispose();
    _studio.dispose();
    _jobsSearch.dispose();
    _jobsSearchFocus.dispose();
    _discoverSearch.dispose();
    _trackedView.dispose();
    super.dispose();
  }

  void _select(_Tab tab) {
    _trackedView.clearSelection();
    setState(() => _tab = tab);
  }

  // Tracked: board moves and bulk actions ------------------------------------

  /// Moves [applications] to [status]. A single move (e.g. a board drop)
  /// can be undone from the snackbar.
  Future<void> _moveApplications(
    List<JobApplication> applications,
    ApplicationStatus status,
  ) async {
    final moving = [
      for (final a in applications)
        if (a.status != status) a,
    ];
    _trackedView.clearSelection();
    if (moving.isEmpty) return;

    var failed = 0;
    for (final application in moving) {
      try {
        final updated =
            await widget.applications.updateStatus(application, status);
        _workspace.replaceApplication(updated);
      } catch (error) {
        debugPrint('Moving ${application.id} failed: $error');
        failed++;
      }
    }
    if (!mounted) return;

    final moved = moving.length - failed;
    if (moved == 0) {
      _showMessage("Couldn't move that. Check your connection and try again.");
      return;
    }
    final label = moved == 1
        ? '${moving.first.role} moved to ${status.label}'
        : 'Moved $moved to ${status.label}';
    final single = moving.length == 1 ? moving.first : null;
    Island.show(
      context,
      failed == 0 ? label : "$label. $failed couldn't move.",
      tone: failed == 0 ? IslandTone.success : IslandTone.error,
      icon: Icons.swap_horiz_rounded,
      actionLabel: single == null ? null : 'Undo',
      onAction: single == null
          ? null
          : () async {
                    final current =
                        _workspace.data?.applicationById(single.id) ?? single;
                    try {
                      final restored = await widget.applications
                          .updateStatus(current, single.status);
                      _workspace.replaceApplication(restored);
                    } catch (error) {
                      _showMessage(friendlyErrorMessage(error));
                    }
                  },
    );
  }

  Future<void> _deleteApplications(List<JobApplication> applications) async {
    if (applications.isEmpty) return;
    final count = applications.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          count == 1 ? 'Delete 1 application?' : 'Delete $count applications?',
        ),
        content: const Text(
          'They\'ll be removed with their timeline and notes. Linked agenda '
          'items stay but lose the link.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _trackedView.clearSelection();
    var failed = 0;
    for (final application in applications) {
      if (await _workspace.deleteApplication(application.id) != null) failed++;
    }
    final deleted = count - failed;
    _showMessage(
      failed == 0
          ? (deleted == 1 ? 'Deleted 1 application' : 'Deleted $deleted applications')
          : "Deleted $deleted. $failed couldn't be deleted.",
    );
  }

  // Start-up -------------------------------------------------------------------

  Future<void> _startUp() async {
    if (!mounted) return;
    try {
      final payload = await widget.notifications.takeLaunchPayload();
      if (payload != null) _openNotification(payload);
    } catch (e) {
      debugPrint('Launch notification unavailable: $e');
    }
    if (!mounted) return;

    final profiles = _discover.profiles;
    if (!profiles.isOnboarded && _discover.profile.isEmpty) {
      await _getStarted();
    } else {
      widget.afterSignIn?.call();
    }

    final shared = await widget.shareInbox.takeInitial();
    if (shared != null && mounted) await _importJob(shared);
    await _checkJobAlerts();
  }

  /// A job link or post shared in from another app, or pasted.
  Future<void> _importJob(String shared) async {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    final created = await importSharedJob(
      context,
      shared: shared,
      reader: _jobPostReader,
      applications: widget.applications,
    );
    if (created == null || !mounted) return;
    await _workspace.load();
    _showMessage('Added ${created.role} at ${created.company}');
  }

  /// First-run setup, which also builds the career profile.
  Future<void> _getStarted() async {
    final result = await Navigator.of(context).push<GetStartedResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GetStartedScreen(
          firstName: widget.authRepository.currentUserName?.split(' ').first,
          initial: _discover.profile,
          canReadResumes: _discover.canReadResumes,
          onReadResume: _readResume,
          onSaveProfile: _discover.saveProfile,
          notifications: widget.notifications,
          settings: widget.notificationSettings,
          appLock: widget.appLock,
        ),
      ),
    );
    try {
      await _discover.profiles.markOnboarded();
    } catch (e) {
      debugPrint("Couldn't record onboarding: $e");
    }
    if (!mounted) return;
    _syncReminders(force: true);
    if (result == GetStartedResult.findJobs) {
      setState(() {
        _tab = _Tab.jobs;
        _jobsSection = JobsSection.discover;
      });
      _discover.search('');
    } else {
      setState(() {});
    }
  }

  // Notifications --------------------------------------------------------------

  /// Keeps scheduled reminders in step with the agenda.
  void _syncReminders({bool force = false}) {
    final upcoming = _workspace.data?.upcoming;
    if (upcoming == null) return;
    final key = [
      for (final e in upcoming)
        '${e.id}|${e.startsAt.toIso8601String()}|${e.isDone}|${e.title}',
    ].join(';');
    if (!force && key == _remindersKey) return;
    _remindersKey = key;
    _reminders.sync(upcoming);
  }

  /// Runs an overdue job-alert check while the app is open (the OS may
  /// defer the background one), then refreshes the "new" badges.
  Future<void> _checkJobAlerts() async {
    try {
      if (await _jobAlerts.isDue()) await _jobAlerts.run(notify: false);
    } catch (e) {
      debugPrint('Job alert check failed: $e');
    }
    await _discover.refreshAlerts();
  }

  void _openNotification(String payload) {
    final route = NotificationRoute.parse(payload);
    if (route == null || !mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    switch (route) {
      case OpenApplicationRoute(:final applicationId):
        _openApplication(applicationId);
      case OpenSavedSearchRoute(:final searchId):
        _openSavedSearch(searchId);
      case OpenAgendaRoute():
        _select(_Tab.agenda);
    }
  }

  void _openSavedSearch(String id) {
    setState(() {
      _tab = _Tab.jobs;
      _jobsSection = JobsSection.discover;
    });
    if (!_runSavedSearch(id)) _pendingSearchId = id;
  }

  bool _runSavedSearch(String id) {
    final search = _discover.savedSearches.where((s) => s.id == id).firstOrNull;
    if (search == null) return false;
    _discoverSearch.text = search.keywords;
    _discover.runSavedSearch(search);
    return true;
  }

  void _runPendingSearch() {
    final id = _pendingSearchId;
    if (id != null && _runSavedSearch(id)) _pendingSearchId = null;
  }

  void _openNotificationCenter() {
    final until = DateTime.now().add(const Duration(days: 2));
    showNotificationCenter(
      context,
      alerts: [
        for (final search in _discover.savedSearches)
          if (_discover.freshCount(search) > 0)
            (search, _discover.freshCount(search)),
      ],
      upcoming: [
        for (final event in _workspace.data?.upcoming ?? const <AgendaEvent>[])
          if (!event.isDone && event.startsAt.isBefore(until)) event,
      ].take(6).toList(),
      onOpenSearch: (search) => _openSavedSearch(search.id),
      onOpenEvent: (event) => event.applicationId == null
          ? _select(_Tab.agenda)
          : _openApplication(event.applicationId!),
      onOpenSettings: _openProfile,
    );
  }

  /// Open agenda items in the next 24 hours, shown as a badge on Agenda.
  int get _dueSoonCount {
    final until = DateTime.now().add(const Duration(days: 1));
    return _workspace.data?.upcoming
            .where((e) => !e.isDone && e.startsAt.isBefore(until))
            .length ??
        0;
  }

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
    Island.show(context, message);
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
    try {
      await _createFromListing(ranked, status: ApplicationStatus.saved);
      await _workspace.load();
      _showMessage('Saved to your tracker');
      return true;
    } catch (error) {
      _showMessage(friendlyErrorMessage(error));
      return false;
    }
  }

  Future<JobApplication> _createFromListing(
    RankedListing ranked, {
    required ApplicationStatus status,
    String? resumeDocumentId,
    String? coverLetterDocumentId,
    DateTime? followUpOn,
  }) {
    final job = ranked.listing;
    final context = _contextForListing(ranked);
    return widget.applications.create(
      company: job.company,
      role: job.title,
      status: status,
      location: job.isRemote && job.location == null ? 'Remote' : job.location,
      jobUrl: job.applyUrl,
      salary: job.salary,
      appliedOn: status == ApplicationStatus.saved ? null : DateTime.now(),
      source: job.source,
      externalId: job.id,
      jobDescription: context.description,
      resumeDocumentId: resumeDocumentId,
      coverLetterDocumentId: coverLetterDocumentId,
      followUpOn: followUpOn,
    );
  }

  Future<void> _dismissListing(RankedListing ranked) async {
    final error = await _discover.dismiss(ranked.listing);
    if (!mounted) return;
    if (error != null) {
      _showMessage(error);
      return;
    }
    Island.show(
      context,
      'Hid ${ranked.listing.title}',
      tone: IslandTone.info,
      icon: Icons.visibility_off_outlined,
      actionLabel: 'Undo',
      onAction: () => _discover.undoDismiss(ranked.listing),
    );
  }

  Future<void> _toggleSaveSearch() async {
    final wasSaved = _discover.isCurrentSearchSaved;
    final error = await _discover.toggleSaveCurrentSearch();
    _showMessage(error ?? (wasSaved ? 'Search removed' : 'Search saved'));
  }

  // Applying ------------------------------------------------------------------

  /// Opens the application kit, then the job's application page. When the
  /// user returns, [_confirmPendingApply] asks whether they applied.
  Future<void> _startApply({
    required JobContext job,
    required String applyUrl,
    JobApplication? application,
    RankedListing? listing,
  }) async {
    final uri = Uri.tryParse(applyUrl.trim());
    final canOpenPage =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final email = ApplicationEmail.find(
      description: job.description,
      applyUrl: applyUrl,
    );
    final result = await showApplyKitSheet(
      context,
      studio: _studio,
      job: job,
      applyEmail: email,
      canOpenPage: canOpenPage || email == null,
    );
    if (!mounted || result == null) return;

    switch (result) {
      case WriteCoverLetterFirst():
        _writeCoverLetter(job);
      case OpenApplication(:final choice):
        if (!canOpenPage) {
          _showMessage("This job doesn't have a valid application link.");
          return;
        }
        _pendingApply = _PendingApply(
          job: job,
          application: application,
          listing: listing,
          choice: choice,
        );
        _applyPageOpen = true;
        final ApplyPageExit exit;
        try {
          exit = await (widget.applyPage?.call(uri) ??
              _openApplyPage(uri, job: job, choice: choice));
        } finally {
          _applyPageOpen = false;
        }
        switch (exit) {
          case ApplyPageExit.closed:
            await _confirmPendingApply();
          case ApplyPageExit.submitted:
            // She saw the confirmation page: no need to ask.
            await _confirmPendingApply(
              answer: const ApplyConfirmation(followUp: true),
            );
          case ApplyPageExit.openedExternally:
            // The question waits until she's back from her browser.
            break;
        }
      case ApplyByEmail(:final choice):
        _pendingApply = _PendingApply(
          job: job,
          application: application,
          listing: listing,
          choice: choice,
        );
        _applyPageOpen = true;
        final bool? sent;
        try {
          sent = await _push<bool>(
            EmailApplyScreen(
              to: email!,
              job: job,
              writer: _messageWriter,
              profile: _discover.profile,
              senderName: widget.authRepository.currentUserName,
              resume: _attachmentFor(choice.resumeDocumentId),
            ),
          );
        } finally {
          _applyPageOpen = false;
        }
        if (sent == true) {
          await _confirmPendingApply();
        } else {
          _pendingApply = null;
        }
    }
  }

  /// The application page in Careerly's browser, with form filling.
  Future<ApplyPageExit> _openApplyPage(
    Uri uri, {
    required JobContext job,
    required ApplyKitChoice choice,
  }) async {
    final exit = await Navigator.of(context).push<ApplyPageExit>(
      MaterialPageRoute(
        builder: (_) => ApplyBrowserScreen(
          url: uri,
          job: job,
          filler: _formFiller,
          loadApplicant: () => _applicant(choice),
          editDetails: _editApplicantDetails,
          openExternally: widget.openUrl,
          companyBrief: () async =>
              (await _companyResearcher.cached(job.company))?.summary,
          resume: _attachmentFor(choice.resumeDocumentId),
          savedAnswers: _answerLibrary.load,
          onAnswersUsed: (answers) =>
              _answerLibrary.remember(answers, company: job.company),
        ),
      ),
    );
    return exit ?? ApplyPageExit.closed;
  }

  /// Everything the form filler knows about her.
  Future<Applicant> _applicant(ApplyKitChoice choice) async {
    final details = await _applicantDetails.load();
    String? resume;
    try {
      final id = choice.resumeDocumentId;
      resume = id == null
          ? await _studio.resumeText()
          : await _studio.resumeContent(id);
    } catch (_) {
      // No resume yet: the form can still be filled from her details.
    }
    return Applicant(
      name: widget.authRepository.currentUserName,
      email: widget.authRepository.currentUserEmail,
      details: details,
      profile: _discover.profile,
      resumeText: resume == null ? null : markupToPlainText(resume),
    );
  }

  /// A saved Studio resume as a PDF to upload. The original upload isn't
  /// offered: she can pick that file from her phone.
  ApplyAttachment? _attachmentFor(String? documentId) {
    if (documentId == null) return null;
    final doc = _studio.items?.where((d) => d.id == documentId).firstOrNull;
    if (doc == null || doc.kind != DocumentKind.resume) return null;
    return ApplyAttachment(
      fileName: DocumentPdf.fileNameFor(doc.title),
      bytes: () async => DocumentPdf.build(
        doc.content,
        design: await _resumeDesigns.load(),
      ),
    );
  }

  Future<void> _editApplicantDetails() async {
    final saved =
        await showApplicantDetailsSheet(context, store: _applicantDetails);
    if (saved != null) _showMessage('Application details saved');
  }

  /// Records the pending application as applied, asking "Did you apply?"
  /// unless [answer] already says so.
  Future<void> _confirmPendingApply({ApplyConfirmation? answer}) async {
    final pending = _pendingApply;
    if (pending == null || !mounted) return;
    _pendingApply = null;

    answer ??= await showApplyConfirmDialog(
      context,
      jobLabel: pending.job.label,
    );
    if (answer == null || !mounted) return;

    final followUpOn = answer.followUp
        ? DateTime.now().add(const Duration(days: 7))
        : null;
    try {
      final existing = pending.application ??
          (pending.listing == null ? null : _trackedFor(pending.listing!));
      final JobApplication applied;
      if (existing != null) {
        applied = await widget.applications.markApplied(
          existing,
          resumeDocumentId: pending.choice.resumeDocumentId,
          coverLetterDocumentId: pending.choice.coverLetterDocumentId,
          followUpOn: followUpOn,
        );
      } else {
        applied = await _createFromListing(
          pending.listing!,
          status: ApplicationStatus.applied,
          resumeDocumentId: pending.choice.resumeDocumentId,
          coverLetterDocumentId: pending.choice.coverLetterDocumentId,
          followUpOn: followUpOn,
        );
      }
      if (followUpOn != null) {
        await widget.agenda.create(
          kind: AgendaEventKind.followUp,
          title: 'Follow up with ${applied.company}',
          startsAt: DateTime(followUpOn.year, followUpOn.month, followUpOn.day, 10),
          applicationId: applied.id,
        );
      }
      await _workspace.load();
      HapticFeedback.mediumImpact();
      _showMessage(
        followUpOn == null
            ? 'Marked as applied. Good luck!'
            : "Marked as applied. We'll remind you to follow up in a week.",
      );
    } catch (error) {
      _showMessage(friendlyErrorMessage(error));
    }
  }

  // Agenda ----------------------------------------------------------------------

  Future<void> _editAgendaEvent(AgendaEvent event) async {
    final updated = await showAgendaEventFormSheet(
      context,
      repository: widget.agenda,
      applications: _workspace.data?.applications ?? const [],
      existing: event,
    );
    if (updated == null) return;
    _showMessage('Agenda item updated');
    await _workspace.load();
  }

  Future<bool> _deleteAgendaEvent(AgendaEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this item?'),
        content: Text('"${event.title}" will be removed from your agenda.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    try {
      await widget.agenda.delete(event.id);
      await _workspace.load();
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
        profileYears: _discover.profile.effectiveYears,
        isSaved: _isListingSaved(ranked),
        onSave: () => _saveListing(ranked),
        onWriteCoverLetter: () => _writeCoverLetter(_contextForListing(ranked)),
        onTailorResume: () => _enhanceResume(_contextForListing(ranked)),
        onAtsCheck: () => _openAts(_contextForListing(ranked)),
        researcher: _companyResearcher,
        jobContext: _contextForListing(ranked),
        onApply: () => _startApply(
          job: _contextForListing(ranked),
          applyUrl: ranked.listing.applyUrl,
          application: _trackedFor(ranked),
          listing: ranked,
        ),
        onNotInterested: () => _dismissListing(ranked),
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

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          authRepository: widget.authRepository,
          appLock: widget.appLock,
          discover: _discover,
          onEditCareerProfile: _editCareerProfile,
          notifications: widget.notifications,
          notificationSettings: widget.notificationSettings,
          onNotificationSettingsChanged: () => _syncReminders(force: true),
          avatars: _avatars,
          onAvatarChanged: () => setState(() {}),
          applicantDetails: _applicantDetails,
          answerLibrary: _answerLibrary,
        ),
      ),
    );
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

  /// Drafts an email for [application]; [followUp] picks the follow-up that
  /// fits its stage.
  void _writeMessage(JobApplication application, {bool followUp = false}) {
    _push<void>(
      MessageComposerScreen(
        application: application,
        writer: _messageWriter,
        profile: _discover.profile,
        senderName: widget.authRepository.currentUserName,
        initialKind: !followUp
            ? null
            : application.status == ApplicationStatus.interviewing
                ? MessageKind.checkIn
                : MessageKind.followUp,
      ),
    );
  }

  /// Coaches salary negotiation for [application], with salaries seen for
  /// other tracked jobs and current search results as a reference.
  void _negotiate(JobApplication application) {
    final comparable = [
      for (final a in _workspace.data?.applications ?? const <JobApplication>[])
        if (a.id != application.id && a.salary != null)
          '${a.role} at ${a.company}: ${a.salary}',
      for (final r in _discover.results ?? const <RankedListing>[])
        if (r.listing.salary != null)
          '${r.listing.title} at ${r.listing.company}: ${r.listing.salary}',
    ].take(12).toList();

    _push<void>(
      NegotiationScreen(
        application: application,
        coach: _negotiationCoach,
        profile: _discover.profile,
        senderName: widget.authRepository.currentUserName,
        comparableSalaries: comparable,
        onSaveToNotes: (note) async {
          try {
            final current = _workspace.data?.applicationById(application.id);
            final notes = current?.notes ?? application.notes;
            final updated = await widget.applications.updateNotes(
              application.id,
              notes == null || notes.trim().isEmpty ? note : '$notes\n\n$note',
            );
            _workspace.replaceApplication(updated);
            return null;
          } catch (error) {
            return friendlyErrorMessage(error);
          }
        },
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

  // Interview prep ------------------------------------------------------------

  /// Asks which tracked job a tool is for. Resolves to null (after saying
  /// why) when there's no job to pick, or when she cancels.
  Future<JobApplication?> _pickApplication({
    required String title,
    required String subtitle,
    required String noJobsMessage,
  }) async {
    final applications = _workspace.data?.applications ?? const [];
    if (applications.every((a) => a.status == ApplicationStatus.rejected)) {
      _showMessage(noJobsMessage);
      return null;
    }
    final application = await showPickApplicationSheet(
      context,
      applications: applications,
      title: title,
      subtitle: subtitle,
    );
    return mounted ? application : null;
  }

  Future<void> _pickInterviewPrep() async {
    final application = await _pickApplication(
      title: 'Prepare for which interview?',
      subtitle: 'Pick a job you track. Careerly tailors the questions to it.',
      noJobsMessage: 'Track a job first, then prepare for its interview here.',
    );
    if (application != null) _openInterviewPrep(application);
  }

  /// Opens a Studio tool, asking which job first for the ones tied to one.
  Future<void> _openStudioTool(StudioTool tool) async {
    switch (tool) {
      case StudioTool.enhanceResume:
        _enhanceResume();
      case StudioTool.coverLetter:
        _writeCoverLetter();
      case StudioTool.interviewPrep:
        await _pickInterviewPrep();
      case StudioTool.mockInterview:
        final application = await _pickApplication(
          title: 'Practice for which job?',
          subtitle: 'The mock interview uses that job\'s likely questions.',
          noJobsMessage: 'Track a job first, then practice its interview.',
        );
        if (application == null) return;
        final prep = await _interviewPreps.fetch(application.id);
        if (!mounted) return;
        if (prep == null) {
          // The questions come from the interview kit, so build it first.
          _openInterviewPrep(application);
          _showMessage('Build the interview kit first, then start the mock '
              'interview from it.');
        } else {
          _push<void>(
            MockInterviewScreen(
              job: _contextForApplication(application),
              prep: prep,
              coach: _coach,
              resumeText: _resumeTextIfAny,
            ),
          );
        }
      case StudioTool.atsCheck:
        final application = await _pickApplication(
          title: 'Check against which job?',
          subtitle: 'The ATS check compares your resume with that job post.',
          noJobsMessage: 'Track a job first, then check your resume against it.',
        );
        if (application != null) _openAts(_contextForApplication(application));
      case StudioTool.resumeDesign:
        await _openResumeDesign();
      case StudioTool.message:
        final application = await _pickApplication(
          title: 'Write to which company?',
          subtitle: 'Careerly suggests the message that fits where it stands.',
          noJobsMessage: 'Track a job first, then write to the company here.',
        );
        if (application != null) _writeMessage(application);
      case StudioTool.negotiate:
        final application = await _pickApplication(
          title: 'Negotiate which offer?',
          subtitle: 'Careerly suggests a fair counter for that job.',
          noJobsMessage: 'Track a job first, then plan your negotiation here.',
        );
        if (application != null) _negotiate(application);
      case StudioTool.companyResearch:
        final application = await _pickApplication(
          title: 'Research which company?',
          subtitle: 'An AI brief on the employer behind a job you track.',
          noJobsMessage: 'Track a job first, then research its company here.',
        );
        if (application != null) _showCompanyResearch(application);
    }
  }

  /// Previews her resume in each PDF design. Uses her latest Studio resume,
  /// or the uploaded one.
  Future<void> _openResumeDesign() async {
    final latest = _studio.items
        ?.where((d) => d.kind == DocumentKind.resume)
        .firstOrNull;
    String? content = latest?.content;
    if (content == null) {
      try {
        content = await _studio.resumeText();
      } catch (_) {
        content = null;
      }
    }
    if (!mounted) return;
    if (content == null || content.trim().isEmpty) {
      _showMessage('Upload your resume first, then pick its design.');
      return;
    }
    await _push<ResumeDesign>(
      ResumeDesignScreen(content: content, store: _resumeDesigns),
    );
  }

  void _showCompanyResearch(JobApplication application) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: CompanyResearchCard(
          researcher: _companyResearcher,
          job: _contextForApplication(application),
        ),
      ),
    );
  }

  void _openInterviewPrep(JobApplication application) {
    final interview = _workspace.data?.upcoming
        .where(
          (e) =>
              e.applicationId == application.id &&
              e.kind == AgendaEventKind.interview &&
              !e.isDone,
        )
        .firstOrNull;
    _push<void>(
      InterviewPrepScreen(
        application: application,
        coach: _coach,
        repository: _interviewPreps,
        profile: () => _discover.profile,
        resumeText: _resumeTextIfAny,
        onUploadResume: _editCareerProfile,
        onMockInterview: (prep) => _push<void>(
          MockInterviewScreen(
            job: _contextForApplication(application),
            prep: prep,
            coach: _coach,
            resumeText: _resumeTextIfAny,
          ),
        ),
        interviewAt: interview?.startsAt,
      ),
    );
  }

  // ATS check ------------------------------------------------------------------

  List<ResumeVersion> get _resumeVersions => ResumeVersion.build(
        original: _discover.profile.resume,
        documents: _studio.items ?? const [],
        applications: _workspace.data?.applications ?? const [],
      );

  /// Checks resume versions against [job], starting with [versionId].
  void _openAts(JobContext job, {String? versionId}) {
    _push<void>(
      AtsScreen(
        job: job,
        versions: _resumeVersions,
        initialVersionId: versionId,
        loadContent: (version) => _studio.resumeContent(version.id),
        onTailor: () => _enhanceResume(job),
      ),
    );
  }

  /// From Studio: check a version against a job she tracks.
  Future<void> _atsCheckVersion(ResumeVersion version) async {
    final application = await _pickApplication(
      title: 'Check against which job?',
      subtitle: 'The ATS check compares your resume with that job post.',
      noJobsMessage: 'Track a job first, then check your resume against it.',
    );
    if (application != null) {
      _openAts(_contextForApplication(application), versionId: version.id);
    }
  }

  /// The career coach chat, grounded in her current profile and search.
  void _openCareerCoach() {
    _push<void>(
      CoachScreen(
        coach: _careerCoach,
        history: _coachHistory,
        firstName: widget.authRepository.currentUserName?.split(' ').first,
        loadContext: () async {
          final resume = await _resumeTextIfAny();
          final data = _workspace.data;
          return CoachContext(
            profile: _discover.profile,
            name: widget.authRepository.currentUserName,
            resumeText: resume == null ? null : markupToPlainText(resume),
            applications: data?.applications ?? const [],
            upcoming: data?.upcoming ?? const [],
            goals: data?.goals ?? const [],
          );
        },
      ),
    );
  }

  Future<String?> _resumeTextIfAny() async {
    try {
      return await _studio.resumeText();
    } catch (_) {
      // No resume yet (or it couldn't load): prep works without it.
      return null;
    }
  }

  // Tracker -----------------------------------------------------------------

  JobContext _contextForApplication(JobApplication application) => JobContext(
        title: application.role,
        company: application.company,
        location: application.location,
        description: application.jobDescription,
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
        onInterviewPrep: _openInterviewPrep,
        onWriteMessage: _writeMessage,
        onAtsCheck: (a) => _openAts(_contextForApplication(a)),
        onNegotiate: _negotiate,
        researcher: _companyResearcher,
        events: widget.events,
        onApply: (a) => _startApply(
          job: _contextForApplication(a),
          applyUrl: a.jobUrl ?? '',
          application: a,
        ),
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
          case QuickAddAction.jobLink:
            final text = await showPasteJobDialog(context);
            if (text != null) await _importJob(text);
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
        await _onStudioAdd();
    }
  }

  /// Studio's "+": what can be created there, plus a new resume upload.
  Future<void> _onStudioAdd() async {
    const creates = [
      StudioTool.enhanceResume,
      StudioTool.coverLetter,
      StudioTool.interviewPrep,
      StudioTool.message,
    ];
    final run = await showAddSheet<Future<void> Function()>(
      context,
      title: 'Create',
      options: [
        AddOption(
          value: () async => _openCareerCoach(),
          icon: Icons.forum_rounded,
          accent: Accent.teal,
          title: 'Ask your career coach',
          subtitle: 'Chat about your search, resume, interviews or offers',
        ),
        for (final tool in creates)
          AddOption(
            value: () => _openStudioTool(tool),
            icon: tool.icon,
            accent: tool.accent,
            title: tool.label,
            subtitle: tool.hint,
          ),
        AddOption(
          value: _editCareerProfile,
          icon: Icons.upload_file_rounded,
          accent: Accent.emerald,
          title: _discover.profile.resume == null
              ? 'Upload your resume'
              : 'Upload a new resume',
          subtitle: 'A PDF that AI reads to tailor everything to you',
        ),
      ],
    );
    if (mounted) await run?.call();
  }

  String get _addTooltip => switch (_tab) {
        _Tab.home => 'Add',
        _Tab.jobs => 'New application',
        _Tab.agenda => 'New interview or reminder',
        _Tab.goals => 'New goal',
        _Tab.studio => 'Create',
      };

  /// Reviews applications with no news for weeks.
  void _reviewQuiet() {
    showStaleApplicationsSheet(
      context,
      applications: StaleApplications.find(
        _workspace.data?.applications ?? const [],
      ),
      onFollowUp: (application) => _writeMessage(application, followUp: true),
      onWait: (application) async {
        try {
          final now = DateTime.now();
          final updated = await widget.applications.setFollowUp(
            application.id,
            DateTime(now.year, now.month, now.day + 7),
          );
          _workspace.replaceApplication(updated);
          return null;
        } catch (error) {
          return friendlyErrorMessage(error);
        }
      },
      onClose: (application) async {
        try {
          final days = StaleApplications.quietDays(application);
          await widget.applications
              .updateStatus(application, ApplicationStatus.rejected);
          final note = 'Closed: no reply after $days days.';
          final notes = application.notes;
          final updated = await widget.applications.updateNotes(
            application.id,
            notes == null || notes.trim().isEmpty ? note : '$notes\n$note',
          );
          _workspace.replaceApplication(updated);
          return null;
        } catch (error) {
          return friendlyErrorMessage(error);
        }
      },
    );
  }

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

    final scaffold = Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab.index,
        children: [
          ListenableBuilder(
            listenable: _discover,
            builder: (context, _) => DashboardScreen(
              controller: _workspace,
              name: name,
              initial:
                  (name ?? email).characters.firstOrNull?.toUpperCase() ?? '?',
              onAccountTap: _openProfile,
              onSearchTap: _openJobsSearch,
              onOpenApplication: _openApplication,
              onSeeAllApplications: _openJobs,
              onAddApplication: _addApplication,
              onAddAgendaEvent: _addAgendaEvent,
              onEventDone: (id) => _setEventDone(id, true),
              onOpenAgenda: () => _select(_Tab.agenda),
              onNotificationsTap: _openNotificationCenter,
              newJobAlerts: _discover.totalFresh,
              avatarUrl: widget.authRepository.currentUserAvatarUrl,
              onReviewQuiet: _reviewQuiet,
            ),
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
            onDismissListing: _dismissListing,
            onToggleSaveSearch: _toggleSaveSearch,
            trackedView: _trackedView,
            onMoveApplications: _moveApplications,
            onDeleteApplications: _deleteApplications,
          ),
          AgendaScreen(
            controller: _workspace,
            onAdd: _addAgendaEvent,
            onToggleDone: _setEventDone,
            onEdit: _editAgendaEvent,
            onDelete: _deleteAgendaEvent,
          ),
          GoalsScreen(
            controller: _workspace,
            onAdd: _addGoal,
            onIncrement: _incrementGoal,
          ),
          ListenableBuilder(
            listenable: _workspace,
            builder: (context, _) => StudioScreen(
              studio: _studio,
              onUploadResume: _editCareerProfile,
              onTool: _openStudioTool,
              onCoach: _openCareerCoach,
              onOpenDocument: _openDocument,
              applications: _workspace.data?.applications ?? const [],
              onAtsCheck: _atsCheckVersion,
            ),
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _workspace,
        builder: (context, _) => FloatingNavBar(
          items: _navItems,
          selectedIndex: _tab.index,
          onSelected: (index) => _select(_Tab.values[index]),
          onAdd: _onAdd,
          addTooltip: _addTooltip,
          badges: {_Tab.agenda.index: _dueSoonCount},
        ),
      ),
    );

    // Back leaves selection mode before leaving the app.
    return ListenableBuilder(
      listenable: _trackedView,
      builder: (context, child) => PopScope(
        canPop: !_trackedView.isSelecting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _trackedView.clearSelection();
        },
        child: child!,
      ),
      child: scaffold,
    );
  }
}

/// A job whose application page the user opened from the kit.
class _PendingApply {
  const _PendingApply({
    required this.job,
    required this.choice,
    this.application,
    this.listing,
  });

  final JobContext job;
  final ApplyKitChoice choice;

  /// The tracked application, if the job is already in the tracker.
  final JobApplication? application;

  /// The discovered listing, used to create the application if needed.
  final RankedListing? listing;
}
