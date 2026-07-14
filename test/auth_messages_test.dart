import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kukkeep/api.dart';
import 'package:kukkeep/auth_messages.dart';

// NOTE (qa-audit): written during the QA audit to cover the friendly-error
// mapper introduced for the Kuklabs error-message policy (no raw server/
// framework text may reach the UI). Not executed in the audit environment —
// no Flutter SDK is installed there. Run with `flutter test` before relying
// on this file; see qa-audit/TEST_COVERAGE_MATRIX.md.
void main() {
  group('friendlyAuthError', () {
    test('unauthorized ApiError during sign-in becomes the generic message', () {
      final e = ApiError('Invalid email or password', unauthorized: true);
      expect(friendlyAuthError(e, signIn: true), AuthMessages.genericSignInError);
    });

    test('unauthorized ApiError outside sign-in keeps its own friendly text', () {
      final e = ApiError('Session expired. Please log in again.', unauthorized: true);
      expect(friendlyAuthError(e), 'Session expired. Please log in again.');
    });

    test('technical-looking ApiError message is replaced with a generic one', () {
      final e = ApiError('TRPCClientError: INTERNAL_SERVER_ERROR at keep.list');
      expect(friendlyAuthError(e), AuthMessages.serverError);
    });

    test('empty ApiError message is replaced with a generic one', () {
      final e = ApiError('');
      expect(friendlyAuthError(e), AuthMessages.serverError);
    });

    test('ordinary ApiError message passes through unchanged', () {
      final e = ApiError('Enter a valid email.');
      expect(friendlyAuthError(e), 'Enter a valid email.');
    });

    test('SocketException maps to the offline message', () {
      final e = const SocketException('Failed host lookup');
      expect(friendlyAuthError(e), AuthMessages.offline);
    });

    test('network-flavored generic exception maps to the offline message', () {
      expect(friendlyAuthError(Exception('Connection reset by peer')),
          AuthMessages.offline);
    });

    test('unrecognized exception falls back to the generic fallback message', () {
      expect(friendlyAuthError(Exception('something odd')),
          AuthMessages.genericFallback);
    });
  });

  group('friendlyError (general-purpose alias, added for BUG-002)', () {
    test('never applies the sign-in-only generic message', () {
      // Unlike friendlyAuthError(e, signIn: true), an unauthorized ApiError
      // outside the sign-in flow (e.g. a 401 while saving a note) should keep
      // its own already-friendly message, not the credentials-specific one.
      final e = ApiError('Session expired. Please log in again.', unauthorized: true);
      expect(friendlyError(e), 'Session expired. Please log in again.');
    });

    test('still sanitizes a technical-looking message', () {
      final e = ApiError('ZodError: invalid_type at keep.create');
      expect(friendlyError(e), AuthMessages.serverError);
    });

    test('still maps network failures to the offline message', () {
      expect(friendlyError(const SocketException('Failed host lookup')),
          AuthMessages.offline);
    });
  });
}
