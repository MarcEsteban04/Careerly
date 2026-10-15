import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/core/ai/ai_chain.dart';
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

/// Serves [pages] by page number; empty past the last one.
class _PagedJSearch extends JSearchClient {
  _PagedJSearch(this.pages) : super(apiKey: 'test');

  final Map<int, List<JobListing>> pages;
  bool failing = false;

  @override
  Future<List<JobListing>> search(JobSearchQuery query) async {
    if (failing) throw const JobSearchException('JSearch returned 500');
    return pages[query.page] ?? const [];
  }
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

  group('pagination', () {
    JobListing job(int n) => JobListing(
          id: 'p$n',
          title: 'Designer $n',
          company: 'Company $n',
          source: 'LinkedIn',
          applyUrl: 'https://example.com/$n',
          description: '',
        );

    DiscoverController withPages(Map<int, List<JobListing>> pages) =>
        DiscoverController(
          jsearch: _PagedJSearch(pages),
          jooble: JoobleClient(apiKey: ''),
          profiles: FakeCareerProfileRepository(resumeProfile),
        );

    test('a full page offers more; the next page appends below', () async {
      final controller = withPages({
        1: [for (var i = 1; i <= 10; i++) job(i)],
        2: [job(10), job(11), job(12)],
      });

      await controller.search('designer');
      expect(controller.results, hasLength(10));
      expect(controller.canLoadMore, isTrue);
      final firstPage = controller.results!.map((r) => r.listing.id).toList();

      await controller.loadMore();

      final ids = controller.results!.map((r) => r.listing.id).toList();
      // The duplicate from page 2 is dropped; earlier jobs keep their place.
      expect(ids, hasLength(12));
      expect(ids.take(10), firstPage);
      expect(ids.skip(10), unorderedEquals(['p11', 'p12']));
      // A short page means the boards have nothing more.
      expect(controller.canLoadMore, isFalse);
      expect(controller.isLoadingMore, isFalse);
    });

    test('a short first page has no more', () async {
      final controller = withPages({1: [job(1), job(2)]});

      await controller.search('designer');

      expect(controller.canLoadMore, isFalse);
    });

    test('a failed page can be retried', () async {
      final jsearch = _PagedJSearch({
        1: [for (var i = 1; i <= 10; i++) job(i)],
      });
      final controller = DiscoverController(
        jsearch: jsearch,
        jooble: JoobleClient(apiKey: ''),
        profiles: FakeCareerProfileRepository(resumeProfile),
      );
      await controller.search('designer');
      jsearch.failing = true;

      await controller.loadMore();

      expect(controller.loadMoreError, isNotNull);
      expect(controller.canLoadMore, isTrue);
      expect(controller.results, hasLength(10));
    });
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
