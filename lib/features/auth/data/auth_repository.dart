import 'package:supabase_flutter/supabase_flutter.dart';

/// Email/password auth backed by Supabase.
class AuthRepository {
  AuthRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  String? get currentUserEmail => _client.auth.currentUser?.email;

  /// The name given at sign-up, if any.
  String? get currentUserName {
    final name = _client.auth.currentUser?.userMetadata?['full_name'];
    return name is String && name.trim().isNotEmpty ? name.trim() : null;
  }

  Future<void> signIn({required String email, required String password}) =>
      _client.auth.signInWithPassword(email: email, password: password);

  /// Creates an account. Returns `true` when the user is signed in right away,
  /// or `false` when Supabase requires the email to be confirmed first.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
    );
    // With email confirmation on, Supabase hides existing accounts by
    // returning a user with no identities instead of an error.
    if (response.user?.identities?.isEmpty ?? false) {
      throw const AuthException('User already registered');
    }
    return response.session != null;
  }

  Future<void> signOut() => _client.auth.signOut();
}
