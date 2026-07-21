import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'google_auth.dart';
import 'l10n/strings.dart';
import 'note_colors.dart';
import 'notifications.dart';
import 'push.dart';
import 'screens/notes_screen.dart';
import 'screens/auth_screen.dart';

/// App-wide theme mode (Light / Dark / System), persisted across launches.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> loadTheme() async {
  final p = await SharedPreferences.getInstance();
  switch (p.getString('kk_theme')) {
    case 'dark': themeNotifier.value = ThemeMode.dark; break;
    case 'light': themeNotifier.value = ThemeMode.light; break;
    default: themeNotifier.value = ThemeMode.system;
  }
}

Future<void> setThemeMode(ThemeMode m) async {
  themeNotifier.value = m;
  final p = await SharedPreferences.getInstance();
  await p.setString('kk_theme', m == ThemeMode.dark ? 'dark' : m == ThemeMode.light ? 'light' : 'system');
}

// Crash reporting (qa-audit: no monitoring existed). Safe to call before
// Firebase finishes initializing — Push.init() sets it up fire-and-forget
// shortly after this runs, and every call here is guarded so a
// reporting failure can never itself crash the app or block anything.
Future<void> _recordError(Object error, StackTrace? stack, {bool fatal = false}) async {
  try {
    if (Firebase.apps.isEmpty) return; // Firebase not ready yet — drop silently
    await FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
  } catch (_) {/* crash reporting must never itself throw */}
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Route every uncaught Flutter/platform error to Crashlytics, then run the
  // rest of startup inside the same guarded zone so async startup errors are
  // caught too. Registering handlers is instant (no await), so this can't
  // delay the first frame the way a real Firebase/notification init would.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _recordError(details.exception, details.stack, fatal: true);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _recordError(error, stack, fatal: true);
    return true;
  };
  runZonedGuarded(() async {
    await Api.instance.load();
    await loadTheme();
    await LocaleController.load();
    await Notifications.instance.loadPrefs();
    runApp(const KukKeepApp());
    // Notifications + Firebase push are optional and must NEVER block the first
    // frame — init them after the UI is up (a hang/failure here must not blank the
    // app). Fire-and-forget; both are internally guarded with try/catch.
    Notifications.instance.init();
    Push.instance.init();
    GoogleAuth.instance.init(); // listen for the kukkeep://auth sign-in deep link
  }, (error, stack) => _recordError(error, stack, fatal: true));
}

class KukKeepApp extends StatelessWidget {
  const KukKeepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => ValueListenableBuilder<Locale>(
        valueListenable: LocaleController.locale,
        builder: (_, locale, __) => MaterialApp(
        title: 'Kuk Keep',
        debugShowCheckedModeBanner: false,
        navigatorKey: GoogleAuth.navigatorKey,
        scaffoldMessengerKey: GoogleAuth.messengerKey,
        themeMode: mode,
        // Localization: user-selected language (Settings → Language), with
        // GlobalMaterialLocalizations providing built-in widget/date/RTL support.
        locale: locale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Inter is the shared KukLabs primary font (§5.1); it falls back to the
        // platform sans when the family isn't bundled.
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: kBrand,
          brightness: Brightness.light,
          scaffoldBackgroundColor: kBg, // #F8FAFC (standard neutral background)
          fontFamily: kFont,
          appBarTheme: const AppBarTheme(
            // Dark status-bar icons over the light canvas (P8).
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
            ),
          ),
          snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: kBrand,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0B1220), // standard dark background
          fontFamily: kFont,
          appBarTheme: const AppBarTheme(
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
            ),
          ),
          snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
        ),
        home: Api.instance.isLoggedIn ? const NotesScreen() : const AuthScreen(),
      ),
      ),
    );
  }
}
