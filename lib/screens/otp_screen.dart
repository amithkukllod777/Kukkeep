import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../auth_messages.dart';
import '../note_colors.dart';
import 'notes_screen.dart';

/// Step 2 of signup: verify the 6-digit email OTP, then ensure the new account
/// has a free workspace and land in the notes board.
class OtpScreen extends StatefulWidget {
  final String email;
  final String name;
  final String phone;
  const OtpScreen({super.key, required this.email, required this.name, required this.phone});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otp = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _info;
  // Resend cooldown (P16) — stops accidental double-taps from spamming emails.
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _otp.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { if (_cooldown > 0) _cooldown--; if (_cooldown == 0) t.cancel(); });
    });
  }

  Future<void> _verify() async {
    final code = _otp.text.trim();
    if (code.length != 6) { setState(() => _error = 'Enter the 6-digit code.'); return; }
    setState(() { _loading = true; _error = null; _info = null; });
    try {
      await Api.instance.verifyOtp(widget.email, code);
      // New account → make sure a free workspace exists, then open notes.
      final cid = await Api.instance.ensureCompany(name: widget.name, phone: widget.phone);
      if (cid == null) { setState(() => _error = 'Could not set up your workspace — please try again.'); return; }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const NotesScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    setState(() { _error = null; _info = null; });
    try {
      await Api.instance.resendOtp(widget.email);
      setState(() => _info = 'A new code has been sent.');
      _startCooldown();
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.mark_email_unread_outlined, size: 52, color: kBrand),
                const SizedBox(height: 14),
                const Text('Verify your email', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Enter the 6-digit code we sent to\n${widget.email}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 22),
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(counterText: '', hintText: '••••••', border: OutlineInputBorder()),
                  onSubmitted: (_) => _verify(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 8),
                  Text(_info!, style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 13), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _verify,
                  style: FilledButton.styleFrom(backgroundColor: kBrand, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify & continue'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: (_loading || _cooldown > 0) ? null : _resend,
                  child: Text(
                    _cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code',
                    style: TextStyle(color: _cooldown > 0 ? Colors.grey : kBrandDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
