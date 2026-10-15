import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/brand_sky.dart';

class HeroStats {
  const HeroStats({
    required this.appliedThisWeek,
    required this.interviewsNextWeek,
    required this.offers,
  });

  final int appliedThisWeek;
  final int interviewsNextWeek;
  final int offers;

  String get message {
    if (offers > 0) return 'You have an offer on the table. Well earned.';
    if (interviewsNextWeek == 1) return "One interview coming up. You've got this.";
    if (interviewsNextWeek > 1) {
      return "$interviewsNextWeek interviews coming up. You've got this.";
    }
    if (appliedThisWeek > 0) return 'Nice momentum: $appliedThisWeek sent this week.';
    return "Let's get your first application in this week.";
  }
}

/// Brand-sky header: date, greeting, a nudge and this week's numbers.
class DashboardHero extends StatelessWidget {
  const DashboardHero({
    super.key,
    required this.firstName,
    required this.initial,
    required this.onAccountTap,
    this.stats,
  });

  final String? firstName;
  final String initial;
  final VoidCallback onAccountTap;

  /// Null while loading.
  final HeroStats? stats;

  static String greetingFor(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final greeting = greetingFor(now);
    final stats = this.stats;

    return BrandSky(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      // Softer stars so they don't compete with the text and numbers.
      starOpacity: 0.35,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg + 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, MMMM d').format(now).toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          firstName == null ? greeting : '$greeting, $firstName',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _AccountButton(initial: initial, onTap: onAccountTap),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  stats?.message ?? 'Getting your week ready…',
                  key: ValueKey(stats?.message),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  _GlassStat(
                    icon: Icons.send_rounded,
                    value: stats?.appliedThisWeek,
                    label: 'Applied',
                    caption: 'this week',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _GlassStat(
                    icon: Icons.groups_2_outlined,
                    value: stats?.interviewsNextWeek,
                    label: 'Interviews',
                    caption: 'next 7 days',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _GlassStat(
                    icon: Icons.celebration_outlined,
                    value: stats?.offers,
                    label: 'Offers',
                    caption: 'all time',
                    highlight: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.initial, required this.onTap});

  final String initial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Account',
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 46,
            child: Center(
              child: Text(
                initial,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassStat extends StatelessWidget {
  const _GlassStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.caption,
    this.highlight = false,
  });

  final IconData icon;
  final int? value;
  final String label;
  final String caption;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Semantics(
        label: '${value ?? 'Loading'} $label $caption',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(AppRadius.md + 2),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 18,
                color: highlight ? AppColors.gold : Colors.white70,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value?.toString() ?? '–',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
