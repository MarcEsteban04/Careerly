import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'hero_header.dart';
import 'scroll_aware_status_bar.dart';

/// Space kept free at the bottom of tab content for the floating nav bar.
const kFloatingNavClearance = 120.0;

/// Standard layout for a top-level tab: a header with a large title,
/// optional subtitle, trailing actions and header content; then an optional
/// header (e.g. search and filters) and the content, with pull-to-refresh
/// and room for the nav bar.
class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.title,
    required this.onRefresh,
    required this.children,
    this.subtitle,
    this.header,
    this.heroChild,
    this.trailing,
  });

  final String title;
  final String? subtitle;

  /// Shown under the header, e.g. search and filter chips.
  final Widget? header;

  /// Shown in the header under the subtitle, e.g. tabs or stats.
  final Widget? heroChild;

  /// Next to the title, e.g. a settings button.
  final Widget? trailing;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return ScrollAwareStatusBar(
      threshold: 60,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        edgeOffset: media.padding.top,
        child: ListView(
          padding: EdgeInsets.only(
            bottom: kFloatingNavClearance + media.padding.bottom,
          ),
          children: [
            HeroHeader(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (heroChild != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    heroChild!,
                  ],
                ],
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (header != null) ...[
                        header!,
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
