import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Local reminder notifications for KukKeep. Schedules an OS notification at a
/// note's reminder time using exact alarms (falling back to inexact if the
/// exact-alarm permission is denied), against the absolute instant so the time
/// is correct regardless of the device timezone.
class Notifications {
  Notifications._();
  static final Notifications instance = Notifications._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    'kukkeep_reminders',
    'Reminders',
    channelDescription: 'KukKeep note reminders',
    importance: Importance.max,
    priority: Priority.high,
  );

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      // Android 13+ runtime notification permission + exact-alarm permission
      // (so reminders fire ON TIME even when the device is idle/locked).
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();
      _ready = true;
    } catch (_) {
      // Never let notification setup crash the app.
    }
  }

  /// Schedule (or reschedule) a reminder for a note. No-op if the time is in the
  /// past. The note id doubles as the notification id so it can be cancelled.
  Future<void> schedule({required int noteId, required String title, required String body, required DateTime when}) async {
    if (!_ready) await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(noteId);
      if (when.isBefore(DateTime.now())) return;
      // TZDateTime.from preserves the absolute instant → correct real-world time.
      final scheduled = tz.TZDateTime.from(when, tz.UTC);
      Future<void> doSchedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
        noteId,
        title.isEmpty ? 'KukKeep reminder' : title,
        body,
        scheduled,
        const NotificationDetails(android: _androidDetails),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      try {
        await doSchedule(AndroidScheduleMode.exactAllowWhileIdle); // on time, even in Doze
      } catch (_) {
        // Exact-alarm permission denied (Android 12/12L can revoke it) —
        // an approximate reminder still beats no reminder at all.
        await doSchedule(AndroidScheduleMode.inexactAllowWhileIdle);
      }
    } catch (_) {/* ignore scheduling errors */}
  }

  // Drop every scheduled reminder — used on logout so the next user of the
  // device doesn't get the previous account's note titles as notifications.
  Future<void> cancelAll() async {
    if (!_ready) await init();
    try { await _plugin.cancelAll(); } catch (_) {}
  }

  Future<void> cancel(int noteId) async {
    if (!_ready) await init();
    try { await _plugin.cancel(noteId); } catch (_) {}
  }

  // Show a notification immediately (used for foreground FCM push messages).
  Future<void> showNow({required String title, required String body}) async {
    if (!_ready) await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title.isEmpty ? 'KukKeep' : title,
        body,
        const NotificationDetails(android: _androidDetails),
      );
    } catch (_) {}
  }
}
