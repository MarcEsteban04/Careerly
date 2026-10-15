import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// Shows the remembered account with a way to switch to a different email.
class AccountChip extends StatelessWidget {
  const AccountChip({
    super.key,
    required this.email,
    required this.onChange,
    this.enabled = true,
  });

  final String email;
  final VoidCallback onChange;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.xxs,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
            child: Text(
              email.characters.first.toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: enabled ? onChange : null,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}
