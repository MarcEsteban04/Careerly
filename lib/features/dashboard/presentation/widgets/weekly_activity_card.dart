import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

/// Bar chart of applications sent on each day of this week.
class WeeklyActivityCard extends StatelessWidget {
  const WeeklyActivityCard({
    super.key,
    required this.perWeekday,
    required this.todayIndex,
  });

  /// Seven counts, Monday first.
  final List<int> perWeekday;

  /// 0 = Monday … 6 = Sunday.
  final int todayIndex;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _chartHeight = 128.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = perWeekday.fold(0, (sum, c) => sum + c);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$total',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  total == 1 ? 'application sent' : 'applications sent',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: _chartHeight,
            child: Stack(
              children: [
                _buildBars(),
                if (total == 0)
                  Positioned.fill(
                    bottom: 36,
                    child: Center(
                      child: Text(
                        'Applications you send this week show up here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBars() {
    final peak = math.max(1, perWeekday.reduce(math.max));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Semantics(
              label: '${_dayNames[i]}: ${perWeekday[i]}',
              excludeSemantics: true,
              child: _DayBar(
                count: perWeekday[i],
                fraction: perWeekday[i] / peak,
                label: _days[i],
                isToday: i == todayIndex,
                delay: i,
              ),
            ),
          ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.count,
    required this.fraction,
    required this.label,
    required this.isToday,
    required this.delay,
  });

  final int count;
  final double fraction;
  final String label;
  final bool isToday;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final emphasis = isToday
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final barColor = count == 0
        ? colorScheme.outlineVariant
        : isToday
        ? colorScheme.primary
        : colorScheme.primary.withValues(alpha: 0.35);

    return Column(
      children: [
        Text(
          count > 0 ? '$count' : '',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: emphasis,
          ),
        ),
        const SizedBox(height: 4),
        // The bar takes whatever height is left, so larger text never
        // overflows the chart.
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : Duration(milliseconds: 500 + delay * 60),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 22,
                  height: math.max(6, value * box.maxHeight),
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: emphasis,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
