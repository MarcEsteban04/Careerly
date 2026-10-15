import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/features/discover/data/job_listing.dart';
import 'package:careerly/features/discover/data/job_search_query.dart';
import 'package:careerly/features/discover/data/jooble_client.dart';
import 'package:careerly/features/discover/data/search_preferences_repository.dart';
import 'package:careerly/features/job_alerts/data/job_alert_checker.dart';
import 'package:careerly/features/job_alerts/data/job_alert_store.dart';
import 'package:careerly/features/notifications/data/notification_settings.dart';
import 'package:careerly/features/notifications/data/notifications.dart';

import '../shell/shell_test_utils.dart';

void main() {
  const search = SavedSearch(
    id: 's1',
    keywords: 'UI Designer',
    scope: SearchScope.philippines,
    postedWithin: PostedWithin.month,
  );

  JobListing job(String id, String title) => JobListing(
        id: id,
        title: title,
        company: 'Acme',
        source: 'LinkedIn',
        applyUrl: 'https://example.com/$id',
        description: '',
      );

  late FakeJSearchClient jsearch;
  late FakeNotifications notifications;
  late JobAlertStore store;
  late NotificationSettings settings;
  late JobAlertChecker checker;

  setUp(() async {
    useInMemoryPrefs();
    jsearch = FakeJSearchClient([job('j1', 'UI Designer')]);
    notifications = FakeNotifications();
    store = JobAlertStore();
    settings = NotificationSettings();
    checker = JobAlertChecker(
      store: store,
      settings: settings,
      notifications: notifications,
      jsearch: jsearch,
      jooble: JoobleClient(apiKey: ''),
    );
    await store.setSearches([search]);
  });

  test('the first check only records what is there', () async {
    final alerts = await checker.run();

    expect(alerts, isEmpty);
    expect(notifications.shown, isEmpty);
    expect(await store.seen('s1'), {'ui designer|acme'});
    expect(await checker.isDue(), isFalse);
  });

  test('later checks alert on new jobs and count them as new', () async {
    await checker.run();
    jsearch.listings = [
      job('j1', 'UI Designer'),
      job('j2', 'Product Designer'),
    ];

    final alerts = await checker.run();

    expect(alerts.single.listings.single.title, 'Product Designer');
    final shown = notifications.shown.single;
    expect(shown.title, 'New UI Designer job');
    expect(shown.body, 'Product Designer · Acme');
    expect(shown.channel, NotificationChannel.jobAlerts);
    expect(NotificationRoute.parse(shown.payload), isA<OpenSavedSearchRoute>());
    expect(await store.freshCounts(), {'s1': 1});
    expect(jsearch.queries.last.postedWithin, PostedWithin.week);
  });

  test('skips jobs marked not interested', () async {
    await checker.run();
    jsearch.listings = [job('j2', 'Product Designer')];
    await store.setDismissed({'product designer|acme'});

    expect(await checker.run(), isEmpty);
    expect(notifications.shown, isEmpty);
  });

  test('does nothing when job alerts are off', () async {
    await settings.setJobAlertsEnabled(false);

    expect(await checker.run(), isEmpty);
    expect(jsearch.queries, isEmpty);
  });

  test('removing a saved search forgets its state', () async {
    await checker.run();
    await store.setSearches(const []);

    expect(await store.seen('s1'), isNull);
  });
}
