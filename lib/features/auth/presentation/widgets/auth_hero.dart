import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/brand_sky.dart';

/// Brand header for the auth screens: logo and wordmark on the brand sky.
///
/// [compact] shrinks it while the keyboard is open.
class AuthHero extends StatelessWidget {
  const AuthHero({
    super.key,
    this.compact = false,
    this.bottomInset = 0,
    this.minHeight = 0,
  });

  final bool compact;

  /// Content is centered vertically within at least this height.
  final double minHeight;

  /// Extra bottom padding so content clears a panel overlapping the hero.
  final double bottomInset;

  static const _logoAsset = 'assets/icons/careerly_logo.png';

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 52.0 : 76.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(minHeight: minHeight),
      child: BrandSky(
        child: SafeArea(
          bottom: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              compact ? AppSpacing.md : AppSpacing.xxl,
              AppSpacing.lg,
              (compact ? AppSpacing.lg : AppSpacing.xxl) + bottomInset,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(logoSize * 0.26),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amber.withValues(alpha: 0.22),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      _logoAsset,
                      filterQuality: FilterQuality.medium,
                      semanticLabel: 'Careerly logo',
                    ),
                  ),
                  SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                  Text(
                    'Careerly',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: compact
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              'Your career, in motion.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
