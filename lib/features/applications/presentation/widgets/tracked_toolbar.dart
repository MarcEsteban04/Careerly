import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/pill_chip.dart';
import '../../data/tracked_view.dart';

/// List/Board switch, Sort and Filter for the Tracked list.
class TrackedToolbar extends StatelessWidget {
  const TrackedToolbar({super.key, required this.view});

  final TrackedViewController view;

  @override
  Widget build(BuildContext context) {
    final filters = view.activeFilterCount;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _LayoutSwitch(view: view),
          const SizedBox(width: AppSpacing.xs),
          PillChip(
            label: view.sort.label,
            leading: const Icon(Icons.swap_vert_rounded),
            selected: false,
            onTap: () => _pickSort(context),
          ),
          const SizedBox(width: AppSpacing.xs),
          PillChip(
            label: filters == 0 ? 'Filter' : 'Filter · $filters',
            leading: const Icon(Icons.tune_rounded),
            selected: filters > 0,
            onTap: () => showTrackedFilterSheet(context, view: view),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSort(BuildContext context) async {
    final sort = await showModalBottomSheet<TrackedSort>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
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
                    AppSpacing.xs,
                    0,
                    AppSpacing.xs,
                    AppSpacing.xs,
                  ),
                  child: Text(
                    'Sort by',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final option in TrackedSort.values)
                  ListTile(
                    title: Text(option.label),
                    trailing: option == view.sort
                        ? Icon(
                            Icons.check_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (sort != null) view.setSort(sort);
  }
}

class _LayoutSwitch extends StatelessWidget {
  const _LayoutSwitch({required this.view});

  final TrackedViewController view;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget option(TrackedLayout layout, IconData icon, String label) {
      final selected = view.layout == layout;
      return Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => view.setLayout(layout),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? colorScheme.onSurface : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? colorScheme.surface : colorScheme.onSurface,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(TrackedLayout.list, Icons.view_agenda_outlined, 'List view'),
          option(TrackedLayout.board, Icons.view_kanban_outlined, 'Board view'),
        ],
      ),
    );
  }
}

/// Remote only, follow-up due, hide closed. Changes apply right away.
Future<void> showTrackedFilterSheet(
  BuildContext context, {
  required TrackedViewController view,
}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListenableBuilder(
        listenable: view,
        builder: (context, _) {
          final theme = Theme.of(context);
          return SafeArea(
            child: Padding(
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
                      AppSpacing.xs,
                      0,
                      AppSpacing.xs,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filter',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (view.activeFilterCount > 0)
                          TextButton(
                            onPressed: view.clearFilters,
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.public_rounded),
                    title: const Text('Remote only'),
                    value: view.remoteOnly,
                    onChanged: (v) => view.setFilters(remoteOnly: v),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.forward_to_inbox_rounded),
                    title: const Text('Follow-up due'),
                    subtitle: const Text('Follow-up date is today or past'),
                    value: view.followUpDue,
                    onChanged: (v) => view.setFilters(followUpDue: v),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.visibility_off_outlined),
                    title: const Text('Hide closed'),
                    subtitle: const Text('Leave out rejected applications'),
                    value: view.hideClosed,
                    onChanged: (v) => view.setFilters(hideClosed: v),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

/// Replaces search and filters while cards are selected.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.allSelected,
    required this.onSelectAll,
    required this.onMove,
    required this.onDelete,
    required this.onCancel,
  });

  final int count;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxs,
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.onSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancel selection',
            icon: Icon(Icons.close_rounded, color: colorScheme.surface),
            onPressed: onCancel,
          ),
          Expanded(
            child: Text(
              '$count selected',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.surface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: allSelected ? 'Deselect all' : 'Select all',
            icon: Icon(
              allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
              color: colorScheme.surface,
            ),
            onPressed: onSelectAll,
          ),
          IconButton(
            tooltip: 'Move to…',
            icon: Icon(Icons.swap_horiz_rounded, color: colorScheme.surface),
            onPressed: onMove,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(
              Icons.delete_outline_rounded,
              color: colorScheme.errorContainer,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
