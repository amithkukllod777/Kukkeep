import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'api.dart';
import 'auth_messages.dart';
import 'google_auth.dart'; // reuse the shared navigator/messenger keys
import 'screens/notes_screen.dart';

/// "Sign in with Apple" — native iOS flow.
///
/// App Store Review Guideline 4.8 requires any app offering a third-party
/// sign-in (we ship Google) to ALSO offer Sign in with Apple. This shows the
/// native Apple sheet (Face ID / Touch ID), then hands the signed identity
/// token to the shared Kuklabs backend, which verifies it and mints the SAME
/// Bearer session as Google — one shared account, no separate auth.
///
/// iOS-only: renders nothing on Android (there the email + Google options
/// already satisfy the guideline, and Apple's native sheet isn't available).
class AppleSignInButton extends StatefulWidget {
  const AppleSignInButton({super.key});

  @override
  State<AppleSignInButton> createState() => _AppleSignInButtonState();
}

class _AppleSignInButtonState extends State<AppleSignInButton> {
  bool _busy = false;

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final cred = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = cred.identityToken;
      if (idToken == null || idToken.isEmpty) {
        _toast('Apple sign-in failed. Please try again.');
        return;
      }
      // Apple sends the name only on the FIRST authorization — forward it then.
      final name = [cred.givenName, cred.familyName]
          .where((e) => e != null && e.trim().isNotEmpty)
          .map((e) => e!.trim())
          .join(' ');
      await Api.instance.appleNative(identityToken: idToken, name: name.isEmpty ? null : name);
      // Brand-new accounts have no workspace yet — silently create one.
      final cid = await Api.instance.ensureCompany(name: Api.instance.userName ?? 'My Notes');
      if (cid == null) {
        _toast('Could not set up your workspace — please try again.');
        return;
      }
      GoogleAuth.navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const NotesScreen()), (r) => false);
    } on SignInWithAppleAuthorizationException catch (e) {
      // A user-initiated cancel is not an error worth a toast.
      if (e.code != AuthorizationErrorCode.canceled) {
        _toast('Apple sign-in was cancelled.');
      }
    } catch (e) {
      _toast(friendlyAuthError(e, signIn: true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) =>
      GoogleAuth.messengerKey.currentState?.showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    // Apple's native sheet exists only on iOS; hide the button everywhere else.
    if (!Platform.isIOS) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 58,
        child: SignInWithAppleButton(
          onPressed: () { _signIn(); },
          height: 58,
          borderRadius: BorderRadius.circular(16),
          style: SignInWithAppleButtonStyle.black,
        ),
      ),
    );
  }
}
