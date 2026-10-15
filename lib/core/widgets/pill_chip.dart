import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Rounded filter/choice chip: outlined when idle, solid ink when selected.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional icon or dot before the label.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final selectedBackground = isDark ? colorScheme.onSurface : AppColors.ink;
    final selectedForeground = isDark ? AppColors.darkBackground : Colors.white;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? selectedBackground : colorScheme.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? selectedBackground : colorScheme.outline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs + 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(
                      size: 16,
                      color: selected ? selectedForeground : null,
                    ),
                    child: leading!,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? selectedForeground : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
