import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Pill-shaped segmented control: a white segment slides across a soft
/// gray track.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _height = 48.0;
  static const _inset = 4.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(_height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: width * selectedIndex + _inset,
                top: _inset,
                bottom: _inset,
                width: width - _inset * 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Color.alphaBlend(
                            Colors.white.withValues(alpha: 0.12),
                            colorScheme.surfaceContainerHighest,
                          )
                        : colorScheme.surface,
                    borderRadius: BorderRadius.circular(_height / 2),
                    boxShadow: AppShadows.raised(theme.brightness),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: i == selectedIndex,
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(_height / 2),
                          onTap: () => onSelected(i),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: theme.textTheme.bodyMedium!.copyWith(
                                fontWeight: i == selectedIndex
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: i == selectedIndex
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                              ),
                              child: Text(labels[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
