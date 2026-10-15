import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// Company initial in a bordered tile, tinted by a stable color per company.
class CompanyAvatar extends StatelessWidget {
  const CompanyAvatar({super.key, required this.company, this.size = 44});

  final String company;
  final double size;

  static const _palette = [
    Color(0xFF2563EB),
    Color(0xFFEA580C),
    Color(0xFF16A34A),
    Color(0xFF9333EA),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
    Color(0xFFCA8A04),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = company.trim();
    final initial =
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
    final color = _palette[trimmed.toLowerCase().hashCode.abs() % _palette.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text(
        initial,
        style: theme.textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
