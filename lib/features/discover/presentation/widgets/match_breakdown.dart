import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/job_matcher.dart';
import 'match_style.dart';

/// Why the score is what it is: role, skills and work setup, each with its
/// share of the score, plus skills the post wants that the profile doesn't
/// list and how its experience ask compares.
class MatchBreakdown extends StatelessWidget {
  const MatchBreakdown({super.key, required this.match, this.profileYears});

  final JobMatch match;

  /// Years of experience on the profile.
  final int? profileYears;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final asked = match.yearsAsked;
    final years = profileYears;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Factor(
          icon: Icons.work_outline_rounded,
          title: 'Role',
          points: match.rolePoints,
          outOf: JobMatcher.roleWeight,
          detail: match.bestRole == null
              ? "The title doesn't match your target roles."
              : 'Closest to your target role “${match.bestRole}”.',
        ),
        _Factor(
          icon: Icons.auto_awesome_outlined,
          title: 'Skills',
          points: match.skillPoints,
          outOf: JobMatcher.skillsWeight,
          detail: match.matchedSkills.isEmpty
              ? "It doesn't mention skills from your profile."
              : match.matchedSkills.length == 1
                  ? 'It mentions 1 of your skills.'
                  : 'It mentions ${match.matchedSkills.length} of your skills.',
          child: match.matchedSkills.isEmpty && match.missingSkills.isEmpty
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (match.matchedSkills.isNotEmpty)
                      _SkillChips(
                        skills: match.matchedSkills,
                        icon: Icons.check_rounded,
                        color: matchColor(100, theme),
                      ),
                    if (match.missingSkills.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        "It also asks for these, which aren't on your profile:",
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      _SkillChips(
                        skills: match.missingSkills,
                        icon: Icons.add_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
        ),
        _Factor(
          icon: Icons.laptop_mac_rounded,
          title: 'Work setup',
          points: match.setupPoints,
          outOf: JobMatcher.setupWeight,
          detail: match.setupNote ?? '',
        ),
        if (asked != null)
          _Note(
            icon: years != null && years < asked
                ? Icons.info_outline_rounded
                : Icons.check_circle_outline_rounded,
            text: years == null
                ? 'Asks for $asked+ years of experience.'
                : years >= asked
                    ? 'Asks for $asked+ years of experience. You have $years.'
                    : 'Asks for $asked+ years of experience; you have $years. '
                        'Still worth applying if the skills fit. Lead with '
                        'your strongest projects.',
          ),
      ],
    );
  }
}

class _Factor extends StatelessWidget {
  const _Factor({
    required this.icon,
    required this.title,
    required this.points,
    required this.outOf,
    required this.detail,
    this.child,
  });

  final IconData icon;
  final String title;
  final int points;
  final int outOf;
  final String detail;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final share = outOf == 0 ? 0.0 : points / outOf;
    final color = matchColor((share * 100).round(), theme);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$points / $outOf',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 6,
              color: color,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              detail,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
          if (child != null) ...[
            const SizedBox(height: AppSpacing.xs),
            child!,
          ],
        ],
      ),
    );
  }
}

class _SkillChips extends StatelessWidget {
  const _SkillChips({
    required this.skills,
    required this.icon,
    required this.color,
  });

  final List<String> skills;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final skill in skills)
          Container(
            padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 3),
                Text(
                  skill,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
