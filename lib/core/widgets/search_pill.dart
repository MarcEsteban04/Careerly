import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Rounded search field. With [onTap] and no [controller] it acts as a
/// button that leads to a real search (e.g. on the dashboard).
class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    this.hint = 'Search',
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onTap,
  });

  final String hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: colorScheme.outline),
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: controller == null,
      onTap: onTap,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: AppSpacing.xxs),
          child: Icon(Icons.search_rounded),
        ),
        suffixIcon: controller == null
            ? null
            : ListenableBuilder(
                listenable: controller!,
                builder: (context, _) => controller!.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          controller!.clear();
                          onChanged?.call('');
                        },
                      ),
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: pill,
        enabledBorder: pill,
        focusedBorder: pill.copyWith(
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
