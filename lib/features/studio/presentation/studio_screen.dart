import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/header_wash.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/tab_page.dart';
import '../../documents/data/career_document.dart';
import '../../resume/data/resume_insights.dart';
import '../data/studio_controller.dart';

/// Studio tab: the uploaded resume, AI tools, and saved documents.
class StudioScreen extends StatelessWidget {
  const StudioScreen({
    super.key,
    required this.studio,
    required this.onUploadResume,
    required this.onEnhanceResume,
    required this.onWriteCoverLetter,
    required this.onInterviewPrep,
    required this.onOpenDocument,
  });

  final StudioController studio;
  final Future<void> Function() onUploadResume;
  final VoidCallback onEnhanceResume;
  final VoidCallback onWriteCoverLetter;
  final VoidCallback onInterviewPrep;
  final ValueChanged<CareerDocument> onOpenDocument;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studio,
      builder: (context, _) {
        final items = studio.items;
        final resumes =
            items?.where((d) => d.kind == DocumentKind.resume).toList() ?? [];
        final letters =
            items?.where((d) => d.kind == DocumentKind.coverLetter).toList() ??
            [];
        final resume = studio.profile().resume;

        return TabPage(
          title: 'Studio',
          subtitle: 'AI resumes, cover letters and interview prep',
          onRefresh: studio.load,
          children: [
            _ResumeCard(
              resume: resume,
              hasText: studio.hasResumeText,
              onUpload: onUploadResume,
            ),
            const SizedBox(height: AppSpacing.md),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ToolCard(
                      icon: Icons.auto_fix_high_rounded,
                      title: 'Enhance resume',
                      subtitle: 'Stronger bullets for a target role',
                      onTap: onEnhanceResume,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ToolCard(
                      icon: Icons.edit_note_rounded,
                      title: 'Cover letter',
                      subtitle: 'Tailored to a specific job',
                      onTap: onWriteCoverLetter,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ToolCard(
                      icon: Icons.record_voice_over_outlined,
                      title: 'Interview prep',
                      subtitle: 'Practice questions for a job you track',
                      onTap: onInterviewPrep,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (items == null && studio.error == null)
              const Center(child: CircularProgressIndicator())
            else if (items == null)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: "Couldn't load your documents",
                  message: 'Check your connection and try again.',
                  actionLabel: 'Try again',
                  actionIcon: Icons.refresh_rounded,
                  onAction: studio.load,
                ),
              )
            else if (items.isEmpty)
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.lg,
                ),
                child: const EmptyState(
                  icon: Icons.folder_open_rounded,
                  title: 'Nothing saved yet',
                  message:
                      'Enhanced resumes and cover letters you save show '
                      'up here, ready to share as PDF.',
                ),
              )
            else ...[
              if (resumes.isNotEmpty) ...[
                const SectionHeader(title: 'Resumes'),
                _DocumentList(documents: resumes, onOpen: onOpenDocument),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (letters.isNotEmpty) ...[
                const SectionHeader(title: 'Cover letters'),
                _DocumentList(documents: letters, onOpen: onOpenDocument),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.resume,
    required this.hasText,
    required this.onUpload,
  });

  final ResumeInsights? resume;
  final bool hasText;
  final Future<void> Function() onUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resume = this.resume;
    final needsUpload = resume == null || !hasText;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: HeaderWash(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  needsUpload
                      ? Icons.upload_file_rounded
                      : Icons.description_outlined,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      needsUpload ? 'Add your resume' : resume.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      needsUpload
                          ? resume == null
                                ? 'Upload a PDF to unlock AI writing.'
                                : 'Re-upload it so AI can work from the full text.'
                          : resume.headline ??
                                'Uploaded ${DateFormat('MMM d').format(resume.uploadedAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              FilledButton.tonal(
                onPressed: onUpload,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                ),
                child: Text(needsUpload ? 'Upload' : 'Replace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: subtitle,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 20, color: colorScheme.primary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({required this.documents, required this.onOpen});

  final List<CareerDocument> documents;
  final ValueChanged<CareerDocument> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Column(
        children: [
          for (final doc in documents)
            ListTile(
              onTap: () => onOpen(doc),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                ),
                child: Icon(
                  doc.kind == DocumentKind.resume
                      ? Icons.description_outlined
                      : Icons.mail_outline_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              title: Text(
                doc.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                DateFormat('MMM d, y · h:mm a').format(doc.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
        ],
      ),
    );
  }
}
