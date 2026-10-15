import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tab_page.dart';
import '../../shell/data/workspace_controller.dart';
import '../../shell/presentation/widgets/workspace_view.dart';
import '../data/job_application.dart';
import 'application_status_style.dart';
import 'widgets/application_tile.dart';

/// Jobs tab: every application, filterable by stage.
class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({
    super.key,
    required this.controller,
    required this.filter,
    required this.onFilterChanged,
    required this.onAdd,
  });

  final WorkspaceController controller;

  /// Null shows every application.
  final ApplicationStatus? filter;
  final ValueChanged<ApplicationStatus?> onFilterChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final applications = controller.data?.applications ?? const [];
        final visible = filter == null
            ? applications
            : applications.where((a) => a.status == filter).toList();

        return TabPage(
          title: 'Applications',
          subtitle: controller.data == null
              ? null
              : applications.length == 1
                  ? '1 role tracked'
                  : '${applications.length} roles tracked',
          onRefresh: controller.load,
          header: _FilterBar(
            applications: applications,
            selected: filter,
            onSelected: onFilterChanged,
          ),
          children: [
            WorkspaceView(
              controller: controller,
              builder: (context, _) => AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: visible.isEmpty
                    ? Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: applications.isEmpty
                            ? EmptyState(
                                icon: Icons.work_outline_rounded,
                                title: 'No applications yet',
                                message: 'Track every role you save or apply '
                                    'for, all in one place.',
                                actionLabel: 'Add application',
                                onAction: onAdd,
                              )
                            : EmptyState(
                                icon: filter!.icon,
                                title: 'Nothing in ${filter!.label}',
                                message: 'Applications move here as you '
                                    'update their status.',
                              ),
                      )
                    : Column(
                        children: [
                          for (final application in visible)
                            ApplicationTile(application: application),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
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

    // Bleed to the screen edges so chips scroll under the page padding.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          ChoiceChip(
            label: Text('All ${applications.length}'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final status in ApplicationStatus.values) ...[
            const SizedBox(width: AppSpacing.xs),
            ChoiceChip(
              avatar: selected == status
                  ? null
                  : Icon(status.icon, size: 16, color: status.colorIn(Theme.of(context))),
              label: Text('${status.label} ${count(status)}'),
              selected: selected == status,
              onSelected: (_) => onSelected(status),
            ),
          ],
        ],
      ),
    );
  }
}
