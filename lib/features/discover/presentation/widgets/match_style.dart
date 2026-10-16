import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/scam_check.dart';

/// Color for a match score: green for strong, teal for decent, grey below.
Color matchColor(int score, ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;
  if (score >= 75) return isDark ? AppColors.successDark : AppColors.success;
  if (score >= 50) return theme.colorScheme.secondary;
  return theme.colorScheme.onSurfaceVariant;
}

/// Red for a likely scam, amber for "look closer".
Color scamColor(ScamRisk risk, ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;
  return risk == ScamRisk.high
      ? theme.colorScheme.error
      : isDark
          ? AppColors.warningDark
          : AppColors.warning;
}

/// Small warning tag on a job card.
class ScamPill extends StatelessWidget {
  const ScamPill({super.key, required this.risk});

  final ScamRisk risk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = scamColor(risk, theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gpp_maybe_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            risk == ScamRisk.high ? 'Possible scam' : 'Check this post',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// What looked off in a post, and how to stay safe.
class ScamBanner extends StatelessWidget {
  const ScamBanner({super.key, required this.check});

  final ScamCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = scamColor(check.risk, theme);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gpp_maybe_outlined, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  check.risk == ScamRisk.high
                      ? 'This post has signs of a scam'
                      : 'Check this post before applying',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final reason in check.reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 8),
                    child: Icon(Icons.circle, size: 5, color: color),
                  ),
                  Expanded(
                    child: Text(reason, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 2),
          Text(
            "Never pay to apply, and don't send money or IDs over chat. "
            'Look the company up on LinkedIn or the SEC before you go further.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
