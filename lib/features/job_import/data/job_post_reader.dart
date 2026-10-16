import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/ai/ai_chain.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/json_extract.dart';

/// A job read from a shared link or post, ready to review and track.
class JobPostDraft {
  const JobPostDraft({
    this.role,
    this.company,
    this.location,
    this.salary,
    this.description,
    this.url,
    this.source,
  });

  final String? role;
  final String? company;
  final String? location;
  final String? salary;

  /// Responsibilities and requirements, as plain text.
  final String? description;
  final String? url;

  /// Where it was posted, e.g. "LinkedIn".
  final String? source;

  bool get hasBasics => (role ?? '').isNotEmpty && (company ?? '').isNotEmpty;

  /// Fills gaps in this draft from [other].
  JobPostDraft merge(JobPostDraft other) => JobPostDraft(
        role: _pick(role, other.role),
        company: _pick(company, other.company),
        location: _pick(location, other.location),
        salary: _pick(salary, other.salary),
        description: _pick(description, other.description),
        url: _pick(url, other.url),
        source: _pick(source, other.source),
      );

  static String? _pick(String? a, String? b) =>
      (a ?? '').trim().isNotEmpty ? a!.trim() : (b ?? '').trim().isEmpty ? null : b!.trim();
}

/// What was shared wasn't a job post.
class NotAJobException implements Exception {
  const NotAJobException();
}

/// Turns a shared link (LinkedIn, JobStreet, Indeed, Facebook…) or pasted
/// text into a [JobPostDraft]. Reads the page's structured job data when
/// there is some; otherwise AI extracts the details from the page text, or
/// looks the link up on the web when the page can't be read (e.g. a login
/// wall).
class JobPostReader {
  JobPostReader(this.ai, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final AiChain ai;
  final http.Client _http;

  static final _urlPattern = RegExp(r'https?://[^\s<>"]+');

  /// The first link in [text], if any.
  static String? firstUrl(String text) =>
      _urlPattern.firstMatch(text)?.group(0)?.replaceAll(RegExp(r'[).,]+$'), '');

  Future<JobPostDraft> read(String shared) async {
    final url = firstUrl(shared);
    final note = (url == null ? shared : shared.replaceAll(url, '')).trim();
    final source = url == null ? null : sourceFor(url);

    var draft = JobPostDraft(url: url, source: source);
    String? pageText;
    if (url != null) {
      try {
        final html = await _fetch(url);
        final structured = fromJsonLd(html);
        if (structured != null) {
          draft = structured.merge(draft);
          if (draft.hasBasics && (draft.description ?? '').length > 80) {
            return draft;
          }
        }
        pageText = visibleText(html);
      } catch (e) {
        debugPrint('Reading the job page failed: $e');
      }
    }

    final usable = (pageText ?? '').length > 200;
    final reply = await ai.complete(
      AiRequest(
        json: true,
        // A link we couldn't read: let the model look it up.
        webSearch: url != null && !usable,
        system: 'You extract job postings into structured data. Use only '
            'what the text or page says; leave a field empty rather than '
            'guess. Reply with JSON only.',
        prompt: '''
Extract the job posting.
${url == null ? '' : 'Link: $url\n'}${note.isEmpty ? '' : 'Shared text:\n${_clip(note, 3000)}\n'}${usable ? 'Page text:\n${_clip(pageText!, 6000)}\n' : ''}
Return JSON: {"is_job": true|false, "role": "", "company": "", "location": "<city, or Remote>", "salary": "<as written, e.g. ₱30,000-40,000/month>", "description": "<responsibilities and requirements, plain text, under 1500 characters>"}''',
      ),
    );

    final json = extractJson(reply.text);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('AI did not return the job details');
    }
    if (json['is_job'] == false) throw const NotAJobException();
    String? field(String key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    return draft.merge(
      JobPostDraft(
        role: field('role'),
        company: field('company'),
        location: field('location'),
        salary: field('salary'),
        description: field('description'),
      ),
    );
  }

  Future<String> _fetch(String url) async {
    final response = await _http.get(
      Uri.parse(url),
      headers: const {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile '
            'Safari/537.36',
        'Accept-Language': 'en-PH,en;q=0.9',
      },
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}');
    }
    return response.body;
  }

  /// Friendly name of the site a job was shared from.
  static String sourceFor(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    const known = {
      'linkedin.': 'LinkedIn',
      'lnkd.in': 'LinkedIn',
      'jobstreet.': 'JobStreet',
      'indeed.': 'Indeed',
      'onlinejobs.ph': 'OnlineJobs.ph',
      'kalibrr.': 'Kalibrr',
      'facebook.': 'Facebook',
      'fb.': 'Facebook',
      'glassdoor.': 'Glassdoor',
      'bossjob.': 'Bossjob',
      'upwork.': 'Upwork',
    };
    for (final entry in known.entries) {
      if (host.contains(entry.key)) return entry.value;
    }
    return host.replaceFirst('www.', '');
  }

  /// Reads a schema.org JobPosting from the page's JSON-LD, which most job
  /// boards publish for search engines.
  @visibleForTesting
  static JobPostDraft? fromJsonLd(String html) {
    final scripts = RegExp(
      r'<script[^>]*type="application/ld\+json"[^>]*>([\s\S]*?)</script>',
      caseSensitive: false,
    ).allMatches(html);

    for (final match in scripts) {
      Object? data;
      try {
        data = jsonDecode(match.group(1)!.trim());
      } on FormatException {
        continue;
      }
      final posting = _findPosting(data);
      if (posting == null) continue;

      final organization = posting['hiringOrganization'];
      final remote = '${posting['jobLocationType']}'.toUpperCase() ==
          'TELECOMMUTE';
      return JobPostDraft(
        role: _text(posting['title']),
        company: organization is Map ? _text(organization['name']) : null,
        location: remote ? 'Remote' : _location(posting['jobLocation']),
        salary: _salary(posting['baseSalary']),
        description: _clip(
          visibleText('${posting['description'] ?? ''}'),
          1500,
        ),
      );
    }
    return null;
  }

  static Map<String, dynamic>? _findPosting(Object? data) {
    if (data is List) {
      for (final item in data) {
        final found = _findPosting(item);
        if (found != null) return found;
      }
    } else if (data is Map<String, dynamic>) {
      final type = data['@type'];
      if (type == 'JobPosting' || (type is List && type.contains('JobPosting'))) {
        return data;
      }
      return _findPosting(data['@graph']);
    }
    return null;
  }

  static String? _location(Object? value) {
    final place = value is List ? value.firstOrNull : value;
    if (place is! Map) return null;
    final address = place['address'];
    if (address is! Map) return null;
    final parts = [
      _text(address['addressLocality']),
      _text(address['addressRegion']),
    ].whereType<String>().toSet();
    return parts.isEmpty ? _text(address['addressCountry']) : parts.join(', ');
  }

  static String? _salary(Object? value) {
    if (value is! Map) return null;
    final amount = value['value'];
    final currency = value['currency'] == 'PHP' ? '₱' : '${value['currency'] ?? ''} ';
    if (amount is! Map) return null;
    String fmt(Object? n) => n is num ? n.round().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
        ) : '';
    final min = fmt(amount['minValue'] ?? amount['value']);
    final max = fmt(amount['maxValue']);
    if (min.isEmpty) return null;
    final unit = '${amount['unitText'] ?? ''}'.toLowerCase();
    final per = unit.isEmpty ? '' : '/$unit';
    return max.isEmpty || max == min
        ? '$currency$min$per'
        : '$currency$min–$max$per';
  }

  static String? _text(Object? value) {
    final text = value is String ? value.trim() : null;
    return text == null || text.isEmpty ? null : text;
  }

  /// The readable text of an HTML page or fragment.
  @visibleForTesting
  static String visibleText(String html) => html
      .replaceAll(RegExp(r'<(script|style|noscript)[\s\S]*?</\1>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<br\s*/?>|</(p|li|div|h\d)>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\s*\n\s*'), '\n')
      .trim();

  static String _clip(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max)}…';
}
