import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/goal.dart';

/// Goal with a progress ring and a +1 button.
class GoalTile extends StatelessWidget {
  const GoalTile({super.key, required this.goal, required this.onIncrement});

  final Goal goal;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final done = goal.isComplete;
    final ringColor = done
        ? (theme.brightness == Brightness.dark
            ? AppColors.successDark
            : AppColors.success)
        : colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: goal.fraction),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                    color: ringColor,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                  ),
                ),
                done
                    ? Icon(Icons.check_rounded, color: ringColor, size: 22)
                    : Text(
                        '${(goal.fraction * 100).round()}%',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${goal.progress} of ${goal.target} · ${goal.period.label}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (!done)
            IconButton.filledTonal(
              tooltip: 'Log progress',
              onPressed: onIncrement,
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
    );
  }
}
