import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../auth/data/app_lock_repository.dart';
import '../../auth/data/auth_repository.dart';

/// Account details, security settings and sign out.
Future<void> showAccountSheet(
  BuildContext context, {
  required AuthRepository authRepository,
  required AppLockRepository appLock,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => _AccountSheet(
      authRepository: authRepository,
      appLock: appLock,
    ),
  );
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet({required this.authRepository, required this.appLock});

  final AuthRepository authRepository;
  final AppLockRepository appLock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = authRepository.currentUserName;
    final email = authRepository.currentUserEmail ?? '';
    final initial = (name ?? email).characters.firstOrNull?.toUpperCase() ?? '?';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
                  child: Text(
                    initial,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: colorScheme.primary),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name ?? 'Your account',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        email,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _AppLockTile(appLock: appLock),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                authRepository.signOut();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error.withValues(alpha: 0.4)),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Toggle for biometric unlock. Hidden when the device has no biometrics.
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

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
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
