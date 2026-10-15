import 'package:supabase_flutter/supabase_flutter.dart';

import 'job_listing.dart';
import 'job_search_query.dart';

/// A search the user bookmarked to run again.
class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.keywords,
    required this.scope,
    required this.postedWithin,
  });

  factory SavedSearch.fromJson(Map<String, dynamic> json) => SavedSearch(
        id: json['id'] as String,
        keywords: json['keywords'] as String,
        scope: SearchScope.values.firstWhere(
          (s) => s.name == json['scope'],
          orElse: () => SearchScope.philippines,
        ),
        postedWithin: PostedWithin.values.firstWhere(
          (p) => p.name == json['posted_within'],
          orElse: () => PostedWithin.month,
        ),
      );

  final String id;
  final String keywords;
  final SearchScope scope;
  final PostedWithin postedWithin;

  Map<String, dynamic> toJson() => {
        'id': id,
        'keywords': keywords,
        'scope': scope.name,
        'posted_within': postedWithin.name,
      };

  String get label => scope == SearchScope.philippines
      ? keywords
      : '$keywords · ${scope.label}';

  bool matches(String keywords, SearchScope scope, PostedWithin postedWithin) =>
      this.keywords.toLowerCase() == keywords.toLowerCase().trim() &&
      this.scope == scope &&
      this.postedWithin == postedWithin;
}

/// Saved searches and jobs marked "Not interested".
class SearchPreferencesRepository {
  SearchPreferencesRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<SavedSearch>> fetchSavedSearches() async {
    final rows = await _client
        .from('saved_searches')
        .select()
        .order('created_at', ascending: false);
    return rows.map(SavedSearch.fromJson).toList();
  }

  Future<SavedSearch> saveSearch({
    required String keywords,
    required SearchScope scope,
    required PostedWithin postedWithin,
  }) async {
    final row = await _client
        .from('saved_searches')
        .upsert(
          {
            'keywords': keywords.trim(),
            'scope': scope.name,
            'posted_within': postedWithin.name,
          },
          onConflict: 'user_id,keywords,scope,posted_within',
        )
        .select()
        .single();
    return SavedSearch.fromJson(row);
  }

  Future<void> deleteSearch(String id) =>
      _client.from('saved_searches').delete().eq('id', id);

  /// Keys of jobs marked "Not interested".
  Future<Set<String>> fetchDismissedKeys() async {
    final rows = await _client.from('dismissed_jobs').select('job_key');
    return rows.map((r) => r['job_key'] as String).toSet();
  }

  Future<void> dismiss(JobListing job) => _client.from('dismissed_jobs').upsert(
        {
          'job_key': job.dedupeKey,
          'title': job.title,
          'company': job.company,
        },
        onConflict: 'user_id,job_key',
      );

  Future<void> undismiss(JobListing job) =>
      _client.from('dismissed_jobs').delete().eq('job_key', job.dedupeKey);
}
