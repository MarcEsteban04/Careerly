import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/document_markup.dart';

/// Renders a resume or cover letter's light Markdown as styled text.
class MarkupView extends StatelessWidget {
  const MarkupView({super.key, required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final body = theme.textTheme.bodyMedium?.copyWith(height: 1.5);

    TextSpan rich(List<MarkupSpan> parts) => TextSpan(
          children: [
            for (final part in parts)
              TextSpan(
                text: part.text,
                style: part.bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
              ),
          ],
        );

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final block in parseMarkup(content))
            switch (block) {
              TitleBlock(:final text) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: Text(
                    text,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              HeadingBlock(:final text) => Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.md,
                    bottom: AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        text.toUpperCase(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          letterSpacing: 0.8,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Divider(color: colorScheme.outline, height: 1),
                    ],
                  ),
                ),
              BulletBlock(:final spans) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 9, 10, 0),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(child: Text.rich(rich(spans), style: body)),
                    ],
                  ),
                ),
              ParagraphBlock(:final spans) => Text.rich(rich(spans), style: body),
              GapBlock() => const SizedBox(height: AppSpacing.sm),
            },
        ],
      ),
    );
  }
}
