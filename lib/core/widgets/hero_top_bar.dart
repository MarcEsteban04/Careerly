import 'package:flutter/material.dart';

import 'circle_icon_button.dart';

/// Back button, centered title and an optional action, for the top of a
/// [HeroHeader] on detail screens.
class HeroTopBar extends StatelessWidget {
  const HeroTopBar({
    super.key,
    required this.title,
    this.trailing,
    this.onBack,
  });

  final String title;

  /// E.g. a "More" button; an empty slot keeps the title centered.
  final Widget? trailing;

  /// Defaults to popping the route.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        CircleIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        trailing ?? const SizedBox(width: 48),
      ],
    );
  }
}
