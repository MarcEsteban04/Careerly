import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Calm color families for icon badges, avatars and charts, so sections
/// can be told apart at a glance without shouting.
enum Accent {
  teal(AppColors.accent, AppColors.accentDeep),
  blue(Color(0xFF8DB1EA), Color(0xFF3966B3)),
  violet(Color(0xFFB2A6E8), Color(0xFF6655BD)),
  amber(Color(0xFFF1C877), Color(0xFF9A6A0E)),
  rose(Color(0xFFEEA6B4), Color(0xFFB4475F)),
  emerald(Color(0xFF8ACDA9), Color(0xFF2C7D56));

  const Accent(this.light, this.deep);

  final Color light;
  final Color deep;

  /// A readable tone for text and icons on the page background.
  Color colorIn(Brightness brightness) =>
      brightness == Brightness.dark ? light : deep;

  /// A soft tint behind an icon or label in this color.
  Color tintIn(Brightness brightness) =>
      light.withValues(alpha: brightness == Brightness.dark ? 0.16 : 0.24);
}
