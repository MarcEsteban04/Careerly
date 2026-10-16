import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'job_listing.dart';
import 'job_search_query.dart';

/// JSearch (OpenWeb Ninja): Google for Jobs results, which include LinkedIn,
/// Indeed, Glassdoor, JobStreet and company career pages.
class JSearchClient {
  JSearchClient({required this.apiKey, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _http;

  static const _host = 'api.openwebninja.com';

  /// Jobs per page; a full page means there may be more.
  static const pageSize = 10;

  bool get isConfigured => apiKey.isNotEmpty;

  Future<List<JobListing>> search(JobSearchQuery query) async {
    final scope = query.scope;
    final abroad = scope.country;
    final String where;
    final String? country;
    if (abroad != null) {
      where = ' in ${abroad.name}';
      country = abroad.code;
    } else if (scope == SearchScope.remote) {
      where = ' remote';
      country = 'ph';
    } else if (scope == SearchScope.anywhere) {
      where = '';
      country = null;
    } else {
      final city = query.location?.trim() ?? '';
      where = ' in ${city.isNotEmpty ? city : 'Philippines'}';
      country = 'ph';
    }
    final uri = Uri.https(_host, '/jsearch/search', {
      'query': '${query.keywords}$where',
      'page': '${query.page}',
      'num_pages': '1',
      'date_posted': query.postedWithin.jsearchValue,
      'country': ?country,
      if (scope == SearchScope.remote) 'work_from_home': 'true',
    });

    final response = await _http
        .get(uri, headers: {'x-api-key': apiKey})
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 429) throw const JobSearchLimitException();
    if (response.statusCode != 200) {
      throw JobSearchException('JSearch returned ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? const [];
    return data.whereType<Map<String, dynamic>>().map(_parse).toList();
  }

  static JobListing _parse(Map<String, dynamic> json) {
    final highlights =
        json['job_highlights'] as Map<String, dynamic>? ?? const {};
    List<String> highlight(String key) =>
        (highlights[key] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();

    final city = json['job_city'] as String?;
    final state = json['job_state'] as String?;
    final location = (json['job_location'] as String?) ??
        [city, state].whereType<String>().join(', ');

    return JobListing(
      id: 'jsearch:${json['job_id']}',
      title: (json['job_title'] as String? ?? 'Untitled role').trim(),
      company: (json['employer_name'] as String? ?? 'Unknown company').trim(),
      source: json['job_publisher'] as String? ?? 'Google Jobs',
      applyUrl: json['job_apply_link'] as String? ??
          json['job_google_link'] as String? ??
          '',
      companyLogoUrl: json['employer_logo'] as String?,
      location: location.isEmpty ? null : location,
      isRemote: json['job_is_remote'] as bool? ?? false,
      employmentType: json['job_employment_type'] as String?,
      salary: json['job_salary_string'] as String? ?? _salary(json),
      postedAt: DateTime.tryParse(
        json['job_posted_at_datetime_utc'] as String? ?? '',
      )?.toLocal(),
      postedLabel: json['job_posted_at'] as String?,
      description: (json['job_description'] as String? ?? '').trim(),
      qualifications: highlight('Qualifications'),
      responsibilities: highlight('Responsibilities'),
      benefits: highlight('Benefits'),
    );
  }

  static String? _salary(Map<String, dynamic> json) {
    final min = (json['job_min_salary'] as num?)?.toDouble();
    final max = (json['job_max_salary'] as num?)?.toDouble();
    if (min == null && max == null) return null;
    final money = NumberFormat.compact();
    final period = switch ((json['job_salary_period'] as String?)?.toUpperCase()) {
      'HOUR' => '/hr',
      'MONTH' => '/month',
      'YEAR' => '/yr',
      _ => '',
    };
    final range = min != null && max != null && min != max
        ? '${money.format(min)}–${money.format(max)}'
        : money.format(min ?? max);
    return '$range$period';
  }
}

class JobSearchException implements Exception {
  const JobSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The monthly request quota of a job API has been used up.
class JobSearchLimitException extends JobSearchException {
  const JobSearchLimitException() : super('Search limit reached');
}
