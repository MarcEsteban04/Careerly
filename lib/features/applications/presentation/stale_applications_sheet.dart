import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/island_toast.dart';
import '../data/job_application.dart';
import '../data/stale_applications.dart';
import 'widgets/company_avatar.dart';

/// Reviews applications that went quiet, one decision each: follow up,
/// give it another week, or close it out. Each action returns an error
/// message on failure.
Future<void> showStaleApplicationsSheet(
  BuildContext context, {
  required List<JobApplication> applications,
  required ValueChanged<JobApplication> onFollowUp,
  required Future<String?> Function(JobApplication application) onWait,
  required Future<String?> Function(JobApplication application) onClose,
}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _StaleSheet(
        applications: applications,
        onFollowUp: (application) {
          Navigator.of(context).pop();
          onFollowUp(application);
        },
        onWait: onWait,
        onClose: onClose,
      ),
    );

class _StaleSheet extends StatefulWidget {
  const _StaleSheet({
    required this.applications,
    required this.onFollowUp,
    required this.onWait,
    required this.onClose,
  });

  final List<JobApplication> applications;
  final ValueChanged<JobApplication> onFollowUp;
  final Future<String?> Function(JobApplication) onWait;
  final Future<String?> Function(JobApplication) onClose;

  @override
  State<_StaleSheet> createState() => _StaleSheetState();
}

class _StaleSheetState extends State<_StaleSheet> {
  late final _remaining = [...widget.applications];
  final _busy = <String>{};

  Future<void> _resolve(
    JobApplication application,
    Future<String?> Function(JobApplication) action,
  ) async {
    setState(() => _busy.add(application.id));
    final error = await action(application);
    if (!mounted) return;
    setState(() {
      _busy.remove(application.id);
      if (error == null) _remaining.remove(application);
    });
    if (error == null) {
      HapticFeedback.lightImpact();
    } else {
      Island.show(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
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
                    'Gone quiet',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'No news on these for a while. Nudge them, give them '
                    'another week, or close them out.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (_remaining.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Icon(
                      Icons.task_alt_rounded,
                      size: 40,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text("All sorted. Nice work!", style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  itemCount: _remaining.length,
                  separatorBuilder: (_, _) => const Divider(height: AppSpacing.lg),
                  itemBuilder: (context, i) {
                    final application = _remaining[i];
                    return _StaleRow(
                      application: application,
                      busy: _busy.contains(application.id),
                      onFollowUp: () => widget.onFollowUp(application),
                      onWait: () => _resolve(application, widget.onWait),
                      onClose: () => _resolve(application, widget.onClose),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StaleRow extends StatelessWidget {
  const _StaleRow({
    required this.application,
    required this.busy,
    required this.onFollowUp,
    required this.onWait,
    required this.onClose,
  });

  final JobApplication application;
  final bool busy;
  final VoidCallback onFollowUp;
  final VoidCallback onWait;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final days = StaleApplications.quietDays(application);
    final stage = application.status == ApplicationStatus.interviewing
        ? 'No update since interviewing'
        : 'Applied';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CompanyAvatar(company: application.company, size: 40),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${application.company} · $stage, $days days ago',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: busy ? null : onFollowUp,
                icon: const Icon(Icons.forward_to_inbox_rounded, size: 18),
                label: const Text('Follow up'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onWait,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                ),
                child: const Text('Wait a week'),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onClose,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: colorScheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                ),
                child: const Text('Close it'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
