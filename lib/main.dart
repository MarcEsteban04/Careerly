import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'features/auth/data/app_lock_repository.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/job_alerts/data/job_alert_worker.dart';
import 'features/notifications/data/local_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Env.ensureConfigured();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  try {
    await LocalNotifications.instance.init();
  } catch (e) {
    // The app works without notifications.
    debugPrint('Notifications unavailable: $e');
  }
  JobAlertWorker.start();

  runApp(
    CareerlyApp(
      authRepository: AuthRepository(),
      appLock: AppLockRepository(),
    ),
  );
}
