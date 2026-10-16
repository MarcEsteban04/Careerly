import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/features/company_research/data/company_researcher.dart';
import 'package:careerly/features/studio/data/career_writer.dart';

import '../../core/ai/fake_ai_provider.dart';

const _reply = '''
{"found": true,
 "summary": "Acme builds payroll software for small businesses in Southeast Asia.",
 "facts": ["Industry: Fintech", "Headquarters: Makati", "Size: 200-500"],
 "good_signs": ["Salary is listed", "Established since 2015"],
 "watch_outs": ["Check recent reviews"],
 "questions_to_ask": ["How is the team structured?"]}''';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  const job = JobContext(
    title: 'Frontend Developer',
    company: 'Acme',
    description: 'Build our payroll dashboard in React.',
  );

  test('researches with a web search and remembers the brief', () async {
    final ai = FakeAiProvider('Gemini', reply: _reply);
    final researcher = CompanyResearcher(AiChain([ai]));
    final now = DateTime(2026, 10, 16);

    final research = await researcher.research(job, now: now);

    expect(research.summary, contains('payroll software'));
    expect(research.facts, contains('Industry: Fintech'));
    expect(research.goodSigns, hasLength(2));
    expect(research.foundReliableInfo, isTrue);
    expect(ai.requests.single.webSearch, isTrue);
    expect(ai.requests.single.prompt, contains('Acme'));

    final saved = await researcher.cached('  acme ', now: now);
    expect(saved?.summary, research.summary);
    expect(saved?.provider, 'Gemini');
  });

  test('a brief older than a month is looked up again', () async {
    final researcher =
        CompanyResearcher(AiChain([FakeAiProvider('Gemini', reply: _reply)]));
    await researcher.research(job, now: DateTime(2026, 8, 1));

    expect(await researcher.cached('Acme', now: DateTime(2026, 10, 16)), isNull);
  });

  test('says when the web has little on the company', () async {
    final researcher = CompanyResearcher(
      AiChain([
        FakeAiProvider(
          'Gemini',
          reply: '{"found": false, "summary": "Little is known about Acme."}',
        ),
      ]),
    );

    final research = await researcher.research(job);
    expect(research.foundReliableInfo, isFalse);
  });

  test('an empty reply is an error', () async {
    final researcher =
        CompanyResearcher(AiChain([FakeAiProvider('Gemini', reply: '{}')]));

    expect(researcher.research(job), throwsFormatException);
  });
}
