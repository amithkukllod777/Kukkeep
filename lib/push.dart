import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notifications.dart';

/// Firebase Cloud Messaging for KukKeep. Initializes Firebase (config baked in
/// from google-services.json by the Gradle plugin), asks for notification
/// permission, and subscribes to a broadcast topic so notifications can be sent
/// from the Firebase console to all KukKeep devices. Foreground messages are
/// surfaced via the local-notifications channel (FCM doesn't draw UI in the
/// foreground). All wrapped in try/catch so push setup can never crash the app.
class Push {
  Push._();
  static final Push instance = Push._();

  static const String broadcastTopic = 'kukkeep-all';
  String? token;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      final fm = FirebaseMessaging.instance;
      // No requestPermission() here — Notifications.init() already asks for the
      // POST_NOTIFICATIONS permission; asking twice shows back-to-back dialogs.
      try { token = await fm.getToken(); } catch (_) {}
      await fm.subscribeToTopic(broadcastTopic);
      // Foreground messages: show them ourselves (system tray only shows them
      // automatically when the app is backgrounded).
      FirebaseMessaging.onMessage.listen((RemoteMessage m) {
        final n = m.notification;
        if (n != null) {
          Notifications.instance.showNow(
            title: (n.title ?? 'KukKeep'),
            body: (n.body ?? ''),
          );
        }
      });
    } catch (_) {
      // Firebase not configured / offline — ignore, app still works.
    }
  }
}
