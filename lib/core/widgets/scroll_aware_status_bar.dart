import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// For screens that start with a dark hero: keeps status bar icons light
/// over the hero, then, once scrolled past [threshold], switches to the
/// theme's icon color and fades in a backdrop so the status bar stays
/// readable over content.
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
    final style = !_overContent || isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

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
