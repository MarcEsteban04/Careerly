import '../../../core/ai/ai_chain.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/json_extract.dart';
import '../../profile/data/career_profile.dart';
import '../../studio/data/career_writer.dart';
import 'interview_prep.dart';

/// Builds interview kits with AI (Gemini, then Groq, then OpenAI), looking
/// the company up on the web. Answers come only from the resume.
class InterviewCoach {
  InterviewCoach(this.ai);

  final AiChain ai;

  bool get isConfigured => ai.isConfigured;

  Future<InterviewPrep> prepare({
    required JobContext job,
    required CareerProfile profile,
    String? resumeText,
    DateTime? now,
  }) async {
    final description = job.description?.trim() ?? '';
    final resume = resumeText?.trim() ?? '';

    final reply = await ai.complete(
      AiRequest(
        json: true,
        webSearch: true,
        system: 'You are a senior recruiter and interview coach. You prepare '
            'candidates with realistic questions for the specific company and '
            'role, and suggest answers built only from the candidate\'s real '
            'experience. Never invent employers, projects, numbers or '
            'skills. Reply with JSON only.',
        prompt: '''
Prepare me for an interview: ${job.label}.
${job.location == null ? '' : 'Location: ${job.location}\n'}${description.isEmpty ? '' : 'Job posting:\n${description.length > 4000 ? description.substring(0, 4000) : description}\n'}
Search the web for what ${job.company} does, its products, culture and recent news, and use it for the company brief and company questions. If you can't find reliable information, say so briefly instead of guessing.

Write 10 likely questions: about 4 role/technical, 3 behavioral, 2 company, 1 situational. For each, a suggested answer as 2-4 short talking points (STAR style for behavioral) using ${resume.isEmpty ? "the candidate's preferences below; where you'd need their experience, say what kind of example to use" : 'specific experience from the resume'}.

CANDIDATE PREFERENCES
${_profile(profile)}
${resume.isEmpty ? '' : '\nRESUME\n$resume\n'}
Return JSON:
{
  "company_brief": "<3-4 sentences: what they do, who they serve, what they likely value in this role>",
  "focus_areas": ["<skill or quality they'll assess, 2-4 words>", "... 4-6 items"],
  "questions": [{"category": "role|behavioral|company|situational", "question": "...", "why": "<one sentence on what they're testing>", "answer": "<talking points, one per line starting with - >"}],
  "questions_to_ask": ["<3-4 thoughtful questions to ask the interviewer>"],
  "tips": ["<3-5 short, specific tips for this interview>"]
}''',
      ),
    );

    final json = extractJson(reply.text);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('AI did not return an interview kit');
    }
    final prep = InterviewPrep.fromJson(
      json,
      provider: reply.provider,
      createdAt: now ?? DateTime.now(),
    );
    if (prep.isEmpty) {
      throw const FormatException('AI returned no interview questions');
    }
    return prep;
  }

  static String _profile(CareerProfile p) => [
        if (p.effectiveRoles.isNotEmpty)
          'Wants roles: ${p.effectiveRoles.join(', ')}',
        if (p.effectiveSkills.isNotEmpty)
          'Skills: ${p.effectiveSkills.take(20).join(', ')}',
        if (p.effectiveYears != null)
          'Years of experience: ${p.effectiveYears}',
        if (p.effectiveLocation != null) 'Based in: ${p.effectiveLocation}',
      ].join('\n');
}
