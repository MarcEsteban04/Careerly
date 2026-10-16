import 'package:intl/intl.dart';

import '../../../core/ai/ai_chain.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/citations.dart';
import '../../../core/ai/json_extract.dart';
import '../../agenda/data/agenda_event.dart';
import '../../applications/data/job_application.dart';
import '../../goals/data/goal.dart';
import '../../profile/data/career_profile.dart';
import 'coach_message.dart';

/// Everything the coach knows about her search right now.
class CoachContext {
  const CoachContext({
    required this.profile,
    this.name,
    this.resumeText,
    this.applications = const [],
    this.upcoming = const [],
    this.goals = const [],
  });

  final String? name;
  final CareerProfile profile;
  final String? resumeText;
  final List<JobApplication> applications;
  final List<AgendaEvent> upcoming;
  final List<Goal> goals;

  /// A compact brief for the model: profile, pipeline, agenda and goals.
  String brief(DateTime now) {
    final day = DateFormat('MMM d');
    final p = profile;
    final open = applications
        .where((a) => a.status != ApplicationStatus.rejected)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final closed =
        applications.where((a) => a.status == ApplicationStatus.rejected).length;
    String job(JobApplication a) => [
          '${a.role} at ${a.company}',
          a.status.label,
          if (a.salary != null) a.salary!,
          if (a.location != null) a.location!,
          if (a.appliedOn != null) 'applied ${day.format(a.appliedOn!)}',
          if (a.followUpOn != null) 'follow up ${day.format(a.followUpOn!)}',
        ].join(' · ');

    final events = upcoming.where((e) => !e.isDone).take(8);
    return [
      'Today: ${DateFormat('EEEE, MMM d, y').format(now)}',
      if (name != null) 'Name: $name',
      if (p.effectiveRoles.isNotEmpty)
        'Target roles: ${p.effectiveRoles.join(', ')}',
      if (p.effectiveSkills.isNotEmpty)
        'Skills: ${p.effectiveSkills.take(25).join(', ')}',
      if (p.effectiveYears != null) 'Years of experience: ${p.effectiveYears}',
      if (p.resume?.seniority != null) 'Seniority: ${p.resume!.seniority}',
      if (p.effectiveLocation != null) 'Based in: ${p.effectiveLocation}',
      'Preferred setup: ${p.workSetup.label}',
      '',
      if (open.isEmpty)
        'Tracked jobs: none yet'
      else ...[
        'Tracked jobs (${open.length} open, $closed closed):',
        for (final a in open.take(25)) '- ${job(a)}',
      ],
      if (events.isNotEmpty) ...[
        '',
        'Coming up:',
        for (final e in events)
          '- ${e.kind.label}: ${e.title}'
              '${e.company == null ? '' : ' (${e.company})'}, '
              '${DateFormat('EEE MMM d, h:mm a').format(e.startsAt)}',
      ],
      if (goals.isNotEmpty) ...[
        '',
        'Goals:',
        for (final g in goals)
          '- ${g.title}: ${g.progress}/${g.target} ${g.period.label.toLowerCase()}',
      ],
    ].join('\n');
  }
}

/// The coach's answer and a few follow-ups to tap.
class CoachReply {
  const CoachReply({
    required this.text,
    required this.suggestions,
    required this.provider,
  });

  final String text;
  final List<String> suggestions;
  final String provider;
}

/// A career coach chat with AI (Gemini, then Groq, then OpenAI as the last
/// resort), grounded in her profile, resume, tracked jobs, agenda and
/// goals.
class CareerCoach {
  CareerCoach(this.ai);

  final AiChain ai;

  bool get isConfigured => ai.isConfigured;

  /// Turns of history sent with each question.
  static const historyTurns = 12;

  /// A chat reply that takes longer than this moves on to the next AI.
  static const providerTimeout = Duration(seconds: 30);

  /// Questions to start a conversation with.
  static List<String> starters(CoachContext context) => [
        if (context.applications.any((a) => a.status == ApplicationStatus.saved))
          'Which of my saved jobs should I apply to first?',
        if (context.upcoming.any(
          (e) => !e.isDone && e.kind == AgendaEventKind.interview,
        ))
          'Help me get ready for my next interview',
        if (context.applications.any((a) => a.status == ApplicationStatus.offer))
          'Should I accept my offer?',
        'What should I focus on this week?',
        'How can I stand out from other applicants?',
        'Am I asking for the right salary?',
      ].take(4).toList();

  Future<CoachReply> reply({
    required String question,
    required CoachContext context,
    List<CoachMessage> history = const [],
    DateTime? now,
  }) async {
    final recent = history.length > historyTurns
        ? history.sublist(history.length - historyTurns)
        : history;
    final resume = context.resumeText?.trim() ?? '';

    final response = await ai.complete(
      AiRequest(
        json: true,
        timeout: providerTimeout,
        system: 'You are Careerly\'s career coach: warm, direct and practical, '
            'like a mentor who knows the Philippine job market (local and '
            'remote/international roles, peso salaries, 13th month, HMO, '
            'OnlineJobs.ph, JobStreet, LinkedIn). Ground every answer in the '
            'candidate\'s own data below: name their real jobs, dates and '
            'skills. Never invent jobs, employers, numbers or experience; if '
            'something isn\'t in the data, say so or ask. Give concrete next '
            'steps. Keep answers short for a phone: 60-170 words, using '
            '**bold** and "- " bullets when it helps. Reply with JSON only.',
        prompt: '''
ABOUT THE CANDIDATE AND THEIR SEARCH
${context.brief(now ?? DateTime.now())}
${resume.isEmpty ? '' : '\nRESUME\n${resume.length > 5000 ? resume.substring(0, 5000) : resume}\n'}
${recent.isEmpty ? '' : 'CONVERSATION SO FAR\n${recent.map((m) => '${m.fromCoach ? 'Coach' : 'Candidate'}: ${m.text}').join('\n')}\n'}
Candidate: ${question.trim()}

Return JSON: {"reply": "<your answer>", "suggestions": ["<2-3 short follow-up questions the candidate might ask next, under 60 characters each>"]}''',
      ),
    );

    final json = extractJson(response.text);
    final text = json is Map<String, dynamic> && json['reply'] is String
        ? stripCitations(json['reply'] as String)
        : '';
    if (text.isEmpty) {
      throw const FormatException('AI did not return a coach reply');
    }
    final suggestions = json is Map<String, dynamic> && json['suggestions'] is List
        ? (json['suggestions'] as List)
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s.length <= 80)
            .take(3)
            .toList()
        : const <String>[];
    return CoachReply(
      text: text,
      suggestions: suggestions,
      provider: response.provider,
    );
  }
}
