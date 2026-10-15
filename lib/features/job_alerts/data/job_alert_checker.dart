import 'package:flutter/foundation.dart';

import '../../discover/data/job_listing.dart';
import '../../discover/data/job_search_query.dart';
import '../../discover/data/jooble_client.dart';
import '../../discover/data/jsearch_client.dart';
import '../../discover/data/search_preferences_repository.dart';
import '../../notifications/data/notification_settings.dart';
import '../../notifications/data/notifications.dart';
import 'job_alert_store.dart';

/// New jobs found for one saved search.
class JobAlert {
  const JobAlert(this.search, this.listings);

  final SavedSearch search;
  final List<JobListing> listings;
}

/// Re-runs saved searches on the job boards and reports jobs not seen
/// before. AI search is skipped to save credit; alerts only use the boards.
class JobAlertChecker {
  JobAlertChecker({
    required this.store,
    required this.settings,
    required this.notifications,
    required this.jsearch,
    required this.jooble,
  });

  final JobAlertStore store;
  final NotificationSettings settings;
  final Notifications notifications;
  final JSearchClient jsearch;
  final JoobleClient jooble;

  /// The job APIs have small monthly quotas, so only the newest few saved
  /// searches are checked.
  static const maxSearches = 3;

  /// How often alerts run.
  static const interval = Duration(hours: 24);

  /// Whether a check is overdue, e.g. because the OS deferred the
  /// background task.
  Future<bool> isDue({DateTime? now}) async {
    final last = await store.lastCheck();
    return last == null ||
        (now ?? DateTime.now()).difference(last) >= interval;
  }

  /// Checks each saved search and, when [notify], posts a notification per
  /// search with new jobs. A search's first check only records what's
  /// there, so alerts start with genuinely new postings.
  Future<List<JobAlert>> run({bool notify = true, DateTime? now}) async {
    if (!await settings.jobAlertsEnabled()) return const [];
    final searches = (await store.searches()).take(maxSearches).toList();
    if (searches.isEmpty) return const [];

    final location = await store.location();
    final dismissed = await store.dismissed();
    final alerts = <JobAlert>[];

    for (final search in searches) {
      final List<JobListing> listings;
      try {
        listings = await _fetch(search, location);
      } catch (e) {
        debugPrint('Job alert for "${search.keywords}" failed: $e');
        continue;
      }

      final current = [
        for (final listing in listings)
          if (!dismissed.contains(listing.dedupeKey)) listing,
      ];
      final seen = await store.seen(search.id);
      await store.markSeen(search.id, current.map((l) => l.dedupeKey));
      if (seen == null) continue;

      final fresh = [
        for (final listing in current)
          if (!seen.contains(listing.dedupeKey)) listing,
      ];
      if (fresh.isEmpty) continue;

      await store.addFresh(search.id, fresh.map((l) => l.dedupeKey));
      final alert = JobAlert(search, fresh);
      alerts.add(alert);
      if (notify) await _notify(alert);
    }

    await store.setLastCheck(now ?? DateTime.now());
    return alerts;
  }

  Future<List<JobListing>> _fetch(SavedSearch search, String? location) async {
    final query = JobSearchQuery(
      keywords: search.keywords,
      scope: search.scope,
      // Alerts are about what's new: look at the last week at most.
      postedWithin: search.postedWithin == PostedWithin.today
          ? PostedWithin.today
          : PostedWithin.week,
      location: location,
    );
    final listings = <JobListing>[
      if (jsearch.isConfigured) ...await jsearch.search(query),
      if (jooble.isConfigured && jooble.supports(query.scope))
        ...await jooble.search(query),
    ];
    final keys = <String>{};
    return [
      for (final listing in listings)
        if (listing.applyUrl.isNotEmpty && keys.add(listing.dedupeKey)) listing,
    ];
  }

  Future<void> _notify(JobAlert alert) async {
    final count = alert.listings.length;
    final keywords = alert.search.keywords;
    final top = alert.listings
        .take(3)
        .map((l) => '${l.title} · ${l.company}')
        .join('\n');
    await notifications.show(
      AppNotification(
        id: stableNotificationId('alert:${alert.search.id}'),
        channel: NotificationChannel.jobAlerts,
        title: count == 1 ? 'New $keywords job' : '$count new $keywords jobs',
        body: count > 3 ? '$top\nand ${count - 3} more' : top,
        payload: OpenSavedSearchRoute(alert.search.id).payload,
      ),
    );
  }
}
