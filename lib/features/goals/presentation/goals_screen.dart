import 'package:flutter/material.dart';

import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/tab_page.dart';
import '../../shell/data/workspace_controller.dart';
import '../../shell/presentation/widgets/workspace_view.dart';
import '../data/goal.dart';
import 'widgets/goal_tile.dart';

/// Goals tab: every goal with progress, grouped into active and completed.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({
    super.key,
    required this.controller,
    required this.onAdd,
    required this.onIncrement,
  });

  final WorkspaceController controller;
  final VoidCallback onAdd;
  final ValueChanged<Goal> onIncrement;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final goals = controller.data?.goals ?? const <Goal>[];
        final active = goals.where((g) => !g.isComplete).toList();
        final done = goals.where((g) => g.isComplete).toList();

        return TabPage(
          title: 'Goals',
          subtitle: controller.data == null
              ? null
              : goals.isEmpty
                  ? 'Small targets keep the search moving'
                  : '${done.length} of ${goals.length} complete',
          onRefresh: controller.load,
          heroChild: goals.isEmpty
              ? null
              : _GoalsSummary(goals: goals, active: active.length, done: done.length),
          children: [
            WorkspaceView(
              controller: controller,
              builder: (context, _) => goals.isEmpty
                  ? AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.lg,
                      ),
                      child: EmptyState(
                        icon: Icons.flag_outlined,
                        title: 'Set your first goal',
                        message: 'A small weekly target, like 5 applications, '
                            'keeps the momentum going.',
                        actionLabel: 'Create goal',
                        onAction: onAdd,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (active.isNotEmpty)
                          _GoalGroup(
                            title: 'In progress',
                            goals: active,
                            onIncrement: onIncrement,
                          ),
                        if (done.isNotEmpty)
                          _GoalGroup(
                            title: 'Completed',
                            goals: done,
                            onIncrement: onIncrement,
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _GoalGroup extends StatelessWidget {
  const _GoalGroup({
    required this.title,
    required this.goals,
    required this.onIncrement,
  });

  final String title;
  final List<Goal> goals;
  final ValueChanged<Goal> onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxs,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          AppCard(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Column(
              children: [
                for (final goal in goals)
                  GoalTile(goal: goal, onIncrement: () => onIncrement(goal)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Overall progress in the header: a ring for every goal combined, and how
/// many are in progress or done.
class _GoalsSummary extends StatelessWidget {
  const _GoalsSummary({
    required this.goals,
    required this.active,
    required this.done,
  });

  final List<Goal> goals;
  final int active;
  final int done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overall =
        goals.fold<double>(0, (sum, g) => sum + g.fraction) / goals.length;

    return Row(
      children: [
        Semantics(
          label: '${(overall * 100).round()}% overall',
          excludeSemantics: true,
          child: SizedBox.square(
            dimension: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: overall),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    color: AppColors.accent,
                    backgroundColor: Theme.of(context).colorScheme.outline,
                    constraints: const BoxConstraints.tightFor(
                      width: 92,
                      height: 92,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(overall * 100).round()}%',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700, height: 1),
                    ),
                    Text(
                      'overall',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatTile(
            value: '$active',
            label: 'In progress',
            icon: Icons.trending_up_rounded,
            accent: Accent.violet,
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: StatTile(
            value: '$done',
            label: 'Completed',
            icon: Icons.emoji_events_rounded,
            accent: Accent.emerald,
          ),
        ),
      ],
    );
  }
}
