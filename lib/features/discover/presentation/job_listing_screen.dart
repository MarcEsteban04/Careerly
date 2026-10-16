import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../../core/widgets/tag_pill.dart';
import '../data/discover_controller.dart';
import '../data/job_matcher.dart';
import 'widgets/company_logo.dart';
import 'widgets/match_breakdown.dart';
import 'widgets/match_style.dart';

/// Full job posting: description, qualifications and why it matches, with
/// actions to save it to the tracker or apply on the source site.
class JobListingScreen extends StatefulWidget {
  const JobListingScreen({
    super.key,
    required this.ranked,
    required this.isSaved,
    required this.onSave,
    required this.onWriteCoverLetter,
    required this.onTailorResume,
    required this.onApply,
    required this.onNotInterested,
    required this.onAtsCheck,
    this.profileYears,
  });

  /// Checks her resume against this job.
  final VoidCallback onAtsCheck;

  final RankedListing ranked;
  final bool isSaved;

  /// Years of experience on the profile, to compare with what the post asks.
  final int? profileYears;

  /// Saves the job as a tracked application; resolves to true on success.
  final Future<bool> Function() onSave;
  final VoidCallback onWriteCoverLetter;
  final VoidCallback onTailorResume;

  /// Opens the application kit.
  final VoidCallback onApply;

  /// Hides this job from future results.
  final VoidCallback onNotInterested;

  @override
  State<JobListingScreen> createState() => _JobListingScreenState();
}

class _JobListingScreenState extends State<JobListingScreen> {
  late bool _isSaved = widget.isSaved;
  bool _isSaving = false;
  int _tab = 0;
  bool _expanded = false;

  Future<void> _save() async {
    if (_isSaved || _isSaving) return;
    setState(() => _isSaving = true);
    final ok = await widget.onSave();
    if (mounted) {
      setState(() {
        _isSaving = false;
        _isSaved = ok;
      });
    }
  }

  Future<void> _apply() async {
    final uri = Uri.tryParse(widget.ranked.listing.applyUrl);
    final opened =
        uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the job post.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final job = widget.ranked.listing;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
                      'Job Detail',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (value) {
                      if (value == 'open') _apply();
                      if (value == 'hide') {
                        widget.onNotInterested();
                        Navigator.of(context).maybePop();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'open',
                        child: ListTile(
                          leading: Icon(Icons.open_in_new_rounded),
                          title: Text('Open job post'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'hide',
                        child: ListTile(
                          leading: Icon(Icons.thumb_down_alt_outlined),
                          title: Text('Not interested'),
                        ),
                      ),
                    ],
                    child: const IgnorePointer(
                      child: CircleIconButton(
                        icon: Icons.more_horiz_rounded,
                        tooltip: 'More',
                        onPressed: null,
                      ),
                    ),
                  ),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CompanyLogo(
                        company: job.company,
                        url: job.companyLogoUrl,
                        size: 56,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.title,
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                job.company,
                                if (job.location != null) job.location!,
                              ].join('  •  '),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: _isSaved ? 'Saved to tracker' : 'Save to tracker',
                        onPressed: _save,
                        icon: Icon(
                          _isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: _isSaved ? colorScheme.primary : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (job.employmentType != null)
                        TagPill(label: job.employmentType!),
                      if (JobMatcher.looksRemote(job))
                        const TagPill(label: 'Remote'),
                      if (job.salary != null) TagPill(label: job.salary!),
                      TagPill(label: 'via ${job.source}'),
                      if (job.postedAt != null || job.postedLabel != null)
                        TagPill(
                          label: job.postedAt?.agoLabel() ?? job.postedLabel!,
                        ),
                    ],
                  ),
                  if (widget.ranked.scam.isFlagged) ...[
                    const SizedBox(height: AppSpacing.md),
                    ScamBanner(check: widget.ranked.scam),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  SegmentedTabs(
                    labels: const ['Description', 'Requirements', 'Match'],
                    selectedIndex: _tab,
                    onSelected: (i) => setState(() => _tab = i),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(_tab),
                      child: switch (_tab) {
                        0 => _buildDescription(theme),
                        1 => _buildRequirements(theme),
                        _ => _buildMatch(theme),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        color: colorScheme.surface,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm + bottomInset,
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onWriteCoverLetter,
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Cover letter'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PrimaryButton(
                label: 'Apply',
                icon: Icons.arrow_outward_rounded,
                onPressed: widget.onApply,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription(ThemeData theme) {
    final description = widget.ranked.listing.description;
    if (description.isEmpty) {
      return _muted(theme, 'No description provided. Open the job post for details.');
    }
    final long = description.length > 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About this role', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: Text(
            description,
            maxLines: !long || _expanded ? null : 9,
            overflow: !long || _expanded ? null : TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ),
        if (long)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(_expanded ? 'Show less' : 'Read more'),
          ),
      ],
    );
  }

  Widget _buildRequirements(ThemeData theme) {
    final job = widget.ranked.listing;
    final sections = {
      'Qualifications': job.qualifications,
      'Responsibilities': job.responsibilities,
      'Benefits': job.benefits,
    }..removeWhere((_, items) => items.isEmpty);

    if (sections.isEmpty) {
      return _muted(
        theme,
        "This posting doesn't list requirements separately. Check the "
        'description or the original job post.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in sections.entries) ...[
          Text(entry.key, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          for (final item in entry.value) _Bullet(item),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  Widget _buildMatch(ThemeData theme) {
    final match = widget.ranked.match;
    if (match == null) {
      return _muted(
        theme,
        'Upload your resume or add target roles to your career profile to see how '
        'well each job fits you.',
      );
    }
    final color = matchColor(match.score, theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox.square(
              dimension: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: match.score / 100,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    color: color,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    constraints:
                        const BoxConstraints.tightFor(width: 72, height: 72),
                  ),
                  Text(
                    '${match.score}%',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                match.score >= 75
                    ? 'Strong match for your profile.'
                    : match.score >= 50
                        ? 'Decent match. Worth a look.'
                        : 'Weak match for your profile.',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        MatchBreakdown(match: match, profileYears: widget.profileYears),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: widget.onAtsCheck,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text("Check my resume's ATS score"),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          onPressed: widget.onTailorResume,
          icon: const Icon(Icons.auto_fix_high_rounded),
          label: const Text('Tailor my resume to this job'),
        ),
      ],
    );
  }

  Widget _muted(ThemeData theme, String text) => Text(
        text,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
