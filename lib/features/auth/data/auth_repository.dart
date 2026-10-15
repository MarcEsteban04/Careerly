import 'package:supabase_flutter/supabase_flutter.dart';

/// Email/password auth for the app's single account. There is no sign-up
/// flow: the account is created in the Supabase dashboard.
class AuthRepository {
  AuthRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  Future<void> signIn({required String email, required String password}) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();
}
