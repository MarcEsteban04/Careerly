import 'package:flutter/foundation.dart';

import '../../../core/ai/ai_chain.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/salary.dart';
import '../../job_alerts/data/job_alert_store.dart';
import '../../profile/data/career_profile.dart';
import '../../profile/data/career_profile_repository.dart';
import '../../resume/data/resume_reader.dart';
import 'ai_job_search_client.dart';
import 'job_listing.dart';
import 'job_matcher.dart';
import 'job_search_query.dart';
import 'jooble_client.dart';
import 'jsearch_client.dart';
import 'search_preferences_repository.dart';
import 'discover_settings_store.dart';
import 'scam_check.dart';

/// A listing with its match against the career profile (if any) and any
/// scam warning signs.
class RankedListing {
  const RankedListing(this.listing, this.match, {this.scam = ScamCheck.clear});

  final JobListing listing;
  final JobMatch? match;
  final ScamCheck scam;
}

/// Salary steps offered by the salary filter, in pesos a month.
const salaryFilterSteps = [20000, 30000, 50000, 80000, 100000];

/// The pages of one search loaded so far.
class _SearchPages {
  const _SearchPages(this.pages, {required this.hasMore});

  final List<List<JobListing>> pages;

  /// Whether the job boards may have another page.
  final bool hasMore;

  Iterable<JobListing> get listings => pages.expand((p) => p);
}

/// Runs job searches and ranks results against the career profile.
///
/// Sources, in order: JSearch and Jooble; if they fail or find nothing,
/// AI web search. Results come a page at a time ([loadMore]), and are
/// cached per query because the job APIs have small quotas.
class DiscoverController extends ChangeNotifier {
  DiscoverController({
    required this.jsearch,
    required this.jooble,
    required this.profiles,
    this.aiSearch,
    this.resumeReader,
    this.preferences,
    this.alerts,
    this.settings,
  }) : _profile = profiles.read() {
    // Remote-minded profiles start on remote jobs.
    if (_profile.workSetup == WorkSetup.remote) _scope = SearchScope.remote;
    _loadPreferences();
    _loadSettings();
  }

  /// Remembers the search area and salary filter; optional.
  final DiscoverSettingsStore? settings;

  Future<void> _loadSettings() async {
    final store = settings;
    if (store == null) return;
    try {
      final (scope, (minSalary, shownOnly)) =
          await (store.readScope(), store.readSalary()).wait;
      // A search already running keeps its area.
      if (scope != null && _query == null) _scope = scope;
      _minSalary = minSalary;
      _salaryShownOnly = shownOnly;
      _refreshResults();
    } catch (e) {
      debugPrint('Saved search settings unavailable: $e');
    }
  }

  final JSearchClient jsearch;
  final JoobleClient jooble;
  final CareerProfileRepository profiles;
  final AiJobSearchClient? aiSearch;
  final ResumeReader? resumeReader;

  /// Saved searches and "Not interested" jobs; optional so search works
  /// without them.
  final SearchPreferencesRepository? preferences;

  /// Device copy of saved searches for background job alerts; optional.
  final JobAlertStore? alerts;

  List<SavedSearch> _savedSearches = const [];
  Set<String> _dismissed = const {};
  Map<String, int> _freshCounts = const {};

  final _cache = <String, _SearchPages>{};

  CareerProfile _profile;
  SearchScope _scope = SearchScope.philippines;
  PostedWithin _postedWithin = PostedWithin.month;
  String _keywords = '';
  JobSearchQuery? _query;
  _SearchPages? _pages;
  List<RankedListing>? _results;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _loadMoreError;
  String? _notice;
  int _generation = 0;
  int? _minSalary;
  bool _salaryShownOnly = false;
  int _hiddenBySalary = 0;

  /// Minimum monthly pay in pesos; null for any.
  int? get minSalary => _minSalary;

  /// Hide jobs that don't show their pay.
  bool get salaryShownOnly => _salaryShownOnly;

  bool get hasSalaryFilter => _minSalary != null || _salaryShownOnly;

  /// Loaded jobs the salary filter is hiding.
  int get hiddenBySalary => _hiddenBySalary;

  /// Filters results by pay; instant, with no new search.
  void setSalaryFilter({required int? minimum, required bool shownOnly}) {
    _minSalary = minimum;
    _salaryShownOnly = shownOnly;
    _refreshResults();
    _bestEffort(
      () => settings?.saveSalary(minimum: minimum, shownOnly: shownOnly),
    );
  }

  CareerProfile get profile => _profile;
  SearchScope get scope => _scope;
  PostedWithin get postedWithin => _postedWithin;
  String get keywords => _keywords;

  /// Null until the first search.
  List<RankedListing>? get results => _results;
  bool get isLoading => _isLoading;

  /// The next page is loading.
  bool get isLoadingMore => _isLoadingMore;

  /// Whether another page of results can be loaded.
  bool get canLoadMore =>
      !_isLoading && _error == null && (_pages?.hasMore ?? false);

  /// Set when loading the next page failed.
  String? get loadMoreError => _loadMoreError;
  String? get error => _error;

  /// Informational message about the current results, e.g. AI fallback.
  String? get notice => _notice;

  List<SavedSearch> get savedSearches => _savedSearches;

  /// New jobs a job alert found for [search] that haven't been viewed.
  int freshCount(SavedSearch search) => _freshCounts[search.id] ?? 0;

  int get totalFresh => _freshCounts.values.fold(0, (sum, n) => sum + n);

  /// Whether the current search is bookmarked.
  bool get isCurrentSearchSaved => _savedSearches
      .any((s) => s.matches(_keywords, _scope, _postedWithin));

  bool get canReadResumes => resumeReader?.ai.isConfigured ?? false;

  /// Searches tailored to the profile and resume: roles first.
  List<String> get suggestions => _profile.effectiveRoles.take(4).toList();

  /// What to search when the box is empty: the best-fit role.
  String get suggestedKeywords => suggestions.isEmpty ? '' : suggestions.first;

  Future<void> saveProfile(CareerProfile profile) async {
    _profile = await profiles.save(profile);
    _bestEffort(() => alerts?.setLocation(_profile.effectiveLocation));
    _refreshResults();
  }

  /// Reads a resume PDF with AI. Throws if no provider can read it.
  Future<ResumeRead> readResume(Uint8List bytes, String fileName) {
    final reader = resumeReader;
    if (reader == null) {
      throw const AiUnavailableException([]);
    }
    return reader.read(bytes, fileName: fileName);
  }

  void setScope(SearchScope scope) {
    if (scope == _scope) return;
    _scope = scope;
    notifyListeners();
    _bestEffort(() => settings?.saveScope(scope));
    if (_results != null) search(_keywords);
  }

  void setPostedWithin(PostedWithin value) {
    if (value == _postedWithin) return;
    _postedWithin = value;
    notifyListeners();
    if (_results != null) search(_keywords);
  }

  Future<void> search(String keywords) async {
    final text = keywords.trim().isEmpty ? suggestedKeywords : keywords.trim();
    if (text.isEmpty) {
      _error = 'Type a role to search, or upload your resume so Careerly can '
          'suggest roles.';
      notifyListeners();
      return;
    }

    final generation = ++_generation;
    _keywords = text;
    _isLoading = true;
    _isLoadingMore = false;
    _error = null;
    _loadMoreError = null;
    _notice = null;
    notifyListeners();

    final query = JobSearchQuery(
      keywords: text,
      scope: _scope,
      postedWithin: _postedWithin,
      location: _profile.effectiveLocation,
    );

    try {
      final pages = _cache[query.cacheKey] ?? await _fetchFirst(query);
      if (generation != _generation) return;
      _cache[query.cacheKey] = pages;
      _query = query;
      _pages = pages;
      _results = _rank(pages);
      final listings = pages.listings;
      final aiProvider = listings.isEmpty ? null : listings.first.foundByAi;
      if (aiProvider != null) {
        _notice = 'The job boards were unavailable, so $aiProvider searched '
            'the web instead. Double-check each post before applying.';
      }
    } on _NoSourcesException catch (e) {
      if (generation != _generation) return;
      _error = e.message;
    } catch (_) {
      if (generation != _generation) return;
      _error = "Couldn't reach the job boards or AI search. Check your "
          'connection and try again.';
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Appends the next page of results. New jobs go below the ones already
  /// shown (each page is sorted by match on its own), so nothing jumps.
  Future<void> loadMore() async {
    final query = _query;
    final current = _pages;
    if (!canLoadMore || _isLoadingMore || query == null || current == null) {
      return;
    }

    final generation = _generation;
    _isLoadingMore = true;
    _loadMoreError = null;
    notifyListeners();

    try {
      final (found, hasMore) =
          await _fetchPage(query.copyWith(page: current.pages.length + 1));
      if (generation != _generation) return;
      final seen = {for (final l in current.listings) l.dedupeKey};
      final added = [
        for (final listing in found)
          if (seen.add(listing.dedupeKey)) listing,
      ];
      final pages = _SearchPages(
        [...current.pages, if (added.isNotEmpty) added],
        hasMore: hasMore && added.isNotEmpty,
      );
      _cache[query.cacheKey] = pages;
      _pages = pages;
      _results = _rank(pages);
    } catch (e) {
      debugPrint('Loading more jobs failed: $e');
      if (generation != _generation) return;
      _loadMoreError = e is JobSearchLimitException
          ? "You've used this month's free job searches."
          : "Couldn't load more jobs. Check your connection and try again.";
    } finally {
      if (generation == _generation) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Clears the cached results for the current query and searches again.
  Future<void> refresh() {
    final prefix = '${_keywords.toLowerCase().trim()}|';
    _cache.removeWhere((key, _) => key.startsWith(prefix));
    return search(_keywords);
  }

  /// One page from the job boards, and whether there may be another.
  /// Throws if every board failed.
  Future<(List<JobListing>, bool)> _fetchPage(JobSearchQuery query) async {
    final listings = <JobListing>[];
    var hasMore = false;
    Object? failure;

    if (jsearch.isConfigured) {
      try {
        final found = await jsearch.search(query);
        listings.addAll(found);
        hasMore |= found.length >= JSearchClient.pageSize;
      } catch (e) {
        debugPrint('JSearch failed: $e');
        failure = e;
      }
    }
    if (jooble.isConfigured && jooble.supports(query.scope)) {
      try {
        final found = await jooble.search(query);
        listings.addAll(found);
        hasMore |= found.isNotEmpty;
        failure = null;
      } catch (e) {
        debugPrint('Jooble failed: $e');
        failure ??= e;
      }
    }
    if (listings.isEmpty && failure != null) throw failure;

    final seen = <String>{};
    return (
      [
        for (final listing in listings)
          if (listing.applyUrl.isNotEmpty && seen.add(listing.dedupeKey))
            listing,
      ],
      hasMore,
    );
  }

  /// The first page, with AI web search as a backup when the boards fail
  /// or find nothing.
  Future<_SearchPages> _fetchFirst(JobSearchQuery query) async {
    var listings = const <JobListing>[];
    var hasMore = false;
    var apisOutOfQuota = false;

    try {
      (listings, hasMore) = await _fetchPage(query);
    } on JobSearchLimitException {
      apisOutOfQuota = true;
    } catch (_) {
      // Logged in _fetchPage; AI search below may still find jobs.
    }
    if (listings.isNotEmpty) {
      return _SearchPages([listings], hasMore: hasMore);
    }

    final ai = aiSearch;
    final found = <JobListing>[];
    if (ai != null && ai.isConfigured) {
      try {
        found.addAll(await ai.search(query));
      } on AiUnavailableException catch (e) {
        debugPrint('AI job search failed: $e');
        if (e.allOutOfQuota || apisOutOfQuota) {
          throw const _NoSourcesException(
            "You've used up this month's job searches and the AI backups are "
            'out of credit too. Try again later.',
          );
        }
      } catch (e) {
        debugPrint('AI job search failed: $e');
      }
    } else if (apisOutOfQuota) {
      throw const _NoSourcesException(
        "You've used this month's free job searches. Try again next month.",
      );
    }

    final seen = <String>{};
    return _SearchPages(
      [
        [
          for (final listing in found)
            if (listing.applyUrl.isNotEmpty && seen.add(listing.dedupeKey))
              listing,
        ],
      ],
      // AI search finds one batch; there's no next page.
      hasMore: false,
    );
  }

  // Saved searches and "Not interested" ------------------------------------

  Future<void> _loadPreferences() async {
    final prefs = preferences;
    if (prefs == null) return;
    try {
      final (saved, dismissed) =
          await (prefs.fetchSavedSearches(), prefs.fetchDismissedKeys()).wait;
      _savedSearches = saved;
      _dismissed = dismissed;
      _refreshResults();
      await _bestEffort(() async {
        await alerts?.setSearches(saved);
        await alerts?.setDismissed(dismissed);
        await alerts?.setLocation(_profile.effectiveLocation);
      });
      await refreshAlerts();
    } catch (e) {
      // Tables missing (migration not run yet) or offline: search still works.
      debugPrint('Search preferences unavailable: $e');
    }
  }

  /// Reloads new-job counts, e.g. after the background check ran.
  Future<void> refreshAlerts() async {
    final store = alerts;
    if (store == null) return;
    try {
      _freshCounts = await store.freshCounts();
      notifyListeners();
    } catch (e) {
      debugPrint('Job alert counts unavailable: $e');
    }
  }

  /// Device storage (alerts, the chosen area) is best-effort; it never
  /// blocks searching.
  Future<void> _bestEffort(Future<void>? Function() write) async {
    try {
      await write();
    } catch (e) {
      debugPrint('Saving on this device failed: $e');
    }
  }

  /// Bookmarks the current search, or removes the bookmark. Returns an
  /// error message on failure.
  Future<String?> toggleSaveCurrentSearch() async {
    final prefs = preferences;
    if (prefs == null || _keywords.isEmpty) return null;
    try {
      final existing = _savedSearches
          .where((s) => s.matches(_keywords, _scope, _postedWithin))
          .firstOrNull;
      if (existing != null) {
        await prefs.deleteSearch(existing.id);
        _savedSearches = [
          for (final s in _savedSearches)
            if (s.id != existing.id) s,
        ];
      } else {
        final saved = await prefs.saveSearch(
          keywords: _keywords,
          scope: _scope,
          postedWithin: _postedWithin,
        );
        _savedSearches = [saved, ..._savedSearches];
        // What's on screen now isn't news: alert only on later postings.
        final shown = _pages?.listings ?? const <JobListing>[];
        await _bestEffort(
          () => alerts?.markSeen(saved.id, shown.map((l) => l.dedupeKey)),
        );
      }
      notifyListeners();
      await _bestEffort(() => alerts?.setSearches(_savedSearches));
      return null;
    } catch (e) {
      return _preferenceError(e);
    }
  }

  Future<void> runSavedSearch(SavedSearch search) async {
    _scope = search.scope;
    _postedWithin = search.postedWithin;
    if (_freshCounts.containsKey(search.id)) {
      _freshCounts = {..._freshCounts}..remove(search.id);
      notifyListeners();
    }
    await _bestEffort(() => alerts?.clearFresh(search.id));
    await this.search(search.keywords);
    final shown = _pages?.listings ?? const <JobListing>[];
    await _bestEffort(
      () => alerts?.markSeen(search.id, shown.map((l) => l.dedupeKey)),
    );
  }

  Future<String?> deleteSavedSearch(SavedSearch search) async {
    final prefs = preferences;
    if (prefs == null) return null;
    try {
      await prefs.deleteSearch(search.id);
      _savedSearches = [
        for (final s in _savedSearches)
          if (s.id != search.id) s,
      ];
      _freshCounts = {..._freshCounts}..remove(search.id);
      notifyListeners();
      await _bestEffort(() => alerts?.setSearches(_savedSearches));
      return null;
    } catch (e) {
      return _preferenceError(e);
    }
  }

  /// Hides a job from this and future searches. Returns an error message
  /// on failure.
  Future<String?> dismiss(JobListing job) async {
    final before = _dismissed;
    _dismissed = {..._dismissed, job.dedupeKey};
    _refreshResults();
    try {
      await preferences?.dismiss(job);
      await _bestEffort(() => alerts?.setDismissed(_dismissed));
      return null;
    } catch (e) {
      _dismissed = before;
      _refreshResults();
      return _preferenceError(e);
    }
  }

  Future<void> undoDismiss(JobListing job) async {
    _dismissed = {..._dismissed}..remove(job.dedupeKey);
    _refreshResults();
    try {
      await preferences?.undismiss(job);
    } catch (e) {
      debugPrint('Undo dismiss failed: $e');
    }
  }

  void _refreshResults() {
    final pages = _pages;
    if (pages != null) _results = _rank(pages);
    notifyListeners();
  }

  static String _preferenceError(Object e) => isMissingSchemaError(e)
      ? 'Run the latest database migration to use this.'
      : friendlyErrorMessage(e);

  /// Scores every job against the profile, best match first within each
  /// page, leaving out jobs marked "Not interested" or outside the salary
  /// filter.
  List<RankedListing> _rank(_SearchPages pages) {
    _hiddenBySalary = 0;
    return [for (final page in pages.pages) ..._rankPage(page)];
  }

  /// Whether [listing] passes the salary filter. Jobs that don't show pay
  /// pass unless [salaryShownOnly] is on.
  bool _passesSalary(JobListing listing) {
    if (_minSalary == null && !_salaryShownOnly) return true;
    final pay = monthlyPesos(listing.salary);
    if (pay == null) return !_salaryShownOnly;
    return _minSalary == null || pay >= _minSalary!;
  }

  List<RankedListing> _rankPage(List<JobListing> listings) {
    final ranked = <RankedListing>[];
    for (final listing in listings) {
      if (_dismissed.contains(listing.dedupeKey)) continue;
      if (!_passesSalary(listing)) {
        _hiddenBySalary++;
        continue;
      }
      ranked.add(
        RankedListing(
          listing,
          JobMatcher.match(listing, _profile),
          scam: ScamCheck.of(listing),
        ),
      );
    }
    if (!_profile.isEmpty) {
      ranked.sort(
        (a, b) => (b.match?.score ?? 0).compareTo(a.match?.score ?? 0),
      );
    }
    return ranked;
  }
}

class _NoSourcesException implements Exception {
  const _NoSourcesException(this.message);

  final String message;
}
