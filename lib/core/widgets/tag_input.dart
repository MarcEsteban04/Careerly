import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Text field that turns entries into removable chips, with optional
/// one-tap suggestions underneath. Commas also separate entries.
class TagInput extends StatefulWidget {
  const TagInput({
    super.key,
    required this.values,
    required this.onChanged,
    required this.hintText,
    this.prefixIcon,
    this.suggestions = const [],
    this.suggestionsLabel = 'Suggestions',
  });

  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final String hintText;
  final IconData? prefixIcon;
  final List<String> suggestions;
  final String suggestionsLabel;

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _has(String value) =>
      widget.values.any((v) => v.toLowerCase() == value.toLowerCase());

  void _add(String text) {
    final added = [
      for (final part in text.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    ];
    final next = [...widget.values];
    for (final value in added) {
      if (!next.any((v) => v.toLowerCase() == value.toLowerCase())) {
        next.add(value);
      }
    }
    _controller.clear();
    if (next.length != widget.values.length) widget.onChanged(next);
  }

  void _remove(String value) =>
      widget.onChanged([...widget.values]..remove(value));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final suggestions = [
      for (final s in widget.suggestions)
        if (!_has(s)) s,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onChanged: (text) {
            if (text.contains(',')) _add(text);
          },
          onSubmitted: (text) {
            _add(text);
            _focusNode.requestFocus();
          },
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon:
                widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
            suffixIcon: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _controller.text.trim().isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Add',
                      icon: const Icon(Icons.add_circle_rounded),
                      color: colorScheme.primary,
                      onPressed: () => _add(_controller.text),
                    ),
            ),
          ),
        ),
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final value in widget.values)
                InputChip(
                  label: Text(value),
                  onDeleted: () => _remove(value),
                  deleteButtonTooltipMessage: 'Remove $value',
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.10),
                  side: BorderSide.none,
                  labelStyle: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  deleteIconColor: colorScheme.primary,
                  shape: const StadiumBorder(),
                ),
            ],
          ),
        ],
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.suggestionsLabel,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final suggestion in suggestions.take(8))
                ActionChip(
                  avatar: Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  label: Text(suggestion),
                  onPressed: () => _add(suggestion),
                  shape: const StadiumBorder(),
                  labelStyle: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
