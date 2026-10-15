import '../../../core/ai/ai_chain.dart';
import '../../../core/utils/error_message.dart';
import '../data/studio_controller.dart';

/// Friendly copy for failures while generating documents.
String writerErrorMessage(Object error) => switch (error) {
      MissingResumeException() =>
        'Upload your resume first. Careerly writes from your real experience.',
      AiUnavailableException(allOutOfQuota: true) =>
        'Gemini, Groq and OpenAI are all out of credit right now. Try again '
            'later.',
      AiUnavailableException() =>
        "Couldn't reach the AI. Check your connection and try again.",
      FormatException() => 'The AI reply came back incomplete. Try again.',
      _ => friendlyErrorMessage(error),
    };
