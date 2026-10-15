import 'package:flutter/foundation.dart';

import '../../../core/ai/ai_chain.dart';
import '../../../core/utils/error_message.dart';
import '../../profile/data/career_profile.dart';
import '../../profile/data/career_profile_repository.dart';
import '../../resume/data/resume_reader.dart';
import 'ai_job_ranker.dart';
import 'ai_job_search_client.dart';
import 'job_listing.dart';
import 'job_matcher.dart';
import 'job_search_query.dart';
import 'jooble_client.dart';
import 'jsearch_client.dart';
import 'search_preferences_repository.dart';

/// A listing with its match against the career profile (if any).
class RankedListing {
  const RankedListing(this.listing, this.match);

  final JobListing listing;
  final JobMatch? match;
}

/// Runs job searches and ranks results for the user.
///
/// Sources, in order: JSearch and Jooble; if they fail or find nothing,
/// AI web search. Ranking: instant keyword scores, then an AI re-rank
/// against the profile and resume when an AI provider is available.
/// Results are cached per query because the job APIs have small quotas.
class DiscoverController extends ChangeNotifier {
  DiscoverController({
    required this.jsearch,
    required this.jooble,
    required this.profiles,
    this.aiSearch,
    this.aiRanker,
    this.resumeReader,
    this.preferences,
  }) : _profile = profiles.read() {
    _loadPreferences();
  }

  final JSearchClient jsearch;
  final JoobleClient jooble;
  final CareerProfileRepository profiles;
  final AiJobSearchClient? aiSearch;
  final AiJobRanker? aiRanker;
  final ResumeReader? resumeReader;

  /// Saved searches and "Not interested" jobs; optional so search works
  /// without them.
  final SearchPreferencesRepository? preferences;

  List<SavedSearch> _savedSearches = const [];
  Set<String> _dismissed = const {};

  final _cache = <String, List<JobListing>>{};

  /// AI verdicts keyed by `profileFingerprint|listingId`.
  final _verdicts = <String, (AiVerdict, String)>{};

  CareerProfile _profile;
  SearchScope _scope = SearchScope.philippines;
  PostedWithin _postedWithin = PostedWithin.month;
  String _keywords = '';
  List<JobListing>? _listings;
  List<RankedListing>? _results;
  bool _isLoading = false;
  bool _isRanking = false;
  String? _error;
  String? _notice;
  int _generation = 0;

  CareerProfile get profile => _profile;
  SearchScope get scope => _scope;
  PostedWithin get postedWithin => _postedWithin;
  String get keywords => _keywords;

  /// Null until the first search.
  List<RankedListing>? get results => _results;
  bool get isLoading => _isLoading;

  /// AI is re-ranking the current results.
  bool get isRanking => _isRanking;
  String? get error => _error;

  /// Informational message about the current results, e.g. AI fallback.
  String? get notice => _notice;

  List<SavedSearch> get savedSearches => _savedSearches;

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
    final listings = _listings;
    if (listings != null) {
      _results = _rankByKeywords(listings);
      notifyListeners();
      await _rankWithAi(listings, _generation);
    } else {
      notifyListeners();
    }
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
    _isRanking = false;
    _error = null;
    _notice = null;
    notifyListeners();

    final query = JobSearchQuery(
      keywords: text,
      scope: _scope,
      postedWithin: _postedWithin,
      location: _profile.effectiveLocation,
    );

    try {
      final listings = _cache[query.cacheKey] ?? await _fetch(query);
      if (generation != _generation) return;
      _cache[query.cacheKey] = listings;
      _listings = listings;
      _results = _rankByKeywords(listings);
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

    final listings = _listings;
    if (generation == _generation && listings != null && _error == null) {
      await _rankWithAi(listings, generation);
    }
  }

  /// Clears the cached results for the current query and searches again.
  Future<void> refresh() {
    final prefix = '${_keywords.toLowerCase().trim()}|';
    _cache.removeWhere((key, _) => key.startsWith(prefix));
    return search(_keywords);
  }

  Future<List<JobListing>> _fetch(JobSearchQuery query) async {
    final listings = <JobListing>[];
    var apisOutOfQuota = false;

    try {
      if (jsearch.isConfigured) listings.addAll(await jsearch.search(query));
    } on JobSearchLimitException {
      apisOutOfQuota = true;
    } catch (e) {
      debugPrint('JSearch failed: $e');
    }
    if (jooble.isConfigured && jooble.supports(query.scope)) {
      try {
        listings.addAll(await jooble.search(query));
      } catch (e) {
        debugPrint('Jooble failed: $e');
      }
    }

    // AI web search backs up the job APIs.
    final ai = aiSearch;
    if (listings.isEmpty && ai != null && ai.isConfigured) {
      try {
        listings.addAll(await ai.search(query));
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
    } else if (listings.isEmpty && apisOutOfQuota) {
      throw const _NoSourcesException(
        "You've used this month's free job searches. Try again next month.",
      );
    }

    final seen = <String>{};
    return [
      for (final listing in listings)
        if (listing.applyUrl.isNotEmpty && seen.add(listing.dedupeKey)) listing,
    ];
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
      final listings = _listings;
      if (listings != null) _results = _rankByKeywords(listings);
      notifyListeners();
    } catch (e) {
      // Tables missing (migration not run yet) or offline: search still works.
      debugPrint('Search preferences unavailable: $e');
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
      }
      notifyListeners();
      return null;
    } catch (e) {
      return _preferenceError(e);
    }
  }

  Future<void> runSavedSearch(SavedSearch search) {
    _scope = search.scope;
    _postedWithin = search.postedWithin;
    return this.search(search.keywords);
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
      notifyListeners();
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
    final listings = _listings;
    if (listings != null) _results = _rankByKeywords(listings);
    notifyListeners();
  }

  static String _preferenceError(Object e) => isMissingSchemaError(e)
      ? 'Run the latest database migration to use this.'
      : friendlyErrorMessage(e);

  List<RankedListing> _rankByKeywords(List<JobListing> listings) {
    final fingerprint = _profile.fingerprint;
    final ranked = [
      for (final listing in listings)
        if (!_dismissed.contains(listing.dedupeKey))
        RankedListing(
          listing,
          _withAi(JobMatcher.match(listing, _profile),
              _verdicts['$fingerprint|${listing.id}']),
        ),
    ];
    _sort(ranked);
    return ranked;
  }

  Future<void> _rankWithAi(List<JobListing> listings, int generation) async {
    final ranker = aiRanker;
    if (ranker == null || !ranker.isConfigured || _profile.isEmpty) return;

    final fingerprint = _profile.fingerprint;
    final pending = listings
        .where((l) => !_verdicts.containsKey('$fingerprint|${l.id}'))
        .toList();
    if (pending.isEmpty) return;

    _isRanking = true;
    notifyListeners();
    try {
      final (verdicts, provider) = await ranker.rank(pending, _profile);
      verdicts.forEach((id, verdict) {
        _verdicts['$fingerprint|$id'] = (verdict, provider);
      });
    } catch (e) {
      // Keyword scores stay in place.
      debugPrint('AI ranking failed: $e');
    } finally {
      if (generation == _generation) {
        _isRanking = false;
        _results = _rankByKeywords(listings);
        notifyListeners();
      }
    }
  }

  static JobMatch? _withAi(JobMatch? keyword, (AiVerdict, String)? ai) {
    if (ai == null) return keyword;
    final (verdict, provider) = ai;
    return JobMatch(
      score: verdict.score,
      reasons: keyword?.reasons ?? const [],
      aiSummary: verdict.reason,
      aiProvider: provider,
    );
  }

  void _sort(List<RankedListing> ranked) {
    if (_profile.isEmpty) return;
    ranked.sort(
      (a, b) => (b.match?.score ?? 0).compareTo(a.match?.score ?? 0),
    );
  }
}

class _NoSourcesException implements Exception {
  const _NoSourcesException(this.message);

  final String message;
}
