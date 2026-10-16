import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Section title with an optional trailing text action, e.g. "See all" or
/// "+ Add".
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add_rounded,
    this.trailingIcon = false,
    this.showIcon = true,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  /// Put the icon after the label (e.g. a chevron).
  final bool trailingIcon;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = Icon(actionIcon, size: 18);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: colorScheme.primary,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                textStyle: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showIcon && !trailingIcon) ...[
                    icon,
                    const SizedBox(width: 4),
                  ],
                  Text(actionLabel!),
                  if (showIcon && trailingIcon) ...[
                    const SizedBox(width: 2),
                    icon,
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
