import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// App logo + wordmark shown at the top of auth screens.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  static const _logoAsset = 'assets/icons/careerly_logo.png';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          _logoAsset,
          width: 44,
          height: 44,
          filterQuality: FilterQuality.medium,
          semanticLabel: 'Careerly logo',
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
