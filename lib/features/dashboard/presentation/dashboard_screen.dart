import 'package:flutter/material.dart';

import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/emphasis_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../../core/widgets/scroll_aware_status_bar.dart';
import '../../../core/widgets/search_pill.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/staggered_reveal.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/tab_page.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../applications/data/job_application.dart';
import '../../applications/data/stale_applications.dart';
import '../../applications/presentation/widgets/job_card.dart';
import '../../shell/data/workspace_controller.dart';
import '../../shell/data/workspace_data.dart';
import '../../shell/presentation/widgets/workspace_view.dart';
import 'widgets/dashboard_skeleton.dart';
import 'widgets/momentum_card.dart';
import 'widgets/next_up_card.dart';

/// Home tab: a greeting hero with your numbers, what's next, your
/// momentum, and your applications by stage.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.name,
    required this.initial,
    required this.onAccountTap,
    required this.onSearchTap,
    required this.onOpenApplication,
    required this.onSeeAllApplications,
    required this.onOpenAgenda,
    required this.onAddApplication,
    required this.onAddAgendaEvent,
    required this.onEventDone,
    required this.onNotificationsTap,
    required this.onReviewQuiet,
    this.newJobAlerts = 0,
    this.avatarUrl,
  });

  /// Opens the review of applications that went quiet.
  final VoidCallback onReviewQuiet;

  final WorkspaceController controller;

  /// Profile photo; the initial shows when there's none.
  final String? avatarUrl;

  /// Opens the notification center (the bell).
  final VoidCallback onNotificationsTap;

  /// New jobs found by alerts, added to the bell's badge.
  final int newJobAlerts;
  final String? name;
  final String initial;
  final VoidCallback onAccountTap;
  final VoidCallback onSearchTap;
  final ValueChanged<String> onOpenApplication;

  /// Opens the Jobs tab, filtered to a stage (or everything when null).
  final ValueChanged<ApplicationStatus?> onSeeAllApplications;
  final VoidCallback onOpenAgenda;
  final VoidCallback onAddApplication;
  final VoidCallback onAddAgendaEvent;
  final ValueChanged<String> onEventDone;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _preview = 5;
  static const _categories = [
    ApplicationStatus.saved,
    ApplicationStatus.applied,
    ApplicationStatus.interviewing,
    ApplicationStatus.offer,
  ];

  ApplicationStatus? _category;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ScrollAwareStatusBar(
      threshold: 120,
      child: RefreshIndicator(
        onRefresh: widget.controller.load,
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: ListView(
          padding: EdgeInsets.only(bottom: kFloatingNavClearance + bottom),
          children: [
            HeroHeader(child: _buildHeader(context)),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: WorkspaceView(
                    controller: widget.controller,
                    loading: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: DashboardSkeleton(),
                    ),
                    builder: _buildSections,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _greeting(DateTime now) => now.hour < 12
      ? 'Good morning'
      : now.hour < 18
          ? 'Good afternoon'
          : 'Good evening';

  Widget _buildHeader(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        // Read here, under the hero, so text picks up its white style.
        final theme = Theme.of(context);
        final data = widget.controller.data;
        final dueSoon = data?.upcoming
                .where(
                  (e) =>
                      !e.isDone &&
                      e.startsAt.isBefore(
                        DateTime.now().add(const Duration(days: 1)),
                      ),
                )
                .length ??
            0;
        final badge = dueSoon + widget.newJobAlerts;
        final tooltip = [
          if (dueSoon > 0) '$dueSoon due in the next day',
          if (widget.newJobAlerts > 0) '${widget.newJobAlerts} new jobs',
        ];
        String count(ApplicationStatus? status) => data == null
            ? '–'
            : '${data.applications.where((a) => status == null || a.status == status).length}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Account',
                  child: InkResponse(
                    onTap: widget.onAccountTap,
                    radius: 28,
                    child: UserAvatar(
                      initial: widget.initial,
                      photoUrl: widget.avatarUrl,
                      ring: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(DateTime.now()),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        widget.name ?? 'there',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                CircleIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: tooltip.isEmpty
                      ? 'Notifications'
                      : 'Notifications, ${tooltip.join(', ')}',
                  badge: badge,
                  onPressed: widget.onNotificationsTap,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            EmphasisText(
              'Your next **big move** starts **here**.',
              emphasisColor: theme.colorScheme.secondary,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontSize: 30, height: 1.18),
            ),
            const SizedBox(height: AppSpacing.lg),
            SearchPill(
              hint: 'Search your applications',
              onTap: widget.onSearchTap,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: count(null),
                    label: 'Tracked',
                    icon: Icons.work_rounded,
                    onTap: () => widget.onSeeAllApplications(null),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Expanded(
                  child: StatTile(
                    value: count(ApplicationStatus.interviewing),
                    label: 'Interviews',
                    icon: Icons.forum_rounded,
                    accent: Accent.amber,
                    onTap: () => widget.onSeeAllApplications(
                      ApplicationStatus.interviewing,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Expanded(
                  child: StatTile(
                    value: count(ApplicationStatus.offer),
                    label: 'Offers',
                    icon: Icons.celebration_rounded,
                    accent: Accent.emerald,
                    onTap: () =>
                        widget.onSeeAllApplications(ApplicationStatus.offer),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSections(BuildContext context, WorkspaceData data) {
    final nextEvent = data.nextEvent;
    final quiet = StaleApplications.find(data.applications);
    final category = _category;
    final visible = category == null
        ? data.applications
        : data.applications.where((a) => a.status == category).toList();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'Up next',
                actionLabel: 'Agenda',
                actionIcon: Icons.chevron_right_rounded,
                trailingIcon: true,
                onAction: widget.onOpenAgenda,
              ),
              NextUpCard(
                event: nextEvent,
                onDone: () {
                  if (nextEvent != null) widget.onEventDone(nextEvent.id);
                },
                onSchedule: widget.onAddAgendaEvent,
                onSeeAgenda: widget.onOpenAgenda,
              ),
            ],
          ),
        ),
        if (quiet.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          section(_QuietCard(count: quiet.length, onTap: widget.onReviewQuiet)),
        ],
        if (data.applications.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          section(
            MomentumCard(
              applications: data.applications,
              onOpenStage: widget.onSeeAllApplications,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        section(
          SectionHeader(
            title: 'Your applications',
            actionLabel: data.applications.isEmpty ? 'Add' : 'See all',
            actionIcon: data.applications.isEmpty
                ? Icons.add_rounded
                : Icons.chevron_right_rounded,
            trailingIcon: data.applications.isNotEmpty,
            onAction: data.applications.isEmpty
                ? widget.onAddApplication
                : () => widget.onSeeAllApplications(category),
          ),
        ),
        if (data.applications.isNotEmpty) ...[
          section(
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  PillChip(
                    label: 'All',
                    selected: category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final status in _categories) ...[
                    const SizedBox(width: AppSpacing.xs),
                    PillChip(
                      label: status.label,
                      selected: category == status,
                      onTap: () => setState(() => _category = status),
                    ),
                  ],
                ],
              ),
            ),
            padded: false,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        section(
          visible.isEmpty
              ? AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.lg,
                  ),
                  child: data.applications.isEmpty
                      ? EmptyState(
                          icon: Icons.work_outline_rounded,
                          title: 'No applications yet',
                          message: 'Track every role you save or apply for, '
                              'all in one place.',
                          actionLabel: 'Add application',
                          onAction: widget.onAddApplication,
                        )
                      : EmptyState(
                          icon: Icons.filter_list_rounded,
                          accent: Accent.violet,
                          title: 'Nothing in ${category!.label}',
                          message: 'Applications show up here as you move '
                              'them along.',
                        ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final application in visible.take(_preview)) ...[
                      JobCard(
                        application: application,
                        nextEvent: data.nextEventFor(application.id),
                        onTap: () => widget.onOpenApplication(application.id),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// "N applications have gone quiet": opens the review sheet.
class _QuietCard extends StatelessWidget {
  const _QuietCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tone = Accent.amber.colorIn(theme.brightness);

    return AppCard(
      onTap: onTap,
      color: Color.alphaBlend(tone.withValues(alpha: 0.07), colorScheme.surface),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.hourglass_bottom_rounded,
            accent: Accent.amber,
            size: 44,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? '1 application has gone quiet'
                      : '$count applications have gone quiet',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Follow up, wait a bit longer, or close them out.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: tone),
        ],
      ),
    );
  }
}
