import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Space kept free at the bottom of tab content for the floating nav bar.
const kFloatingNavClearance = 120.0;

/// Standard layout for a top-level tab: large title on a soft wash, optional
/// subtitle and header widget, pull-to-refresh, and room for the nav bar.
class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.title,
    required this.onRefresh,
    required this.children,
    this.subtitle,
    this.header,
  });

  final String title;
  final String? subtitle;

  /// Shown under the title, e.g. search and filter chips.
  final Widget? header;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final media = MediaQuery.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    AppColors.washTopDark,
                    AppColors.darkBackground,
                    AppColors.darkBackground,
                  ]
                : [
                    AppColors.washTop,
                    AppColors.washBottom,
                    theme.scaffoldBackgroundColor,
                  ],
            stops: const [0, 0.22, 0.4],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: onRefresh,
          edgeOffset: media.padding.top,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  media.padding.top + AppSpacing.lg,
                  AppSpacing.lg,
                  kFloatingNavClearance + media.padding.bottom,
                ),
                children: [
                  Text(title, style: theme.textTheme.headlineMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  if (header != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    header!,
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
