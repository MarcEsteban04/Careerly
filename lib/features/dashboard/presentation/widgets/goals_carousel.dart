import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../goals/data/goal.dart';

/// Horizontally scrolling goal cards with big progress rings, ending in a
/// "New goal" card.
class GoalsCarousel extends StatelessWidget {
  const GoalsCarousel({
    super.key,
    required this.goals,
    required this.onIncrement,
    required this.onAdd,
  });

  final List<Goal> goals;
  final ValueChanged<Goal> onIncrement;
  final VoidCallback onAdd;

  static const _cardWidth = 160.0;
  static const _height = 172.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: goals.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => SizedBox(
          width: _cardWidth,
          child: index == goals.length
              ? _NewGoalCard(onTap: onAdd, isFirst: goals.isEmpty)
              : _GoalCard(
                  goal: goals[index],
                  onIncrement: () => onIncrement(goals[index]),
                ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onIncrement});

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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: goal.fraction),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => CircularProgressIndicator(
                        value: value,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        color: ringColor,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        constraints: const BoxConstraints.tightFor(
                          width: 60,
                          height: 60,
                        ),
                      ),
                    ),
                    done
                        ? Icon(Icons.check_rounded, color: ringColor, size: 26)
                        : Text(
                            '${(goal.fraction * 100).round()}%',
                            style: theme.textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                  ],
                ),
              ),
              const Spacer(),
              if (!done)
                IconButton.filledTonal(
                  tooltip: 'Log progress',
                  visualDensity: VisualDensity.compact,
                  onPressed: onIncrement,
                  icon: const Icon(Icons.add_rounded, size: 20),
                ),
            ],
          ),
          const Spacer(),
          Text(
            goal.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
          ),
          const SizedBox(height: 2),
          Text(
            done
                ? 'Done · ${goal.period.label}'
                : '${goal.progress} of ${goal.target} · ${goal.period.label}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NewGoalCard extends StatelessWidget {
  const _NewGoalCard({required this.onTap, required this.isFirst});

  final VoidCallback onTap;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.primary.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, color: colorScheme.primary),
              ),
              const Spacer(),
              Text(
                isFirst ? 'Set your first goal' : 'New goal',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Small weekly targets keep you moving.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
