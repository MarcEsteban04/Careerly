import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/tag_pill.dart';
import '../../../agenda/data/agenda_event.dart';
import '../../data/job_application.dart';
import '../application_status_style.dart';
import 'company_avatar.dart';

/// Application card: a white card for the role, set in a soft tray whose
/// footer shows when it was last touched and anything that needs attention.
class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.application,
    required this.onTap,
    this.nextEvent,
  });

  final JobApplication application;
  final VoidCallback onTap;

  /// The application's next open agenda item, if any.
  final AgendaEvent? nextEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(AppRadius.lg);

    return Semantics(
      button: true,
      label: '${application.role} at ${application.company}, '
          '${application.status.label}',
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBody(context),
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtitle = [
      application.company,
      if (application.location != null) application.location!,
    ].join('  •  ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompanyAvatar(company: application.company),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (application.salary != null) ...[
                const SizedBox(width: AppSpacing.xs),
                _Salary(application.salary!),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              TagPill(
                label: application.status.label,
                leading: StatusDot(color: application.status.colorIn(theme)),
              ),
              if (application.jobUrl != null)
                const TagPill(
                  label: 'Job post',
                  leading: Icon(Icons.link_rounded, size: 14),
                ),
              if (application.notes != null)
                const TagPill(
                  label: 'Notes',
                  leading: Icon(Icons.sticky_note_2_outlined, size: 14),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final verb = switch (application.status) {
      ApplicationStatus.saved => 'Saved',
      ApplicationStatus.applied => 'Applied',
      _ => 'Updated',
    };
    final when = application.status == ApplicationStatus.applied
        ? (application.appliedOn ?? application.updatedAt)
        : application.updatedAt;
    final badge = _badge(theme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs + 2,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$verb ${when.agoLabel().toLowerCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          ?badge,
        ],
      ),
    );
  }

  /// Highlights what needs attention, like the reference's "URGENT" label.
  Widget? _badge(ThemeData theme) {
    final event = nextEvent;
    final (String, Color)? content = event != null
        ? (
            '${event.kind.label} · ${event.startsAt.relativeDayLabel()}'
                .toUpperCase(),
            ApplicationStatus.interviewing.colorIn(theme),
          )
        : switch (application.status) {
            ApplicationStatus.offer => (
                'OFFER',
                ApplicationStatus.offer.colorIn(theme),
              ),
            ApplicationStatus.rejected => (
                'CLOSED',
                theme.colorScheme.onSurfaceVariant,
              ),
            _ => null,
          };
    if (content == null) return null;
    final (label, color) = content;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// "$4,000/month" with the amount bold and the period muted.
class _Salary extends StatelessWidget {
  const _Salary(this.salary);

  final String salary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slash = salary.indexOf('/');
    final amount = slash == -1 ? salary : salary.substring(0, slash);
    final period = slash == -1 ? '' : salary.substring(slash);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: amount,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (period.isNotEmpty)
              TextSpan(
                text: period,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: theme.textTheme.titleMedium,
      ),
    );
  }
}
