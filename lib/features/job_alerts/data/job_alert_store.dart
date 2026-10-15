import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../discover/data/search_preferences_repository.dart';

/// What job alerts need on this device: the saved searches to check, the
/// jobs already seen for each, and which new ones the user hasn't opened.
///
/// Uses [SharedPreferencesAsync] (no in-memory cache) because the
/// background task writes from another isolate.
class JobAlertStore {
  JobAlertStore([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _searchesKey = 'job_alerts.searches';
  static const _locationKey = 'job_alerts.location';
  static const _dismissedKey = 'job_alerts.dismissed';
  static const _lastCheckKey = 'job_alerts.last_check';
  static String _seenKey(String id) => 'job_alerts.seen.$id';
  static String _freshKey(String id) => 'job_alerts.fresh.$id';

  /// Seen jobs kept per search; old ones fall off.
  static const _seenLimit = 300;

  Future<List<SavedSearch>> searches() async {
    final raw = await _prefs.getString(_searchesKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(SavedSearch.fromJson)
          .toList();
    } on FormatException {
      return const [];
    }
  }

  /// Mirrors the saved searches, and forgets state for removed ones.
  Future<void> setSearches(List<SavedSearch> searches) async {
    final ids = {for (final s in searches) s.id};
    for (final old in await this.searches()) {
      if (!ids.contains(old.id)) {
        await _prefs.remove(_seenKey(old.id));
        await _prefs.remove(_freshKey(old.id));
      }
    }
    await _prefs.setString(
      _searchesKey,
      jsonEncode([for (final s in searches) s.toJson()]),
    );
  }

  /// City used for Philippine searches.
  Future<String?> location() => _prefs.getString(_locationKey);

  Future<void> setLocation(String? location) => location == null
      ? _prefs.remove(_locationKey)
      : _prefs.setString(_locationKey, location);

  Future<Set<String>> dismissed() async =>
      (await _prefs.getStringList(_dismissedKey))?.toSet() ?? const {};

  Future<void> setDismissed(Set<String> keys) =>
      _prefs.setStringList(_dismissedKey, keys.toList());

  /// Jobs already seen for a search, or null if it was never checked.
  Future<Set<String>?> seen(String searchId) async =>
      (await _prefs.getStringList(_seenKey(searchId)))?.toSet();

  /// Records jobs as seen, newest first.
  Future<void> markSeen(String searchId, Iterable<String> keys) async {
    final before = await _prefs.getStringList(_seenKey(searchId)) ?? const [];
    final merged = <String>{...keys, ...before}.take(_seenLimit).toList();
    await _prefs.setStringList(_seenKey(searchId), merged);
  }

  /// New jobs found in the background that the user hasn't looked at yet.
  Future<Set<String>> fresh(String searchId) async =>
      (await _prefs.getStringList(_freshKey(searchId)))?.toSet() ?? const {};

  Future<void> addFresh(String searchId, Iterable<String> keys) async {
    final merged = {...await fresh(searchId), ...keys};
    await _prefs.setStringList(_freshKey(searchId), merged.toList());
  }

  Future<void> clearFresh(String searchId) => _prefs.remove(_freshKey(searchId));

  /// Fresh-job counts per saved search id (zero counts left out).
  Future<Map<String, int>> freshCounts() async {
    final counts = <String, int>{};
    for (final search in await searches()) {
      final count = (await fresh(search.id)).length;
      if (count > 0) counts[search.id] = count;
    }
    return counts;
  }

  Future<DateTime?> lastCheck() async {
    final raw = await _prefs.getString(_lastCheckKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setLastCheck(DateTime time) =>
      _prefs.setString(_lastCheckKey, time.toIso8601String());
}
