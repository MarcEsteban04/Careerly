import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/core/ai/ai_provider.dart';
import 'package:careerly/features/agenda/data/agenda_event.dart';
import 'package:careerly/features/applications/data/job_application.dart';
import 'package:careerly/features/career_coach/data/career_coach.dart';
import 'package:careerly/features/career_coach/data/coach_history_store.dart';
import 'package:careerly/features/career_coach/data/coach_message.dart';
import 'package:careerly/features/profile/data/career_profile.dart';

import '../../core/ai/fake_ai_provider.dart';

void main() {
  final now = DateTime(2026, 10, 17, 9);
  final saved = JobApplication(
    id: 'a1',
    company: 'Acme PH',
    role: 'UI Designer',
    status: ApplicationStatus.saved,
    salary: '₱45K/month',
    createdAt: now,
    updatedAt: now,
  );
  final context = CoachContext(
    profile: const CareerProfile(
      targetRoles: ['UI Designer'],
      skills: ['Figma'],
      yearsOfExperience: 1,
    ),
    name: 'Princess Elfa',
    resumeText: 'Princess Elfa\nUI designer, Figma',
    applications: [saved],
    upcoming: [
      AgendaEvent(
        id: 'e1',
        title: 'Portfolio review',
        kind: AgendaEventKind.interview,
        company: 'Globex',
        startsAt: DateTime(2026, 10, 20, 14),
      ),
    ],
  );

  CoachMessage turn(int i) => CoachMessage(
        fromCoach: i.isOdd,
        text: 'Turn $i',
        sentAt: now,
      );

  test('answers from her profile, jobs, agenda and resume', () async {
    final ai = FakeAiProvider(
      'Gemini',
      reply: '{"reply": "Apply to **Acme PH** today [1].", '
          '"suggestions": ["Tailor my resume", "", "${'x' * 90}"]}',
    );
    final coach = CareerCoach(AiChain([ai]));

    final reply = await coach.reply(
      question: 'What should I do first?',
      context: context,
      now: now,
    );

    expect(reply.text, 'Apply to **Acme PH** today.');
    expect(reply.suggestions, ['Tailor my resume']);
    expect(reply.provider, 'Gemini');
    // A slow AI hands over quickly in a chat.
    expect(ai.requests.single.timeout, CareerCoach.providerTimeout);
    final prompt = ai.requests.single.prompt;
    expect(prompt, contains('Name: Princess Elfa'));
    expect(prompt, contains('UI Designer at Acme PH'));
    expect(prompt, contains('₱45K/month'));
    expect(prompt, contains('Portfolio review (Globex)'));
    expect(prompt, contains('RESUME'));
    expect(prompt, contains('Candidate: What should I do first?'));
  });

  test('sends only the most recent turns of the conversation', () async {
    final ai = FakeAiProvider('Gemini', reply: '{"reply": "Sure."}');
    final coach = CareerCoach(AiChain([ai]));

    await coach.reply(
      question: 'And then?',
      context: context,
      history: [for (var i = 0; i < 20; i++) turn(i)],
    );

    final prompt = ai.requests.single.prompt;
    expect(prompt, isNot(contains('Turn 7\n')));
    expect(prompt, contains('Candidate: Turn 8'));
    expect(prompt, contains('Coach: Turn 19'));
  });

  test('falls back to the next AI, keeping OpenAI last', () async {
    final gemini = FakeAiProvider(
      'Gemini',
      error: const AiProviderException('Gemini', 'quota'),
    );
    final groq = FakeAiProvider('Groq', reply: '{"reply": "From Groq."}');
    final openAi = FakeAiProvider('OpenAI', reply: '{"reply": "From OpenAI."}');
    final coach = CareerCoach(AiChain([gemini, groq, openAi]));

    final reply = await coach.reply(question: 'Hi', context: context);

    expect(reply.provider, 'Groq');
    expect(openAi.requests, isEmpty);
  });

  test('an empty reply is an error', () async {
    final coach = CareerCoach(
      AiChain([FakeAiProvider('Gemini', reply: '{"suggestions": []}')]),
    );
    expect(
      () => coach.reply(question: 'Hi', context: context),
      throwsFormatException,
    );
  });

  test('starters fit what she has going on', () {
    final starters = CareerCoach.starters(context);
    expect(starters, hasLength(4));
    expect(starters.first, contains('saved jobs'));
    expect(starters, contains('Help me get ready for my next interview'));
  });

  group('history', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('is kept on the device and capped', () async {
      final store = CoachHistoryStore();
      expect(await store.load(), isEmpty);

      await store.save([
        for (var i = 0; i < CoachHistoryStore.maxMessages + 5; i++) turn(i),
      ]);
      final loaded = await store.load();
      expect(loaded, hasLength(CoachHistoryStore.maxMessages));
      expect(loaded.first.text, 'Turn 5');

      await store.clear();
      expect(await store.load(), isEmpty);
    });
  });
}
