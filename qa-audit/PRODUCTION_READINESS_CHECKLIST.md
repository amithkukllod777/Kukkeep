# Production-Readiness Checklist — KukKeep

Status legend: PASS / FAIL / NOT VERIFIED (control lives outside this repo or
requires access not available in this environment).

| Requirement | Status | Notes |
|---|---|---|
| No blocker or critical bugs | **PASS** (fixed, not re-verified on device) | BUG-001 (silent data loss) fixed in branch `claude/kukkeep-fix-critical-bugs`. No Blocker-severity bug found. |
| Production environment variables are correct | NOT VERIFIED | Server-side/CI-secret concern; this repo has no `.env` — the only "config" is the hardcoded `Api.base = 'https://keep.kuklabs.com'`, which is correct for production per CLAUDE.md |
| Test credentials removed | PASS | No test/debug credentials found hardcoded anywhere in `lib/` |
| Debug mode disabled | PASS | `debugShowCheckedModeBanner: false` set (`main.dart:52`); release builds are produced via `flutter build apk/appbundle --release` in CI, not debug builds |
| Secrets are secured | PASS | Play signing keystore + passwords are GitHub Actions Secrets (`KUKKEEP_KEYSTORE_BASE64`, etc.), not committed; verified in this session's earlier CI work |
| Production APIs are configured | PASS | `Api.base` points at the production `keep.kuklabs.com` host |
| Payment live configuration is correct | NOT APPLICABLE | No payment feature exists in this app |
| Monitoring is enabled | **FAIL** | No crash-reporting SDK (Crashlytics/Sentry/equivalent) is in `pubspec.yaml`; a crash on a user's device today produces no signal to the team beyond a Play Console ANR/crash-rate percentage (itself NOT VERIFIED as configured, since it depends on Play Console settings outside this repo) |
| Backup and restore are tested | NOT APPLICABLE to this repo | Data backup is a server/DB (kukbook-erp/MySQL) concern; not testable from the client |
| Legal pages are available | **PASS** (fixed) | Terms/Privacy links exist on the auth screen and, as of branch `claude/kukkeep-fix-critical-bugs`, in Settings too |
| App version is correct | PASS | `pubspec.yaml` `2.2.2+35`, matches `kAppVersion`/`kAppBuild` in `note_colors.dart` (kept in sync as part of this session's earlier logo-update PR) |
| Database migrations are safe | NOT APPLICABLE to this repo | No local DB; server-side migrations are `kukbook-erp`'s concern |
| Rollback plan exists | PARTIAL | Play Store's own staged-rollout/halt mechanism is available at the platform level (standard for any Play app); no app-specific rollback documentation exists in this repo beyond that |
| Support contact works | PARTIAL | `support@kuklabs.com` is documented in `PLAY_STORE_LISTING.md`; not independently verified as a monitored inbox (outside this repo's ability to check) |
| Store metadata is correct | **PASS** | `PLAY_STORE_LISTING.md` has complete copy-paste listing content; the Play "Account Deletion" policy item below is now resolved with an in-app path — the Data Safety form should still be double-checked to reflect it |
| Release notes are prepared | PASS | `PLAY_STORE_LISTING.md` has a ready "What's new" section |

## Additional production-readiness items surfaced by this audit

### Google Play "Account Deletion" policy — RESOLVED

**Status: FIXED** (branch `claude/kukkeep-fix-critical-bugs`). A backend read
of `kukbook-erp` found the shared platform already has GDPR/DPDP-compliant
endpoints for this — `auth.exportMyData` (`server/routers.ts:1337`) and
`auth.deleteMyAccount` (`server/routers.ts:1345`, a soft-delete/anonymize
that blocks with an actionable message if the user still solely owns a
company). KukKeep's Settings screen now has:
- **"Export my data"** — calls `auth.exportMyData`, shows the result
  (profile, workspaces, KukChat handle) with a copy-to-clipboard action.
- **"Delete account"** (in a new "Danger Zone" section) — confirms, then
  calls `auth.deleteMyAccount`, and returns to the auth screen on success.

This closes the in-app path Play's Account Deletion policy expects. One
remaining action item (not a code fix): **confirm the Play Console → App
content → Data Safety form for this app reflects the in-app deletion path**
now that it exists — that configuration lives outside this repo and wasn't
accessible to verify here.

### No crash reporting

Still open. Flagged above under "Monitoring is enabled" — recommend adding
`firebase_crashlytics` (the project already uses `firebase_core`, so this is
a low-effort addition) before the next significant release, so that
real-world crashes are visible at all.

### Legal links missing from Settings

**Status: FIXED** — Terms of Use / Privacy Policy rows added to Settings in
branch `claude/kukkeep-fix-critical-bugs`.

## Overall production-readiness assessment

**GO** (upgraded from CONDITIONAL GO) — both release-blocking items from the
original audit (BUG-001 and the Account Deletion policy gap) are fixed in
branch `claude/kukkeep-fix-critical-bugs`. Neither fix has been re-verified
on a physical device/emulator (none was available in this environment) —
recommend a manual smoke test of both flows (offline edit+back, and the new
export/delete actions) before the next Play submission. See
`EXECUTIVE_SUMMARY.md` for the full reasoning.
