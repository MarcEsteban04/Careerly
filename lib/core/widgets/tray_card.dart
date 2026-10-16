import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A white content card set in a soft tray, with a footer row underneath
/// (e.g. timing and a status badge).
class TrayCard extends StatelessWidget {
  const TrayCard({
    super.key,
    required this.body,
    required this.footer,
    required this.onTap,
    this.onLongPress,
    this.selected,
    this.semanticLabel,
  });

  final Widget body;
  final Widget footer;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Null when selecting isn't on; otherwise shows a check circle.
  final bool? selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = selected ?? false;

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.10)
            : colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              _content(Theme.of(context)),
              if (selected != null)
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.surface,
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: colorScheme.onPrimary,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(ThemeData theme) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xxs + 1),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg - 5),
            border: theme.brightness == Brightness.dark
                ? Border.all(color: theme.colorScheme.outline)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          // Keep the text clear of the check circle while selecting.
          child: selected == null
              ? body
              : Padding(padding: const EdgeInsets.only(right: 30), child: body),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs + 2,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: footer,
        ),
      ],
    ),
  );
}

/// Footer row for a [TrayCard]: clock + text on the left, optional badge.
class TrayFooter extends StatelessWidget {
  const TrayFooter({super.key, required this.text, this.badge, this.icon});

  final String text;
  final Widget? badge;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(icon ?? Icons.schedule_rounded, size: 16, color: muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
        ?badge,
      ],
    );
  }
}

/// Small uppercase label in a tinted box, e.g. "OFFER" or "92% MATCH".
class TrayBadge extends StatelessWidget {
  const TrayBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
