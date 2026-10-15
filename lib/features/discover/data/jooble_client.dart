import 'dart:convert';

import 'package:http/http.dart' as http;

import 'job_listing.dart';
import 'job_search_query.dart';
import 'jsearch_client.dart';

/// Jooble job aggregator. The current key only covers Jooble's international
/// index, so it's used for remote and "anywhere" searches.
class JoobleClient {
  JoobleClient({required this.apiKey, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _http;

  bool get isConfigured => apiKey.isNotEmpty;

  bool supports(SearchScope scope) => scope != SearchScope.philippines;

  Future<List<JobListing>> search(JobSearchQuery query) async {
    final response = await _http
        .post(
          Uri.https('jooble.org', '/api/$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'keywords': query.keywords,
            if (query.scope == SearchScope.remote) 'location': 'Remote',
            'page': '${query.page}',
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 429) throw const JobSearchLimitException();
    if (response.statusCode != 200) {
      throw JobSearchException('Jooble returned ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final jobs = body['jobs'] as List<dynamic>? ?? const [];
    return jobs.whereType<Map<String, dynamic>>().map(_parse).toList();
  }

  static JobListing _parse(Map<String, dynamic> json) {
    final location = (json['location'] as String?)?.trim();
    final salary = (json['salary'] as String?)?.trim();
    final type = (json['type'] as String?)?.trim();

    return JobListing(
      id: 'jooble:${json['id']}',
      title: _clean(json['title'] as String? ?? 'Untitled role'),
      company: _clean(json['company'] as String? ?? 'Unknown company'),
      source: (json['source'] as String?)?.trim().isNotEmpty == true
          ? json['source'] as String
          : 'Jooble',
      applyUrl: json['link'] as String? ?? '',
      location: location == null || location.isEmpty ? null : location,
      isRemote: (location ?? '').toLowerCase().contains('remote'),
      employmentType: type == null || type.isEmpty ? null : type,
      salary: salary == null || salary.isEmpty ? null : salary,
      postedAt: DateTime.tryParse(json['updated'] as String? ?? '')?.toLocal(),
      description: _clean(json['snippet'] as String? ?? ''),
    );
  }

  /// Jooble snippets contain HTML tags and entities.
  static String _clean(String text) => text
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
