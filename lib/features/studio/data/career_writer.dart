import '../../../core/ai/ai_chain.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/json_extract.dart';
import '../../profile/data/career_profile.dart';

/// The job a resume or cover letter is aimed at.
class JobContext {
  const JobContext({
    required this.title,
    required this.company,
    this.location,
    this.description,
    this.applicationId,
  });

  final String title;
  final String company;
  final String? location;

  /// Posting text, which makes tailoring much better when available.
  final String? description;

  /// Set when the job is a tracked application, to link saved documents.
  final String? applicationId;

  String get label => '$title at $company';
}

class EnhancedResume {
  const EnhancedResume({
    required this.content,
    required this.changes,
    required this.provider,
  });

  /// Light Markdown (see CareerDocument).
  final String content;

  /// What was improved, for the user to review.
  final List<String> changes;
  final String provider;
}

enum LetterTone {
  professional('Professional'),
  warm('Warm'),
  confident('Confident');

  const LetterTone(this.label);

  final String label;
}

enum LetterLength {
  short('Short', '150-200 words'),
  standard('Standard', '250-320 words');

  const LetterLength(this.label, this.words);

  final String label;
  final String words;
}

class CoverLetter {
  const CoverLetter({required this.content, required this.provider});

  final String content;
  final String provider;
}

/// Writes resumes and cover letters with AI (Gemini, then Groq, then
/// OpenAI). Never invents experience: everything comes from the resume.
class CareerWriter {
  CareerWriter(this.ai);

  final AiChain ai;

  bool get isConfigured => ai.isConfigured;

  static const _format = '''
Format the resume in light Markdown only:
- First line: "# Full Name"
- Second line: contact details on one line, separated by " · "
- Sections as "## Heading" (e.g. Summary, Experience, Skills, Education)
- Each job as a line "**Job Title** · Company · Dates", followed by "- " bullets
- No tables, no images, no HTML.''';

  Future<EnhancedResume> enhanceResume({
    required String resumeText,
    required CareerProfile profile,
    String? targetRole,
    JobContext? job,
  }) async {
    final target = job != null
        ? 'Tailor it to this job: ${job.label}.'
            '${_jobDetails(job)}'
        : targetRole != null && targetRole.trim().isNotEmpty
            ? 'Optimize it for "${targetRole.trim()}" roles.'
            : 'Optimize it for the roles this person wants: '
                '${profile.effectiveRoles.join(', ')}.';

    final reply = await ai.complete(
      AiRequest(
        json: true,
        system: 'You are an expert resume writer and recruiter. Improve '
            'resumes so they are clear, concise, achievement-focused and pass '
            'applicant tracking systems. Never invent employers, titles, '
            'dates, degrees, numbers or skills that are not in the original. '
            'Reply with JSON only.',
        prompt: '''
Rewrite this resume. $target

Do:
- Lead each bullet with a strong action verb; show impact and scope.
- Keep any numbers that exist; where impact is implied, describe it without inventing figures.
- Put the most relevant skills and experience first; use the target's keywords where truthful.
- Write a 2-3 sentence summary at the top.
- Keep it to what fits on 1-2 pages.

$_format

CANDIDATE PREFERENCES
${_profile(profile)}

ORIGINAL RESUME
$resumeText

Return JSON: {"resume": "<the full rewritten resume in Markdown>", "changes": ["<short note on each main improvement, max 6>"]}''',
      ),
    );

    final json = extractJson(reply.text);
    final resume = json is Map<String, dynamic> ? json['resume'] : null;
    if (resume is! String || resume.trim().isEmpty) {
      throw const FormatException('AI did not return a resume');
    }
    final changes = json is Map<String, dynamic> && json['changes'] is List
        ? (json['changes'] as List).whereType<String>().take(6).toList()
        : const <String>[];
    return EnhancedResume(
      content: resume.trim(),
      changes: changes,
      provider: reply.provider,
    );
  }

  Future<CoverLetter> writeCoverLetter({
    required String resumeText,
    required CareerProfile profile,
    required JobContext job,
    LetterTone tone = LetterTone.professional,
    LetterLength length = LetterLength.standard,
  }) async {
    final reply = await ai.complete(
      AiRequest(
        json: true,
        system: 'You write tailored, human-sounding cover letters. Use only '
            'facts from the resume; never invent experience, employers or '
            'numbers. Avoid clichés like "I am writing to express my '
            'interest". Reply with JSON only.',
        prompt: '''
Write a cover letter for ${job.label}.${_jobDetails(job)}

Tone: ${tone.label.toLowerCase()}. Length: ${length.words}.
Structure: greeting ("Dear Hiring Manager," unless a name is known), a hook connecting the candidate to this role and company, 1-2 paragraphs matching their most relevant experience and skills to the job's needs, a short closing with a call to action, and a sign-off with the candidate's name.
Plain text with blank lines between paragraphs. No placeholders like [Company].

CANDIDATE PREFERENCES
${_profile(profile)}

RESUME
$resumeText

Return JSON: {"letter": "<the cover letter>"}''',
      ),
    );

    final json = extractJson(reply.text);
    final letter = json is Map<String, dynamic> ? json['letter'] : null;
    if (letter is! String || letter.trim().isEmpty) {
      throw const FormatException('AI did not return a cover letter');
    }
    return CoverLetter(content: letter.trim(), provider: reply.provider);
  }

  static String _jobDetails(JobContext job) {
    final description = job.description?.trim();
    return [
      if (job.location != null) '\nLocation: ${job.location}',
      if (description != null && description.isNotEmpty)
        '\nJob posting:\n${description.length > 4000 ? description.substring(0, 4000) : description}',
    ].join();
  }

  static String _profile(CareerProfile p) => [
        if (p.effectiveRoles.isNotEmpty) 'Wants roles: ${p.effectiveRoles.join(', ')}',
        if (p.skills.isNotEmpty) 'Extra skills to highlight: ${p.skills.join(', ')}',
        if (p.effectiveYears != null) 'Years of experience: ${p.effectiveYears}',
        if (p.effectiveLocation != null) 'Based in: ${p.effectiveLocation}',
        'Work setup: ${p.workSetup.label}',
      ].join('\n');
}
