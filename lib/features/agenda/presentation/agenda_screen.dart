import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tab_page.dart';
import '../../shell/data/workspace_controller.dart';
import '../../shell/presentation/widgets/workspace_view.dart';
import '../data/agenda_event.dart';
import 'widgets/agenda_tile.dart';
import 'widgets/week_strip.dart';

/// Agenda tab: upcoming interviews and reminders, grouped by day.
class AgendaScreen extends StatelessWidget {
  const AgendaScreen({
    super.key,
    required this.controller,
    required this.onAdd,
    required this.onToggleDone,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkspaceController controller;
  final VoidCallback onAdd;
  final void Function(String id, bool isDone) onToggleDone;
  final ValueChanged<AgendaEvent> onEdit;

  /// Confirms and deletes; resolves to true if the item was removed.
  final Future<bool> Function(AgendaEvent event) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final events = controller.data?.upcoming ?? const <AgendaEvent>[];
        final open = events.where((e) => !e.isDone).length;

        return TabPage(
          title: 'Agenda',
          subtitle: controller.data == null
              ? null
              : open == 0
              ? 'Nothing coming up'
              : open == 1
              ? '1 thing coming up'
              : '$open things coming up',
          onRefresh: controller.load,
          heroChild: controller.data == null
              ? null
              : WeekStrip(events: events, today: DateTime.now()),
          children: [
            WorkspaceView(
              controller: controller,
              builder: (context, _) => events.isEmpty
                  ? AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.lg,
                      ),
                      child: EmptyState(
                        icon: Icons.event_available_outlined,
                        title: 'Nothing scheduled',
                        message:
                            'Add interviews, follow-ups and deadlines so '
                            'nothing slips.',
                        actionLabel: 'Add to agenda',
                        onAction: onAdd,
                      ),
                    )
                  : _GroupedAgenda(
                      events: events,
                      onToggleDone: onToggleDone,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _GroupedAgenda extends StatelessWidget {
  const _GroupedAgenda({
    required this.events,
    required this.onToggleDone,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AgendaEvent> events;
  final void Function(String id, bool isDone) onToggleDone;
  final ValueChanged<AgendaEvent> onEdit;
  final Future<bool> Function(AgendaEvent event) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = <DateTime, List<AgendaEvent>>{};
    for (final event in events) {
      groups.putIfAbsent(event.startsAt.dateOnly, () => []).add(event);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxs,
              bottom: AppSpacing.sm,
            ),
            child: Row(
              children: [
                _DayLabel(
                  label: entry.key.relativeDayLabel(),
                  isToday: entry.key.isSameDay(DateTime.now()),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  entry.value.length == 1 ? '1 item' : '${entry.value.length} items',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          AppCard(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Column(
              children: [
                for (final event in entry.value)
                  // Tap to edit, swipe left to delete.
                  Dismissible(
                    key: ValueKey(event.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => onDelete(event),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    child: AgendaTile(
                      event: event,
                      onToggleDone: (done) => onToggleDone(event.id, done),
                      onTap: () => onEdit(event),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

/// A day heading: "Today" stands out as an ink pill.
class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.label, required this.isToday});

  final String label;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: isToday ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
    );
    if (!isToday) return Text(label, style: style);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: style),
    );
  }
}
