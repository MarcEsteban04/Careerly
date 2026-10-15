import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// Gently pulsing placeholder blocks shaped like the dashboard, shown while
/// it loads.
class DashboardSkeleton extends StatefulWidget {
  const DashboardSkeleton({super.key});

  @override
  State<DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    Widget block(double height, {double radius = AppRadius.lg}) => Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return Semantics(
      label: 'Loading dashboard',
      child: FadeTransition(
        opacity: Tween(begin: 0.5, end: 1.0).animate(_pulse),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            block(172, radius: AppRadius.lg + 4),
            const SizedBox(height: AppSpacing.xl),
            block(20, radius: AppRadius.sm),
            const SizedBox(height: AppSpacing.sm),
            block(132),
            const SizedBox(height: AppSpacing.xl),
            block(20, radius: AppRadius.sm),
            const SizedBox(height: AppSpacing.sm),
            block(180),
          ],
        ),
      ),
    );
  }
}
