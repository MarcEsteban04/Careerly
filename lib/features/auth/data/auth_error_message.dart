import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns Supabase auth errors into short, human-friendly copy.
String authErrorMessage(Object error) {
  if (error is AuthRetryableFetchException) {
    return "Can't reach the server. Check your connection and try again.";
  }
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return "That email and password don't match. Please try again.";
    }
    if (message.contains('email not confirmed')) {
      return 'This email hasn\'t been confirmed yet.';
    }
    if (error.statusCode == '429') {
      return 'Too many attempts. Wait a moment and try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
