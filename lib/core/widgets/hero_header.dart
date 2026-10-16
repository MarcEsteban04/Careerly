import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// The header at the top of a screen: title, key facts and controls on the
/// page background, below the status bar and within the content width.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.md,
    ),
    this.safeTop = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Pads below the status bar; off when something above already does.
  final bool safeTop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: safeTop,
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
