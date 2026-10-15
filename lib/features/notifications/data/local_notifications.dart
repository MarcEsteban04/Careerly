import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notifications.dart';

/// [Notifications] backed by the OS, via flutter_local_notifications.
class LocalNotifications implements Notifications {
  LocalNotifications._();

  /// One per isolate: the app and the background job-alert task each get
  /// their own.
  static final instance = LocalNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  Future<void>? _ready;
  bool _launchPayloadTaken = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Sets up time zones, channels and tap handling. Safe to call repeatedly.
  Future<void> init() => _ready ??= _init();

  Future<void> _init() async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      // Unknown zone name: fall back to the device's UTC offset via Manila,
      // where Careerly is used.
      debugPrint('Time zone lookup failed: $e');
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _taps.add(payload);
      },
    );

    for (final channel in NotificationChannel.values) {
      await _android?.createNotificationChannel(
        AndroidNotificationChannel(
          channel.id,
          channel.label,
          description: channel.description,
          importance: channel == NotificationChannel.reminders
              ? Importance.high
              : Importance.defaultImportance,
        ),
      );
    }
  }

  NotificationDetails _details(NotificationChannel channel) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.label,
          channelDescription: channel.description,
          importance: channel == NotificationChannel.reminders
              ? Importance.high
              : Importance.defaultImportance,
          priority: channel == NotificationChannel.reminders
              ? Priority.high
              : Priority.defaultPriority,
          category: channel == NotificationChannel.reminders
              ? AndroidNotificationCategory.reminder
              : AndroidNotificationCategory.recommendation,
          color: const Color(0xFF2563EB),
          styleInformation: const BigTextStyleInformation(''),
        ),
        iOS: const DarwinNotificationDetails(),
      );

  @override
  Future<bool> requestPermission() async {
    await init();
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  @override
  Future<bool> isPermitted() async {
    await init();
    return await _android?.areNotificationsEnabled() ?? true;
  }

  @override
  Future<void> show(AppNotification notification) async {
    await init();
    await _plugin.show(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      notificationDetails: _details(notification.channel),
      payload: notification.payload,
    );
  }

  @override
  Future<void> schedule(AppNotification notification, DateTime at) async {
    await init();
    // Exact alarms keep "in 1 hour" honest; fall back to inexact (a few
    // minutes late at most) when the OS doesn't allow them.
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details(notification.channel),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: notification.payload,
    );
  }

  @override
  Future<Set<int>> scheduledIds() async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    return {for (final request in pending) request.id};
  }

  @override
  Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id: id);
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> takeLaunchPayload() async {
    await init();
    if (_launchPayloadTaken) return null;
    _launchPayloadTaken = true;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details!.notificationResponse?.payload;
  }

  @override
  Future<void> openSettings() async {
    await init();
    await _plugin.openAppNotificationSettings();
  }
}
