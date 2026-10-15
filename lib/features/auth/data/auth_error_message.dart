import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns Supabase auth errors into short, human-friendly copy.
String authErrorMessage(Object error) {
  if (error is AuthRetryableFetchException) {
    return "Can't reach the server. Check your connection and try again.";
  }
  if (error is AuthWeakPasswordException) {
    return 'That password is too weak. Use at least 8 characters with '
        'letters and numbers.';
  }
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return "That email and password don't match. Please try again.";
    }
    if (message.contains('email not confirmed')) {
      return 'Confirm your email first. Check your inbox for the link.';
    }
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return 'An account with this email already exists. Try signing in.';
    }
    if (message.contains('signups not allowed') ||
        message.contains('signup is disabled')) {
      return 'New sign-ups are turned off for this workspace.';
    }
    if (message.contains('email rate limit')) {
      return 'Too many emails sent. Try again in a few minutes.';
    }
    if (message.contains('invalid') && message.contains('email')) {
      return 'That email address looks invalid.';
    }
    if (error.statusCode == '429') {
      return 'Too many attempts. Wait a moment and try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
