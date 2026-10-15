import 'dart:ui';

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

/// Frosted dark tab bar that floats above content. The active tab grows
/// into a blue pill with its label; the others stay as icons. A separate
/// round "+" button sits to the right.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.onAdd,
    this.addTooltip = 'Add',
    this.badges = const {},
  });

  static const height = 68.0;

  /// Gap above the system gesture area / bottom edge.
  static const _bottomGap = 10.0;

  final List<FloatingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;
  final String addTooltip;

  /// Small counts on tabs, by index (e.g. agenda items due soon).
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        bottom + _bottomGap,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Row(
            children: [
              Expanded(child: _Bar(bar: this)),
              const SizedBox(width: AppSpacing.sm),
              _AddButton(onPressed: onAdd, tooltip: addTooltip),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.bar});

  final FloatingNavBar bar;

  static const _padding = 6.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(FloatingNavBar.height / 2);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: FloatingNavBar.height,
            padding: const EdgeInsets.all(_padding),
            decoration: BoxDecoration(
              borderRadius: radius,
              color: (isDark ? AppColors.darkNav : AppColors.ink).withValues(
                alpha: 0.92,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            // Fine highlight along the top edge, like light on glass.
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.white.withValues(alpha: 0.06),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final total = constraints.maxWidth;
                final count = bar.items.length;
                // The active tab gets room for its label.
                final active = (total * 0.36).clamp(92.0, 150.0);
                final inactive = (total - active) / (count - 1);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < count; i++)
                      AnimatedContainer(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 340),
                        curve: Curves.easeOutCubic,
                        width: i == bar.selectedIndex ? active : inactive,
                        child: _NavButton(
                          item: bar.items[i],
                          selected: i == bar.selectedIndex,
                          badge: bar.badges[i] ?? 0,
                          reduceMotion: reduceMotion,
                          onTap: () {
                            if (i != bar.selectedIndex) {
                              HapticFeedback.selectionClick();
                            }
                            bar.onSelected(i);
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.badge,
    required this.reduceMotion,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool selected;
  final int badge;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selected;
    final duration = widget.reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 340);
    final iconColor = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.58);

    return Tooltip(
      message: widget.item.label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: selected,
        label: widget.badge > 0
            ? '${widget.item.label}, ${widget.badge} due soon'
            : widget.item.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.9 : 1,
            duration: const Duration(milliseconds: 120),
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(FloatingNavBar.height),
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3B82F6), AppColors.brand],
                      )
                    : null,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.brand.withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ClipRect(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _BadgedIcon(
                      icon: selected
                          ? widget.item.selectedIcon
                          : widget.item.icon,
                      color: iconColor,
                      badge: selected ? 0 : widget.badge,
                    ),
                    // Flexible so the label shrinks with the pill while it
                    // animates instead of overflowing.
                    // The pill's width animation reveals the label; it
                    // shrinks and fades at the edge rather than overflowing.
                    if (selected)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: duration,
                            curve: Curves.easeOut,
                            builder: (context, opacity, child) =>
                                Opacity(opacity: opacity, child: child),
                            child: Text(
                              widget.item.label,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({
    required this.icon,
    required this.color,
    required this.badge,
  });

  final IconData icon;
  final Color color;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(icon, key: ValueKey(icon), color: color, size: 24),
        ),
        if (badge > 0)
          Positioned(
            top: -5,
            right: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17),
              height: 17,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.warningDark,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.ink, width: 2),
              ),
              child: Text(
                badge > 9 ? '9+' : '$badge',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddButton extends StatefulWidget {
  const _AddButton({required this.onPressed, required this.tooltip});

  final VoidCallback onPressed;
  final String tooltip;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const size = FloatingNavBar.height;

    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        excludeSemantics: true,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onPressed();
          },
          child: AnimatedScale(
            scale: _pressed ? 0.9 : 1,
            duration: const Duration(milliseconds: 120),
            child: AnimatedRotation(
              turns: _pressed ? 0.125 : 0,
              duration: const Duration(milliseconds: 160),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
