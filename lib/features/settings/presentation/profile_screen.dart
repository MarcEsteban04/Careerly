import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/header_wash.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/data/app_lock_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../discover/data/discover_controller.dart';
import '../../profile/data/career_profile.dart';
import '../../resume/data/resume_insights.dart';

/// Profile: who's signed in, the career profile and resume that tailor job
/// search and AI writing, security, and sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.authRepository,
    required this.appLock,
    required this.discover,
    required this.onEditCareerProfile,
  });

  final AuthRepository authRepository;
  final AppLockRepository appLock;

  /// Owns the career profile; rebuilding on it keeps this screen current.
  final DiscoverController discover;

  /// Opens the career profile form (which also handles resume upload).
  final Future<void> Function() onEditCareerProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: ListenableBuilder(
          listenable: discover,
          builder: (context, _) {
            final profile = discover.profile;
            return ListView(
              padding: EdgeInsets.only(bottom: AppSpacing.xl + bottomInset),
              children: [
                _Header(authRepository: authRepository),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      SectionHeader(
                        title: 'Career profile',
                        actionLabel: profile.isEmpty ? null : 'Edit',
                        actionIcon: Icons.edit_outlined,
                        onAction: onEditCareerProfile,
                      ),
                      _CareerProfileCard(
                        profile: profile,
                        onEdit: onEditCareerProfile,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SectionHeader(title: 'Resume'),
                      _ResumeCard(
                        resume: profile.resume,
                        onUpload: onEditCareerProfile,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SectionHeader(title: 'Security'),
                      _AppLockTile(appLock: appLock),
                      const SizedBox(height: AppSpacing.xl),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          authRepository.signOut();
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(
                            color: theme.colorScheme.error.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = authRepository.currentUserName;
    final email = authRepository.currentUserEmail ?? '';
    final initial =
        (name ?? email).characters.firstOrNull?.toUpperCase() ?? '?';

    return HeaderWash(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      'Profile',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              CircleAvatar(
                radius: 40,
                backgroundColor: colorScheme.primary,
                child: Text(
                  initial,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                name ?? 'Your account',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                email,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CareerProfileCard extends StatelessWidget {
  const _CareerProfileCard({required this.profile, required this.onEdit});

  final CareerProfile profile;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (profile.isEmpty) {
      return AppCard(
        onTap: onEdit,
        color: colorScheme.primary.withValues(alpha: 0.05),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_add_alt_rounded, color: colorScheme.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set up your career profile',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Roles, skills and your resume tailor job matches and AI '
                    'writing to you.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
          ],
        ),
      );
    }

    final years = profile.effectiveYears;
    final seniority = profile.resume?.seniority;
    final experience = [
      if (years != null) '$years ${years == 1 ? 'year' : 'years'}',
      ?seniority,
    ].join(' · ');
    final skills = profile.effectiveSkills;

    return AppCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('Looking for'),
          const SizedBox(height: AppSpacing.xs),
          _Chips(items: profile.effectiveRoles, emphasized: true),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _Label('Skills'),
            const SizedBox(height: AppSpacing.xs),
            _Chips(items: skills, max: 12),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.xs),
          _Fact(
            icon: Icons.timeline_rounded,
            label: 'Experience',
            value: experience.isEmpty ? 'Not set' : experience,
          ),
          _Fact(
            icon: Icons.place_outlined,
            label: 'City',
            value: profile.effectiveLocation ?? 'Not set',
          ),
          _Fact(
            icon: Icons.laptop_mac_rounded,
            label: 'Work setup',
            value: profile.workSetup.label,
          ),
        ],
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.resume, required this.onUpload});

  final ResumeInsights? resume;
  final Future<void> Function() onUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resume = this.resume;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: resume == null
                  ? colorScheme.primary.withValues(alpha: 0.12)
                  : colorScheme.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              resume == null
                  ? Icons.upload_file_rounded
                  : Icons.description_outlined,
              color: resume == null ? colorScheme.primary : colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resume?.fileName ?? 'No resume yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  resume == null
                      ? 'Upload a PDF to tailor matches and AI writing.'
                      : resume.headline ??
                          'Uploaded ${DateFormat('MMM d, y').format(resume.uploadedAt)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton.tonal(
            onPressed: onUpload,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            child: Text(resume == null ? 'Upload' : 'Replace'),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
      );
}

class _Chips extends StatelessWidget {
  const _Chips({required this.items, this.max = 6, this.emphasized = false});

  final List<String> items;
  final int max;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final extra = items.length - max;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in items.take(max))
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: emphasized
                  ? colorScheme.primary.withValues(alpha: 0.10)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item,
              style: theme.textTheme.bodySmall?.copyWith(
                color: emphasized ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(
              '+$extra more',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle for biometric unlock. Disabled when the device has no biometrics.
class _AppLockTile extends StatefulWidget {
  const _AppLockTile({required this.appLock});

  final AppLockRepository appLock;

  @override
  State<_AppLockTile> createState() => _AppLockTileState();
}

class _AppLockTileState extends State<_AppLockTile> {
  bool? _available;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await widget.appLock.canUseBiometrics();
    final enabled = await widget.appLock.isEnabled();
    if (mounted) {
      setState(() {
        _available = available;
        _enabled = enabled;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    if (value &&
        await widget.appLock.authenticate(reason: 'Turn on biometric unlock') !=
            UnlockResult.success) {
      return;
    }
    await widget.appLock.setEnabled(value);
    if (mounted) setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final available = _available ?? false;

    return AppCard(
      padding: EdgeInsets.zero,
      child: SwitchListTile(
        secondary: Icon(Icons.fingerprint_rounded, color: colorScheme.primary),
        title: const Text('Biometric unlock'),
        subtitle: Text(
          _available == false
              ? 'Set up a fingerprint or face on this device to use it'
              : 'Require fingerprint or face to open Careerly',
        ),
        value: _enabled && available,
        onChanged: available ? _toggle : null,
      ),
    );
  }
}
