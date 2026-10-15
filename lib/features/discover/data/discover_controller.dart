import 'package:flutter/foundation.dart';

import '../../profile/data/career_profile.dart';
import '../../profile/data/career_profile_repository.dart';
import 'job_listing.dart';
import 'job_matcher.dart';
import 'job_search_query.dart';
import 'jooble_client.dart';
import 'jsearch_client.dart';

/// A listing with its match against the career profile (if any).
class RankedListing {
  const RankedListing(this.listing, this.match);

  final JobListing listing;
  final JobMatch? match;
}

/// Runs job searches across sources, ranks results by fit, and keeps the
/// last results while the user moves between tabs. Results are cached per
/// query because the job APIs have small monthly quotas.
class DiscoverController extends ChangeNotifier {
  DiscoverController({
    required this.jsearch,
    required this.jooble,
    required this.profiles,
  }) : _profile = profiles.read();

  final JSearchClient jsearch;
  final JoobleClient jooble;
  final CareerProfileRepository profiles;

  final _cache = <String, List<JobListing>>{};

  CareerProfile _profile;
  SearchScope _scope = SearchScope.philippines;
  PostedWithin _postedWithin = PostedWithin.month;
  String _keywords = '';
  List<RankedListing>? _results;
  bool _isLoading = false;
  String? _error;

  CareerProfile get profile => _profile;
  SearchScope get scope => _scope;
  PostedWithin get postedWithin => _postedWithin;
  String get keywords => _keywords;

  /// Null until the first search.
  List<RankedListing>? get results => _results;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// What to search when the box is empty: the first target role.
  String get suggestedKeywords =>
      _profile.targetRoles.isNotEmpty ? _profile.targetRoles.first : '';

  Future<void> saveProfile(CareerProfile profile) async {
    _profile = await profiles.save(profile);
    _rerank();
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
      _error = 'Type a role to search, or add target roles to your profile.';
      notifyListeners();
      return;
    }

    _keywords = text;
    _isLoading = true;
    _error = null;
    notifyListeners();

    final query = JobSearchQuery(
      keywords: text,
      scope: _scope,
      postedWithin: _postedWithin,
      location: _profile.location,
    );

    try {
      final listings = _cache[query.cacheKey] ?? await _fetch(query);
      _cache[query.cacheKey] = listings;
      _results = _rank(listings);
    } on JobSearchLimitException {
      _error = "You've used this month's free job searches. "
          'Try again next month or upgrade the JSearch plan.';
    } catch (_) {
      _error = "Couldn't reach the job boards. Check your connection and "
          'try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears the cached results for the current query and searches again.
  Future<void> refresh() {
    _cache.removeWhere((key, _) => key.startsWith('${_keywords.toLowerCase()}|'));
    return search(_keywords);
  }

  Future<List<JobListing>> _fetch(JobSearchQuery query) async {
    final requests = <Future<List<JobListing>>>[
      if (jsearch.isConfigured) jsearch.search(query),
      if (jooble.isConfigured && jooble.supports(query.scope))
        // Jooble is a bonus source; never fail the whole search because of it.
        jooble.search(query).catchError((_) => <JobListing>[]),
    ];
    if (requests.isEmpty) {
      throw const JobSearchException('No job search API keys configured');
    }

    final batches = await Future.wait(requests);
    final seen = <String>{};
    return [
      for (final listing in batches.expand((b) => b))
        if (listing.applyUrl.isNotEmpty && seen.add(listing.dedupeKey)) listing,
    ];
  }

  void _rerank() {
    final results = _results;
    if (results != null) {
      _results = _rank(results.map((r) => r.listing).toList());
    }
    notifyListeners();
  }

  List<RankedListing> _rank(List<JobListing> listings) {
    final ranked = [
      for (final listing in listings)
        RankedListing(listing, JobMatcher.match(listing, _profile)),
    ];
    if (!_profile.isEmpty) {
      ranked.sort((a, b) => (b.match?.score ?? 0).compareTo(a.match?.score ?? 0));
    }
    return ranked;
  }
}
