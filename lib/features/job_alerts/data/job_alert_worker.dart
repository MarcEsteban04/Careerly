import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/config/env.dart';
import '../../discover/data/jooble_client.dart';
import '../../discover/data/jsearch_client.dart';
import '../../notifications/data/local_notifications.dart';
import '../../notifications/data/notification_settings.dart';
import 'job_alert_checker.dart';
import 'job_alert_store.dart';

const _taskName = 'careerly.job_alerts';

/// Builds a checker wired to the real job boards and device notifications.
JobAlertChecker buildJobAlertChecker() => JobAlertChecker(
      store: JobAlertStore(),
      settings: NotificationSettings(),
      notifications: LocalNotifications.instance,
      jsearch: JSearchClient(apiKey: Env.jsearchApiKey),
      jooble: JoobleClient(apiKey: Env.joobleApiKey),
    );

/// Entry point of the background isolate that checks job alerts.
@pragma('vm:entry-point')
void jobAlertsDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await buildJobAlertChecker().run();
      return true;
    } catch (e) {
      debugPrint('Background job alerts failed: $e');
      // Let WorkManager retry later.
      return false;
    }
  });
}

/// Schedules the daily background job-alert check.
abstract final class JobAlertWorker {
  static Future<void> start() async {
    try {
      await Workmanager().initialize(jobAlertsDispatcher);
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: JobAlertChecker.interval,
        initialDelay: const Duration(hours: 1),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      // Unsupported platform: alerts still run when the app opens.
      debugPrint('Job alert worker unavailable: $e');
    }
  }
}
