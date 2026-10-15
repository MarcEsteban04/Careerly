import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../../core/widgets/search_pill.dart';
import '../../../core/widgets/tab_page.dart';
import '../../shell/data/workspace_controller.dart';
import '../../shell/presentation/widgets/workspace_view.dart';
import '../data/job_application.dart';
import 'widgets/job_card.dart';

/// Jobs tab: every application, searchable and filterable by stage.
class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({
    super.key,
    required this.controller,
    required this.filter,
    required this.onFilterChanged,
    required this.searchController,
    required this.searchFocusNode,
    required this.onOpenApplication,
    required this.onAdd,
  });

  final WorkspaceController controller;

  /// Null shows every stage.
  final ApplicationStatus? filter;
  final ValueChanged<ApplicationStatus?> onFilterChanged;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onOpenApplication;
  final VoidCallback onAdd;

  static bool _matches(JobApplication a, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return a.role.toLowerCase().contains(q) ||
        a.company.toLowerCase().contains(q) ||
        (a.location?.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, searchController]),
      builder: (context, _) {
        final data = controller.data;
        final applications = data?.applications ?? const <JobApplication>[];
        final query = searchController.text.trim();
        final visible = applications
            .where((a) => filter == null || a.status == filter)
            .where((a) => _matches(a, query))
            .toList();

        return TabPage(
          title: 'Applications',
          subtitle: data == null
              ? null
              : applications.length == 1
                  ? '1 role tracked'
                  : '${applications.length} roles tracked',
          onRefresh: controller.load,
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchPill(
                hint: 'Search roles or companies',
                controller: searchController,
                focusNode: searchFocusNode,
              ),
              const SizedBox(height: AppSpacing.md),
              _FilterBar(
                applications: applications,
                selected: filter,
                onSelected: onFilterChanged,
              ),
            ],
          ),
          children: [
            WorkspaceView(
              controller: controller,
              builder: (context, data) => visible.isEmpty
                  ? AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.lg,
                      ),
                      child: _buildEmpty(applications.isEmpty, query),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final application in visible) ...[
                          JobCard(
                            application: application,
                            nextEvent: data.nextEventFor(application.id),
                            onTap: () => onOpenApplication(application.id),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
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
    return EmptyState(
      icon: Icons.filter_list_rounded,
      title: 'Nothing in ${filter!.label}',
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
