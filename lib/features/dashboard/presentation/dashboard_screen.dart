import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/emphasis_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/header_wash.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../../core/widgets/search_pill.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/staggered_reveal.dart';
import '../../../core/widgets/tab_page.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../applications/data/job_application.dart';
import '../../applications/data/stale_applications.dart';
import '../../applications/presentation/widgets/job_card.dart';
import '../../shell/data/workspace_controller.dart';
import '../../shell/data/workspace_data.dart';
import '../../shell/presentation/widgets/workspace_view.dart';
import 'widgets/dashboard_skeleton.dart';
import 'widgets/next_up_card.dart';

/// Home tab: greeting, search, what's next, and your applications by stage.
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
  static const _sheetRadius = 28.0;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: RefreshIndicator(
        onRefresh: widget.controller.load,
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: ListView(
          padding: EdgeInsets.only(
            bottom: kFloatingNavClearance + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            HeaderWash(
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.lg + _sheetRadius,
                      ),
                      child: _buildHeader(context),
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -_sheetRadius),
              child: _buildSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final dueSoon = widget.controller.data?.upcoming
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
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        widget.name ?? 'there',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
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
              "Let's get you **hired** for the job you **deserve**!",
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 28),
            ),
            const SizedBox(height: AppSpacing.lg),
            SearchPill(
              hint: 'Search your applications',
              onTap: widget.onSearchTap,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_sheetRadius),
        ),
        border: Border(top: BorderSide(color: colorScheme.outline)),
      ),
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
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
        const SizedBox(height: AppSpacing.lg),
        section(const SectionHeader(title: 'Category')),
        section(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
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
        const SizedBox(height: AppSpacing.lg),
        section(
          SectionHeader(
            title: 'Your applications',
            actionLabel: data.applications.isEmpty ? 'Add' : 'See All',
            actionIcon: Icons.add_rounded,
            trailingIcon: data.applications.isNotEmpty,
            showIcon: data.applications.isEmpty,
            onAction: data.applications.isEmpty
                ? widget.onAddApplication
                : () => widget.onSeeAllApplications(category),
          ),
        ),
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

    return AppCard(
      onTap: onTap,
      color: colorScheme.tertiaryContainer.withValues(alpha: 0.35),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.hourglass_bottom_rounded,
              color: colorScheme.primary,
            ),
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
                      ?.copyWith(fontWeight: FontWeight.w600),
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
          Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
