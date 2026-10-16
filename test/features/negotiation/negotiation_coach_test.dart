import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/features/negotiation/data/negotiation_coach.dart';
import 'package:careerly/features/profile/data/career_profile.dart';
import 'package:careerly/features/studio/data/career_writer.dart';

import '../../core/ai/fake_ai_provider.dart';

const planReply = '''
{"verdict": "A little below market for 2 years of experience.",
 "counter_offer": "₱52,000 a month",
 "walk_away": "₱48,000 a month",
 "market_note": "Similar roles in Manila pay about ₱45-60K. This is an estimate.",
 "talking_points": ["2 years shipping React apps", "Led a client launch"],
 "also_ask_for": ["Signing bonus", "HMO for a dependent"],
 "avoid": ["Accepting on the spot"],
 "email_subject": "Frontend Developer offer",
 "email": "Hi Ana,\\n\\nThank you for the offer...",
 "call_script": "Thank you for the offer. I'm excited..."}''';

void main() {
  const job = JobContext(title: 'Frontend Developer', company: 'Acme');

  test('builds a plan from the offer, profile and salaries seen', () async {
    final ai = FakeAiProvider('Gemini', reply: planReply);
    final coach = NegotiationCoach(AiChain([ai]));

    final plan = await coach.plan(
      job: job,
      offer: const OfferDetails(
        offer: '₱45,000 a month',
        benefits: 'HMO',
        recipient: 'Ana',
      ),
      profile: const CareerProfile(
        targetRoles: ['Frontend Developer'],
        yearsOfExperience: 2,
      ),
      comparableSalaries: const ['Web Developer at Globex: ₱55,000'],
      senderName: 'Princess',
    );

    expect(plan.counterOffer, '₱52,000 a month');
    expect(plan.walkAway, '₱48,000 a month');
    expect(plan.talkingPoints, hasLength(2));
    expect(plan.email, startsWith('Hi Ana,'));
    final prompt = ai.requests.single.prompt;
    expect(prompt, contains('₱45,000 a month'));
    expect(prompt, contains('Web Developer at Globex: ₱55,000'));
    expect(prompt, contains('Years of experience: 2'));
    expect(prompt, contains('sign the email as Princess'));
    expect(prompt, contains('"Hi Ana,"'));

    final note = plan.toNote(DateTime(2026, 10, 16));
    expect(note, contains('Negotiation plan (2026-10-16)'));
    expect(note, contains('Counter: ₱52,000 a month'));
  });

  test('a plan without a counter or email is an error', () async {
    final coach = NegotiationCoach(
      AiChain([FakeAiProvider('Gemini', reply: '{"verdict": "Fair"}')]),
    );

    expect(
      coach.plan(
        job: job,
        offer: const OfferDetails(offer: '₱45,000'),
        profile: const CareerProfile(),
      ),
      throwsFormatException,
    );
  });
}
