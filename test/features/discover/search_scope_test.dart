import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:careerly/features/discover/data/discover_controller.dart';
import 'package:careerly/features/discover/data/job_search_query.dart';
import 'package:careerly/features/discover/data/jooble_client.dart';
import 'package:careerly/features/discover/data/jsearch_client.dart';
import 'package:careerly/features/discover/data/discover_settings_store.dart';
import 'package:careerly/features/profile/data/career_profile.dart';

import '../shell/shell_test_utils.dart';

void main() {
  const singapore = JobCountry('sg', 'Singapore');

  test('areas round-trip through their stored names', () {
    for (final scope in [
      ...SearchScope.presets,
      SearchScope.abroad(singapore),
    ]) {
      expect(SearchScope.parse(scope.name), scope);
    }
    expect(SearchScope.parse('country:sg').label, 'Singapore');
    expect(SearchScope.parse('country:zz'), SearchScope.philippines);
    expect(SearchScope.parse(null), SearchScope.philippines);
    expect(singapore.flag, '🇸🇬');
  });

  test('JSearch searches the chosen country', () async {
    Uri? requested;
    final client = JSearchClient(
      apiKey: 'test',
      httpClient: MockClient((request) async {
        requested = request.url;
        return http.Response('{"data": []}', 200);
      }),
    );

    await client.search(
      JobSearchQuery(
        keywords: 'Nurse',
        scope: SearchScope.abroad(singapore),
      ),
    );
    expect(requested!.queryParameters['query'], 'Nurse in Singapore');
    expect(requested!.queryParameters['country'], 'sg');
    expect(requested!.queryParameters.containsKey('work_from_home'), isFalse);

    await client.search(
      const JobSearchQuery(keywords: 'Nurse', scope: SearchScope.anywhere),
    );
    expect(requested!.queryParameters.containsKey('country'), isFalse);

    await client.search(
      const JobSearchQuery(keywords: 'Nurse', scope: SearchScope.remote),
    );
    expect(requested!.queryParameters['country'], 'ph');
    expect(requested!.queryParameters['work_from_home'], 'true');
  });

  group('the chosen area', () {
    setUp(useInMemoryPrefs);

    DiscoverController controller({
      CareerProfile profile = const CareerProfile(),
      DiscoverSettingsStore? store,
    }) =>
        DiscoverController(
          jsearch: FakeJSearchClient(),
          jooble: JoobleClient(apiKey: ''),
          profiles: FakeCareerProfileRepository(profile),
          settings: store,
        );

    test('starts on remote for a remote-minded profile', () {
      expect(
        controller(
          profile: const CareerProfile(workSetup: WorkSetup.remote),
        ).scope,
        SearchScope.remote,
      );
      expect(controller().scope, SearchScope.philippines);
    });

    test('is remembered for next time', () async {
      final store = DiscoverSettingsStore();
      controller(store: store).setScope(SearchScope.abroad(singapore));
      await pumpEventQueue();

      final next = controller(store: store);
      await pumpEventQueue();

      expect(next.scope, SearchScope.abroad(singapore));
    });
  });
}
