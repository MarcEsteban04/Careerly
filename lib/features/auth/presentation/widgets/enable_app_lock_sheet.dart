import 'package:flutter/material.dart';

import '../../../../core/theme/app_accents.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../core/widgets/primary_button.dart';

/// Asks once, after the first password sign-in, whether to turn on biometric
/// unlock. Resolves to `true` if the user opts in.
Future<bool> showEnableAppLockSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => const _EnableAppLockSheet(),
  );
  return result ?? false;
}

class _EnableAppLockSheet extends StatelessWidget {
  const _EnableAppLockSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            Align(
              alignment: Alignment.centerLeft,
              child: const IconBadge(
                icon: Icons.fingerprint_rounded,
                accent: Accent.violet,
                size: 56,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Unlock faster next time',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Use your fingerprint or face to open Careerly instead of '
              'typing your password. You can change this anytime.',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Turn on',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
