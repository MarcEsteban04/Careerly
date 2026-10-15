import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Single-select row of chips for a small set of options.
class ChoiceChipGroup<T> extends StatelessWidget {
  const ChoiceChipGroup({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.iconOf,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final IconData Function(T value)? iconOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(labelOf(value)),
            avatar: iconOf == null || value == selected
                ? null
                : Icon(iconOf!(value), size: 18),
            selected: value == selected,
            showCheckmark: true,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}
