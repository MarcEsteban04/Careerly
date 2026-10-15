import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// App mark + wordmark shown at the top of auth screens.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brandBright, AppColors.brandDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.work_outline_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Careerly',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
        ),
      ],
    );
  }
}
