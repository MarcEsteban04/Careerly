import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status bar icons in the theme's color, with a backdrop that fades in once
/// content scrolls past [threshold] so the status bar stays readable over
/// it.
class ScrollAwareStatusBar extends StatefulWidget {
  const ScrollAwareStatusBar({
    super.key,
    required this.threshold,
    required this.child,
  });

  final double threshold;
  final Widget child;

  @override
  State<ScrollAwareStatusBar> createState() => _ScrollAwareStatusBarState();
}

class _ScrollAwareStatusBarState extends State<ScrollAwareStatusBar> {
  bool _overContent = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical) {
      final over = notification.metrics.pixels > widget.threshold;
      if (over != _overContent) setState(() => _overContent = over);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final style =
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style,
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.child,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _overContent ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: ColoredBox(
                  color: theme.scaffoldBackgroundColor.withValues(alpha: 0.94),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
