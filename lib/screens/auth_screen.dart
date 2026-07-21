import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../auth_messages.dart';
import '../google_auth.dart';
import '../models.dart';
import '../note_colors.dart';
import 'notes_screen.dart';
import 'otp_screen.dart';

/// Unified authentication screen — the single logged-out surface for KukKeep.
///
/// Follows the Kuklabs UI/Auth standard (docs/kuklabs/KUKLABS_MASTER_STANDARD.md
/// §8, APPROVED_LOGIN_REFERENCE.png): product icon → "Welcome to" → product
/// name → tagline → Login/Sign Up tabs → form → primary action → OR →
/// Continue with Google → Terms/Privacy → Powered by Kuklabs. Only the product
/// icon, name, tagline and accent are product-specific; the structure, sizes
/// (KUKLABS_DESIGN_TOKENS.json authPage) and content (AuthMessages) are shared
/// across every Kuk app.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int _tab = 0; // 0 = Login, 1 = Sign Up

  // Login
  final _loginId = TextEditingController();
  final _loginPass = TextEditingController();
  bool _loginObscure = true;

  // Sign Up
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _signupPass = TextEditingController();
  bool _signupObscure = true;
  bool _accepted = false;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _loginId.dispose();
    _loginPass.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _signupPass.dispose();
    super.dispose();
  }

  void _switchTab(int t) {
    if (_tab == t) return;
    setState(() { _tab = t; _error = null; });
  }

  // ── Login ──
  Future<void> _login() async {
    final id = _loginId.text.trim();
    final pass = _loginPass.text;
    if (id.isEmpty) { setState(() => _error = AuthMessages.emptyIdentity); return; }
    if (pass.isEmpty) { setState(() => _error = AuthMessages.emptyPassword); return; }
    // Backend login is email-based; mobile-number login is not available yet.
    if (!id.contains('@')) { setState(() => _error = 'Mobile-number login is coming soon — please log in with your email address.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await Api.instance.login(id, pass);
      final companies = await Api.instance.companies();
      if (!mounted) return;
      if (companies.isEmpty) {
        final cid = await Api.instance.ensureCompany(name: Api.instance.userName ?? 'My Notes');
        if (!mounted) return;
        if (cid == null) { setState(() => _error = 'Could not set up your workspace — please try again.'); return; }
        _goToNotes();
      } else if (companies.length == 1) {
        Api.instance.setCompany(companies.first.id);
        _goToNotes();
      } else {
        _pickCompany(companies);
      }
    } catch (e) {
      setState(() => _error = friendlyAuthError(e, signIn: true));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Sign Up ──
  Future<void> _signup() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    final pass = _signupPass.text;
    if (name.length < 2) { setState(() => _error = 'Enter your full name.'); return; }
    if (!email.contains('@')) { setState(() => _error = AuthMessages.invalidEmail); return; }
    if (phone.replaceAll(RegExp(r'[^0-9]'), '').length < 10) { setState(() => _error = AuthMessages.invalidPhone); return; }
    if (pass.length < 8 || !pass.contains(RegExp(r'[A-Za-z]')) || !pass.contains(RegExp(r'[0-9]'))) {
      setState(() => _error = AuthMessages.weakPassword); return;
    }
    if (!_accepted) { setState(() => _error = AuthMessages.termsRequired); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await Api.instance.register(name: name, email: email, phone: phone, password: pass);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OtpScreen(email: email, name: name, phone: phone)));
    } catch (e) {
      setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToNotes() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const NotesScreen()), (r) => false);
  }

  void _pickCompany(List<Company> companies) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(padding: EdgeInsets.all(16),
            child: Text('Choose a workspace', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          for (final c in companies)
            ListTile(
              leading: const Icon(Icons.business, color: kBrand),
              title: Text(c.name),
              onTap: () { Api.instance.setCompany(c.id); Navigator.pop(context); _goToNotes(); },
            ),
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      // resizeToAvoidBottomInset lets the scroll view handle the keyboard.
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          // Scale the header/typography to the viewport so the whole screen
          // fits WITHOUT scrolling on any phone; the scroll view only kicks in
          // when the keyboard shrinks the available height.
          final h = c.maxHeight;
          final tight = h < 680;
          final headerH = (h * 0.20).clamp(120.0, 180.0).toDouble();
          final iconSize = (h * 0.105).clamp(58.0, 84.0).toDouble();
          final nameSize = tight ? 30.0 : 38.0;
          final gap = tight ? 10.0 : 16.0;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: h),
              child: ConstrainedBox(
                // authPage.contentMaxWidthMobile (KUKLABS_DESIGN_TOKENS.json)
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Collage header + product icon (assets/logo.png) ──
                      SizedBox(
                        height: headerH,
                        child: Stack(alignment: Alignment.center, children: [
                          const Positioned.fill(child: _CollageBackground()),
                          Image.asset(kLogoAsset, width: iconSize, height: iconSize),
                        ]),
                      ),
                      const SizedBox(height: 2),
                      Text('Welcome to', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: tight ? 20 : 23, height: 1.2, fontWeight: FontWeight.w500, color: kTextPrimary, fontFamily: kFont)),
                      Text.rich(
                        const TextSpan(children: [
                          TextSpan(text: 'Kuk ', style: TextStyle(color: kTextPrimary)),
                          TextSpan(text: 'Keep', style: TextStyle(color: kBrand)),
                        ]),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: nameSize, height: 1.1, fontWeight: FontWeight.w800, fontFamily: kFont),
                      ),
                      SizedBox(height: tight ? 4 : 6),
                      Text(AuthMessages.tagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: tight ? 14 : 15, height: 1.35, color: kTextMuted, fontFamily: kFont)),
                      SizedBox(height: gap + 4),
                      _tabs(),
                      SizedBox(height: gap),
                      if (_tab == 0) _loginForm() else _signupForm(),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center,
                            style: const TextStyle(color: kError, fontSize: 13, fontFamily: kFont)),
                      ],
                      SizedBox(height: gap),
                      _primaryButton(),
                      SizedBox(height: gap),
                      _orDivider(),
                      SizedBox(height: gap),
                      const GoogleSignInButton(),
                      const SizedBox(height: 2),
                      _legal(),
                      SizedBox(height: tight ? 6 : 10),
                      _poweredBy(),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Login / Sign Up tabs (56 high, radius 16 — authPage tokens) ──
  Widget _tabs() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Row(children: [
        Expanded(child: _tabItem(AuthMessages.login, 0)),
        Container(width: 1, height: 28, color: kBorderSubtle),
        Expanded(child: _tabItem(AuthMessages.signup, 1)),
      ]),
    );
  }

  Widget _tabItem(String label, int i) {
    final active = _tab == i;
    return InkWell(
      onTap: () => _switchTab(i),
      borderRadius: BorderRadius.circular(16),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(
          fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600, fontFamily: kFont,
          color: active ? kBrand : kTextSecondary)),
        const SizedBox(height: 6),
        Container(height: 2, width: 96,
          decoration: BoxDecoration(
            color: active ? kBrand : Colors.transparent,
            borderRadius: BorderRadius.circular(2))),
      ]),
    );
  }

  Widget _loginForm() {
    return Column(children: [
      _field(controller: _loginId, hint: AuthMessages.identity, icon: Icons.smartphone_outlined,
          keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.username]),
      const SizedBox(height: 14),
      _field(controller: _loginPass, hint: AuthMessages.password, icon: Icons.lock_outline,
          obscure: _loginObscure, autofill: const [AutofillHints.password],
          onSubmit: (_) => _login(),
          suffix: _eyeToggle(_loginObscure, () => setState(() => _loginObscure = !_loginObscure))),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: () => _open('$kWebBase/forgot-password'),
          child: const Text(AuthMessages.forgotPassword,
              style: TextStyle(color: kBrand, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500, fontFamily: kFont)),
        ),
      ),
    ]);
  }

  Widget _signupForm() {
    return Column(children: [
      _field(controller: _name, hint: AuthMessages.fullName, icon: Icons.person_outline,
          keyboard: TextInputType.name, capitalize: TextCapitalization.words),
      const SizedBox(height: 14),
      _field(controller: _email, hint: 'Email address', icon: Icons.mail_outline, keyboard: TextInputType.emailAddress),
      const SizedBox(height: 14),
      _field(controller: _phone, hint: 'Mobile number', icon: Icons.smartphone_outlined, keyboard: TextInputType.phone),
      const SizedBox(height: 14),
      _field(controller: _signupPass, hint: AuthMessages.password, icon: Icons.lock_outline,
          obscure: _signupObscure,
          suffix: _eyeToggle(_signupObscure, () => setState(() => _signupObscure = !_signupObscure))),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 24, width: 24,
          child: Checkbox(value: _accepted, activeColor: kBrand,
            onChanged: (v) => setState(() => _accepted = v ?? false)),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Padding(
          padding: EdgeInsets.only(top: 3),
          child: Text('I accept the Terms & Privacy Policy and I am 18 or older.',
              style: TextStyle(fontSize: 13, height: 18 / 13, color: kTextMuted, fontFamily: kFont)),
        )),
      ]),
    ]);
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboard,
    TextCapitalization capitalize = TextCapitalization.none,
    List<String>? autofill,
    ValueChanged<String>? onSubmit,
  }) {
    // authPage.inputHeight 58 / radius 16 (KUKLABS_DESIGN_TOKENS.json)
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          textCapitalization: capitalize,
          autofillHints: autofill,
          onSubmitted: onSubmit,
          style: const TextStyle(fontSize: 16, height: 24 / 16, color: kTextPrimary, fontFamily: kFont),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: kPlaceholder, fontSize: 16, fontFamily: kFont),
            prefixIcon: Icon(icon, size: 22, color: kTextMuted),
            suffixIcon: suffix,
            border: InputBorder.none,
            isCollapsed: false,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _eyeToggle(bool obscured, VoidCallback onTap) => IconButton(
        icon: Icon(obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 22, color: kTextMuted),
        onPressed: onTap,
      );

  Widget _primaryButton() {
    final label = _tab == 0 ? AuthMessages.login : AuthMessages.createAccount;
    // authPage.buttonHeight 58 / radius 16 (KUKLABS_DESIGN_TOKENS.json)
    return SizedBox(
      height: 58,
      child: FilledButton(
        onPressed: _loading ? null : (_tab == 0 ? _login : _signup),
        style: FilledButton.styleFrom(
          backgroundColor: kBrand,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _loading
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w600, fontFamily: kFont)),
      ),
    );
  }

  Widget _orDivider() => Row(children: const [
        Expanded(child: Divider(color: kBorderSubtle)),
        Padding(padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: TextStyle(color: kTextMuted, fontSize: 14, fontFamily: kFont))),
        Expanded(child: Divider(color: kBorderSubtle)),
      ]);

  Widget _legal() {
    const style = TextStyle(fontSize: 13, height: 19 / 13, color: kTextMuted, fontFamily: kFont);
    const link = TextStyle(fontSize: 13, height: 19 / 13, color: kBrand, fontWeight: FontWeight.w600, fontFamily: kFont);
    return Text.rich(
      TextSpan(style: style, children: [
        const TextSpan(text: 'By continuing, you agree to our '),
        WidgetSpan(child: GestureDetector(onTap: () => _open(kTermsUrl),
            child: const Text('Terms of Use', style: link))),
        const TextSpan(text: ' and '),
        WidgetSpan(child: GestureDetector(onTap: () => _open(kPrivacyUrl),
            child: const Text('Privacy Policy', style: link))),
      ]),
      textAlign: TextAlign.center,
    );
  }

  // §6.3: "Powered by" 400 muted + "Kuklabs" 600 secondary — never the accent.
  Widget _poweredBy() => Text.rich(
        const TextSpan(children: [
          TextSpan(text: '${AuthMessages.poweredBy} ', style: TextStyle(color: kTextMuted, fontSize: 13, height: 18 / 13, fontFamily: kFont)),
          TextSpan(text: AuthMessages.poweredByBrand, style: TextStyle(color: kTextSecondary, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600, fontFamily: kFont)),
        ]),
        textAlign: TextAlign.center,
      );
}

/// Faded, tilted note cards behind the product icon (the Kuklabs auth collage).
class _CollageBackground extends StatelessWidget {
  const _CollageBackground();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      Widget card(double dx, double dy, double w, double angle, Color c, {bool check = false}) {
        final width = box.maxWidth * w;
        return Positioned(
          left: box.maxWidth * dx,
          top: box.maxHeight * dy,
          child: Transform.rotate(
            angle: angle * math.pi / 180,
            child: Opacity(
              opacity: 0.5,
              child: Container(
                width: width, height: width * 0.82,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(14)),
                child: check
                    ? Align(alignment: Alignment.bottomLeft, child: Icon(Icons.check_circle, size: width * 0.28, color: Colors.white.withOpacity(0.8)))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        _line(width * 0.6), const SizedBox(height: 6), _line(width * 0.42),
                      ]),
              ),
            ),
          ),
        );
      }

      return Stack(clipBehavior: Clip.none, children: [
        card(-0.14, -0.10, 0.30, -12, const Color(0xFFB794F4), check: true),
        card(0.16, -0.28, 0.30, 8, const Color(0xFF60A5FA)),
        card(0.60, -0.24, 0.30, -6, const Color(0xFFF9A8D4)),
        card(0.80, 0.02, 0.30, 10, const Color(0xFF34D399), check: true),
        card(0.72, 0.42, 0.30, -8, const Color(0xFFFBBF77)),
      ]);
    });
  }

  static Widget _line(double w) => Container(height: 4, width: w,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(3)));
}
