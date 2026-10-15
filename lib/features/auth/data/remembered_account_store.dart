import 'package:shared_preferences/shared_preferences.dart';

class RememberedAccount {
  const RememberedAccount({required this.email, this.name});

  final String email;
  final String? name;

  String? get firstName {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed.split(RegExp(r'\s+')).first;
  }
}

/// Remembers the last account that signed in so the login screen can greet
/// it by name and only ask for a password.
class RememberedAccountStore {
  static const _emailKey = 'auth.remembered_email';
  static const _nameKey = 'auth.remembered_name';

  Future<RememberedAccount?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_emailKey);
    if (email == null || email.isEmpty) return null;
    return RememberedAccount(email: email, name: prefs.getString(_nameKey));
  }

  Future<void> save(RememberedAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, account.email);
    final name = account.name;
    if (name == null || name.isEmpty) {
      await prefs.remove(_nameKey);
    } else {
      await prefs.setString(_nameKey, name);
    }
  }
}
