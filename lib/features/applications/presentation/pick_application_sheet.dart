import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../data/job_application.dart';
import 'widgets/company_avatar.dart';

/// Asks which tracked job something is for, e.g. interview prep or an ATS
/// check. Interviews come first; rejected applications are left out.
Future<JobApplication?> showPickApplicationSheet(
  BuildContext context, {
  required List<JobApplication> applications,
  required String title,
  required String subtitle,
}) {
  int rank(ApplicationStatus status) => switch (status) {
        ApplicationStatus.interviewing => 0,
        ApplicationStatus.offer => 1,
        ApplicationStatus.applied => 2,
        ApplicationStatus.saved => 3,
        ApplicationStatus.rejected => 4,
      };
  final choices = [
    for (final a in applications)
      if (a.status != ApplicationStatus.rejected) a,
  ]..sort((a, b) => rank(a.status).compareTo(rank(b.status)));

  return showModalBottomSheet<JobApplication>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  children: [
                    for (final application in choices)
                      ListTile(
                        onTap: () => Navigator.of(context).pop(application),
                        leading: CompanyAvatar(
                          company: application.company,
                          size: 40,
                        ),
                        title: Text(
                          application.role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${application.company} · '
                          '${application.status.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
