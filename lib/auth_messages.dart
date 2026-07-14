import 'dart:io';

import 'api.dart';

/// Approved Kuklabs auth content + friendly-error policy.
///
/// Source of truth: docs/kuklabs/KUKLABS_AUTH_CONTENT_TEMPLATES.json and
/// KUKLABS_MASTER_STANDARD.md §8.7/§9 — raw server/framework errors must never
/// reach the UI, and wrong credentials always use the one safe generic message.
class AuthMessages {
  AuthMessages._();

  // Labels
  static const login = 'Login';
  static const signup = 'Sign Up';
  static const createAccount = 'Create Account';
  static const continueWithGoogle = 'Continue with Google';
  static const forgotPassword = 'Forgot Password?';
  static const identity = 'Mobile number or email';
  static const password = 'Password';
  static const fullName = 'Full name';
  static const poweredBy = 'Powered by';
  static const poweredByBrand = 'Kuklabs';
  static const tagline =
      'Notes, checklists & reminders — synced with your Kuklabs account.';

  // Field-level messages (approved catalogue)
  static const genericSignInError =
      "We couldn't sign you in. Check your email or mobile number and password, then try again.";
  static const emptyIdentity = 'Enter your email address or mobile number.';
  static const invalidEmail = 'Enter a valid email address.';
  static const invalidPhone =
      'Enter a valid mobile number for the selected country.';
  static const emptyPassword = 'Enter your password.';
  static const weakPassword =
      'Use at least 8 characters with at least one letter and one number.';
  static const termsRequired =
      'Review and accept the Terms of Use and Privacy Policy to continue.';
  static const offline =
      "You're offline. Check your internet connection and try again.";
  static const serverError =
      'Something went wrong on our side. Please try again in a moment.';
  static const genericFallback =
      "We couldn't complete that action. Please try again.";
}

/// True when a message looks like a raw framework/server error that must not
/// be shown to users (TRPCClientError, ZodError, JSON, stack traces, SQL…).
bool _looksTechnical(String m) {
  if (m.length > 160) return true;
  const markers = [
    'trpc', 'zod', 'exception', 'stack', 'sql', 'econn', 'etimedout',
    'enotfound', 'socketexception', 'internal_server_error', '{', '<html',
  ];
  final lower = m.toLowerCase();
  return markers.any(lower.contains);
}

/// Maps any thrown error to an approved, user-safe message.
///
/// [signIn] marks the credentials flow: an unauthorized failure there always
/// becomes the single safe generic sign-in message the standard mandates.
String friendlyAuthError(Object e, {bool signIn = false}) {
  if (e is SocketException) return AuthMessages.offline;
  if (e is ApiError) {
    if (signIn && e.unauthorized) return AuthMessages.genericSignInError;
    final m = e.message.trim();
    if (m.isEmpty || _looksTechnical(m)) return AuthMessages.serverError;
    return m; // client-side ApiError copy is already friendly
  }
  // package:http wraps I/O failures in ClientException — sniff for network-ish
  // causes so offline shows the right message instead of the generic one.
  final s = e.toString().toLowerCase();
  if (s.contains('socket') || s.contains('network') || s.contains('connection')) {
    return AuthMessages.offline;
  }
  return AuthMessages.genericFallback;
}
