import 'package:shared_preferences/shared_preferences.dart';

/// On/off switches for reminders and job alerts, kept on this device (the
/// background job-alert task reads them too).
class NotificationSettings {
  NotificationSettings([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _remindersKey = 'notifications.reminders';
  static const _jobAlertsKey = 'notifications.job_alerts';

  Future<bool> remindersEnabled() async =>
      await _prefs.getBool(_remindersKey) ?? true;

  Future<void> setRemindersEnabled(bool value) =>
      _prefs.setBool(_remindersKey, value);

  Future<bool> jobAlertsEnabled() async =>
      await _prefs.getBool(_jobAlertsKey) ?? true;

  Future<void> setJobAlertsEnabled(bool value) =>
      _prefs.setBool(_jobAlertsKey, value);
}
