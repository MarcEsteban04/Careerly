import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the email of the last successful sign-in so the login screen
/// only needs a password next time.
class LastEmailStore {
  static const _key = 'auth.last_email';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> save(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, email);
  }
}
