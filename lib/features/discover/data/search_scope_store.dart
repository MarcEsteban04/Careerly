import 'package:shared_preferences/shared_preferences.dart';

import 'job_search_query.dart';

/// Remembers where the user last chose to search, on this device.
class SearchScopeStore {
  SearchScopeStore([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _key = 'discover.scope';

  /// The saved choice, or null if none was made yet.
  Future<SearchScope?> read() async {
    final name = await _prefs.getString(_key);
    return name == null ? null : SearchScope.parse(name);
  }

  Future<void> save(SearchScope scope) => _prefs.setString(_key, scope.name);
}
