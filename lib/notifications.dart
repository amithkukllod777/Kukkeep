import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Local reminder notifications for KukKeep. Schedules an OS notification at a
/// note's reminder time using exact alarms (falling back to inexact if the
/// exact-alarm permission is denied), against the absolute instant so the time
/// is correct regardless of the device timezone.
///
/// Delivery notes (why a reminder might not fire, and what this does about it):
///  - The channel is created **explicitly** with max importance + sound. A new
///    channel id (`_v2`) is used so devices that already had the old channel
///    (possibly created with the wrong importance/sound and then cached by
///    Android, which ignores later code changes) get a correctly-configured one.
///  - Notification + exact-alarm permissions are (re)requested on demand.
///  - On aggressive OEMs (Samsung/Xiaomi/etc.) the app must also be exempt from
///    battery optimization — Settings exposes a shortcut to that system screen.
class Notifications {
  Notifications._();
  static final Notifications instance = Notifications._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // Fresh channel ids. Android caches a channel's sound/importance at CREATION
  // time and ignores later code changes, so a device that created an earlier
  // channel silently keeps it silent — bumping the id forces a correct one.
  static const String _channelSound = 'kukkeep_reminders_v3';
  static const String _channelSilent = 'kukkeep_reminders_silent_v3';

  // ── User preferences (Settings → Notifications) ──
  static const _kRemindersKey = 'kk_reminders_enabled';
  static const _kSoundKey = 'kk_reminders_sound';
  bool _remindersEnabled = true;
  bool _soundEnabled = true;
  bool get remindersEnabled => _remindersEnabled;
  bool get soundEnabled => _soundEnabled;

  Future<void> loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      _remindersEnabled = p.getBool(_kRemindersKey) ?? true;
      _soundEnabled = p.getBool(_kSoundKey) ?? true;
    } catch (_) {/* defaults on */}
  }

  Future<void> setRemindersEnabled(bool on) async {
    _remindersEnabled = on;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kRemindersKey, on);
    } catch (_) {}
    if (!on) await cancelAll(); // drop any already-armed reminders
  }

  Future<void> setSoundEnabled(bool on) async {
    _soundEnabled = on;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kSoundKey, on);
    } catch (_) {}
  }

  AndroidNotificationDetails get _androidDetails => AndroidNotificationDetails(
        _soundEnabled ? _channelSound : _channelSilent,
        _soundEnabled ? 'Reminders' : 'Reminders (silent)',
        channelDescription: 'KukKeep note reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: _soundEnabled,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
      );

  Future<void> init() async {
    if (_ready) return;
    try { tzdata.initializeTimeZones(); } catch (_) {}
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
    } catch (_) {
      return; // core plugin init failed — retry on the next call
    }
    // CRITICAL: mark ready as soon as the plugin core is up. Everything below
    // is best-effort — a throwing permission/channel call must NOT leave the
    // whole notification system disabled (that was why nothing fired at all).
    _ready = true;
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    // Create both channels up front with the correct config (importance + sound).
    try {
      await a?.createNotificationChannel(const AndroidNotificationChannel(
        _channelSound, 'Reminders',
        description: 'KukKeep note reminders',
        importance: Importance.max, playSound: true, enableVibration: true,
      ));
    } catch (_) {}
    try {
      await a?.createNotificationChannel(const AndroidNotificationChannel(
        _channelSilent, 'Reminders (silent)',
        description: 'KukKeep note reminders without sound',
        importance: Importance.high, playSound: false, enableVibration: true,
      ));
    } catch (_) {}
    // Android 13+ runtime notification permission + exact-alarm permission,
    // each independently guarded.
    try { await a?.requestNotificationsPermission(); } catch (_) {}
    try { await a?.requestExactAlarmsPermission(); } catch (_) {}
  }

  /// (Re)request notification + exact-alarm permissions. Safe to call anytime
  /// (e.g. from Settings when the user is fixing reminders).
  Future<void> requestPermissions() async {
    if (!_ready) await init();
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try { await a?.requestNotificationsPermission(); } catch (_) {}
    try { await a?.requestExactAlarmsPermission(); } catch (_) {}
  }

  /// Whether the OS currently lets this app post notifications. When false,
  /// nothing we do will show — the user must enable them in system settings.
  Future<bool> areEnabled() async {
    if (!_ready) await init();
    try {
      final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return (await a?.areNotificationsEnabled()) ?? true;
    } catch (_) {
      return true; // unknown — don't block the happy path
    }
  }

  /// Immediate diagnostic notification (NOT scheduled — bypasses the alarm
  /// subsystem entirely). Returns false if the OS is blocking notifications, so
  /// the caller can send the user to system settings to enable them.
  Future<bool> sendTestNow() async {
    if (!_ready) await init();
    if (!_ready) return false;
    try {
      final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      try { await a?.requestNotificationsPermission(); } catch (_) {}
      final enabled = (await a?.areNotificationsEnabled()) ?? true;
      if (!enabled) return false;
      // 1) Immediate notification — proves display + sound (channel) work now.
      await _plugin.show(
        2147483645,
        'Kuk Keep',
        'Test notification — you should hear a sound \u{1F514}',
        NotificationDetails(android: _androidDetails),
      );
      // 2) A 10-second SCHEDULED reminder — proves the alarm path works
      //    end-to-end (this is what real note reminders use).
      try { await a?.requestExactAlarmsPermission(); } catch (_) {}
      await _scheduleAt(
        2147483644,
        'Kuk Keep',
        'Scheduled test fired on time \u{23F0} — reminders work',
        DateTime.now().add(const Duration(seconds: 10)),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // Shared scheduling core. Ignores the user's on/off pref so it can also power
  // the "send test reminder" diagnostic.
  Future<void> _scheduleAt(int id, String title, String body, DateTime when) async {
    if (!_ready) await init();
    if (!_ready) return;
    await _plugin.cancel(id);
    if (when.isBefore(DateTime.now())) return;
    // TZDateTime.from preserves the absolute instant → correct real-world time.
    final scheduled = tz.TZDateTime.from(when, tz.UTC);
    final details = NotificationDetails(android: _androidDetails);
    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          title.isEmpty ? 'Kuk Keep reminder' : title,
          body,
          scheduled,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
    try {
      await go(AndroidScheduleMode.exactAllowWhileIdle); // on time, even in Doze
    } catch (_) {
      // Exact-alarm permission denied — an approximate reminder still beats none.
      try {
        await go(AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (_) {}
    }
  }

  /// Schedule (or reschedule) a reminder for a note. No-op if reminders are off
  /// or the time is in the past. The note id doubles as the notification id.
  Future<void> schedule({required int noteId, required String title, required String body, required DateTime when}) async {
    if (!_remindersEnabled) return; // user turned reminders off (Settings)
    try {
      await _scheduleAt(noteId, title, body, when);
    } catch (_) {/* ignore scheduling errors */}
  }

  /// Fires a reminder ~5 seconds from now through the real scheduling path, so
  /// the user can confirm reminders actually reach them (Settings → test).
  Future<void> scheduleTest() async {
    try {
      await _scheduleAt(
        2147483646, // a fixed, out-of-range-for-notes id
        'Kuk Keep',
        'Test reminder — reminders are working \u{1F514}',
        DateTime.now().add(const Duration(seconds: 5)),
      );
    } catch (_) {}
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
        title.isEmpty ? 'Kuk Keep' : title,
        body,
        NotificationDetails(android: _androidDetails),
      );
    } catch (_) {}
  }
}
