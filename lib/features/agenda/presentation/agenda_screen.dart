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

/// Agenda tab: upcoming interviews and reminders, grouped by day.
class AgendaScreen extends StatelessWidget {
  const AgendaScreen({
    super.key,
    required this.controller,
    required this.onAdd,
    required this.onToggleDone,
  });

  final WorkspaceController controller;
  final VoidCallback onAdd;
  final void Function(String id, bool isDone) onToggleDone;

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
                        message: 'Add interviews, follow-ups and deadlines so '
                            'nothing slips.',
                        actionLabel: 'Add to agenda',
                        onAction: onAdd,
                      ),
                    )
                  : _GroupedAgenda(events: events, onToggleDone: onToggleDone),
            ),
          ],
        );
      },
    );
  }
}

class _GroupedAgenda extends StatelessWidget {
  const _GroupedAgenda({required this.events, required this.onToggleDone});

  final List<AgendaEvent> events;
  final void Function(String id, bool isDone) onToggleDone;

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
              bottom: AppSpacing.xs,
            ),
            child: Text(
              entry.key.relativeDayLabel(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: entry.key.isSameDay(DateTime.now())
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
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
                  AgendaTile(
                    event: event,
                    onToggleDone: (done) => onToggleDone(event.id, done),
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
