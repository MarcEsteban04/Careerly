import 'package:supabase_flutter/supabase_flutter.dart';

import 'career_profile.dart';

/// Stores the career profile in the Supabase user's metadata, so it follows
/// the account without needing its own table.
class CareerProfileRepository {
  CareerProfileRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _key = 'career_profile';

  CareerProfile read() {
    final raw = _client.auth.currentUser?.userMetadata?[_key];
    return raw is Map<String, dynamic>
        ? CareerProfile.fromJson(raw)
        : const CareerProfile();
  }

  Future<CareerProfile> save(CareerProfile profile) async {
    await _client.auth.updateUser(UserAttributes(data: {_key: profile.toJson()}));
    return profile;
  }
}
