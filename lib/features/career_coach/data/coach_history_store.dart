import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coach_message.dart';

/// Keeps the coach conversation on the device, so it's there next time.
class CoachHistoryStore {
  CoachHistoryStore({SharedPreferencesAsync? prefs}) : _injectedPrefs = prefs;

  final SharedPreferencesAsync? _injectedPrefs;
  late final _prefs = _injectedPrefs ?? SharedPreferencesAsync();

  static const _key = 'career_coach_history';

  /// Older messages are dropped beyond this.
  static const maxMessages = 80;

  Future<List<CoachMessage>> load() async {
    try {
      final raw = await _prefs.getString(_key);
      if (raw == null) return const [];
      final json = jsonDecode(raw);
      return json is List
          ? json
              .whereType<Map<String, dynamic>>()
              .map(CoachMessage.fromJson)
              .where((m) => m.text.isNotEmpty)
              .toList()
          : const [];
    } catch (e) {
      debugPrint('Coach history unreadable: $e');
      return const [];
    }
  }

  Future<void> save(List<CoachMessage> messages) {
    final kept = messages.length > maxMessages
        ? messages.sublist(messages.length - maxMessages)
        : messages;
    return _prefs.setString(
      _key,
      jsonEncode([for (final m in kept) m.toJson()]),
    );
  }

  Future<void> clear() => _prefs.remove(_key);
}
