import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The user's photo, or their initial on ink while it loads or
/// when there's no photo.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.initial,
    this.photoUrl,
    this.radius = 24,
    this.ring = false,
  });

  final String initial;
  final String? photoUrl;
  final double radius;

  /// A white ring and soft shadow, for a featured avatar.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Center(
      child: Text(
        initial,
        style: (radius >= 36
                ? theme.textTheme.headlineMedium
                : theme.textTheme.titleMedium)
            ?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final url = photoUrl;
    // The ring sits inside the avatar's size, so the photo is clipped to
    // its own circle (clipping the outer box would leave the inset photo a
    // rounded square).
    final ringWidth = ring ? 3.0 : 0.0;
    final photoSize = radius * 2 - ringWidth * 2;

    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        color: ring ? Colors.white : null,
        shape: BoxShape.circle,
        boxShadow: ring
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: ColoredBox(
          color: AppColors.ink,
          child: url == null
              ? fallback
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: photoSize,
                  height: photoSize,
                  // Decode at display size, not the upload's full resolution.
                  cacheWidth:
                      (photoSize * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                  errorBuilder: (_, _, _) => fallback,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : fallback,
                ),
        ),
      ),
    );
  }
}
