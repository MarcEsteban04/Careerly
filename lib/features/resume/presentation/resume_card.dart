import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../data/resume_insights.dart';

/// Upload prompt, a "reading…" state, or a summary of what AI found in the
/// resume, with replace and remove actions.
class ResumeCard extends StatelessWidget {
  const ResumeCard({
    super.key,
    required this.resume,
    required this.isReading,
    required this.enabled,
    required this.onUpload,
    required this.onRemove,
  });

  final ResumeInsights? resume;
  final bool isReading;

  /// False when no AI provider is configured.
  final bool enabled;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resume = this.resume;

    final Widget content;
    if (isReading) {
      content = Row(
        children: [
          const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Reading your resume…',
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      );
    } else if (resume == null) {
      content = Row(
        children: [
          _icon(colorScheme, Icons.upload_file_rounded),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload your resume',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  enabled
                      ? 'PDF. AI reads it to tailor job matches to you.'
                      : 'Add an AI key to enable resume reading.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
        ],
      );
    } else {
      final facts = [
        if (resume.roles.isNotEmpty) '${resume.roles.length} roles',
        '${resume.skills.length} skills',
        if (resume.seniority != null) resume.seniority!,
        if (resume.yearsOfExperience != null) '${resume.yearsOfExperience} yrs',
      ].join(' · ');
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _icon(colorScheme, Icons.description_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resume.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Read ${DateFormat('MMM d').format(resume.uploadedAt)} · $facts',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove resume',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          if (resume.headline != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              resume.headline!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
          if (resume.skills.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in resume.skills.take(8))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      skill,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: colorScheme.primary),
                    ),
                  ),
                if (resume.skills.length > 8)
                  Text(
                    '+${resume.skills.length - 8} more',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: enabled ? onUpload : null,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Replace resume'),
          ),
        ],
      );
    }

    return Material(
      color: colorScheme.primary.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md + 2),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: resume == null && enabled && !isReading ? onUpload : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          child: content,
        ),
      ),
    );
  }

  Widget _icon(ColorScheme colorScheme, IconData icon) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: colorScheme.primary, size: 20),
      );
}
