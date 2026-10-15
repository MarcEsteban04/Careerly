import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
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
          subtitle: controller.data == null || goals.isEmpty
              ? null
              : '${done.length} of ${goals.length} complete',
          onRefresh: controller.load,
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
