/// What kind of question an interviewer is likely to ask.
enum QuestionCategory {
  behavioral('Behavioral'),
  role('Role'),
  company('Company'),
  situational('Situational');

  const QuestionCategory(this.label);

  final String label;

  static QuestionCategory parse(Object? value) => values.firstWhere(
        (c) => c.name == '$value'.toLowerCase().trim(),
        orElse: () => QuestionCategory.role,
      );
}

class InterviewQuestion {
  const InterviewQuestion({
    required this.category,
    required this.question,
    required this.answer,
    this.why,
  });

  factory InterviewQuestion.fromJson(Map<String, dynamic> json) =>
      InterviewQuestion(
        category: QuestionCategory.parse(json['category']),
        question: '${json['question'] ?? ''}'.trim(),
        answer: '${json['answer'] ?? ''}'.trim(),
        why: (json['why'] as String?)?.trim(),
      );

  final QuestionCategory category;
  final String question;

  /// Suggested answer drawn from the resume, as talking points.
  final String answer;

  /// What the interviewer wants to learn.
  final String? why;

  Map<String, dynamic> toJson() => {
        'category': category.name,
        'question': question,
        'answer': answer,
        'why': ?why,
      };
}

/// Coaching on one mock-interview answer.
class AnswerFeedback {
  const AnswerFeedback({
    required this.score,
    required this.verdict,
    required this.strengths,
    required this.improvements,
    required this.betterAnswer,
  });

  /// 1–10; 7 and up would impress.
  final int score;
  final String verdict;
  final List<String> strengths;
  final List<String> improvements;
  final String betterAnswer;
}

/// An AI interview kit for one application.
class InterviewPrep {
  const InterviewPrep({
    required this.companyBrief,
    required this.focusAreas,
    required this.questions,
    required this.questionsToAsk,
    required this.tips,
    required this.provider,
    required this.createdAt,
  });

  factory InterviewPrep.fromJson(
    Map<String, dynamic> json, {
    required String provider,
    required DateTime createdAt,
  }) {
    List<String> strings(Object? value) => value is List
        ? value
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : const [];

    return InterviewPrep(
      companyBrief: '${json['company_brief'] ?? ''}'.trim(),
      focusAreas: strings(json['focus_areas']),
      questions: json['questions'] is List
          ? (json['questions'] as List)
              .whereType<Map<String, dynamic>>()
              .map(InterviewQuestion.fromJson)
              .where((q) => q.question.isNotEmpty)
              .toList()
          : const [],
      questionsToAsk: strings(json['questions_to_ask']),
      tips: strings(json['tips']),
      provider: provider,
      createdAt: createdAt,
    );
  }

  /// A few sentences on the company and what it's likely to value.
  final String companyBrief;

  /// Skills and qualities the interview will probably test.
  final List<String> focusAreas;
  final List<InterviewQuestion> questions;

  /// Smart questions for the candidate to ask at the end.
  final List<String> questionsToAsk;
  final List<String> tips;

  /// AI provider that wrote it.
  final String provider;
  final DateTime createdAt;

  bool get isEmpty => questions.isEmpty;

  Map<String, dynamic> toJson() => {
        'company_brief': companyBrief,
        'focus_areas': focusAreas,
        'questions': [for (final q in questions) q.toJson()],
        'questions_to_ask': questionsToAsk,
        'tips': tips,
      };
}
