import 'package:flutter/material.dart';

import '../theme/app_accents.dart';

/// A rounded tile holding an icon in the accent's color on a soft tint of
/// it.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.accent = Accent.teal,
    this.size = 44,
  });

  final IconData icon;
  final Accent accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.tintIn(brightness),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.48, color: accent.colorIn(brightness)),
    );
  }
}
