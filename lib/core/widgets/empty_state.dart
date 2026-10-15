import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Friendly placeholder for an empty list, with an optional call to action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add_rounded,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: colorScheme.primary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.4),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: onAction,
            icon: Icon(actionIcon, size: 18),
            label: Text(actionLabel!),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          ),
        ],
      ],
    );
  }
}
