import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/tag_pill.dart';
import '../../data/job_application.dart';
import '../application_status_style.dart';
import 'company_avatar.dart';

/// Kanban board: one column per stage. Long-press a card and drag it to
/// another column to move it, or use its move button. Columns sit in one
/// horizontal strip; the page scrolls vertically as usual.
class ApplicationBoard extends StatefulWidget {
  const ApplicationBoard({
    super.key,
    required this.applications,
    required this.stages,
    required this.onOpen,
    required this.onMove,
    required this.onPickStage,
  });

  /// Already searched, filtered and sorted.
  final List<JobApplication> applications;
  final List<ApplicationStatus> stages;
  final ValueChanged<JobApplication> onOpen;

  /// A card was dropped on another stage's column.
  final void Function(JobApplication application, ApplicationStatus status)
      onMove;

  /// The card's move button: pick a stage from a list.
  final ValueChanged<JobApplication> onPickStage;

  static const columnWidth = 264.0;

  @override
  State<ApplicationBoard> createState() => _ApplicationBoardState();
}

class _ApplicationBoardState extends State<ApplicationBoard> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the strip while a card is dragged near the screen's edge.
  void _autoScroll(DragUpdateDetails details) {
    if (!_scroll.hasClients) return;
    final width = MediaQuery.sizeOf(context).width;
    const edge = 56.0;
    final x = details.globalPosition.dx;
    final delta = x < edge
        ? -14.0
        : x > width - edge
            ? 14.0
            : 0.0;
    if (delta == 0) return;
    final position = _scroll.position;
    _scroll.jumpTo(
      (position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, stage) in widget.stages.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            _Column(
              stage: stage,
              applications: [
                for (final a in widget.applications)
                  if (a.status == stage) a,
              ],
              onOpen: widget.onOpen,
              onMove: widget.onMove,
              onPickStage: widget.onPickStage,
              onDragUpdate: _autoScroll,
            ),
          ],
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.stage,
    required this.applications,
    required this.onOpen,
    required this.onMove,
    required this.onPickStage,
    required this.onDragUpdate,
  });

  final ApplicationStatus stage;
  final List<JobApplication> applications;
  final ValueChanged<JobApplication> onOpen;
  final void Function(JobApplication, ApplicationStatus) onMove;
  final ValueChanged<JobApplication> onPickStage;
  final ValueChanged<DragUpdateDetails> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = stage.colorIn(theme);

    return DragTarget<JobApplication>(
      onWillAcceptWithDetails: (details) => details.data.status != stage,
      onAcceptWithDetails: (details) {
        HapticFeedback.mediumImpact();
        onMove(details.data, stage);
      },
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: ApplicationBoard.columnWidth,
          constraints: const BoxConstraints(minHeight: 220),
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: hovering
                ? color.withValues(alpha: 0.10)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: hovering ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 4,
                margin: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.xxs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.xxs,
                  AppSpacing.xs,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    StatusDot(color: color),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        stage.label,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${applications.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (applications.isEmpty)
                Container(
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Text(
                    hovering ? 'Drop here' : 'Nothing here yet',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              for (final (i, application) in applications.indexed) ...[
                if (i > 0) const SizedBox(height: AppSpacing.xs),
                LongPressDraggable<JobApplication>(
                  data: application,
                  hapticFeedbackOnStart: true,
                  onDragUpdate: onDragUpdate,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: ApplicationBoard.columnWidth - AppSpacing.md,
                      child: Transform.rotate(
                        angle: -0.03,
                        child: _BoardCard(
                          application: application,
                          lifted: true,
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.35,
                    child: _BoardCard(application: application),
                  ),
                  child: _BoardCard(
                    application: application,
                    onTap: () => onOpen(application),
                    onMove: () => onPickStage(application),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.application,
    this.onTap,
    this.onMove,
    this.lifted = false,
  });

  final JobApplication application;
  final VoidCallback? onTap;
  final VoidCallback? onMove;

  /// Being dragged: a stronger shadow.
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final salary = application.salary;

    return Material(
      color: colorScheme.surface,
      elevation: lifted ? 8 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Semantics(
          label: '${application.role} at ${application.company}. Long-press '
              'and drag to move it.',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xxs,
              AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompanyAvatar(company: application.company, size: 34),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.role,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        application.company,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      if (salary != null && salary.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          salary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onMove != null)
                  IconButton(
                    tooltip: 'Move ${application.role}',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.swap_horiz_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onMove,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
