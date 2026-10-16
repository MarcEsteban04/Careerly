import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../../core/widgets/search_pill.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../../core/widgets/tab_page.dart';
import '../../discover/data/discover_controller.dart';
import '../../discover/presentation/discover_view.dart';
import '../../shell/data/workspace_controller.dart';
import '../../shell/presentation/widgets/workspace_view.dart';
import '../data/job_application.dart';
import '../data/tracked_view.dart';
import 'status_picker_sheet.dart';
import 'widgets/application_board.dart';
import 'widgets/job_card.dart';
import 'widgets/tracked_toolbar.dart';

enum JobsSection { tracked, discover }

/// Jobs tab. "Tracked" lists every application, searchable and filterable by
/// stage; "Discover" searches job boards for openings that fit the profile.
class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({
    super.key,
    required this.controller,
    required this.section,
    required this.onSectionChanged,
    required this.filter,
    required this.onFilterChanged,
    required this.searchController,
    required this.searchFocusNode,
    required this.onOpenApplication,
    required this.onAdd,
    required this.discover,
    required this.discoverSearchController,
    required this.isListingSaved,
    required this.onOpenListing,
    required this.onEditProfile,
    required this.onDismissListing,
    required this.onToggleSaveSearch,
    required this.trackedView,
    required this.onMoveApplications,
    required this.onDeleteApplications,
  });

  final WorkspaceController controller;

  /// List or board, sort, filters and selection for Tracked.
  final TrackedViewController trackedView;

  /// Moves applications to a stage (one dropped on the board, or several
  /// selected).
  final void Function(List<JobApplication> applications, ApplicationStatus to)
      onMoveApplications;
  final ValueChanged<List<JobApplication>> onDeleteApplications;
  final JobsSection section;
  final ValueChanged<JobsSection> onSectionChanged;
  final DiscoverController discover;
  final TextEditingController discoverSearchController;
  final bool Function(RankedListing ranked) isListingSaved;
  final ValueChanged<RankedListing> onOpenListing;
  final VoidCallback onEditProfile;
  final ValueChanged<RankedListing> onDismissListing;
  final VoidCallback onToggleSaveSearch;

  /// Null shows every stage.
  final ApplicationStatus? filter;
  final ValueChanged<ApplicationStatus?> onFilterChanged;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onOpenApplication;
  final VoidCallback onAdd;

  Future<void> _moveSelected(
    BuildContext context,
    List<JobApplication> selected,
  ) async {
    final status = await showStatusPicker(
      context,
      title: 'Move ${selected.length} to…',
    );
    if (status != null) onMoveApplications(selected, status);
  }

  Future<void> _pickStage(
    BuildContext context,
    JobApplication application,
  ) async {
    final status = await showStatusPicker(
      context,
      current: application.status,
    );
    if (status != null && status != application.status) {
      onMoveApplications([application], status);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller,
        searchController,
        discover,
        trackedView,
      ]),
      builder: (context, _) {
        final data = controller.data;
        final applications = data?.applications ?? const <JobApplication>[];
        final query = searchController.text.trim();
        final board = trackedView.layout == TrackedLayout.board;
        final visible = trackedView.apply(
          applications,
          // The board shows every stage as a column.
          status: board ? null : filter,
          query: query,
        );
        final selected = [
          for (final a in applications)
            if (trackedView.isSelected(a.id)) a,
        ];
        final discovering = section == JobsSection.discover;

        final sectionTabs = SegmentedTabs(
          labels: const ['Tracked', 'Discover'],
          selectedIndex: section.index,
          onSelected: (i) => onSectionChanged(JobsSection.values[i]),
        );

        if (discovering) {
          return TabPage(
            title: 'Jobs',
            subtitle: 'Openings matched to your profile',
            onRefresh: discover.results == null ? () async {} : discover.refresh,
            heroChild: sectionTabs,
            header: DiscoverHeader(
              controller: discover,
              searchController: discoverSearchController,
              onEditProfile: onEditProfile,
            ),
            children: [
              DiscoverResults(
                controller: discover,
                searchController: discoverSearchController,
                isSaved: isListingSaved,
                onOpenListing: onOpenListing,
                onEditProfile: onEditProfile,
                onDismiss: onDismissListing,
                onToggleSaveSearch: onToggleSaveSearch,
              ),
            ],
          );
        }

        final page = TabPage(
          title: 'Jobs',
          subtitle: data == null
              ? null
              : applications.length == 1
                  ? '1 role tracked'
                  : '${applications.length} roles tracked',
          onRefresh: controller.load,
          heroChild: sectionTabs,
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchPill(
                hint: 'Search roles or companies',
                controller: searchController,
                focusNode: searchFocusNode,
              ),
              const SizedBox(height: AppSpacing.md),
              TrackedToolbar(view: trackedView),
              if (!board) ...[
                const SizedBox(height: AppSpacing.sm),
                _FilterBar(
                  applications: applications,
                  selected: filter,
                  onSelected: onFilterChanged,
                ),
              ],
            ],
          ),
          children: [
            WorkspaceView(
              controller: controller,
              builder: (context, data) {
                if (applications.isEmpty || (!board && visible.isEmpty)) {
                  return AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.lg,
                    ),
                    child: _buildEmpty(applications.isEmpty, query),
                  );
                }
                if (board) {
                  return ApplicationBoard(
                    applications: visible,
                    stages: [
                      for (final stage in ApplicationStatus.values)
                        if (!(trackedView.hideClosed &&
                            stage == ApplicationStatus.rejected))
                          stage,
                    ],
                    onOpen: (a) => onOpenApplication(a.id),
                    onMove: (a, status) => onMoveApplications([a], status),
                    onPickStage: (a) => _pickStage(context, a),
                  );
                }
                final selecting = trackedView.isSelecting;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!selecting && visible.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text(
                          'Tip: long-press a job to select several.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    for (final application in visible) ...[
                      JobCard(
                        application: application,
                        nextEvent: data.nextEventFor(application.id),
                        selected: selecting
                            ? trackedView.isSelected(application.id)
                            : null,
                        onTap: selecting
                            ? () => trackedView.toggleSelected(application.id)
                            : () => onOpenApplication(application.id),
                        onLongPress: () {
                          HapticFeedback.selectionClick();
                          trackedView.toggleSelected(application.id);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                );
              },
            ),
          ],
        );

        if (!trackedView.isSelecting) return page;
        // Floats at the top so it stays in reach wherever the list is
        // scrolled.
        return Stack(
          children: [
            page,
            Positioned(
              top: MediaQuery.paddingOf(context).top + AppSpacing.xs,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: Material(
                color: Colors.transparent,
                elevation: 6,
                shadowColor: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(999),
                child: SelectionBar(
                  count: selected.length,
                  allSelected: selected.length == visible.length,
                  onSelectAll: () => selected.length == visible.length
                      ? trackedView.clearSelection()
                      : trackedView.selectAll(visible.map((a) => a.id)),
                  onMove: () => _moveSelected(context, selected),
                  onDelete: () => onDeleteApplications(selected),
                  onCancel: trackedView.clearSelection,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty(bool noApplications, String query) {
    if (noApplications) {
      return EmptyState(
        icon: Icons.work_outline_rounded,
        title: 'No applications yet',
        message: 'Track every role you save or apply for, all in one place.',
        actionLabel: 'Add application',
        onAction: onAdd,
      );
    }
    if (query.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches for "$query"',
        message: 'Try a different role, company or location.',
      );
    }
    if (trackedView.activeFilterCount > 0) {
      return EmptyState(
        icon: Icons.tune_rounded,
        title: 'Nothing matches your filters',
        message: 'Turn a filter off to see more.',
        actionLabel: 'Clear filters',
        actionIcon: Icons.filter_alt_off_outlined,
        onAction: trackedView.clearFilters,
      );
    }
    return EmptyState(
      icon: Icons.filter_list_rounded,
      title: 'Nothing in ${filter?.label ?? 'this view'}',
      message: 'Applications show up here as you move them along.',
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.applications,
    required this.selected,
    required this.onSelected,
  });

  final List<JobApplication> applications;
  final ApplicationStatus? selected;
  final ValueChanged<ApplicationStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    int count(ApplicationStatus s) =>
        applications.where((a) => a.status == s).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          PillChip(
            label: 'All ${applications.length}',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final status in ApplicationStatus.values) ...[
            const SizedBox(width: AppSpacing.xs),
            PillChip(
              label: '${status.label} ${count(status)}',
              selected: selected == status,
              onTap: () => onSelected(status),
            ),
          ],
        ],
      ),
    );
  }
}
