import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../auth/data/app_lock_repository.dart';
import '../../auth/data/auth_repository.dart';

/// Placeholder home until the main app screens are designed.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.authRepository,
    required this.appLock,
  });

  final AuthRepository authRepository;
  final AppLockRepository appLock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Careerly'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: authRepository.signOut,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text("You're signed in.", style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.lg),
          _AppLockTile(appLock: appLock),
        ],
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
    if (_available != true) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Card.filled(
      color: colorScheme.surfaceContainerHighest,
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        secondary: Icon(Icons.fingerprint_rounded, color: colorScheme.primary),
        title: const Text('Biometric unlock'),
        subtitle: const Text('Require fingerprint or face to open Careerly'),
        value: _enabled,
        onChanged: _toggle,
      ),
    );
  }
}
