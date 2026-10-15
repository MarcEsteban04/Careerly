import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/tag_pill.dart';
import '../../../../core/widgets/tray_card.dart';
import '../../../agenda/data/agenda_event.dart';
import '../../data/job_application.dart';
import '../application_status_style.dart';
import 'company_avatar.dart';
import 'salary_text.dart';

/// Tracked application card: role, company, tags, and a footer with when
/// it was last touched and anything that needs attention.
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
    final subtitle = [
      application.company,
      if (application.location != null) application.location!,
    ].join('  •  ');
    final verb = switch (application.status) {
      ApplicationStatus.saved => 'Saved',
      ApplicationStatus.applied => 'Applied',
      _ => 'Updated',
    };
    final when = application.status == ApplicationStatus.applied
        ? (application.appliedOn ?? application.updatedAt)
        : application.updatedAt;

    return TrayCard(
      onTap: onTap,
      semanticLabel: '${application.role} at ${application.company}, '
          '${application.status.label}',
      body: Column(
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
                SalaryText(application.salary!),
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
      footer: TrayFooter(
        text: '$verb ${when.agoLabel().toLowerCase()}',
        badge: _badge(theme),
      ),
    );
  }

  /// Highlights what needs attention, like the reference's "URGENT" label.
  Widget? _badge(ThemeData theme) {
    final event = nextEvent;
    if (event != null) {
      return TrayBadge(
        label: '${event.kind.label} · ${event.startsAt.relativeDayLabel()}',
        color: ApplicationStatus.interviewing.colorIn(theme),
      );
    }
    return switch (application.status) {
      ApplicationStatus.offer => TrayBadge(
          label: 'Offer',
          color: ApplicationStatus.offer.colorIn(theme),
        ),
      ApplicationStatus.rejected => TrayBadge(
          label: 'Closed',
          color: theme.colorScheme.onSurfaceVariant,
        ),
      _ => null,
    };
  }
}
