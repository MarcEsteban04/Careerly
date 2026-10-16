import '../../../core/ai/citations.dart';

/// An AI brief on an employer: what they do, a few key facts, good signs,
/// things worth checking, and questions to ask them.
class CompanyResearch {
  const CompanyResearch({
    required this.company,
    required this.summary,
    required this.facts,
    required this.goodSigns,
    required this.watchOuts,
    required this.questionsToAsk,
    required this.foundReliableInfo,
    required this.provider,
    required this.createdAt,
  });

  factory CompanyResearch.fromJson(
    Map<String, dynamic> json, {
    required String company,
    required String provider,
    required DateTime createdAt,
  }) =>
      CompanyResearch(
        company: company,
        summary: _text(json['summary']),
        facts: _list(json['facts'], 5),
        goodSigns: _list(json['good_signs'], 4),
        watchOuts: _list(json['watch_outs'], 4),
        questionsToAsk: _list(json['questions_to_ask'], 4),
        foundReliableInfo: json['found'] != false,
        provider: provider,
        createdAt: createdAt,
      );

  /// Reads back what [toJson] stored.
  factory CompanyResearch.fromStored(Map<String, dynamic> json) =>
      CompanyResearch.fromJson(
        json,
        company: _text(json['company']),
        provider: _text(json['provider']),
        createdAt: DateTime.tryParse(_text(json['created_at'])) ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  final String company;

  /// 2-3 sentences: what they do and for whom.
  final String summary;

  /// Short "Label: value" lines, e.g. "Industry: Fintech".
  final List<String> facts;
  final List<String> goodSigns;

  /// Red flags or things to verify before going further.
  final List<String> watchOuts;
  final List<String> questionsToAsk;

  /// False when the web had little reliable information on the company,
  /// itself worth knowing.
  final bool foundReliableInfo;
  final String provider;
  final DateTime createdAt;

  bool get isEmpty => summary.isEmpty && facts.isEmpty;

  Map<String, dynamic> toJson() => {
        'company': company,
        'summary': summary,
        'facts': facts,
        'good_signs': goodSigns,
        'watch_outs': watchOuts,
        'questions_to_ask': questionsToAsk,
        'found': foundReliableInfo,
        'provider': provider,
        'created_at': createdAt.toIso8601String(),
      };

  static String _text(Object? value) =>
      value is String ? stripCitations(value) : '';

  static List<String> _list(Object? value, int max) => value is List
      ? value
          .whereType<String>()
          .map(stripCitations)
          .where((s) => s.isNotEmpty)
          .take(max)
          .toList()
      : const [];
}
