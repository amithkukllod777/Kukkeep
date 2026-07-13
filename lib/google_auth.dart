import 'dart:async';
import 'dart:math' as math;
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'screens/notes_screen.dart';

/// "Continue with Google" — server-side OAuth in the phone browser.
///
/// The app opens keep.kuklabs.com/api/auth/google/start?app=kukkeep in the
/// external browser; after Google finishes, the server deep-links back to
/// kukkeep://auth?code=<one-time>. We trade that code for the same Bearer
/// session token directLogin issues. No SHA-1 / keystore registration needed —
/// the flow never touches Play Services, so it survives our CI's ephemeral
/// debug signing.
class GoogleAuth {
  GoogleAuth._();
  static final GoogleAuth instance = GoogleAuth._();

  /// Set on the MaterialApp so a deep link can navigate from outside any screen.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  static Future<bool>? _enabledFut;
  /// Cached availability probe (one network call per app run).
  static Future<bool> enabled() => _enabledFut ??= Api.instance.googleEnabled();

  StreamSubscription<Uri>? _sub;
  String? _lastCode; // codes are one-time; never exchange the same one twice

  /// Start listening for the kukkeep://auth deep link. Fire-and-forget from
  /// main() — a failure here only means the Google button can't complete.
  Future<void> init() async {
    if (_sub != null) return;
    try {
      final links = AppLinks();
      try {
        final initial = await links.getInitialLink(); // app cold-started by the link
        if (initial != null) _handle(initial);
      } catch (_) {}
      _sub = links.uriLinkStream.listen(_handle, onError: (_) {});
    } catch (_) {/* plugin unavailable — email login keeps working */}
  }

  /// Open the Google sign-in page in the external browser.
  Future<void> signIn() async {
    try {
      final ok = await launchUrl(Uri.parse(Api.googleStartUrl), mode: LaunchMode.externalApplication);
      if (!ok) _toast('Could not open the browser.');
    } catch (_) {
      _toast('Could not open the browser.');
    }
  }

  Future<void> _handle(Uri uri) async {
    if (uri.scheme != 'kukkeep' || uri.host != 'auth') return;
    final err = uri.queryParameters['error'] ?? '';
    if (err.isNotEmpty) { _toast('Google sign-in was cancelled.'); return; }
    final code = uri.queryParameters['code'] ?? '';
    if (code.isEmpty || code == _lastCode) return;
    _lastCode = code;
    try {
      await Api.instance.googleExchange(code);
      // Brand-new Google accounts have no workspace yet — silently create one.
      final cid = await Api.instance.ensureCompany(name: Api.instance.userName ?? 'My Notes');
      if (cid == null) { _toast('Could not set up your workspace — please try again.'); return; }
      navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const NotesScreen()), (r) => false);
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _toast(String m) =>
      messengerKey.currentState?.showSnackBar(SnackBar(content: Text(m)));
}

/// The multicolor Google "G", drawn as four ring segments + the blue crossbar
/// (official brand colors) — no image asset needed, crisp at any size.
class _GoogleG extends StatelessWidget {
  final double size;
  const _GoogleG({this.size = 18});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GoogleGPainter());
}

class _GoogleGPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.22;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s - stroke, s - stroke);
    double deg(double d) => d * math.pi / 180;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    // Canvas angles: 0° = 3 o'clock, positive = clockwise. The ring opens
    // between -45° and 0° (top-right), where the crossbar enters.
    canvas.drawArc(rect, deg(0), deg(45), false, p..color = _blue);     // right → bottom-right
    canvas.drawArc(rect, deg(45), deg(90), false, p..color = _green);   // bottom
    canvas.drawArc(rect, deg(135), deg(60), false, p..color = _yellow); // bottom-left
    canvas.drawArc(rect, deg(195), deg(120), false, p..color = _red);   // left → top → top-right
    // Crossbar: center to the outer right edge, same band as the 0° stroke.
    final c = s / 2;
    canvas.drawRect(Rect.fromLTRB(c, c - stroke / 2, s, c + stroke / 2), Paint()..color = _blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// White "Continue with Google" pill. Renders nothing until the server reports
/// Google OAuth is configured, so shipping ahead of the credentials is safe.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: GoogleAuth.enabled(),
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        return SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: () => GoogleAuth.instance.signIn(),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              _GoogleG(size: 20),
              SizedBox(width: 10),
              Text('Continue with Google',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            ]),
          ),
        );
      },
    );
  }
}
