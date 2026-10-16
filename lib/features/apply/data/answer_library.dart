import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'form_field_info.dart';

/// An answer she approved for a form question.
class SavedAnswer {
  const SavedAnswer({
    required this.question,
    required this.answer,
    required this.updatedAt,
    this.company,
  });

  factory SavedAnswer.fromJson(Map<String, dynamic> json) => SavedAnswer(
        question: '${json['question'] ?? ''}',
        answer: '${json['answer'] ?? ''}',
        company: json['company'] is String ? json['company'] as String : null,
        updatedAt: DateTime.tryParse('${json['updated_at']}') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  final String question;
  final String answer;

  /// Set when the answer is about one employer, so it's only reused there.
  final String? company;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        'company': company,
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// Remembers the answers she approves on application forms, so the same
/// questions are answered the same way next time. Kept on the device.
class AnswerLibrary {
  AnswerLibrary({SharedPreferencesAsync? prefs}) : _injectedPrefs = prefs;

  final SharedPreferencesAsync? _injectedPrefs;
  late final _prefs = _injectedPrefs ?? SharedPreferencesAsync();

  static const _key = 'answer_library';

  /// Oldest answers are dropped beyond this.
  static const maxAnswers = 100;

  static const _stopWords = {
    'a', 'an', 'the', 'and', 'or', 'of', 'to', 'for', 'in', 'on', 'at', 'is',
    'are', 'do', 'does', 'you', 'your', 'our', 'we', 'us', 'this', 'with',
    'what', 'why', 'how', 'please', 'tell', 'about', 'any', 'have',
  };

  Future<List<SavedAnswer>> load() async {
    try {
      final raw = await _prefs.getString(_key);
      if (raw == null) return const [];
      final json = jsonDecode(raw);
      return json is List
          ? json
              .whereType<Map<String, dynamic>>()
              .map(SavedAnswer.fromJson)
              .where((a) => a.question.isNotEmpty && a.answer.isNotEmpty)
              .toList()
          : const [];
    } catch (e) {
      debugPrint('Answer library unreadable: $e');
      return const [];
    }
  }

  Future<void> save(List<SavedAnswer> answers) => _prefs.setString(
        _key,
        jsonEncode([for (final a in answers.take(maxAnswers)) a.toJson()]),
      );

  /// Saves approved answers to questions, newest first, replacing older
  /// answers to the same question.
  Future<void> remember(
    List<FieldAnswer> answers, {
    required String company,
    DateTime? now,
  }) async {
    final fresh = [
      for (final a in answers)
        if (a.source != AnswerSource.details &&
            a.field.displayLabel.length > 3 &&
            a.value.trim().isNotEmpty)
          SavedAnswer(
            question: a.field.displayLabel,
            answer: a.value.trim(),
            company: _mentions(a.field.displayLabel, company) ||
                    _mentions(a.value, company)
                ? company
                : null,
            updatedAt: now ?? DateTime.now(),
          ),
    ];
    if (fresh.isEmpty) return;
    final existing = await load();
    final kept = [
      for (final old in existing)
        if (!fresh.any(
          (f) => _normalized(f.question) == _normalized(old.question) && f.company == old.company,
        ))
          old,
    ];
    await save([...fresh, ...kept]);
  }

  /// The saved answer for [field] at [company], if one fits.
  static SavedAnswer? match(
    FormFieldInfo field,
    List<SavedAnswer> saved, {
    required String company,
  }) {
    final words = _words(field.displayLabel, company);
    if (words.isEmpty) return null;
    SavedAnswer? best;
    var bestScore = 0.0;
    for (final answer in saved) {
      // About another employer: not reusable here.
      if (answer.company != null &&
          answer.company!.toLowerCase() != company.toLowerCase()) {
        continue;
      }
      if (field.kind.hasOptions && field.optionFor(answer.answer) == null) {
        continue;
      }
      final other = _words(answer.question, answer.company ?? company);
      if (other.isEmpty) continue;
      final score =
          words.intersection(other).length / words.union(other).length;
      if (score > bestScore) {
        bestScore = score;
        best = answer;
      }
    }
    return bestScore >= 0.6 ? best : null;
  }

  static bool _mentions(String text, String company) =>
      company.trim().length > 1 &&
      text.toLowerCase().contains(company.trim().toLowerCase());

  static String _normalized(String question) =>
      question.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static Set<String> _words(String question, String company) {
    final text = question.toLowerCase().replaceAll(company.toLowerCase(), ' ');
    return {
      for (final w in text.split(RegExp(r'[^a-z0-9]+')))
        if (w.length > 1 && !_stopWords.contains(w)) w,
    };
  }
}
