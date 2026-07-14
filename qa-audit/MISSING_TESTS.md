# Missing Tests — KukKeep

Prioritized by risk. Before this audit, the repository had **zero** automated
tests (no `test/` directory existed). This audit added two files (`test/
auth_messages_test.dart`, `test/models_test.dart`, 15 cases) covering the two
pieces of pure, easily-unit-testable logic in the codebase. Everything below
that is still missing.

## P0 — Critical paths, no coverage at all

1. **Note editor save/back-navigation logic**
   (`lib/screens/note_editor_screen.dart` `_save`/`_onBack`) — this is exactly
   where BUG-001 (silent data loss) lives. A widget test driving "edit → back
   while the mocked API throws → assert the editor is still showing the
   edited text" would have caught this class of bug and should be added
   alongside the BUG-001 fix.
2. **Auth login/signup/OTP flow** (`lib/screens/auth_screen.dart`,
   `lib/screens/otp_screen.dart`) — no widget tests exist for form validation,
   tab switching, or the success/failure paths. Given this is the app's
   front door, it deserves the most coverage of any screen.
3. **`Api` class HTTP-layer behavior** (`lib/api.dart`) — `_unwrap()`'s status-
   code/error-shape branching (401-with-token vs. 401-without-token, non-JSON
   body, tRPC batch array vs. object) is exactly the kind of logic that's easy
   to get subtly wrong and easy to unit-test with a mocked `http.Client`
   (e.g., via `package:http/testing.dart`'s `MockClient`, or by extracting
   `_unwrap` to accept a decoded body instead of a raw `http.Response` for
   easier testing).

## P1 — High-value, currently uncovered

4. **Reminder scheduling logic** (`lib/notifications.dart`) — the
   past-time guard, exact-vs-inexact fallback, and cancel-on-trash/archive/
   delete interactions (`notes_screen.dart`, `note_editor_screen.dart`) are
   pure enough to unit-test with a fake `FlutterLocalNotificationsPlugin` or
   by extracting the "should this reminder still fire" decision into a
   testable pure function.
5. **Checklist reorder/toggle-done logic**
   (`lib/screens/note_editor_screen.dart` `_toggleDone`, `_onReorderItems`,
   `_uncheckedCount`) — this is intricate index-juggling code (three parallel
   lists kept in sync: items, controllers, focus nodes) that would benefit
   from extraction into a plain, testable class separate from widget state.
6. **`identity`/error-message routing once BUG-002 is fixed** — once a
   general `friendlyError()` helper replaces the 19 raw `e.toString()` call
   sites, it should get the same kind of table-driven test as
   `auth_messages_test.dart`.

## P2 — Useful, lower urgency

7. **Search filtering** (`_filtered` in `notes_screen.dart`) — pure list-
   filtering logic, cheap to unit-test once extracted from the `State`
   class, and would also serve as a regression test once BUG-003 (view-
   scoped search) is fixed.
8. **Widget/golden tests for the auth screen** against
   `docs/kuklabs/APPROVED_LOGIN_REFERENCE.png` — a golden-image test would
   catch future accidental drift from the approved Kuklabs design (control
   sizes, spacing) automatically instead of relying on manual comparison.
9. **CI integration**: neither `flutter test` nor `flutter analyze` currently
   runs in `.github/workflows/build-flutter-apk.yml` or `build-play-aab.yml`
   — both workflows go straight from `flutter pub get` to `flutter build`.
   Once tests exist, add a `flutter test` (and ideally `flutter analyze`)
   step before the build step so a broken test fails the workflow instead of
   silently shipping.

## P3 — Nice to have

10. End-to-end/integration tests (`integration_test` package) for the full
    signup → create note → attach image → set reminder → logout journey,
    once the app has enough unit/widget coverage to make E2E tests worth the
    added CI time.

## Explicitly out of scope for this repo's test suite

- Server-side logic (tRPC routers, DB queries, AI/OCR providers) — belongs in
  `kukbook-erp`'s own test suite, not here.
- Payment/subscription flows — not present in this app.
