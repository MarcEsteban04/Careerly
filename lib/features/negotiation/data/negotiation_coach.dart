import '../../../core/ai/ai_chain.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/citations.dart';
import '../../../core/ai/json_extract.dart';
import '../../profile/data/career_profile.dart';
import '../../studio/data/career_writer.dart';

/// What the candidate knows about an offer.
class OfferDetails {
  const OfferDetails({
    required this.offer,
    this.target,
    this.benefits,
    this.notes,
    this.recipient,
  });

  /// The pay offered, as written, e.g. "₱45,000 a month".
  final String offer;

  /// What she hoped for, if she has a number in mind.
  final String? target;

  /// Everything else in the offer, e.g. HMO, 13th month, WFH.
  final String? benefits;

  /// Context such as other offers, a deadline or the start date.
  final String? notes;

  /// Who the email goes to, e.g. the recruiter's name.
  final String? recipient;
}

/// A plan for negotiating one offer: where it stands, what to ask for, how
/// to say it.
class NegotiationPlan {
  const NegotiationPlan({
    required this.verdict,
    required this.counterOffer,
    required this.walkAway,
    required this.marketNote,
    required this.talkingPoints,
    required this.alsoAskFor,
    required this.avoid,
    required this.emailSubject,
    required this.email,
    required this.callScript,
    required this.provider,
  });

  /// One line on how fair the offer looks.
  final String verdict;

  /// The amount to ask for, e.g. "₱52,000 a month".
  final String counterOffer;

  /// The lowest offer worth accepting; empty when there's no basis for one.
  final String walkAway;

  /// What pay for similar roles looks like, with a caveat.
  final String marketNote;
  final List<String> talkingPoints;

  /// Non-salary things worth asking for.
  final List<String> alsoAskFor;
  final List<String> avoid;
  final String emailSubject;
  final String email;
  final String callScript;
  final String provider;

  /// A plain-text summary for the application's notes.
  String toNote(DateTime date) => [
        'Negotiation plan (${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')})',
        'Counter: $counterOffer',
        if (walkAway.isNotEmpty) 'Lowest to accept: $walkAway',
        if (talkingPoints.isNotEmpty)
          'Talking points:\n${talkingPoints.map((p) => '- $p').join('\n')}',
        if (alsoAskFor.isNotEmpty) 'Also ask for: ${alsoAskFor.join(', ')}',
      ].join('\n');
}

/// Coaches salary negotiation with AI (Gemini, then Groq, then OpenAI),
/// grounded in the offer, her profile and salaries she has seen for
/// similar roles.
class NegotiationCoach {
  NegotiationCoach(this.ai);

  final AiChain ai;

  bool get isConfigured => ai.isConfigured;

  Future<NegotiationPlan> plan({
    required JobContext job,
    required OfferDetails offer,
    required CareerProfile profile,
    List<String> comparableSalaries = const [],
    String? senderName,
  }) async {
    String? clean(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
    final target = clean(offer.target);
    final benefits = clean(offer.benefits);
    final notes = clean(offer.notes);
    final recipient = clean(offer.recipient);
    final background = [
      if (profile.effectiveRoles.isNotEmpty)
        'Roles: ${profile.effectiveRoles.take(3).join(', ')}',
      if (profile.effectiveYears != null)
        'Years of experience: ${profile.effectiveYears}',
      if (profile.resume?.seniority != null)
        'Seniority: ${profile.resume!.seniority}',
      if (profile.effectiveSkills.isNotEmpty)
        'Key skills: ${profile.effectiveSkills.take(10).join(', ')}',
      if (profile.effectiveLocation != null)
        'Based in: ${profile.effectiveLocation}',
    ].join('\n');

    final reply = await ai.complete(
      AiRequest(
        json: true,
        webSearch: true,
        system: 'You are a calm, practical salary negotiation coach for job '
            'seekers in the Philippines (local and remote/international '
            'roles). You know Philippine pay norms: monthly salaries, 13th '
            'month pay, HMO, allowances, government contributions. Be honest '
            'and realistic: never push for an amount that could cost the '
            'candidate the offer, and say so when an offer is already fair. '
            'Never invent facts about the candidate. Reply with JSON only.',
        prompt: '''
Help me negotiate this job offer.
Job: ${job.label}${job.location == null ? '' : ' (${job.location})'}
Offer: ${offer.offer.trim()}
${target == null ? '' : 'What I hoped for: $target\n'}${benefits == null ? '' : 'Rest of the offer: $benefits\n'}${notes == null ? '' : 'Context: $notes\n'}
MY BACKGROUND
${background.isEmpty ? 'Not provided' : background}
${comparableSalaries.isEmpty ? '' : '\nSALARIES I HAVE SEEN FOR SIMILAR JOBS\n${comparableSalaries.map((s) => '- $s').join('\n')}\n'}
Search the web for current pay for this role and level in this location (or for remote roles hiring from the Philippines). Use it, and the salaries above, to judge the offer.

Keep the counter realistic: usually 5-15% above the offer, more only if the offer is clearly below market. Use the same currency and period as the offer. The email and call script are in my voice, warm and confident. Start the email with ${recipient == null ? '"Hi," or "Dear Hiring Team,"' : '"Hi $recipient,"'}; never use placeholders in brackets such as [Name]${senderName == null || senderName.trim().isEmpty ? '' : '; sign the email as ${senderName.trim()}'}.

Return JSON:
{
  "verdict": "<one sentence: below, around or above market, and why>",
  "counter_offer": "<the amount to ask for, e.g. ₱52,000 a month>",
  "walk_away": "<the lowest offer worth accepting, or an empty string if there's no basis>",
  "market_note": "<1-2 sentences on typical pay for this role, with a caveat that it's an estimate>",
  "talking_points": ["<3-4 reasons to give, grounded in my background and the role>"],
  "also_ask_for": ["<2-4 non-salary things worth asking for, e.g. signing bonus, WFH days, HMO dependents, earlier review>"],
  "avoid": ["<2-3 things not to say or do>"],
  "email_subject": "<short subject line>",
  "email": "<a short email asking for the counter, under 150 words, with line breaks>",
  "call_script": "<what to say on a call, 4-6 short lines>"
}''',
      ),
    );

    final json = extractJson(reply.text);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('AI did not return a negotiation plan');
    }
    String text(String key) =>
        json[key] is String ? stripCitations(json[key] as String) : '';
    List<String> list(String key, int max) => json[key] is List
        ? (json[key] as List)
            .whereType<String>()
            .map(stripCitations)
            .where((s) => s.isNotEmpty)
            .take(max)
            .toList()
        : const [];

    final plan = NegotiationPlan(
      verdict: text('verdict'),
      counterOffer: text('counter_offer'),
      walkAway: text('walk_away'),
      marketNote: text('market_note'),
      talkingPoints: list('talking_points', 4),
      alsoAskFor: list('also_ask_for', 4),
      avoid: list('avoid', 3),
      emailSubject: text('email_subject'),
      email: text('email'),
      callScript: text('call_script'),
      provider: reply.provider,
    );
    if (plan.counterOffer.isEmpty || plan.email.isEmpty) {
      throw const FormatException('AI returned an incomplete plan');
    }
    return plan;
  }
}
