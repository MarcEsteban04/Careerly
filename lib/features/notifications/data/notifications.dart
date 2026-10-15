/// Which Android channel a notification goes to. Users can mute each one
/// separately in system settings.
enum NotificationChannel {
  reminders(
    'reminders',
    'Reminders',
    'Interviews, follow-ups and deadlines from your agenda',
  ),
  jobAlerts(
    'job_alerts',
    'Job alerts',
    'New jobs for your saved searches',
  );

  const NotificationChannel(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;
}

/// One notification to show now or later.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.channel,
    required this.title,
    required this.body,
    this.payload,
  });

  final int id;
  final NotificationChannel channel;
  final String title;
  final String body;

  /// Where tapping it should go; see [NotificationRoute].
  final String? payload;
}

/// Device notifications. Abstract so tests and background tasks can swap
/// in their own implementation.
abstract class Notifications {
  /// Asks the OS for permission (Android 13+). Returns whether it's granted.
  Future<bool> requestPermission();

  Future<bool> isPermitted();

  Future<void> show(AppNotification notification);

  /// Shows [notification] at [at], local time.
  Future<void> schedule(AppNotification notification, DateTime at);

  /// Ids of notifications scheduled for later.
  Future<Set<int>> scheduledIds();

  Future<void> cancel(int id);

  /// Payloads of notifications the user taps while the app is running.
  Stream<String> get taps;

  /// The payload of the notification that launched the app, once.
  Future<String?> takeLaunchPayload();

  /// Opens the system notification settings for the app.
  Future<void> openSettings();
}

/// Where a notification tap leads.
sealed class NotificationRoute {
  const NotificationRoute();

  static NotificationRoute? parse(String? payload) {
    if (payload == null) return null;
    final separator = payload.indexOf(':');
    final kind = separator < 0 ? payload : payload.substring(0, separator);
    final id = separator < 0 ? '' : payload.substring(separator + 1);
    return switch (kind) {
      'application' when id.isNotEmpty => OpenApplicationRoute(id),
      'search' when id.isNotEmpty => OpenSavedSearchRoute(id),
      'agenda' => const OpenAgendaRoute(),
      _ => null,
    };
  }

  String get payload;
}

class OpenApplicationRoute extends NotificationRoute {
  const OpenApplicationRoute(this.applicationId);

  final String applicationId;

  @override
  String get payload => 'application:$applicationId';
}

class OpenSavedSearchRoute extends NotificationRoute {
  const OpenSavedSearchRoute(this.searchId);

  final String searchId;

  @override
  String get payload => 'search:$searchId';
}

class OpenAgendaRoute extends NotificationRoute {
  const OpenAgendaRoute();

  @override
  String get payload => 'agenda';
}

/// A stable 31-bit id for [key] (FNV-1a), so the same reminder always gets
/// the same notification id across app launches.
int stableNotificationId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
