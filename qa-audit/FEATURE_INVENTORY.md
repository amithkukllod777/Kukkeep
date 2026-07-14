# Feature Inventory — KukKeep (Flutter, Android)

Scope: `amithkukllod777/Kukkeep` repository only (native mobile client). The
backend (`keep` tRPC router, `kuk_keep_*` tables) lives in the separate
`kukbook-erp` repository and is **out of scope** for this audit — it is
referenced here only where the client's behavior depends on it, and those
references are marked NOT VERIFIED (server code not audited).

Audited at commit `7112ec3` (branch `claude/kukkeep-flutter-migration-cgent8`),
2026-07-14. Method: full static read of every file in `lib/`, `pubspec.yaml`,
both GitHub Actions workflows, and `docs/kuklabs/`. No emulator/device was
available in this environment (see `TEST_COVERAGE_MATRIX.md`), so "Working"
below means "implemented per code and internally consistent," not "manually
verified on a running app."

| Module | Feature | User role | Implementation status | Test status | Documentation status | Risk level |
|---|---|---|---|---|---|---|
| Auth | Email + password login | Any user | Working (code-consistent) | Not tested (no device) | Documented (CLAUDE.md, docs/kuklabs) | Medium — logout doesn't revoke server session (see BUG-004) |
| Auth | Email + password signup + OTP verification | Any user | Working | Not tested | Documented | Low |
| Auth | Resend OTP with 30s cooldown | Any user | Working | Not tested | Undocumented (nice touch, not in any doc) | Low |
| Auth | Google Sign-In (browser + deep link) | Any user | Working, feature-flagged (hidden until server reports `googleEnabled()`) | Not tested | Documented (CLAUDE.md, google_auth.dart docstring) | Medium — custom URL scheme, no App Links (see SEC-006) |
| Auth | Mobile-number login | Any user | **Missing** — signup collects a phone number, but login only accepts email; UI shows a guiding message | Not tested | Documented as a known follow-up (KUKKEEP.md) | Low (documented gap) |
| Auth | "Forgot password" | Any user | Partial — opens a web URL (`{base}/forgot-password`); no in-app flow | Not tested | Undocumented | Low |
| Auth | Multi-workspace picker at login | User with 2+ companies | Working at login only | Not tested | Undocumented | Medium — no way to switch workspace after login (see BUG-011) |
| Notes | Create / edit / delete text note | Any user | Working | Not tested | Documented | Low |
| Notes | Checklists (add/remove/reorder/check items) | Any user | Working, drag-to-reorder for unchecked items, completed items collapse | Not tested | Documented | Low |
| Notes | Convert note ⇄ checklist | Any user | Working, content-preserving | Not tested | Undocumented | Low |
| Notes | Pin / unpin | Any user | Working | Not tested | Documented | Low |
| Notes | 8 background colors | Any user | Working | Not tested | Documented | Low |
| Notes | Labels (add/rename/delete, filter by label) | Any user | Working | Not tested | Documented | Low |
| Notes | Reminders (date+time picker → OS notification) | Any user | Working; exact-alarm with inexact fallback; re-armed on app relaunch | Not tested (needs device across a real reboot) | Documented | Medium — no reschedule-on-boot test possible in this environment |
| Notes | Search (title/body/checklist items/labels, highlighted matches) | Any user | Working, but **scoped to the current view only** (e.g., searching in Archive doesn't search all notes) | Not tested | Undocumented gap | Low |
| Notes | Grid / list layout toggle (persisted) | Any user | Working | Not tested | Undocumented | Low |
| Notes | Archive | Any user | Working | Not tested | Documented | Low |
| Notes | Trash (30-day retention per copy, restore, empty trash, permanent delete) | Any user | Working client-side; the 30-day auto-purge itself is a **server-side job** (kukbook-erp) — NOT VERIFIED from this repo | Not tested | Documented | Medium — retention enforcement unverified |
| Notes | Pull-to-refresh | Any user | Working | Not tested | Undocumented | Low |
| Notes | Offline access / local cache | Any user | **Missing** — every screen open calls the network; no local DB/cache; a network failure blocks the entire notes list | Not tested | Undocumented gap | High (competitive gap, see COMPETITIVE_FEATURE_MATRIX.md) |
| Attachments | Image attach (gallery) | Any user | Working, 8 MB client-side cap | Not tested | Documented | Low |
| Attachments | Image + OCR (scan text from photo) | Any user | Working; depends on server OCR/vision API — NOT VERIFIED | Not tested | Documented | Medium (server dependency) |
| Attachments | Arbitrary file attach | Any user | Working, 8 MB client-side cap | Not tested | Documented | Low |
| Attachments | Drawing / sketch → uploaded as image attachment | Any user | Working (custom Canvas, no native plugin) | Not tested | Documented | Low |
| Attachments | Delete attachment (confirm dialog) | Any user | Working | Not tested | Documented | Low |
| Attachments | Attachment thumbnails cached offline | Any user | **Missing** — `Image.network` with no disk cache package | Not tested | Undocumented gap | Medium |
| AI | AI Memory — natural-language "ask your notes" | Any user | Working; entirely server-side (kukbook-erp) — NOT VERIFIED (quality/accuracy of answers) | Not tested | Documented | Medium (server dependency, unverifiable here) |
| AI | Per-note actions: Title / Summarize / Clean up / Key points | Any user | Working; server-side — NOT VERIFIED | Not tested | Documented | Medium |
| Notifications | Local reminder notifications | Any user | Working (see Reminders above) | Not tested | Documented | Low |
| Notifications | Firebase Cloud Messaging (broadcast only) | Any user | Working for a single broadcast topic (`kukkeep-all`); **no per-user/per-device targeted push** — the FCM token is fetched but never sent to the backend | Not tested | Undocumented gap | Low (feature gap, not a defect — local reminders cover the main need) |
| Settings | Theme (System/Light/Dark), persisted | Any user | Working | Not tested | Documented | Low |
| Settings | Account name / "About" / version display | Any user | Working, now in the approved `Version x.y.z (Build n)` format | Not tested | Documented | Low |
| Settings | Workspace/organisation switch | User with 2+ companies | **Missing** (see Notes → Multi-workspace above) | N/A | Undocumented gap | Medium |
| Settings | Notification preferences | Any user | **Missing** — no granular control (e.g., mute reminders) | N/A | Undocumented gap | Low |
| Settings | Data export | Any user | **Missing** — no in-app export of notes/attachments | N/A | Undocumented gap | High (Play Store policy relevance, see PRODUCTION_READINESS_CHECKLIST.md) |
| Settings | Account / data deletion | Any user | **Missing in-app** — only an email-based process (`support@kuklabs.com`) documented in `PLAY_STORE_LISTING.md`; no in-app "Delete Account" action | N/A | Documented only as an email process | **Blocker for Play Store** if in-app account creation exists without an in-app deletion path — see PRODUCTION_READINESS_CHECKLIST.md |
| Settings | Help & Support link | Any user | **Missing** from Settings (Terms/Privacy links exist only on the auth screen, not in Settings/About) | N/A | Undocumented gap | Low |
| Settings | Logout | Any user | Working client-side (clears local token); **does not call a server-side revoke/logout endpoint** | Not tested | Undocumented gap | Medium (see SEC-002) |
| Platform | Light/dark mode | Any user | Working | Not tested | Documented | Low |
| Platform | Android only (no iOS) | Any user | By design (`flutter_launcher_icons: ios: false`) | N/A | Documented | Low (documented scope) |
| Platform | Localization / multi-language | Any user | **Missing** — English only, no `intl`/ARB translation scaffold | N/A | Undocumented gap | Low–Medium (market-dependent) |
| Platform | Accessibility (screen reader labels, semantics) | Any user | Partial — most icon-only buttons lack `Semantics`/`tooltip`; drag-reorder has no non-drag alternative | N/A | Undocumented gap | Medium |
| Release | Signed Play Store AAB build (CI) | N/A | Working (verified green in this session, PR #1/#2 on Kukkeep) | Verified via CI run | Documented | Low |
| Release | Unsigned APK build for sideload testing (CI) | N/A | Working (verified green) | Verified via CI run | Documented | Low |
| Release | Crash reporting / error monitoring | N/A | **Missing** — no Crashlytics/Sentry dependency | N/A | Undocumented gap | Medium |
| Release | Automated tests | N/A | **Missing** — no `test/` directory anywhere in the repo | N/A | Undocumented gap | High (see MISSING_TESTS.md) |

## Summary counts

- Fully working (code-consistent): 27
- Partially implemented: 3 (forgot-password, multi-workspace, search scoping)
- Missing: 11 (offline cache, attachment disk cache, workspace switcher, notification
  prefs, data export, in-app account deletion, help/support link, server-side
  logout revoke, localization, full accessibility, crash reporting, automated tests
  — note this list is 12; "11" above undercounts by one, corrected here)
- Server-dependent, not verifiable from this repo: 6 (OCR, AI Memory/actions ×2,
  trash 30-day purge job, Google OAuth server flow, API key restriction)
