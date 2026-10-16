import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/header_wash.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/app_lock_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../discover/data/discover_controller.dart';
import '../../notifications/data/notification_settings.dart';
import '../../notifications/data/notifications.dart';
import '../../profile/data/career_profile.dart';
import '../../resume/data/resume_insights.dart';
import '../data/avatar_repository.dart';

/// Profile: who's signed in, the career profile and resume that tailor job
/// search and AI writing, security, and sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.authRepository,
    required this.appLock,
    required this.discover,
    required this.onEditCareerProfile,
    required this.notifications,
    required this.notificationSettings,
    required this.onNotificationSettingsChanged,
    required this.avatars,
    required this.onAvatarChanged,
  });

  final AuthRepository authRepository;
  final AppLockRepository appLock;
  final AvatarRepository avatars;

  /// Refreshes places that show the photo, e.g. the dashboard.
  final VoidCallback onAvatarChanged;
  final Notifications notifications;
  final NotificationSettings notificationSettings;

  /// Re-syncs reminders after a switch changes.
  final VoidCallback onNotificationSettingsChanged;

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
                _Header(
                  authRepository: authRepository,
                  avatars: avatars,
                  onAvatarChanged: onAvatarChanged,
                ),
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
                      const SectionHeader(title: 'Notifications'),
                      _NotificationsCard(
                        notifications: notifications,
                        settings: notificationSettings,
                        onChanged: onNotificationSettingsChanged,
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

class _Header extends StatefulWidget {
  const _Header({
    required this.authRepository,
    required this.avatars,
    required this.onAvatarChanged,
  });

  final AuthRepository authRepository;
  final AvatarRepository avatars;
  final VoidCallback onAvatarChanged;

  @override
  State<_Header> createState() => _HeaderState();
}

enum _PhotoAction { camera, gallery, remove }

class _HeaderState extends State<_Header> {
  bool _isSaving = false;

  void _showMessage(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _changePhoto() async {
    final hasPhoto = widget.authRepository.currentUserAvatarUrl != null;
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.of(context).pop(_PhotoAction.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.of(context).pop(_PhotoAction.gallery),
              ),
              if (hasPhoto)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Remove photo',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  onTap: () => Navigator.of(context).pop(_PhotoAction.remove),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;

    try {
      if (action == _PhotoAction.remove) {
        setState(() => _isSaving = true);
        await widget.avatars.remove();
        await widget.authRepository.setAvatarUrl(null);
        _showMessage('Photo removed');
      } else {
        final photo = await ImagePicker().pickImage(
          source: action == _PhotoAction.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          preferredCameraDevice: CameraDevice.front,
          maxWidth: 600,
          maxHeight: 600,
          imageQuality: 85,
        );
        if (photo == null || !mounted) return;
        setState(() => _isSaving = true);
        final url = await widget.avatars.upload(await photo.readAsBytes());
        await widget.authRepository.setAvatarUrl(url);
        _showMessage('Photo updated');
      }
      widget.onAvatarChanged();
    } catch (error) {
      debugPrint('Avatar update failed: $error');
      _showMessage(
        error is StorageException &&
                (error.statusCode == '404' ||
                    error.message.toLowerCase().contains('bucket'))
            ? 'Run the latest database migration to add photos.'
            : friendlyErrorMessage(error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authRepository = widget.authRepository;
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
              Semantics(
                button: true,
                label: 'Change profile photo',
                child: InkResponse(
                  onTap: _isSaving ? null : _changePhoto,
                  radius: 48,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatar(
                        initial: initial,
                        photoUrl: authRepository.currentUserAvatarUrl,
                        radius: 44,
                      ),
                      if (_isSaving)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: SizedBox.square(
                                dimension: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 17,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
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

/// Chips that show the first [max], with "+N more" to reveal the rest.
class _Chips extends StatefulWidget {
  const _Chips({required this.items, this.max = 6, this.emphasized = false});

  final List<String> items;
  final int max;
  final bool emphasized;

  @override
  State<_Chips> createState() => _ChipsState();
}

class _ChipsState extends State<_Chips> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final items = widget.items;
    final emphasized = widget.emphasized;
    final extra = items.length - widget.max;
    final shown = _expanded ? items : items.take(widget.max);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in shown)
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
          Semantics(
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expanded ? 'Show less' : '+$extra more',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
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

/// Reminder and job-alert switches, plus a fix-it row when the OS has
/// notifications turned off for the app.
class _NotificationsCard extends StatefulWidget {
  const _NotificationsCard({
    required this.notifications,
    required this.settings,
    required this.onChanged,
  });

  final Notifications notifications;
  final NotificationSettings settings;
  final VoidCallback onChanged;

  @override
  State<_NotificationsCard> createState() => _NotificationsCardState();
}

class _NotificationsCardState extends State<_NotificationsCard>
    with WidgetsBindingObserver {
  bool _reminders = true;
  bool _jobAlerts = true;
  bool _permitted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from system settings: the permission may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final (reminders, jobAlerts, permitted) = await (
        widget.settings.remindersEnabled(),
        widget.settings.jobAlertsEnabled(),
        widget.notifications.isPermitted(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _reminders = reminders;
        _jobAlerts = jobAlerts;
        _permitted = permitted;
      });
    } catch (e) {
      debugPrint('Notification settings unavailable: $e');
    }
  }

  Future<void> _allow() async {
    final granted = await widget.notifications.requestPermission();
    if (!granted) await widget.notifications.openSettings();
    if (mounted) setState(() => _permitted = granted);
    if (granted) widget.onChanged();
  }

  Future<void> _set({bool? reminders, bool? jobAlerts}) async {
    setState(() {
      _reminders = reminders ?? _reminders;
      _jobAlerts = jobAlerts ?? _jobAlerts;
    });
    if (reminders != null) await widget.settings.setRemindersEnabled(reminders);
    if (jobAlerts != null) await widget.settings.setJobAlertsEnabled(jobAlerts);
    if ((reminders ?? false) || (jobAlerts ?? false)) {
      final granted = await widget.notifications.requestPermission();
      if (mounted) setState(() => _permitted = granted);
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final blocked = !_permitted && (_reminders || _jobAlerts);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (blocked)
            Container(
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                0,
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xxs,
                AppSpacing.xxs,
                AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 18,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Notifications are off for Careerly',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(onPressed: _allow, child: const Text('Turn on')),
                ],
              ),
            ),
          SwitchListTile(
            secondary:
                Icon(Icons.event_available_rounded, color: colorScheme.primary),
            title: const Text('Reminders'),
            subtitle: const Text(
              'Before interviews, and for follow-ups and deadlines',
            ),
            value: _reminders,
            onChanged: (v) => _set(reminders: v),
          ),
          const Divider(height: 1, indent: 72),
          SwitchListTile(
            secondary: Icon(
              Icons.notifications_active_outlined,
              color: colorScheme.primary,
            ),
            title: const Text('Job alerts'),
            subtitle: const Text('New jobs for your saved searches, daily'),
            value: _jobAlerts,
            onChanged: (v) => _set(jobAlerts: v),
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
