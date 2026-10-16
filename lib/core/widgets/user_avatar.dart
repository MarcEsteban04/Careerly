import 'package:flutter/material.dart';

/// The user's photo, or their initial on the brand color while it loads or
/// when there's no photo.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.initial,
    this.photoUrl,
    this.radius = 24,
  });

  final String initial;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fallback = Center(
      child: Text(
        initial,
        style: (radius >= 36
                ? theme.textTheme.headlineMedium
                : theme.textTheme.titleMedium)
            ?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final url = photoUrl;

    return Container(
      width: radius * 2,
      height: radius * 2,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: url == null
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: radius * 2,
              height: radius * 2,
              // Decode at display size, not the upload's full resolution.
              cacheWidth: (radius * 2 * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              errorBuilder: (_, _, _) => fallback,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : fallback,
            ),
    );
  }
}
