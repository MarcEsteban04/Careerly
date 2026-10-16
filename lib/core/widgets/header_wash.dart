import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Soft accent-tinted wash for full-screen backgrounds, e.g. while loading.
class HeaderWash extends StatelessWidget {
  const HeaderWash({super.key, required this.child});

  final Widget child;

  static LinearGradient gradientFor(Brightness brightness) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: brightness == Brightness.dark
            ? const [Color(0xFF16272A), AppColors.darkBackground]
            : const [Color(0xFFE4F3F5), AppColors.lightBackground],
      );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradientFor(Theme.of(context).brightness),
      ),
      child: child,
    );
  }
}
