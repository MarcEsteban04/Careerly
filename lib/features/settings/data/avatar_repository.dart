import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores profile photos in the public `avatars` bucket, one folder per
/// user (see the avatars migration for the access rules).
class AvatarRepository {
  AvatarRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _bucket = 'avatars';

  /// Uploads [bytes] (a JPEG) and returns its public URL. Each upload gets a
  /// new name so the old photo never lingers in image caches.
  Future<String> upload(Uint8List bytes) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not signed in');

    await _removeAll(userId);
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  Future<void> remove() async {
    final userId = _client.auth.currentUser?.id;
    if (userId != null) await _removeAll(userId);
  }

  Future<void> _removeAll(String userId) async {
    final files = await _client.storage.from(_bucket).list(path: userId);
    if (files.isEmpty) return;
    await _client.storage
        .from(_bucket)
        .remove([for (final f in files) '$userId/${f.name}']);
  }
}
