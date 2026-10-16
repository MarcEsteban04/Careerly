import '../../../core/ai/ai_chain.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/json_extract.dart';
import '../../applications/data/job_application.dart';
import '../../profile/data/career_profile.dart';
import '../../studio/data/career_writer.dart';

/// The messages a job search needs, each with when to send it.
enum MessageKind {
  followUp('Follow-up', 'A polite nudge after applying'),
  thankYou('Thank-you', 'Within a day of an interview'),
  checkIn('Status check', 'No news a week after an interview'),
  acceptOffer('Accept offer', 'Say yes and confirm next steps'),
  declineOffer('Decline offer', 'Say no and keep the door open'),
  askFeedback('Ask for feedback', 'After a rejection, to learn from it'),
  withdraw('Withdraw', 'Step out of the process gracefully');

  const MessageKind(this.label, this.when);

  final String label;
  final String when;

  /// The message that usually fits an application's stage.
  static MessageKind suggestedFor(ApplicationStatus status) => switch (status) {
        ApplicationStatus.saved || ApplicationStatus.applied => followUp,
        ApplicationStatus.interviewing => thankYou,
        ApplicationStatus.offer => acceptOffer,
        ApplicationStatus.rejected => askFeedback,
      };
}

class DraftMessage {
  const DraftMessage({
    required this.subject,
    required this.body,
    required this.provider,
  });

  final String subject;
  final String body;
  final String provider;
}

/// Writes short, professional job-search emails with AI (Gemini, then
/// Groq, then OpenAI).
class MessageWriter {
  MessageWriter(this.ai);

  final AiChain ai;

  static String _purpose(MessageKind kind) => switch (kind) {
        MessageKind.followUp =>
          'Follow up on an application sent a while ago: restate interest in '
              'one line, add one relevant strength, ask about next steps.',
        MessageKind.thankYou =>
          'Thank the interviewer after an interview: thank them for their '
              'time, mention something specific from the conversation if '
              'given, reaffirm fit and interest.',
        MessageKind.checkIn =>
          'Check on the status after an interview with no news yet: '
              'friendly, brief, not pushy; reaffirm interest.',
        MessageKind.acceptOffer =>
          'Accept the job offer: thank them, accept clearly, confirm the '
              'start date and next steps or documents needed.',
        MessageKind.declineOffer =>
          'Decline the job offer: thank them sincerely, decline clearly '
              'without over-explaining, keep the relationship warm.',
        MessageKind.askFeedback =>
          'Respond to a rejection: thank them, accept gracefully, ask for '
              'brief feedback, and ask to be considered for future roles.',
        MessageKind.withdraw =>
          'Withdraw from the hiring process: thank them, withdraw clearly '
              'and politely, no lengthy reasons.',
      };

  Future<DraftMessage> write({
    required MessageKind kind,
    required JobContext job,
    required CareerProfile profile,
    String? senderName,
    String? recipientName,
    String? details,
  }) async {
    final recipient = recipientName?.trim() ?? '';
    final extra = details?.trim() ?? '';
    final reply = await ai.complete(
      AiRequest(
        json: true,
        system: 'You write short, warm, professional emails for job seekers '
            'in the Philippines applying to local and international '
            'companies. Plain, natural English; no clichés, no flattery, no '
            'placeholders in brackets. Never invent facts. Reply with JSON '
            'only.',
        prompt: '''
Write an email.
Purpose: ${_purpose(kind)}
Job: ${job.label}${job.location == null ? '' : ' (${job.location})'}
Greeting: ${recipient.isEmpty ? 'use "Hi," or "Dear Hiring Team,"' : 'address $recipient by name'}
Sender: ${senderName?.trim().isNotEmpty == true ? senderName!.trim() : 'the candidate'} (sign off with this name)
${profile.effectiveRoles.isEmpty ? '' : 'Candidate background: ${profile.effectiveRoles.take(2).join(', ')}${profile.effectiveYears == null ? '' : ', ${profile.effectiveYears} years of experience'}\n'}${extra.isEmpty ? '' : 'Mention this: $extra\n'}
Keep the body under 130 words, in 2-3 short paragraphs.

Return JSON: {"subject": "<short subject line>", "body": "<the email, with line breaks>"}''',
      ),
    );

    final json = extractJson(reply.text);
    final body = json is Map<String, dynamic> ? json['body'] : null;
    if (body is! String || body.trim().isEmpty) {
      throw const FormatException('AI did not return a message');
    }
    final subject = json is Map<String, dynamic> ? json['subject'] : null;
    return DraftMessage(
      subject: subject is String && subject.trim().isNotEmpty
          ? subject.trim()
          : '${job.title} application',
      body: body.trim(),
      provider: reply.provider,
    );
  }
}
