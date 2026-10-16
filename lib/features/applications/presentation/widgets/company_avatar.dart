import 'package:flutter/material.dart';

import '../../../../core/theme/app_accents.dart';

/// Company initial on a soft tile, in a stable color per company so the
/// same employer always looks the same.
class CompanyAvatar extends StatelessWidget {
  const CompanyAvatar({super.key, required this.company, this.size = 44});

  final String company;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = company.trim();
    final initial =
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
    final accent =
        Accent.values[trimmed.toLowerCase().hashCode.abs() % Accent.values.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.tintIn(theme.brightness),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        initial,
        style: theme.textTheme.titleMedium?.copyWith(
          color: accent.colorIn(theme.brightness),
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
