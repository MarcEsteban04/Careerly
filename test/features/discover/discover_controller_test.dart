import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/features/discover/data/ai_job_ranker.dart';
import 'package:careerly/features/discover/data/ai_job_search_client.dart';
import 'package:careerly/features/discover/data/discover_controller.dart';
import 'package:careerly/features/discover/data/job_listing.dart';
import 'package:careerly/features/discover/data/job_search_query.dart';
import 'package:careerly/features/discover/data/jooble_client.dart';
import 'package:careerly/features/discover/data/jsearch_client.dart';
import 'package:careerly/features/profile/data/career_profile.dart';
import 'package:careerly/features/resume/data/resume_insights.dart';

import '../../core/ai/fake_ai_provider.dart';
import '../shell/shell_test_utils.dart';

class _FailingJSearch extends JSearchClient {
  _FailingJSearch() : super(apiKey: 'test');

  @override
  Future<List<JobListing>> search(JobSearchQuery query) async =>
      throw const JobSearchLimitException();
}

void main() {
  final resumeProfile = CareerProfile(
    resume: ResumeInsights(
      fileName: 'cv.pdf',
      uploadedAt: DateTime(2026, 10, 1),
      roles: const ['Product Designer', 'UI Designer'],
      skills: const ['Figma', 'Prototyping'],
      yearsOfExperience: 4,
    ),
  );

  test('resume roles and skills drive suggestions and matching', () {
    final controller = fakeDiscover(profile: resumeProfile);

    expect(controller.suggestions, ['Product Designer', 'UI Designer']);
    expect(controller.suggestedKeywords, 'Product Designer');
    expect(resumeProfile.effectiveSkills, ['Figma', 'Prototyping']);
    expect(resumeProfile.isEmpty, isFalse);
  });

  test('user-entered roles come before resume suggestions', () {
    final profile = resumeProfile.copyWith(targetRoles: ['UX Researcher']);

    expect(profile.effectiveRoles.first, 'UX Researcher');
    expect(profile.effectiveRoles, contains('Product Designer'));
  });

  test('AI re-ranks results with a reason', () async {
    final ai = FakeAiProvider(
      'Gemini',
      reply: '{"results": ['
          '{"id": "j2", "score": 91, "reason": "Your Figma work fits."},'
          '{"id": "j1", "score": 40, "reason": "Different field."}]}',
    );
    final controller = DiscoverController(
      jsearch: FakeJSearchClient(sampleListings),
      jooble: JoobleClient(apiKey: ''),
      profiles: FakeCareerProfileRepository(resumeProfile),
      aiRanker: AiJobRanker(AiChain([ai])),
    );

    await controller.search('designer');

    final results = controller.results!;
    expect(results.first.listing.id, 'j2');
    expect(results.first.match!.score, 91);
    expect(results.first.match!.aiSummary, 'Your Figma work fits.');
    expect(results.first.match!.aiProvider, 'Gemini');
    expect(controller.isRanking, isFalse);
  });

  test('keyword scores stay when AI ranking fails', () async {
    final controller = DiscoverController(
      jsearch: FakeJSearchClient(sampleListings),
      jooble: JoobleClient(apiKey: ''),
      profiles: FakeCareerProfileRepository(resumeProfile),
      aiRanker: AiJobRanker(AiChain([FakeAiProvider('Gemini', reply: 'oops')])),
    );

    await controller.search('designer');

    expect(controller.results, hasLength(2));
    expect(controller.results!.every((r) => r.match?.aiSummary == null), isTrue);
    expect(controller.error, isNull);
  });

  test('AI web search backs up the job APIs when they run out', () async {
    final ai = FakeAiProvider(
      'Groq',
      reply: '[{"title": "UI Designer", "company": "Bjak", '
          '"location": "Remote", "url": "https://jobs.example.com/1", '
          '"source": "Ashby", "remote": true}]',
    );
    final controller = DiscoverController(
      jsearch: _FailingJSearch(),
      jooble: JoobleClient(apiKey: ''),
      profiles: FakeCareerProfileRepository(),
      aiSearch: AiJobSearchClient(AiChain([ai])),
    );

    await controller.search('ui designer');

    expect(ai.requests.single.webSearch, isTrue);
    expect(controller.results!.single.listing.title, 'UI Designer');
    expect(controller.results!.single.listing.foundByAi, 'Groq');
    expect(controller.notice, contains('Groq searched the web'));
  });

  test('explains when job APIs and AI backups are all out of quota', () async {
    final controller = DiscoverController(
      jsearch: _FailingJSearch(),
      jooble: JoobleClient(apiKey: ''),
      profiles: FakeCareerProfileRepository(),
      aiSearch: AiJobSearchClient(AiChain([])),
    );

    await controller.search('ui designer');

    expect(controller.error, contains("used this month's free job searches"));
  });
}
