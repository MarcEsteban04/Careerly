import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shakes its child horizontally when [ShakeEffectState.shake] is called,
/// e.g. to signal a rejected form. Respects the system "reduce motion" setting.
class ShakeEffect extends StatefulWidget {
  const ShakeEffect({super.key, required this.child});

  final Widget child;

  @override
  State<ShakeEffect> createState() => ShakeEffectState();
}

class ShakeEffectState extends State<ShakeEffect>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  void shake() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
