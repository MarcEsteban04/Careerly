import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/features/applications/data/job_application.dart';
import 'package:careerly/features/messages/data/message_writer.dart';
import 'package:careerly/features/profile/data/career_profile.dart';
import 'package:careerly/features/studio/data/career_writer.dart';

import '../../core/ai/fake_ai_provider.dart';

void main() {
  const job = JobContext(title: 'UI Designer', company: 'Acme');

  test('writes a subject and body, signed by the sender', () async {
    final ai = FakeAiProvider(
      'Gemini',
      reply: '{"subject": "Thank you, Ana", "body": "Hi Ana,\\n\\nThank you..."}',
    );
    final writer = MessageWriter(AiChain([ai]));

    final draft = await writer.write(
      kind: MessageKind.thankYou,
      job: job,
      profile: const CareerProfile(targetRoles: ['UI Designer']),
      senderName: 'Princess',
      recipientName: 'Ana',
      details: 'We talked about their design system',
    );

    expect(draft.subject, 'Thank you, Ana');
    expect(draft.body, startsWith('Hi Ana,'));
    expect(draft.provider, 'Gemini');
    final prompt = ai.requests.single.prompt;
    expect(prompt, contains('Princess'));
    expect(prompt, contains('address Ana by name'));
    expect(prompt, contains('design system'));
  });

  test('falls back to a plain subject', () async {
    final writer = MessageWriter(
      AiChain([FakeAiProvider('Groq', reply: '{"body": "Hello"}')]),
    );

    final draft = await writer.write(
      kind: MessageKind.followUp,
      job: job,
      profile: const CareerProfile(),
    );

    expect(draft.subject, 'UI Designer application');
  });

  test('suggests the message that fits each stage', () {
    expect(MessageKind.suggestedFor(ApplicationStatus.applied),
        MessageKind.followUp);
    expect(MessageKind.suggestedFor(ApplicationStatus.interviewing),
        MessageKind.thankYou);
    expect(MessageKind.suggestedFor(ApplicationStatus.offer),
        MessageKind.acceptOffer);
    expect(MessageKind.suggestedFor(ApplicationStatus.rejected),
        MessageKind.askFeedback);
  });
}
