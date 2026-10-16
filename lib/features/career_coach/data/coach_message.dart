/// One turn in the career coach chat.
class CoachMessage {
  const CoachMessage({
    required this.fromCoach,
    required this.text,
    required this.sentAt,
    this.suggestions = const [],
    this.provider,
  });

  factory CoachMessage.fromJson(Map<String, dynamic> json) => CoachMessage(
        fromCoach: json['coach'] == true,
        text: '${json['text'] ?? ''}',
        sentAt: DateTime.tryParse('${json['at']}') ?? DateTime.now(),
        suggestions: json['suggestions'] is List
            ? (json['suggestions'] as List).whereType<String>().toList()
            : const [],
        provider: json['provider'] is String ? json['provider'] as String : null,
      );

  final bool fromCoach;

  /// Light Markdown for the coach (bold, bullets); plain for her.
  final String text;
  final DateTime sentAt;

  /// Follow-up questions she can tap, from the coach.
  final List<String> suggestions;

  /// Which AI answered.
  final String? provider;

  Map<String, dynamic> toJson() => {
        'coach': fromCoach,
        'text': text,
        'at': sentAt.toIso8601String(),
        if (suggestions.isNotEmpty) 'suggestions': suggestions,
        if (provider != null) 'provider': provider,
      };
}
