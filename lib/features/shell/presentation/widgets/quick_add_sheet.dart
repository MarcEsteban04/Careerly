import 'package:flutter/material.dart';

import '../../../../core/theme/app_accents.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/icon_badge.dart';

enum QuickAddAction { jobLink, application, agendaEvent, goal }

/// "What do you want to add?" menu behind the dashboard's Add button.
Future<QuickAddAction?> showQuickAddSheet(BuildContext context) {
  return showModalBottomSheet<QuickAddAction>(
    context: context,
    showDragHandle: true,
    // Size to the options rather than the default 9/16 of the screen.
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
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
              action: QuickAddAction.jobLink,
              icon: Icons.link_rounded,
              accent: Accent.blue,
              title: 'Job from a link',
              subtitle: 'Paste a LinkedIn, JobStreet or OnlineJobs.ph link',
            ),
            _Option(
              action: QuickAddAction.application,
              icon: Icons.work_outline_rounded,
              accent: Accent.violet,
              title: 'Application',
              subtitle: 'Type in a role you saved or applied for',
            ),
            _Option(
              action: QuickAddAction.agendaEvent,
              icon: Icons.event_outlined,
              accent: Accent.teal,
              title: 'Interview or reminder',
              subtitle: 'Interviews, follow-ups and deadlines',
            ),
            _Option(
              action: QuickAddAction.goal,
              icon: Icons.flag_outlined,
              accent: Accent.amber,
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
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  final QuickAddAction action;
  final IconData icon;
  final Accent accent;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      leading: IconBadge(icon: icon, accent: accent),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}
