import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/form_banner.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../studio/data/career_writer.dart';
import '../../studio/data/resume_versions.dart';
import '../data/ats_checker.dart';

/// How well a resume version would get through an applicant-tracking
/// system for one job, with what to fix. Switch versions to compare.
class AtsScreen extends StatefulWidget {
  const AtsScreen({
    super.key,
    required this.job,
    required this.versions,
    required this.loadContent,
    required this.onTailor,
    this.initialVersionId,
  });

  final JobContext job;
  final List<ResumeVersion> versions;

  /// The text of a version.
  final Future<String> Function(ResumeVersion version) loadContent;

  /// Opens the AI resume tailoring for this job.
  final VoidCallback onTailor;
  final String? initialVersionId;

  @override
  State<AtsScreen> createState() => _AtsScreenState();
}

class _AtsScreenState extends State<AtsScreen> {
  late ResumeVersion? _version = widget.versions
          .where((v) => v.id == widget.initialVersionId)
          .firstOrNull ??
      widget.versions.firstOrNull;
  final _reports = <String, AtsReport>{};
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final version = _version;
    if (version != null) _check(version);
  }

  Future<void> _check(ResumeVersion version) async {
    setState(() {
      _version = version;
      _error = null;
    });
    if (_reports.containsKey(version.id)) return;
    setState(() => _loading = true);
    try {
      final content = await widget.loadContent(version);
      if (!mounted) return;
      _reports[version.id] = AtsChecker.check(resume: content, job: widget.job);
    } catch (error) {
      debugPrint('ATS check failed: $error');
      if (mounted) {
        setState(() => _error = "Couldn't open that resume. Try again.");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final version = _version;
    final report = version == null ? null : _reports[version.id];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      'ATS check',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  120 + bottomInset,
                ),
                children: [
                  Text(
                    widget.job.label,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'How well your resume would get through an applicant-'
                    'tracking system for this job.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (widget.versions.isEmpty)
                    const AppCard(
                      child: EmptyState(
                        icon: Icons.description_outlined,
                        title: 'No resume yet',
                        message: 'Upload your resume in Studio, then check it '
                            'against this job.',
                      ),
                    )
                  else ...[
                    if (widget.versions.length > 1) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          children: [
                            for (final (i, v) in widget.versions.indexed) ...[
                              if (i > 0) const SizedBox(width: AppSpacing.xs),
                              PillChip(
                                label: v.isOriginal ? 'Original' : v.title,
                                leading: _reports[v.id] == null
                                    ? null
                                    : Text(
                                        '${_reports[v.id]!.score}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                selected: v.id == version?.id,
                                onTap: () => _check(v),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (_error != null) FormBanner(message: _error!),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (report != null)
                      _ReportView(report: report),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        color: theme.colorScheme.surface,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm + bottomInset,
        ),
        child: PrimaryButton(
          label: 'Tailor a version with AI',
          icon: Icons.auto_fix_high_rounded,
          onPressed: widget.onTailor,
        ),
      ),
    );
  }
}

Color _scoreColor(BuildContext context, double share) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (share >= 0.8) return isDark ? AppColors.successDark : AppColors.success;
  if (share >= 0.6) return Theme.of(context).colorScheme.primary;
  return isDark ? AppColors.warningDark : AppColors.warning;
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});

  final AtsReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = _scoreColor(context, report.score / 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Row(
            children: [
              SizedBox.square(
                dimension: 84,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: report.score / 100,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.15),
                    ),
                    Center(
                      child: Text(
                        '${report.score}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                        semanticsLabel: 'ATS score ${report.score} out of 100',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  report.verdict,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        if (!report.hasJobDetails) ...[
          const SizedBox(height: AppSpacing.sm),
          const FormBanner(
            message: "This job has no description saved, so keywords come "
                'from the title only. Add the posting to the application '
                'for a fuller check.',
            tone: FormBannerTone.info,
          ),
        ],
        if (report.missingKeywords.isNotEmpty ||
            report.matchedKeywords.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Keywords',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in report.matchedKeywords)
                _Keyword(label: k, found: true),
              for (final k in report.missingKeywords)
                _Keyword(label: k, found: false),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Breakdown',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final check in report.checks)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        check.passed
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        size: 20,
                        color: _scoreColor(context, check.points / check.outOf),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          check.title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${check.points}/${check.outOf}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: _scoreColor(
                            context,
                            check.points / check.outOf,
                          ),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    check.detail,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  if (check.tip != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Expanded(
                          child: Text(
                            check.tip!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        Text(
          'This is a guide, not a guarantee: every company tunes its system '
          'differently. Only add skills you really have.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Keyword extends StatelessWidget {
  const _Keyword({required this.label, required this.found});

  final String label;
  final bool found;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = found
        ? _scoreColor(context, 1)
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: found ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: found ? null : Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(found ? Icons.check_rounded : Icons.add_rounded, size: 14, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
            semanticsLabel: found ? '$label, included' : '$label, missing',
          ),
        ],
      ),
    );
  }
}
