import 'package:flutter/material.dart';

import '../../../../core/theme/app_accents.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/icon_badge.dart';

/// One choice in an add menu.
class AddOption<T> {
  const AddOption({
    required this.value,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  final T value;
  final IconData icon;
  final Accent accent;
  final String title;
  final String subtitle;
}

/// The menu behind the "+" button: a titled list of things to add or
/// create. Resolves to the chosen option's value, or null.
Future<T?> showAddSheet<T>(
  BuildContext context, {
  required String title,
  required List<AddOption<T>> options,
}) {
  return showModalBottomSheet<T>(
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final option in options) _Option(option: option),
          ],
        ),
      ),
    ),
  );
}

enum QuickAddAction { jobLink, application, agendaEvent, goal }

/// "What do you want to add?" menu behind the dashboard's Add button.
Future<QuickAddAction?> showQuickAddSheet(BuildContext context) =>
    showAddSheet(
      context,
      title: 'Add',
      options: const [
        AddOption(
          value: QuickAddAction.jobLink,
          icon: Icons.link_rounded,
          accent: Accent.blue,
          title: 'Job from a link',
          subtitle: 'Paste a LinkedIn, JobStreet or OnlineJobs.ph link',
        ),
        AddOption(
          value: QuickAddAction.application,
          icon: Icons.work_outline_rounded,
          accent: Accent.violet,
          title: 'Application',
          subtitle: 'Type in a role you saved or applied for',
        ),
        AddOption(
          value: QuickAddAction.agendaEvent,
          icon: Icons.event_outlined,
          accent: Accent.teal,
          title: 'Interview or reminder',
          subtitle: 'Interviews, follow-ups and deadlines',
        ),
        AddOption(
          value: QuickAddAction.goal,
          icon: Icons.flag_outlined,
          accent: Accent.amber,
          title: 'Goal',
          subtitle: 'A target to keep you moving',
        ),
      ],
    );

class _Option<T> extends StatelessWidget {
  const _Option({required this.option});

  final AddOption<T> option;

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
      leading: IconBadge(icon: option.icon, accent: option.accent),
      title: Text(
        option.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(option.subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).pop(option.value),
    );
  }
}
