import 'package:flutter/material.dart';

/// Headline text where `**marked**` words are bold and the rest is regular,
/// e.g. "Let's get you **hired**". [emphasisColor] tints the marked words.
class EmphasisText extends StatelessWidget {
  const EmphasisText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.emphasisColor,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Color? emphasisColor;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? Theme.of(context).textTheme.headlineMedium)!;
    final parts = text.split('**');

    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++)
            if (parts[i].isNotEmpty)
              TextSpan(
                text: parts[i],
                style: i.isOdd
                    ? TextStyle(fontWeight: FontWeight.w700, color: emphasisColor)
                    : const TextStyle(fontWeight: FontWeight.w400),
              ),
        ],
      ),
      style: base,
      textAlign: textAlign,
    );
  }
}
