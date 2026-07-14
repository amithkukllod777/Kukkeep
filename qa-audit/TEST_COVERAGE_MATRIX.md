# Test Coverage Matrix — KukKeep

**Environment constraint that shapes this entire document:** this audit ran in
a container with no Flutter/Dart SDK installed (`which flutter dart` returns
nothing) and no Android emulator/device. Every row below that says "NOT
TESTED" means exactly that — it was not possible to execute in this
environment, not that it's assumed fine. Two new unit-test files were written
(`test/auth_messages_test.dart`, `test/models_test.dart`, 15 test cases total)
but **could not be run here** — mark them NOT EXECUTED until run with
`flutter test` in an environment with the SDK. The CI-based APK/AAB builds
*were* actually executed (via GitHub Actions in this session) and did compile
successfully — that is real, verified evidence the code compiles, not that
the features behave correctly at runtime.

| Feature | Smoke | Functional | Negative | Boundary | API | Security | Regression | UI/UX | Automated coverage | Result |
|---|---|---|---|---|---|---|---|---|---|---|
| Build compiles (APK) | Executed (CI) | N/A | N/A | N/A | N/A | N/A | N/A | N/A | CI workflow | **PASS** (verified: run 29300797780, green) |
| Build compiles (signed AAB) | Executed (CI) | N/A | N/A | N/A | N/A | N/A | N/A | N/A | CI workflow | **PASS** (verified: run 29244642343, green) |
| Email/password login | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Reviewed (SEC-001/002) | NOT TESTED | NOT TESTED | None | NOT TESTED |
| Signup + OTP verify | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | None | NOT TESTED |
| Google Sign-In (deep link) | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | Reviewed (SEC-005) | NOT TESTED | NOT TESTED | None | NOT TESTED |
| friendlyAuthError() mapping | N/A | Reviewed by hand-tracing against implementation | Reviewed (technical-string detection) | Reviewed (empty message) | N/A | N/A | N/A | N/A | `test/auth_messages_test.dart` (8 cases) | **NOT EXECUTED** — written, traced by hand against the implementation, not run |
| Note.fromJson / Attachment.fromJson / Company.fromJson parsing | N/A | Reviewed by hand-tracing | Reviewed (malformed JSON, null fields) | Reviewed (empty strings, missing keys) | N/A | N/A | N/A | N/A | `test/models_test.dart` (7 cases) | **NOT EXECUTED** — same caveat |
| Create/edit/delete note | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | N/A | NOT TESTED | NOT TESTED | None | NOT TESTED |
| Checklist add/reorder/complete | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | N/A | N/A | NOT TESTED | NOT TESTED | None | NOT TESTED |
| Search | NOT TESTED | NOT TESTED | Reviewed (BUG-003 view-scoping) | NOT TESTED | N/A | N/A | NOT TESTED | NOT TESTED | None | NOT TESTED |
| Archive / Trash / Restore / Empty Trash | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | N/A | NOT TESTED | NOT TESTED | None | NOT TESTED |
| Reminders (schedule, reboot persistence) | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | N/A | N/A | NOT TESTED | NOT TESTED | None | NOT TESTED — reboot persistence specifically requires a physical/emulated device reboot, impossible here |
| Image/file attach + 8MB cap | NOT TESTED | NOT TESTED | Reviewed (code-level cap exists) | Reviewed (8MB boundary is a hardcoded constant, not tested at the boundary) | NOT TESTED | Reviewed (SEC — no type allowlist) | NOT TESTED | NOT TESTED | None | NOT TESTED |
| OCR | NOT TESTED (server-dependent) | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | N/A | NOT TESTED | NOT TESTED | None | NOT TESTED — also NOT VERIFIABLE without the kukbook-erp server |
| Drawing → attachment upload | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | N/A | NOT TESTED | NOT TESTED | None | NOT TESTED |
| AI Memory (ask notes) / AI actions | NOT TESTED (server-dependent) | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | N/A | NOT TESTED | NOT TESTED | None | NOT TESTED — server-dependent, out of repo scope |
| Reminder local notification delivery | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | N/A | N/A | NOT TESTED | NOT TESTED | None | NOT TESTED — requires a device |
| FCM push (broadcast) | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | N/A | NOT TESTED | NOT TESTED | None | NOT TESTED |
| Theme (light/dark/system), persisted | NOT TESTED | NOT TESTED | N/A | N/A | N/A | N/A | NOT TESTED | NOT TESTED | None | NOT TESTED |
| Settings / About / Version display | NOT TESTED | Reviewed (format matches KUKLABS_BRAND_CONFIG.json) | N/A | N/A | N/A | N/A | NOT TESTED | NOT TESTED | None | NOT TESTED |
| Logout | NOT TESTED | Reviewed (SEC-002: no server revoke) | N/A | N/A | NOT TESTED | Reviewed (SEC-002) | NOT TESTED | NOT TESTED | None | NOT TESTED |
| Accessibility (screen reader, focus order) | NOT TESTED | N/A | N/A | N/A | N/A | N/A | N/A | Reviewed (BUG-007 — gaps found) | None | NOT TESTED (no TalkBack pass possible here) |
| Localization | N/A | N/A | N/A | N/A | N/A | N/A | N/A | Reviewed (English-only, no l10n scaffold) | None | NOT TESTED / NOT APPLICABLE (single-language by design today) |
| Offline behavior | NOT TESTED | Reviewed (no offline cache exists — BUG/gap, not a "test failure" per se) | NOT TESTED | N/A | N/A | N/A | N/A | NOT TESTED | None | NOT TESTED |
| Payment flows | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | **NOT APPLICABLE** — KukKeep has no payment/subscription feature in this repo |
| Backup/Disaster-recovery of note data | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | **NOT APPLICABLE to this repo** — data persistence and backup are entirely server-side (kukbook-erp/MySQL), out of scope |

## What could not be executed, and why

- **No Flutter/Dart SDK in this environment** → cannot run `flutter test`,
  `flutter analyze`, `flutter pub outdated`, or launch an emulator. This
  blocks essentially all Functional/Negative/Boundary/UI rows above.
- **No Android device/emulator** → blocks reminder-notification delivery,
  reboot-persistence, TalkBack accessibility passes, and any visual/UX
  verification beyond static code + the one static reference image
  (`docs/kuklabs/APPROVED_LOGIN_REFERENCE.png`).
- **No backend test/staging instance credentials** → `keep.kuklabs.com` is a
  live production endpoint; no sandbox credentials were provided, so no live
  API call was made in this audit (consistent with "do not access production
  user data").
- **CI builds were genuinely executed** (this is the one category of "test"
  actually run, via the GitHub Actions workflows already in the repo) and
  both are green as of this audit.

## Exact manual test procedure required (for the rows above)

1. Install Flutter (matching `pubspec.yaml`'s `sdk: '>=3.4.0 <4.0.0'` and the
   CI's pinned `flutter-version: "3.44.4"`).
2. `flutter pub get && flutter test` — runs the 15 new unit tests plus any
   future ones.
3. `flutter analyze` — confirms no new lint regressions (note BUG-009 about
   the disabled `use_build_context_synchronously` rule).
4. Sideload the CI-built APK
   (`https://github.com/amithkukllod777/Kukkeep/releases/download/flutter-latest/KukKeep-flutter.apk`)
   onto a real Android device or emulator and manually walk each row above.
5. For reminder reboot-persistence specifically: schedule a reminder, reboot
   the device, confirm it still fires at the correct time.
6. For accessibility: enable TalkBack and navigate every screen without
   looking at it.
