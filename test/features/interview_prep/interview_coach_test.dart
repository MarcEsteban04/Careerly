import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/features/interview_prep/data/interview_coach.dart';
import 'package:careerly/features/interview_prep/data/interview_prep.dart';
import 'package:careerly/features/profile/data/career_profile.dart';
import 'package:careerly/features/studio/data/career_writer.dart';

import '../../core/ai/fake_ai_provider.dart';
import 'interview_prep_fixtures.dart';

void main() {
  const job = JobContext(title: 'UI Designer', company: 'Acme');

  test('parses the kit and keeps answers grounded in the resume', () async {
    final ai = FakeAiProvider('Gemini', reply: sampleKitReply);
    final coach = InterviewCoach(AiChain([ai]));

    final prep = await coach.prepare(
      job: job,
      profile: const CareerProfile(targetRoles: ['UI Designer']),
      resumeText: 'Jane Doe. Designer at Globex.',
    );

    expect(prep.provider, 'Gemini');
    expect(prep.companyBrief, contains('design tools'));
    expect(prep.focusAreas, ['Visual design', 'Collaboration']);
    expect(prep.questions, hasLength(3));
    expect(prep.questions.first.category, QuestionCategory.behavioral);
    expect(prep.questions[1].category, QuestionCategory.role);
    // Unknown categories fall back to role questions.
    expect(prep.questions[2].category, QuestionCategory.role);
    expect(prep.questionsToAsk, hasLength(1));
    expect(prep.tips, ['Bring two case studies.']);

    final request = ai.requests.single;
    expect(request.webSearch, isTrue);
    expect(request.prompt, contains('Designer at Globex'));
    expect(request.prompt, contains('UI Designer at Acme'));
  });

  test('round-trips through JSON for saving', () async {
    final coach = InterviewCoach(
      AiChain([FakeAiProvider('Groq', reply: sampleKitReply)]),
    );
    final prep = await coach.prepare(job: job, profile: const CareerProfile());

    final restored = InterviewPrep.fromJson(
      prep.toJson(),
      provider: prep.provider,
      createdAt: prep.createdAt,
    );
    expect(restored.questions.map((q) => q.question),
        prep.questions.map((q) => q.question));
    expect(restored.questions.first.why, 'Tests openness.');
  });

  test('rejects a reply without questions', () async {
    final coach = InterviewCoach(
      AiChain([FakeAiProvider('Gemini', reply: '{"company_brief": "x"}')]),
    );

    expect(
      () => coach.prepare(job: job, profile: const CareerProfile()),
      throwsFormatException,
    );
  });
}
