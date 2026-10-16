import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Links and text shared into Careerly from other apps (Android's Share
/// menu). Abstract so tests don't need the platform plugin.
abstract class JobShareInbox {
  /// Shares that arrive while the app is open.
  Stream<String> get shares;

  /// What was shared to launch the app, once.
  Future<String?> takeInitial();
}

class PlatformJobShareInbox implements JobShareInbox {
  const PlatformJobShareInbox();

  static String? _text(List<SharedMediaFile> files) {
    for (final file in files) {
      if ((file.type == SharedMediaType.text ||
              file.type == SharedMediaType.url) &&
          file.path.trim().isNotEmpty) {
        return file.path.trim();
      }
    }
    return null;
  }

  @override
  Stream<String> get shares => ReceiveSharingIntent.instance
      .getMediaStream()
      .map(_text)
      .where((text) => text != null)
      .cast<String>()
      .handleError((Object e) => debugPrint('Share stream failed: $e'));

  @override
  Future<String?> takeInitial() async {
    try {
      final text = _text(await ReceiveSharingIntent.instance.getInitialMedia());
      await ReceiveSharingIntent.instance.reset();
      return text;
    } catch (e) {
      debugPrint('Initial share unavailable: $e');
      return null;
    }
  }
}
