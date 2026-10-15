import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/tag_pill.dart';
import '../../../../core/widgets/tray_card.dart';
import '../../../applications/presentation/widgets/salary_text.dart';
import '../../data/discover_controller.dart';
import 'company_logo.dart';
import 'match_style.dart';

/// A found job: employer, title, tags, source and how well it matches.
class JobListingCard extends StatelessWidget {
  const JobListingCard({
    super.key,
    required this.ranked,
    required this.isSaved,
    required this.onTap,
  });

  final RankedListing ranked;
  final bool isSaved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final job = ranked.listing;
    final match = ranked.match;
    final subtitle = [
      job.company,
      if (job.location != null) job.location!,
    ].join('  •  ');
    final posted = job.postedAt?.agoLabel() ?? job.postedLabel;

    return TrayCard(
      onTap: onTap,
      semanticLabel: '${job.title} at ${job.company}'
          '${match == null ? '' : ', ${match.score}% match'}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompanyLogo(company: job.company, url: job.companyLogoUrl),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 2,
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
              if (job.salary != null) ...[
                const SizedBox(width: AppSpacing.xs),
                SalaryText(job.salary!, maxWidth: 110),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (job.isRemote)
                const TagPill(
                  label: 'Remote',
                  leading: Icon(Icons.public_rounded, size: 14),
                ),
              if (job.employmentType != null) TagPill(label: job.employmentType!),
              TagPill(
                label: 'via ${job.source}',
                leading: const Icon(Icons.travel_explore_rounded, size: 14),
              ),
              if (isSaved)
                TagPill(
                  label: 'Saved',
                  leading: Icon(
                    Icons.bookmark_rounded,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
        ],
      ),
      footer: TrayFooter(
        text: posted == null ? 'Recently posted' : 'Posted ${posted.toLowerCase()}',
        badge: match == null
            ? null
            : TrayBadge(
                label: '${match.score}% match',
                color: matchColor(match.score, theme),
              ),
      ),
    );
  }
}
