/// Configuration injected at build time with
/// `--dart-define-from-file=.env.app`.
///
/// This is a personal, sideloaded app, so the job search and AI keys are
/// bundled too. Never put the Supabase service role key here.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SB_PROJECT_URL');
  static const supabaseAnonKey = String.fromEnvironment('SB_ANON_KEY');

  static const jsearchApiKey = String.fromEnvironment('JSEARCH_API_KEY');
  static const joobleApiKey = String.fromEnvironment('JOOBLE_API_KEY');

  // AI providers, tried in this order: Gemini, then Groq, then OpenAI.
  static const geminiApiKey = String.fromEnvironment('GEMINI_AI_API_KEY');
  static const groqApiKey = String.fromEnvironment('GROQ_AI_API_KEY');
  static const openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');

  static void ensureConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Supabase config is missing. Run the app with '
        '--dart-define-from-file=.env.app (see README).',
      );
    }
  }
}
