import '../../../core/ai/ai_chain.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/json_extract.dart';
import 'job_listing.dart';
import 'job_search_query.dart';

/// Backup job source: asks an AI model with web search to find current
/// postings. Used only when the job APIs fail or find nothing.
class AiJobSearchClient {
  AiJobSearchClient(this.ai);

  final AiChain ai;

  bool get isConfigured => ai.isConfigured;

  static const _system =
      'You find real, currently open job postings on the web. Never invent '
      'jobs or links; only include postings you actually found, with their '
      'real URLs. Reply with JSON only.';

  Future<List<JobListing>> search(JobSearchQuery query) async {
    final where = switch (query.scope) {
      SearchScope.philippines =>
        'in ${query.location?.trim().isNotEmpty == true ? '${query.location}, ' : ''}the Philippines',
      SearchScope.remote => 'that are remote and open to applicants in the Philippines',
      SearchScope.anywhere => 'anywhere',
    };
    final recency = switch (query.postedWithin) {
      PostedWithin.today => 'posted today',
      PostedWithin.week => 'posted in the last 7 days',
      PostedWithin.month => 'posted in the last 30 days',
      PostedWithin.any => 'still open',
    };

    final reply = await ai.complete(
      AiRequest(
        system: _system,
        webSearch: true,
        prompt: '''
Search the web for up to 10 job postings for "${query.keywords}" $where, $recency.
Prefer LinkedIn, Indeed, JobStreet, OnlineJobs.ph, Kalibrr and company career pages.

Return ONLY a JSON array. Each item:
{"title": "...", "company": "...", "location": "...", "url": "direct link to the posting", "source": "site name", "remote": true/false, "employment_type": "Full-time/Part-time/Contract or null", "salary": "as written, or null", "posted": "e.g. 3 days ago, or null", "description": "1-2 sentence summary"}''',
      ),
    );

    final json = extractJson(reply.text);
    final items = json is List
        ? json
        : json is Map<String, dynamic>
            ? (json['jobs'] ?? json['results']) as List<dynamic>?
            : null;
    if (items == null) throw const FormatException('AI search reply had no jobs');

    final listings = <JobListing>[];
    for (final item in items.whereType<Map<String, dynamic>>()) {
      final url = (item['url'] as String?)?.trim() ?? '';
      final title = (item['title'] as String?)?.trim() ?? '';
      if (title.isEmpty || !_isWebUrl(url)) continue;
      listings.add(
        JobListing(
          id: 'ai:${url.hashCode}',
          title: title,
          company: (item['company'] as String?)?.trim() ?? 'Unknown company',
          source: (item['source'] as String?)?.trim().isNotEmpty == true
              ? item['source'] as String
              : Uri.parse(url).host,
          applyUrl: url,
          location: _nonEmpty(item['location']),
          isRemote: item['remote'] == true,
          employmentType: _nonEmpty(item['employment_type']),
          salary: _nonEmpty(item['salary']),
          postedLabel: _nonEmpty(item['posted']),
          description: _nonEmpty(item['description']) ?? '',
          foundByAi: reply.provider,
        ),
      );
    }
    return listings;
  }

  static bool _isWebUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.contains('.');
  }

  static String? _nonEmpty(Object? value) {
    final text = value is String ? value.trim() : null;
    return text == null || text.isEmpty || text.toLowerCase() == 'null' ? null : text;
  }
}
