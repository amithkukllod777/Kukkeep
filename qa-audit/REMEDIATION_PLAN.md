# Remediation Plan — KukKeep

## Immediate (before the next Play Store release)

| Action | Priority | Owner type | Complexity | Dependencies | Verification steps |
|---|---|---|---|---|---|
| Fix BUG-001: don't pop the note editor on a failed save | P0 | Mobile dev | S | None | Add a widget test (see MISSING_TESTS.md #1); manually test airplane-mode edit+back |
| Fix BUG-002: route all 19 raw-error call sites through a general `friendlyError()` helper | P1 | Mobile dev | M | None | Extend `test/auth_messages_test.dart`-style coverage to the new helper; manually trigger an offline error on each affected screen |
| Confirm/resolve the Google Play Account Deletion policy gap (add in-app "Delete Account", or confirm the existing web/email process already satisfies Play's requirement in Data Safety) | P0 | Product owner + backend (kukbook-erp) | M–L | Needs a corresponding server-side account-deletion endpoint if none exists | Re-check Play Console → App content → Data safety against Play's published Account Deletion policy before submitting the next release |
| Add crash reporting (Firebase Crashlytics) | P1 | Mobile dev | S | `firebase_core` already present | Force a test crash in a debug build, confirm it appears in the Firebase console |
| Fix BUG-004/SEC-002: call a server-side logout/revoke endpoint | P1 | Mobile dev + backend (kukbook-erp) | M | Needs a `kukbook-erp` endpoint if one doesn't exist | Log in, log out, confirm the old token is rejected by the server |
| Fix SEC-001: move the session token to `flutter_secure_storage` | P1 | Mobile dev | M | New dependency | Confirm the token is no longer present in the plaintext SharedPreferences XML on a test device |
| Add legal links (Terms/Privacy) to Settings → About | P2 | Mobile dev | S | None | Manual check |

## Short term (next sprint)

| Action | Priority | Owner type | Complexity | Dependencies | Verification steps |
|---|---|---|---|---|---|
| Add `flutter test` (and `flutter analyze`) as a CI step in both workflows | P1 | Mobile dev | S | Tests must pass first | CI run goes green with tests executed, not skipped |
| Fix BUG-003: make search global across all notes (or add an explicit "search everywhere" toggle) | P2 | Mobile dev | M | None | Manual: search for text only present in an archived note from the Notes view |
| Fix BUG-007: add accessible labels to all icon-only controls; add a non-drag reorder alternative | P2 | Mobile dev | M | None | Manual TalkBack pass over every screen |
| Fix BUG-008: adopt `cached_network_image` for cover images and attachment thumbnails | P2 | Mobile dev | S | New dependency | Manual: reopen a note with images while offline, confirm previously-viewed images still show |
| Add a workspace/company switcher to Settings (BUG-011) | P2 | Mobile dev | M | None | Manual: log in with a multi-company account, switch, confirm the notes list updates |
| Add request timeouts to all `Api` HTTP calls (SEC-007) | P2 | Mobile dev | S | None | Manual: simulate a slow/hung connection, confirm a timeout error surfaces instead of an infinite spinner |
| Re-enable `use_build_context_synchronously` lint and fix resulting warnings (BUG-009) | P3 | Mobile dev | S | None | `flutter analyze` clean |
| Fix BUG-005: dirty-check before saving on editor exit | P3 | Mobile dev | S | None | Manual: open-then-close a note with no edits, confirm no network call fires (e.g., via a proxy/log check) |

## Medium term

| Action | Priority | Owner type | Complexity | Dependencies | Verification steps |
|---|---|---|---|---|---|
| Offline-first note cache (local persistence + background sync) | P1 (competitive) | Mobile dev | XL | Possibly a local DB package (e.g., `drift`/`sqflite`/`hive`) | Manual: enable airplane mode, confirm previously-loaded notes remain visible and editable, and sync on reconnect |
| Pagination for `keep.list` + virtualized note list rendering | P2 | Mobile dev + backend (kukbook-erp) | L | Server-side API change | Manual/profiled test with 1,000+ synthetic notes |
| Draft autosave in the note editor (BUG-010) | P3 | Mobile dev | M | Should build on the BUG-005 dirty-check work | Manual: type, force-kill the app, reopen, confirm the draft survived |
| Migrate the Google OAuth deep link from a custom scheme to Android App Links (SEC-005) | P3 | Mobile dev + backend (kukbook-erp, for `assetlinks.json`) | L | Server-side `.well-known/assetlinks.json` | Manual: confirm the link opens only this app, not a picker |
| Move the OAuth code exchange from GET to POST (SEC-004) | P3 | Mobile dev + backend | M | Server-side endpoint change | Manual: confirm sign-in still works after the change |

## Long-term technical debt

| Action | Priority | Owner type | Complexity | Dependencies | Verification steps |
|---|---|---|---|---|---|
| Build out a real automated test suite (unit + widget + integration) beyond the 15 cases added in this audit | P2 | Mobile dev | L (ongoing) | None | Coverage tooling / CI gate |
| Localization (multi-language support) | P3 | Mobile dev + translators | L | Product decision on target markets | Manual verification per added locale |
| Certificate pinning (SEC-003) | P3 | Mobile dev | M | None | Manual MITM-proxy test confirming the pinned connection is rejected when intercepted |
| Notification preferences / granular reminder controls in Settings | P3 | Mobile dev | M | None | Manual |
