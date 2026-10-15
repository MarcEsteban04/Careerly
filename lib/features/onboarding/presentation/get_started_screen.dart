import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/choice_chip_group.dart';
import '../../../core/widgets/emphasis_text.dart';
import '../../../core/widgets/form_banner.dart';
import '../../../core/widgets/header_wash.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/tag_input.dart';
import '../../auth/data/app_lock_repository.dart';
import '../../notifications/data/notification_settings.dart';
import '../../notifications/data/notifications.dart';
import '../../profile/data/career_profile.dart';
import '../../resume/data/resume_insights.dart';
import '../../resume/presentation/resume_card.dart';
import '../../resume/presentation/resume_upload.dart';

/// Where to go once setup is done.
enum GetStartedResult {
  /// Search jobs for the new profile.
  findJobs,

  /// Just open the dashboard.
  dashboard,

  /// Setup was skipped.
  skipped,
}

enum _Step { welcome, resume, roles, preferences, notifications, done }

/// First-run setup: welcome, resume, roles and skills, work preferences,
/// then notifications and biometric unlock. Saves the career profile.
class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({
    super.key,
    required this.firstName,
    required this.initial,
    required this.canReadResumes,
    required this.onReadResume,
    required this.onSaveProfile,
    required this.notifications,
    required this.settings,
    required this.appLock,
  });

  final String? firstName;
  final CareerProfile initial;
  final bool canReadResumes;
  final ResumeReaderCallback onReadResume;
  final Future<void> Function(CareerProfile profile) onSaveProfile;
  final Notifications notifications;
  final NotificationSettings settings;
  final AppLockRepository appLock;

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
  _Step _step = _Step.welcome;

  late ResumeInsights? _resume = widget.initial.resume;
  late List<String> _roles = [...widget.initial.targetRoles];
  late List<String> _skills = [...widget.initial.skills];
  late final _years = TextEditingController(
    text: widget.initial.yearsOfExperience?.toString() ?? '',
  );
  late final _city = TextEditingController(text: widget.initial.location ?? '');
  late WorkSetup _workSetup = widget.initial.workSetup;

  bool _reminders = true;
  bool _jobAlerts = true;
  bool _biometrics = false;
  bool _canUseBiometrics = false;

  bool _isReadingResume = false;
  String? _resumeMessage;
  bool _resumeFailed = false;
  bool _isSaving = false;
  String? _error;

  static const _progressSteps = [
    _Step.resume,
    _Step.roles,
    _Step.preferences,
    _Step.notifications,
  ];

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
  }

  Future<void> _loadBiometrics() async {
    try {
      final available = await widget.appLock.canUseBiometrics() &&
          !await widget.appLock.isEnabled();
      if (mounted) setState(() => _canUseBiometrics = available);
    } catch (_) {
      // No biometrics: the toggle stays hidden.
    }
  }

  @override
  void dispose() {
    _years.dispose();
    _city.dispose();
    super.dispose();
  }

  CareerProfile get _profile {
    final city = _city.text.trim();
    return CareerProfile(
      targetRoles: _roles,
      skills: _skills,
      yearsOfExperience: int.tryParse(_years.text),
      location: city.isEmpty ? null : city,
      workSetup: _workSetup,
      resume: _resume,
    );
  }

  bool get _hasRoles => _roles.isNotEmpty || (_resume?.roles.isNotEmpty ?? false);

  void _go(_Step step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
  }

  void _back() {
    if (_step == _Step.welcome || _step == _Step.done) return;
    _go(_Step.values[_step.index - 1]);
  }

  Future<void> _uploadResume() async {
    final result = await pickAndReadResume(
      read: widget.onReadResume,
      onReading: () {
        if (!mounted) return;
        setState(() {
          _isReadingResume = true;
          _resumeMessage = null;
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _isReadingResume = false;
      switch (result) {
        case null:
          break;
        case ResumeUploaded(:final resume, :final summary):
          _resume = resume;
          _resumeFailed = false;
          _resumeMessage = '$summary Review them on the next step.';
          if (_years.text.isEmpty && resume.yearsOfExperience != null) {
            _years.text = '${resume.yearsOfExperience}';
          }
          if (_city.text.isEmpty && resume.location != null) {
            _city.text = resume.location!;
          }
        case ResumeUploadFailed(:final message):
          _resumeFailed = true;
          _resumeMessage = message;
      }
    });
  }

  Future<void> _finish() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final profile = _profile;
      if (!profile.isEmpty) await widget.onSaveProfile(profile);

      await widget.settings.setRemindersEnabled(_reminders);
      await widget.settings.setJobAlertsEnabled(_jobAlerts);
      if (_reminders || _jobAlerts) {
        await widget.notifications.requestPermission();
      }

      await widget.appLock.markOffered();
      if (_biometrics &&
          await widget.appLock.authenticate(reason: 'Turn on biometric unlock') ==
              UnlockResult.success) {
        await widget.appLock.setEnabled(true);
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _go(_Step.done);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final body = switch (_step) {
      _Step.welcome => _WelcomeStep(firstName: widget.firstName),
      _Step.resume => _resumeStep(),
      _Step.roles => _rolesStep(),
      _Step.preferences => _preferencesStep(),
      _Step.notifications => _notificationsStep(),
      _Step.done => _DoneStep(
          firstName: widget.firstName,
          profile: _profile,
        ),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: HeaderWash(
          child: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  step: _step,
                  progressSteps: _progressSteps,
                  onBack: _back,
                  onSkip: () =>
                      Navigator.of(context).pop(GetStartedResult.skipped),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        children: [
                          body,
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            FormBanner(message: _error!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm + (bottomInset > 0 ? 0 : AppSpacing.xs),
                  ),
                  child: _actions(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    Widget secondary(String label, VoidCallback onPressed) => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          child: Text(label),
        );

    return switch (_step) {
      _Step.welcome => PrimaryButton(
          label: "Let's set you up",
          icon: Icons.arrow_forward_rounded,
          onPressed: () => _go(_Step.resume),
        ),
      _Step.resume => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_resume == null && widget.canReadResumes)
              PrimaryButton(
                label: 'Upload my resume',
                icon: Icons.upload_file_rounded,
                isLoading: _isReadingResume,
                onPressed: _uploadResume,
              )
            else
              PrimaryButton(
                label: 'Continue',
                onPressed: _isReadingResume ? null : () => _go(_Step.roles),
              ),
            if (_resume == null && !_isReadingResume)
              secondary("I'll add it later", () => _go(_Step.roles)),
          ],
        ),
      _Step.roles => PrimaryButton(
          label: _hasRoles ? 'Continue' : 'Add a role to continue',
          onPressed: _hasRoles ? () => _go(_Step.preferences) : null,
        ),
      _Step.preferences => PrimaryButton(
          label: 'Continue',
          onPressed: () => _go(_Step.notifications),
        ),
      _Step.notifications => PrimaryButton(
          label: 'Finish setup',
          icon: Icons.check_rounded,
          isLoading: _isSaving,
          onPressed: _finish,
        ),
      _Step.done => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(
              label: 'See my job matches',
              icon: Icons.auto_awesome_rounded,
              onPressed: () =>
                  Navigator.of(context).pop(GetStartedResult.findJobs),
            ),
            secondary(
              'Go to my dashboard',
              () => Navigator.of(context).pop(GetStartedResult.dashboard),
            ),
          ],
        ),
    };
  }

  Widget _resumeStep() => _StepLayout(
        headline: 'Start with your **resume**',
        subtitle: 'Careerly reads it to find your roles, skills and '
            "experience, so you don't have to type them. PDF only.",
        children: [
          ResumeCard(
            resume: _resume,
            isReading: _isReadingResume,
            enabled: widget.canReadResumes,
            onUpload: _uploadResume,
            onRemove: () => setState(() {
              _resume = null;
              _resumeMessage = null;
            }),
          ),
          if (_resumeMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FormBanner(
              message: _resumeMessage!,
              tone: _resumeFailed ? FormBannerTone.error : FormBannerTone.success,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _Hint(
            icon: Icons.lock_outline_rounded,
            text: 'Your resume stays in your account. It\'s only used to '
                'tailor matches and writing for you.',
          ),
        ],
      );

  Widget _rolesStep() {
    final resumeRoles = _resume?.roles ?? const <String>[];
    final resumeSkills = _resume?.skills ?? const <String>[];

    return _StepLayout(
      headline: 'What **roles** do you want?',
      subtitle: 'Careerly searches these first and scores every job against '
          'them.',
      children: [
        LabeledField(
          label: 'Roles',
          child: TagInput(
            values: _roles,
            onChanged: (v) => setState(() => _roles = v),
            hintText: 'e.g. UI Designer',
            prefixIcon: Icons.work_outline_rounded,
            suggestions: resumeRoles,
            suggestionsLabel: 'From your resume',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        LabeledField(
          label: resumeSkills.isEmpty ? 'Skills' : 'Extra skills',
          child: TagInput(
            values: _skills,
            onChanged: (v) => setState(() => _skills = v),
            hintText: resumeSkills.isEmpty
                ? 'e.g. Figma, UX research'
                : "Anything your resume doesn't show",
            prefixIcon: Icons.auto_awesome_outlined,
            suggestions: resumeSkills.isEmpty ? _commonSkills : const [],
          ),
        ),
        if (resumeSkills.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _Hint(
            icon: Icons.check_circle_outline_rounded,
            text: 'Plus ${resumeSkills.length} skills from your resume, like '
                '${resumeSkills.take(3).join(', ')}.',
          ),
        ],
      ],
    );
  }

  static const _commonSkills = [
    'Communication',
    'Microsoft Excel',
    'Customer service',
    'Project management',
    'Canva',
    'Figma',
  ];

  Widget _preferencesStep() => _StepLayout(
        headline: 'Where and how do you want to **work**?',
        subtitle: 'Used to find jobs near you and to weigh seniority.',
        children: [
          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Experience',
                  child: TextField(
                    controller: _years,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Years',
                      prefixIcon: Icon(Icons.timeline_rounded),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: LabeledField(
                  label: 'City',
                  child: TextField(
                    controller: _city,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Manila',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          LabeledField(
            label: 'Work setup',
            child: ChoiceChipGroup<WorkSetup>(
              values: WorkSetup.values,
              selected: _workSetup,
              labelOf: (s) => s.label,
              onSelected: (s) => setState(() => _workSetup = s),
            ),
          ),
        ],
      );

  Widget _notificationsStep() => _StepLayout(
        headline: 'Stay on **top** of it',
        subtitle: "Careerly can nudge you so nothing slips. Change these any "
            'time in your profile.',
        children: [
          _ToggleCard(
            icon: Icons.event_available_rounded,
            title: 'Reminders',
            subtitle: 'The evening before and an hour before interviews, plus '
                'follow-ups and deadlines.',
            value: _reminders,
            onChanged: (v) => setState(() => _reminders = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ToggleCard(
            icon: Icons.notifications_active_outlined,
            title: 'Job alerts',
            subtitle: 'Once a day, new jobs for the searches you save.',
            value: _jobAlerts,
            onChanged: (v) => setState(() => _jobAlerts = v),
          ),
          if (_canUseBiometrics) ...[
            const SizedBox(height: AppSpacing.sm),
            _ToggleCard(
              icon: Icons.fingerprint_rounded,
              title: 'Biometric unlock',
              subtitle: 'Open Careerly with your fingerprint or face.',
              value: _biometrics,
              onChanged: (v) => setState(() => _biometrics = v),
            ),
          ],
        ],
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.step,
    required this.progressSteps,
    required this.onBack,
    required this.onSkip,
  });

  final _Step step;
  final List<_Step> progressSteps;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final position = progressSteps.indexOf(step);
    final showBack = step != _Step.welcome && step != _Step.done;

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: showBack
                  ? IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: onBack,
                    )
                  : null,
            ),
            Expanded(
              child: position < 0
                  ? const SizedBox.shrink()
                  : Semantics(
                      label: 'Step ${position + 1} of ${progressSteps.length}',
                      child: Row(
                        children: [
                          for (var i = 0; i < progressSteps.length; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: 4,
                                decoration: BoxDecoration(
                                  color: i <= position
                                      ? colorScheme.primary
                                      : colorScheme.primary
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
            SizedBox(
              width: 64,
              child: step == _Step.done
                  ? null
                  : TextButton(onPressed: onSkip, child: const Text('Skip')),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.headline,
    required this.subtitle,
    required this.children,
  });

  final String headline;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmphasisText(
          headline,
          style: theme.textTheme.headlineMedium?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...children,
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.firstName});

  final String? firstName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = firstName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Image.asset(
            'assets/icons/careerly_logo.png',
            width: 72,
            height: 72,
            semanticLabel: 'Careerly',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        EmphasisText(
          name == null
              ? 'Welcome to **Careerly**'
              : 'Hi $name, welcome to **Careerly**',
          style: theme.textTheme.headlineMedium?.copyWith(fontSize: 30),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          "Let's set up your career profile so every match, resume and "
          'cover letter fits you. It takes about two minutes.',
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _Feature(
          icon: Icons.travel_explore_rounded,
          title: 'Jobs picked for you',
          subtitle: 'From LinkedIn, Indeed, JobStreet and more, scored '
              'against your profile.',
        ),
        const _Feature(
          icon: Icons.auto_awesome_rounded,
          title: 'AI that writes with you',
          subtitle: 'Tailored resumes, cover letters and interview prep.',
        ),
        const _Feature(
          icon: Icons.notifications_active_outlined,
          title: 'Nothing slips through',
          subtitle: 'Reminders before interviews and alerts for new jobs.',
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: SwitchListTile(
        secondary: Icon(icon, color: colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.firstName, required this.profile});

  final String? firstName;
  final CareerProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final roles = profile.effectiveRoles;

    return Column(
      children: [
        const SizedBox(height: AppSpacing.xl),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(Icons.check_rounded, size: 48, color: colorScheme.onPrimary),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        EmphasisText(
          firstName == null
              ? "You're **all set**!"
              : "You're **all set**, $firstName!",
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          roles.isEmpty
              ? 'Your profile is saved. Add roles any time from your profile.'
              : 'Careerly will look for ${roles.take(2).join(' and ')} roles '
                  '${profile.effectiveLocation == null ? '' : 'around ${profile.effectiveLocation} '}'
                  'and score each one for you.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
