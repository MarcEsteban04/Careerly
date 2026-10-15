/// Public, client-safe configuration injected at build time with
/// `--dart-define-from-file=.env.app`.
///
/// Only values that are safe to ship inside the app belong here. Server-side
/// secrets (service role key, AI provider keys) must never be read by the app.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SB_PROJECT_URL');
  static const supabaseAnonKey = String.fromEnvironment('SB_ANON_KEY');

  static void ensureConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Supabase config is missing. Run the app with '
        '--dart-define-from-file=.env.app (see README).',
      );
    }
  }
}
