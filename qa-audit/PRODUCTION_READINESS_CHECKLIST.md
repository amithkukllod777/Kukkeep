# Production-Readiness Checklist — KukKeep

Status legend: PASS / FAIL / NOT VERIFIED (control lives outside this repo or
requires access not available in this environment).

| Requirement | Status | Notes |
|---|---|---|
| No blocker or critical bugs | **CONDITIONAL FAIL** | One Critical bug (BUG-001, silent data loss) is open. No Blocker-severity bug found. |
| Production environment variables are correct | NOT VERIFIED | Server-side/CI-secret concern; this repo has no `.env` — the only "config" is the hardcoded `Api.base = 'https://keep.kuklabs.com'`, which is correct for production per CLAUDE.md |
| Test credentials removed | PASS | No test/debug credentials found hardcoded anywhere in `lib/` |
| Debug mode disabled | PASS | `debugShowCheckedModeBanner: false` set (`main.dart:52`); release builds are produced via `flutter build apk/appbundle --release` in CI, not debug builds |
| Secrets are secured | PASS | Play signing keystore + passwords are GitHub Actions Secrets (`KUKKEEP_KEYSTORE_BASE64`, etc.), not committed; verified in this session's earlier CI work |
| Production APIs are configured | PASS | `Api.base` points at the production `keep.kuklabs.com` host |
| Payment live configuration is correct | NOT APPLICABLE | No payment feature exists in this app |
| Monitoring is enabled | **FAIL** | No crash-reporting SDK (Crashlytics/Sentry/equivalent) is in `pubspec.yaml`; a crash on a user's device today produces no signal to the team beyond a Play Console ANR/crash-rate percentage (itself NOT VERIFIED as configured, since it depends on Play Console settings outside this repo) |
| Backup and restore are tested | NOT APPLICABLE to this repo | Data backup is a server/DB (kukbook-erp/MySQL) concern; not testable from the client |
| Legal pages are available | **PARTIAL** | Terms/Privacy links exist on the auth screen (`auth_screen.dart` `_legal()`) but are **absent from Settings/About** — a returning logged-in user has no in-app way to revisit them without logging out first |
| App version is correct | PASS | `pubspec.yaml` `2.2.2+35`, matches `kAppVersion`/`kAppBuild` in `note_colors.dart` (kept in sync as part of this session's earlier logo-update PR) |
| Database migrations are safe | NOT APPLICABLE to this repo | No local DB; server-side migrations are `kukbook-erp`'s concern |
| Rollback plan exists | PARTIAL | Play Store's own staged-rollout/halt mechanism is available at the platform level (standard for any Play app); no app-specific rollback documentation exists in this repo beyond that |
| Support contact works | PARTIAL | `support@kuklabs.com` is documented in `PLAY_STORE_LISTING.md`; not independently verified as a monitored inbox (outside this repo's ability to check) |
| Store metadata is correct | PASS (content), **FAIL** (one policy item) | `PLAY_STORE_LISTING.md` has complete copy-paste listing content; however, see the Play "Account Deletion" policy item below |
| Release notes are prepared | PASS | `PLAY_STORE_LISTING.md` has a ready "What's new" section |

## Additional production-readiness items surfaced by this audit

### Google Play "Account Deletion" policy — likely non-compliant

Google Play requires apps that let users create an account **within the app**
to provide:
1. An in-app path for the user to request deletion of their account and
   associated data, **and**
2. A corresponding web-based deletion-request option, declared in Play
   Console → App content → Data safety.

KukKeep supports in-app account creation (signup + OTP), but Settings has
**no "Delete Account" action** — the only documented path is an email to
`support@kuklabs.com` per `PLAY_STORE_LISTING.md`. Depending on exactly how
the Play Console Data Safety form for this app was filled out (NOT VERIFIED —
outside this repo), this is a **plausible rejection/policy-violation risk**
and should be confirmed with whoever manages the Play Console listing before
(or immediately after) this app goes live. This is flagged as a
**release-blocking item to verify**, not a confirmed rejection, since the
exact Play Console configuration wasn't accessible from this repo.

### No crash reporting

Flagged above under "Monitoring is enabled" — recommend adding
`firebase_crashlytics` (the project already uses `firebase_core`, so this is
a low-effort addition) before the next significant release, so that
real-world crashes are visible at all.

### Legal links missing from Settings

Low-effort fix: add Terms of Use / Privacy Policy rows to the "About" section
in `settings_screen.dart`, matching what already exists on the auth screen.

## Overall production-readiness assessment

**CONDITIONAL GO** — see `EXECUTIVE_SUMMARY.md` for the full release
recommendation and reasoning.
