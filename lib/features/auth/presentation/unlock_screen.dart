import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/form_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/app_lock_repository.dart';
import 'widgets/auth_scaffold.dart';

/// Shown instead of the app while the biometric lock is on. Opens the system
/// prompt automatically; the user can retry or fall back to their password.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({
    super.key,
    required this.appLock,
    required this.onUnlocked,
    required this.onUsePassword,
    this.firstName,
  });

  final AppLockRepository appLock;
  final VoidCallback onUnlocked;
  final VoidCallback onUsePassword;
  final String? firstName;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final result = await widget.appLock.authenticate();
    if (!mounted) return;

    if (result == UnlockResult.success) {
      widget.onUnlocked();
      return;
    }
    if (result != UnlockResult.canceled) HapticFeedback.mediumImpact();
    setState(() {
      _isAuthenticating = false;
      _errorMessage = switch (result) {
        UnlockResult.lockedOut =>
          'Too many attempts. Use your password, or try again later.',
        UnlockResult.unavailable =>
          'Biometrics aren\'t available right now. Use your password instead.',
        UnlockResult.failed => 'Not recognized. Try again.',
        UnlockResult.canceled || UnlockResult.success => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = widget.firstName == null
        ? 'Welcome back'
        : 'Welcome back, ${widget.firstName}';

    return AuthScaffold(
      heroHeightFactor: 0.45,
      builder: (context, reveal) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          reveal(
            0.35,
            0.85,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Careerly is locked. Unlock to pick up where you left off.',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _errorMessage == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: FormBanner(message: _errorMessage!),
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          reveal(
            0.5,
            1,
            PrimaryButton(
              label: 'Unlock',
              icon: Icons.fingerprint_rounded,
              isLoading: _isAuthenticating,
              onPressed: _unlock,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          reveal(
            0.6,
            1,
            TextButton(
              onPressed: _isAuthenticating ? null : widget.onUsePassword,
              child: const Text('Use password instead'),
            ),
          ),
        ],
      ),
    );
  }
}
