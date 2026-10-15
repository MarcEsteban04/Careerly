import 'dart:convert';

import '../../../core/ai/ai_chain.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/json_extract.dart';
import '../../profile/data/career_profile.dart';
import 'job_listing.dart';

/// An AI verdict on one listing.
class AiVerdict {
  const AiVerdict({required this.score, required this.reason});

  final int score;
  final String reason;
}

/// Scores listings against the profile and resume with an AI model, in one
/// request per search. Callers fall back to keyword scoring on failure.
class AiJobRanker {
  AiJobRanker(this.ai);

  final AiChain ai;

  /// Ranking more than this per request gets slow and expensive.
  static const maxListings = 15;

  static const _system =
      'You are a recruiter matching one candidate to job postings. Be honest: '
      'reward real overlap in role, skills, seniority and location or work '
      'setup; penalize mismatches. Reply with JSON only.';

  bool get isConfigured => ai.isConfigured;

  /// Returns verdicts by listing id, and which provider produced them.
  Future<(Map<String, AiVerdict>, String)> rank(
    List<JobListing> listings,
    CareerProfile profile,
  ) async {
    final batch = listings.take(maxListings).toList();
    final jobs = [
      for (final job in batch)
        {
          'id': job.id,
          'title': job.title,
          'company': job.company,
          'location': job.location ?? (job.isRemote ? 'Remote' : null),
          'remote': job.isRemote,
          'type': job.employmentType,
          'details': _snippet(job),
        },
    ];

    final reply = await ai.complete(
      AiRequest(
        system: _system,
        json: true,
        prompt: '''
CANDIDATE
${_candidate(profile)}

JOBS (JSON)
${jsonEncode(jobs)}

For every job, return a JSON object: {"results": [{"id": "<job id>", "score": <0-100>, "reason": "<max 14 words, second person, e.g. 'Your Figma and 3 years of UI work fit this mid-level role'>"}]}''',
      ),
    );

    final json = extractJson(reply.text);
    final results = json is Map<String, dynamic>
        ? json['results']
        : json is List
            ? json
            : null;
    if (results is! List) {
      throw const FormatException('AI ranking reply had no results');
    }

    final ids = batch.map((j) => j.id).toSet();
    final verdicts = <String, AiVerdict>{};
    for (final item in results.whereType<Map<String, dynamic>>()) {
      final id = item['id'] as String?;
      final score = (item['score'] as num?)?.round();
      final reason = (item['reason'] as String?)?.trim();
      if (id == null || !ids.contains(id) || score == null) continue;
      verdicts[id] = AiVerdict(
        score: score.clamp(0, 100),
        reason: reason == null || reason.isEmpty ? 'Ranked by AI' : reason,
      );
    }
    if (verdicts.isEmpty) throw const FormatException('No usable AI scores');
    return (verdicts, reply.provider);
  }

  static String _candidate(CareerProfile p) {
    final resume = p.resume;
    return [
      if (resume?.headline != null) 'Headline: ${resume!.headline}',
      if (resume?.summary != null) 'Summary: ${resume!.summary}',
      if (p.effectiveRoles.isNotEmpty) 'Wants roles: ${p.effectiveRoles.join(', ')}',
      if (p.effectiveSkills.isNotEmpty) 'Skills: ${p.effectiveSkills.join(', ')}',
      if (p.effectiveYears != null) 'Years of experience: ${p.effectiveYears}',
      if (resume?.seniority != null) 'Seniority: ${resume!.seniority}',
      if (p.effectiveLocation != null) 'Based in: ${p.effectiveLocation}',
      'Work setup preference: ${p.workSetup.label}',
    ].join('\n');
  }

  static String _snippet(JobListing job) {
    final text = [
      if (job.qualifications.isNotEmpty) job.qualifications.join('; '),
      job.description,
    ].join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 600 ? text : '${text.substring(0, 600)}…';
  }
}
