import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

enum QuickAddAction { application, agendaEvent, goal }

/// "What do you want to add?" menu behind the dashboard's Add button.
Future<QuickAddAction?> showQuickAddSheet(BuildContext context) {
  return showModalBottomSheet<QuickAddAction>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _Option(
              action: QuickAddAction.application,
              icon: Icons.work_outline_rounded,
              title: 'Application',
              subtitle: 'A role you saved or applied for',
            ),
            _Option(
              action: QuickAddAction.agendaEvent,
              icon: Icons.event_outlined,
              title: 'Interview or reminder',
              subtitle: 'Interviews, follow-ups and deadlines',
            ),
            _Option(
              action: QuickAddAction.goal,
              icon: Icons.flag_outlined,
              title: 'Goal',
              subtitle: 'A target to keep you moving',
            ),
          ],
        ),
      ),
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.action,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final QuickAddAction action;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        ),
        child: Icon(icon, color: colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}
