import 'package:flutter/material.dart';

/// Tiny bar chart for trends, e.g. applications per week. The last bar is
/// drawn solid, the rest faded.
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 40,
    this.barGap = 4,
  });

  final List<int> values;
  final Color color;
  final double height;
  final double barGap;

  @override
  Widget build(BuildContext context) {
    final peak = values.fold<int>(0, (m, v) => v > m ? v : m);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, value) in values.indexed)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: barGap / 2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: peak == 0 ? 0 : value / peak),
                  duration: Duration(milliseconds: 500 + i * 40),
                  curve: Curves.easeOutCubic,
                  builder: (context, share, _) => Container(
                    // A stub for empty weeks keeps the rhythm of the chart.
                    height: 4 + (height - 4) * share,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == values.length - 1
                          ? color
                          : color.withValues(alpha: 0.32),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
