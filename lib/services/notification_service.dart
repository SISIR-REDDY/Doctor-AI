import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules local (on-device) reminders for medications, vaccinations,
/// appointments and custom reminders. Fires even when the app is closed.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const String _channelId = 'clinix_reminders';
  static const String _channelName = 'Health Reminders';
  static const String _channelDesc =
      'Medication, vaccination and appointment reminders';

  /// Initializes timezones and the plugin. Safe to call multiple times.
  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final localName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localName));
      } catch (_) {
        // Fall back to UTC if the platform tz can't be resolved.
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: darwin),
      );
      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] init failed: $e');
    }
  }

  /// Requests notification + exact-alarm permission. Returns true if allowed.
  Future<bool> requestPermissions() async {
    await init();
    var granted = true;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        granted = await android.requestNotificationsPermission() ?? true;
        // Best-effort: needed for exact daily/scheduled alarms on Android 12+.
        await android.requestExactAlarmsPermission();
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        granted = await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            granted;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] perms failed: $e');
    }
    return granted;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Stable positive 31-bit id derived from a string key.
  static int idFor(String key) => key.hashCode & 0x7fffffff;

  /// A daily repeating reminder at [hour]:[minute] (used for medication doses).
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await init();
    await _zoned(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      DateTimeComponents.time, // repeat daily
    );
  }

  /// A one-off reminder at an absolute [when]. No-op if [when] is in the past.
  Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    await init();
    final scheduled = tz.TZDateTime.from(when, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _zoned(id, title, body, scheduled, null);
  }

  /// A reminder that repeats on a [recurrence] of none|daily|weekly|monthly,
  /// anchored at [first]. For 'none' this behaves like [scheduleOnce].
  Future<void> scheduleRecurring({
    required int id,
    required String title,
    required String body,
    required DateTime first,
    required String recurrence,
  }) async {
    await init();
    DateTimeComponents? match;
    switch (recurrence) {
      case 'daily':
        match = DateTimeComponents.time;
        break;
      case 'weekly':
        match = DateTimeComponents.dayOfWeekAndTime;
        break;
      case 'monthly':
        match = DateTimeComponents.dayOfMonthAndTime;
        break;
      default:
        match = null; // one-off
    }

    var scheduled = tz.TZDateTime.from(first, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (match == null) {
      if (scheduled.isBefore(now)) return;
    } else {
      // Roll forward to the next future occurrence keeping the matched fields.
      var guard = 0;
      while (scheduled.isBefore(now) && guard < 600) {
        guard++;
        if (recurrence == 'daily') {
          scheduled = scheduled.add(const Duration(days: 1));
        } else if (recurrence == 'weekly') {
          scheduled = scheduled.add(const Duration(days: 7));
        } else {
          scheduled = tz.TZDateTime(tz.local, scheduled.year,
              scheduled.month + 1, scheduled.day, scheduled.hour,
              scheduled.minute);
        }
      }
    }

    await _zoned(id, title, body, scheduled, match);
  }

  /// Schedules with an exact alarm, falling back to an inexact alarm if the OS
  /// denies exact-alarm permission (Android 12+). This guarantees the reminder
  /// is still scheduled rather than silently dropped.
  Future<void> _zoned(
    int id,
    String title,
    String body,
    tz.TZDateTime when,
    DateTimeComponents? match,
  ) async {
    Future<void> attempt(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          _details,
          androidScheduleMode: mode,
          matchDateTimeComponents: match,
        );
    try {
      await attempt(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] exact failed ($e); using inexact');
      }
      try {
        await attempt(AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (e2) {
        if (kDebugMode) debugPrint('[NotificationService] schedule failed: $e2');
      }
    }
  }

  /// Shows a notification immediately (used to surface foreground FCM pushes).
  Future<void> showNow({required String title, required String body}) async {
    await init();
    try {
      final id =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) & 0x7fffffff;
      await _plugin.show(id, title, body, _details);
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] showNow: $e');
    }
  }

  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
