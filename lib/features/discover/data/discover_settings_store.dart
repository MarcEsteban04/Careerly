import 'package:shared_preferences/shared_preferences.dart';

import 'job_search_query.dart';

/// Search settings remembered on this device: where to search and the
/// salary filter.
class DiscoverSettingsStore {
  DiscoverSettingsStore([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _scopeKey = 'discover.scope';
  static const _minSalaryKey = 'discover.min_salary';
  static const _salaryShownOnlyKey = 'discover.salary_shown_only';

  /// The saved area, or null if none was chosen yet.
  Future<SearchScope?> readScope() async {
    final name = await _prefs.getString(_scopeKey);
    return name == null ? null : SearchScope.parse(name);
  }

  Future<void> saveScope(SearchScope scope) =>
      _prefs.setString(_scopeKey, scope.name);

  /// Minimum monthly pay in pesos, and whether to hide jobs without pay.
  Future<(int?, bool)> readSalary() async => (
        await _prefs.getInt(_minSalaryKey),
        await _prefs.getBool(_salaryShownOnlyKey) ?? false,
      );

  Future<void> saveSalary({int? minimum, required bool shownOnly}) async {
    if (minimum == null) {
      await _prefs.remove(_minSalaryKey);
    } else {
      await _prefs.setInt(_minSalaryKey, minimum);
    }
    await _prefs.setBool(_salaryShownOnlyKey, shownOnly);
  }
}
