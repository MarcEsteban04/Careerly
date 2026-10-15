import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether [error] means the database tables haven't been created yet.
bool isMissingSchemaError(Object error) =>
    error is PostgrestException &&
    (error.code == 'PGRST205' ||
        error.code == '42P01' ||
        error.message.contains('Could not find the table'));

/// Short, human-friendly copy for data-layer errors.
String friendlyErrorMessage(Object error) {
  if (isMissingSchemaError(error)) {
    return "Careerly's database isn't set up yet. Run the migration in "
        'supabase/migrations, then try again.';
  }
  if (error is AuthException || error is TimeoutException) {
    return "Can't reach the server. Check your connection and try again.";
  }
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup')) {
    return "Can't reach the server. Check your connection and try again.";
  }
  return 'Something went wrong. Please try again.';
}
