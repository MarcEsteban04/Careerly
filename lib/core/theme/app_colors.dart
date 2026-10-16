import 'package:flutter/material.dart';

/// Palette: soft off-white pages, white cards, near-black actions and a
/// calm teal accent. Screens should read colors from `Theme.of(context)`;
/// the few surfaces outside the color scheme (the nav bar, accents) read
/// these directly.
abstract final class AppColors {
  /// Near-black for primary buttons, selected chips and the nav bar.
  static const ink = Color(0xFF202326);

  /// The accent: highlights, charts, today markers and the add button.
  static const accent = Color(0xFF6FC4D0);

  /// The accent deep enough to read as text or an icon on white.
  static const accentDeep = Color(0xFF26808C);

  static const lightBackground = Color(0xFFF5F6F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightMuted = Color(0xFFEEF0F2);
  static const lightOutline = Color(0xFFE6E8EB);
  static const lightText = Color(0xFF17191B);
  static const lightTextMuted = Color(0xFF777D84);

  static const darkBackground = Color(0xFF111315);
  static const darkSurface = Color(0xFF1B1E21);
  static const darkMuted = Color(0xFF25292D);
  static const darkOutline = Color(0xFF2E3237);
  static const darkText = Color(0xFFF3F4F5);
  static const darkTextMuted = Color(0xFF9AA0A6);
  static const darkNav = Color(0xFF26292D);

  static const success = Color(0xFF1F7A4F);
  static const successDark = Color(0xFF5DCB94);
  static const warning = Color(0xFFA8650C);
  static const warningDark = Color(0xFFF2B65C);

  static const error = Color(0xFFC8372D);
  static const errorDark = Color(0xFFF2857B);
}
