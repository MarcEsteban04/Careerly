import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Soft blue-to-white wash used behind screen headers.
class HeaderWash extends StatelessWidget {
  const HeaderWash({super.key, required this.child});

  final Widget child;

  static LinearGradient gradientFor(Brightness brightness) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: brightness == Brightness.dark
            ? const [AppColors.washTopDark, AppColors.washBottomDark]
            : const [AppColors.washTop, AppColors.washBottom],
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
