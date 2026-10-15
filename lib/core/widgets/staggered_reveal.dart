import 'dart:async';

import 'package:flutter/material.dart';

/// Fades and lifts its child in once, after a delay based on [index], so a
/// list of sections cascades into view. Respects "reduce motion".
class StaggeredReveal extends StatefulWidget {
  const StaggeredReveal({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  static const _step = Duration(milliseconds: 70);

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _timer?.cancel();
      _controller.value = 1;
    } else if (_controller.isDismissed && _timer == null) {
      _timer = Timer(StaggeredReveal._step * widget.index, _controller.forward);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(_curve),
        child: widget.child,
      ),
    );
  }
}
