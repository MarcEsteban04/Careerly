import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/scroll_aware_status_bar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/staggered_reveal.dart';
import '../../../core/widgets/tab_page.dart';
import '../../applications/data/job_application.dart';
import '../../applications/presentation/widgets/application_tile.dart';
import '../../goals/data/goal.dart';
import '../../shell/data/workspace_controller.dart';
import '../../shell/data/workspace_data.dart';
import '../../shell/presentation/widgets/workspace_view.dart';
import 'widgets/ai_studio_banner.dart';
import 'widgets/dashboard_hero.dart';
import 'widgets/dashboard_skeleton.dart';
import 'widgets/goals_carousel.dart';
import 'widgets/next_up_card.dart';
import 'widgets/pipeline_card.dart';
import 'widgets/weekly_activity_card.dart';

/// Home tab: this week at a glance, what's next, and shortcuts into the
/// other tabs.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.firstName,
    required this.initial,
    required this.onAccountTap,
    required this.onAddApplication,
    required this.onAddAgendaEvent,
    required this.onAddGoal,
    required this.onEventDone,
    required this.onGoalIncrement,
    required this.onOpenApplications,
    required this.onOpenAgenda,
  });

  final WorkspaceController controller;
  final String? firstName;
  final String initial;
  final VoidCallback onAccountTap;
  final VoidCallback onAddApplication;
  final VoidCallback onAddAgendaEvent;
  final VoidCallback onAddGoal;
  final ValueChanged<String> onEventDone;
  final ValueChanged<Goal> onGoalIncrement;

  /// Opens the Jobs tab, optionally filtered to one stage.
  final ValueChanged<ApplicationStatus?> onOpenApplications;
  final VoidCallback onOpenAgenda;

  static const _recentPreview = 4;

  @override
  Widget build(BuildContext context) {
    return ScrollAwareStatusBar(
      // Roughly where the hero's bottom edge passes under the status bar.
      threshold: 260,
      child: RefreshIndicator(
        onRefresh: controller.load,
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final data = controller.data;
            return ListView(
              padding: EdgeInsets.only(
                bottom:
                    kFloatingNavClearance + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                DashboardHero(
                  firstName: firstName,
                  initial: initial,
                  onAccountTap: onAccountTap,
                  stats: data == null
                      ? null
                      : HeroStats(
                          appliedThisWeek: data.appliedThisWeek(),
                          interviewsNextWeek: data.interviewsNextWeek(),
                          offers: data.countWith(ApplicationStatus.offer),
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: WorkspaceView(
                      controller: controller,
                      loading: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: DashboardSkeleton(),
                      ),
                      builder: (context, data) => _buildSections(context, data),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSections(BuildContext context, WorkspaceData data) {
    final today = DateTime.now();
    final nextEvent = data.nextEvent;
    var index = 0;

    Widget section(Widget child, {bool padded = true}) => StaggeredReveal(
          index: index++,
          child: padded
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: child,
                )
              : child,
        );

    const gap = SizedBox(height: AppSpacing.xl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          NextUpCard(
            event: nextEvent,
            onDone: () {
              if (nextEvent != null) onEventDone(nextEvent.id);
            },
            onSchedule: onAddAgendaEvent,
            onSeeAgenda: onOpenAgenda,
          ),
        ),
        gap,
        section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(title: 'This week'),
              WeeklyActivityCard(
                perWeekday: data.appliedPerWeekday(today),
                todayIndex: today.weekday - 1,
              ),
            ],
          ),
        ),
        gap,
        section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'Pipeline',
                actionLabel: 'See all',
                actionIcon: Icons.chevron_right_rounded,
                trailingIcon: true,
                onAction: () => onOpenApplications(null),
              ),
              PipelineCard(
                countOf: data.countWith,
                onStageTap: onOpenApplications,
              ),
            ],
          ),
        ),
        gap,
        section(
          SectionHeader(title: 'Goals', actionLabel: 'Add', onAction: onAddGoal),
        ),
        section(
          GoalsCarousel(
            goals: data.goals,
            onIncrement: onGoalIncrement,
            onAdd: onAddGoal,
          ),
          padded: false,
        ),
        gap,
        section(const AiStudioBanner()),
        gap,
        section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'Recent applications',
                actionLabel: data.applications.isEmpty ? 'Add' : 'See all',
                actionIcon: data.applications.isEmpty
                    ? Icons.add_rounded
                    : Icons.chevron_right_rounded,
                trailingIcon: data.applications.isNotEmpty,
                onAction: data.applications.isEmpty
                    ? onAddApplication
                    : () => onOpenApplications(null),
              ),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: data.applications.isEmpty
                    ? Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: EmptyState(
                          icon: Icons.work_outline_rounded,
                          title: 'No applications yet',
                          message: 'Track every role you save or apply for, '
                              'all in one place.',
                          actionLabel: 'Add application',
                          onAction: onAddApplication,
                        ),
                      )
                    : Column(
                        children: [
                          for (final application
                              in data.applications.take(_recentPreview))
                            ApplicationTile(application: application),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
