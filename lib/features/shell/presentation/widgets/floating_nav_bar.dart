import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Dark pill tab bar that floats above content, with the active tab in a
/// sliding blue pill, plus a separate round "+" button to its right.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.onAdd,
    this.addTooltip = 'Add',
  });

  static const height = 68.0;

  final List<FloatingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;
  final String addTooltip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Row(
            children: [
              Expanded(child: _TabPill(bar: this)),
              const SizedBox(width: AppSpacing.sm),
              _AddButton(onPressed: onAdd, tooltip: addTooltip),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({required this.bar});

  final FloatingNavBar bar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(FloatingNavBar.height / 2);
    const inset = 8.0;

    return Container(
      height: FloatingNavBar.height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkNav : AppColors.ink,
        borderRadius: radius,
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.08))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / bar.items.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: itemWidth * bar.selectedIndex + inset,
                top: inset,
                bottom: inset,
                width: itemWidth - inset * 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(
                      FloatingNavBar.height / 2 - inset,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < bar.items.length; i++)
                    Expanded(
                      child: _TabButton(
                        item: bar.items[i],
                        selected: i == bar.selectedIndex,
                        onTap: () {
                          if (i != bar.selectedIndex) {
                            HapticFeedback.selectionClick();
                          }
                          bar.onSelected(i);
                        },
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

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: Semantics(
        selected: selected,
        button: true,
        label: item.label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                key: ValueKey(selected),
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.62),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed, required this.tooltip});

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.40),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: AppColors.brand,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onPressed();
              },
              child: const SizedBox.square(
                dimension: FloatingNavBar.height,
                child: Icon(Icons.add_rounded, color: Colors.white, size: 30),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
