# Security Audit — KukKeep (Flutter, Android)

Scope: the mobile client only (`amithkukllod777/Kukkeep`). Server-side controls
(rate limiting, session storage, SQL/query safety, CORS, secrets management)
live in `kukbook-erp` and are **out of scope / NOT VERIFIED** here — each such
item is marked explicitly below. No dynamic testing (no rooted device, no
proxy/MITM tooling, no APK decompilation) was performed in this environment;
all findings are from static source review. Mapped informally to the OWASP
Mobile Application Security Verification Standard (MASVS) categories where
relevant.

---

### SEC-001 — Session token stored in plaintext SharedPreferences

- **Status: FIXED** (branch `claude/kukkeep-fix-critical-bugs`) — the Bearer
  token now lives in `flutter_secure_storage` (Android Keystore-backed
  `EncryptedSharedPreferences`); `kk_company`/`kk_user` (non-sensitive) stay
  in ordinary `SharedPreferences`. Not re-verified on a device (no toolchain
  in this environment).
- **Severity:** Major
- **Affected component:** `lib/api.dart:29-41` (`load()`/`_save()`), backed by
  the `shared_preferences` package
- **Attack scenario:** `shared_preferences` on Android writes to an XML file
  under the app's private data directory. On a rooted device, a device with
  ADB debugging enabled and unlocked, or via an insecure/misconfigured backup,
  the Bearer session token (`kk_token`) can be read in plaintext and reused
  to impersonate the user for up to the token's ~30-day lifetime (per the
  code comment in `google_auth.dart`).
- **Evidence:** `lib/api.dart:29-41`; `pubspec.yaml` has no
  `flutter_secure_storage` (or equivalent Keystore-backed storage) dependency.
- **Recommended remediation:** Store the Bearer token via
  `flutter_secure_storage` (Android Keystore-backed `EncryptedSharedPreferences`)
  instead of plain `shared_preferences`.
- **Verification method:** Static review confirmed no encryption layer exists
  in the dependency list or the `Api` class. Dynamic verification (pulling the
  file off a rooted/emulated device) was not performed in this environment.

---

### SEC-002 — Logout does not revoke the session server-side

- **Status: PARTIALLY FIXED, and now fully verified against the backend**
  (branch `claude/kukkeep-fix-critical-bugs`) — `Api.logout()` now calls the
  shared backend's `auth.logout` (`kukbook-erp/server/routers.ts:1328-1334`)
  best-effort before clearing local state. A follow-up backend read
  confirmed exactly what that endpoint does and doesn't do:
  - `auth.logout` only calls `clearSessionCookie` (and logs a
    `auth.logout` security event) — it clears the **httpOnly cookie** the
    web client uses, which is irrelevant to a Bearer-token client like
    KukKeep.
  - The token itself is a **stateless JWT** (`jose` `SignJWT`/`jwtVerify`,
    HS256, signed with `ENV.cookieSecret` — see
    `kukbook-erp/server/_core/sdk.ts:209-281`), verified with no DB or
    session-table lookup and no blacklist/revocation check
    (`authenticateRequest`, `kukbook-erp/server/_core/sdk.ts:363-374`).
    `kukbook-erp`'s Drizzle schema has no session/JWT-id table to revoke
    against.
  - **Conclusion:** calling `auth.logout` from KukKeep is worth doing (it
    logs the event, and matches expected behavior if a session-table/
    revocation-list is added later) but it does **not**, and today
    **cannot**, actually invalidate the Bearer token — the JWT remains valid
    until its own expiry regardless. A true fix needs backend work (a
    session/JWT-id table plus a revocation check in `authenticateRequest`)
    and is out of this repo's scope; flagged here for `kukbook-erp` to pick
    up.
- **Severity:** Major
- **Affected component:** `lib/api.dart` (`Api.logout()`);
  `kukbook-erp/server/routers.ts:1328-1334` (`auth.logout`);
  `kukbook-erp/server/_core/sdk.ts:209-281,363-374` (JWT issuance/verification)
- **Attack scenario:** If a device is lost, stolen, or a token is otherwise
  captured (e.g., via SEC-001, now fixed) before the user logs out, the
  token remains valid and replayable until its own expiry — logging out in
  the app does not shorten that window today.
- **Recommended remediation:** In `kukbook-erp`: add a session/JWT-id table
  (or a short blacklist) and check it in `authenticateRequest`; then have
  `auth.logout` (and the new `auth.deleteMyAccount` flow) revoke against it.
  This is a backend architecture change, not a KukKeep-only fix.
- **Verification method:** Static review of `lib/api.dart`'s `logout()`, plus
  a direct read of the relevant `kukbook-erp` source (exact file:line
  citations above) — this is one of the few findings in this audit verified
  against the actual backend rather than marked NOT VERIFIED.

---

### SEC-003 — No certificate pinning

- **Severity:** Minor (defense-in-depth, not an active exploit path today)
- **Affected component:** `lib/api.dart` (uses the plain `http` package
  against the OS trust store)
- **Attack scenario:** If a device trusts a malicious root/intermediate CA
  (via MDM misconfiguration, malware, or a user manually installing a rogue
  CA), an attacker with that CA could MITM the app's HTTPS traffic to
  `keep.kuklabs.com`, including the Bearer token and full note content.
- **Evidence:** `pubspec.yaml` — only `http: ^1.2.2`, no pinning library
  (`http_certificate_pinning`, `dio` + pinning interceptor, etc.).
- **Recommended remediation:** Consider certificate/public-key pinning for
  the API host, weighed against the operational cost of rotating pins on
  certificate renewal. Given this is a personal-notes app (not
  financial/health data), this is reasonable to defer, but should be a
  conscious decision, not an oversight.
- **Verification method:** Static — confirmed no pinning dependency exists.

---

### SEC-004 — Google OAuth code exchanged over a GET request (URL query parameter)

- **Severity:** Minor
- **Affected component:** `lib/api.dart:171-186` (`googleExchange`)
- **Attack scenario:** The one-time OAuth code is passed as a URL query
  parameter (`GET /api/auth/google/app-exchange?code=...`) rather than in a
  POST body. Query parameters are more likely to be captured in server access
  logs, reverse proxy logs, or browser/http-client history than a POST body.
  If the code is genuinely one-time-use and short-lived (can't confirm — the
  validation logic is server-side, out of scope), the practical risk is low,
  but this is a well-known anti-pattern for anything sensitive.
- **Evidence:** `lib/api.dart:172-173`
- **Recommended remediation:** Change this endpoint to accept POST with the
  code in the request body (requires a coordinated change in `kukbook-erp`).
- **Verification method:** Static — confirmed the client issues a GET.

---

### SEC-005 — Client uses a custom URL scheme, not Android App Links, for the OAuth return

- **Severity:** Minor (informational / MASVS-PLATFORM)
- **Affected component:** `kukkeep://auth` deep link
  (`.github/workflows/build-flutter-apk.yml` intent-filter injection;
  `lib/google_auth.dart:29-44,56-73`)
- **Attack scenario:** Custom URL schemes (`kukkeep://...`) are not
  exclusive to one app on Android the way verified App Links
  (`https://keep.kuklabs.com/...` with Digital Asset Links) are — a second,
  malicious app could register the same scheme and race to intercept the
  callback, or a user could be tricked into tapping a crafted
  `kukkeep://auth?code=...&error=` link. The app does guard against replaying
  the *same* code twice in the same run (`_lastCode` check in
  `google_auth.dart:30,60-61`), which limits (but doesn't eliminate) impact,
  since the real mitigation must be that the code is single-use and
  short-lived on the server (NOT VERIFIED — out of scope).
- **Evidence:** `lib/google_auth.dart:9-16,56-73`;
  `.github/workflows/build-flutter-apk.yml` (deep-link intent-filter step)
- **Recommended remediation:** Migrate to Android App Links
  (`https://keep.kuklabs.com/auth/callback` verified via
  `assetlinks.json`) where practical; this is a larger change (needs a
  `/.well-known/assetlinks.json` on the server) so treat as a backlog item,
  not urgent given the one-time-code mitigation already in place.
- **Verification method:** Static — confirmed scheme type and replay guard.

---

### SEC-006 — Firebase API key and multi-app `google-services.json` reviewed — no issue found

- **Severity:** N/A (documented as a check performed, not a finding)
- **Details:** The committed `google-services.json` contains client entries
  for four Kuklabs apps (`com.kukbook.erp`, `com.kukchat.app`,
  `com.kuklabs.keep`, `com.kuklabs.task`) under one Firebase project
  (`kukchat-b6402`). This is **consistent with, not a violation of**, the
  "one shared Google Cloud/Firebase project" mandate in
  `KUKLABS_IDENTITY.md`. The API key present
  (`AIzaSyCKs1PhjIpjsA6TFGY9su-7DUzKTFeb8pA`) is a public Firebase **client**
  key by design (safe to ship; it is not a secret credential) — provided it
  is restricted server-side (Android package name + SHA-1, API restrictions)
  in Google Cloud Console. That restriction configuration lives outside this
  repo and could not be verified here.
- **Recommended action:** Confirm (in Google Cloud Console, out of this
  repo's scope) that the API key is restricted to the four expected Android
  package names/signing certificates.
- **Verification method:** Static review of the committed JSON file only.

---

### SEC-007 — No request timeouts on most network calls

- **Status: FIXED** (branch `claude/kukkeep-fix-critical-bugs`) — `query()`,
  `mutate()`, and `googleExchange()` now all apply a consistent 20s
  `.timeout(...)`; `googleEnabled()` already had its own 6s timeout.
  `TimeoutException` falls through `friendlyError()`'s generic-exception
  branch to the safe fallback message (not technical-looking, so this is
  correct even though it isn't a dedicated "request timed out" string).
- **Severity:** Minor
- **Affected component:** `lib/api.dart` — `query()`/`mutate()` and every
  auth call except `googleEnabled()` (which has a 6s timeout) issue
  `http.get`/`http.post` with no `.timeout(...)`.
- **Attack scenario:** Not an exploit path, but a resilience/DoS-adjacent
  issue: a hung connection (bad network, server-side stall) leaves the UI
  stuck on a loading spinner indefinitely with no user recourse beyond
  force-closing the app.
- **Evidence:** `lib/api.dart:96-108,112-123,133-149,171-186`
- **Recommended remediation:** Add a consistent timeout (e.g., 15-20s) to all
  HTTP calls, surfaced via the existing friendly-error offline/timeout
  message.
- **Verification method:** Static — confirmed via `grep` for `.timeout(` in
  `lib/api.dart` (only one match, in `googleEnabled()`).

---

### SEC-008 — Error-message policy is inconsistently applied (cross-reference)

- **Severity:** Major (raw error text can occasionally include lower-level
  exception detail — see BUG-002 in `BUG_REPORT.md` for the full list of 19
  call sites). Not repeated in full here to avoid duplication; flagged here
  because inconsistent error handling is itself a MASVS-CODE finding (a raw
  stack/exception string is a low-grade information-disclosure risk, e.g. it
  could reveal internal package/class names).
- **Evidence:** See `BUG_REPORT.md` BUG-002.

---

## Checklist against the requested OWASP-adjacent categories

| Category | Status | Notes |
|---|---|---|
| Broken access control | NOT APPLICABLE (client) | Access control is enforced server-side (`kukbook-erp`); not verifiable from this repo |
| Insecure direct object references | NOT APPLICABLE (client) | Server-side concern |
| Authentication weaknesses | **FOUND** (SEC-001, SEC-002) | See above |
| Authorization bypass | NOT VERIFIED | Server-side |
| Privilege escalation | NOT APPLICABLE | No roles/privilege model visible in this client |
| Weak password policy | PARTIAL | Client enforces "≥8 chars, 1 letter, 1 number" (`auth_messages.dart` `weakPassword`); actual enforcement is presumably also server-side — NOT VERIFIED there |
| Brute-force vulnerability | NOT VERIFIABLE (client) | No client-side lockout is expected or present; server-side rate limiting NOT VERIFIED |
| Missing rate limits | NOT VERIFIABLE (client) | Server-side |
| Session fixation | NOT APPLICABLE | Bearer-token model, no session cookies |
| Session expiry issues | PARTIAL | ~30-day token TTL per code comment; no client-side re-auth prompt before expiry; NOT VERIFIED server-side |
| Token leakage | **FOUND** (SEC-001) | Plaintext storage |
| Insecure token storage | **FOUND** (SEC-001) | Same |
| SQL injection | NOT APPLICABLE (client) | No local SQL; server-side scope |
| XSS | NOT APPLICABLE | Native Flutter UI, no WebView rendering of untrusted HTML found |
| CSRF | NOT APPLICABLE | Bearer-token API, not cookie-based |
| SSRF | NOT APPLICABLE (client) | Server-side scope |
| Command injection | NOT APPLICABLE | No shell/process invocation in this client |
| Path traversal | NOT APPLICABLE | No local filesystem paths built from user input found |
| Unsafe deserialization | PASS | JSON decode only, into typed models with defensive `?? default` parsing (`models.dart`) |
| Unrestricted file upload | PARTIAL | Client caps attachments at 8MB (`note_editor_screen.dart:277,298`); no client-side type allowlist — relies on server-side validation (NOT VERIFIED) |
| Exposed API keys | REVIEWED, no issue (SEC-006) | Public Firebase client key by design |
| Hardcoded credentials | PASS | No passwords/secrets found hardcoded in the client |
| Secrets committed to Git | PASS | `google-services.json` is public client config by design; Play signing keystore/passwords are GitHub Secrets, not committed (confirmed in the CI workflow review from the earlier session) |
| Debug endpoints | PASS | None found |
| Sensitive info in logs | NOT VERIFIED | No explicit logging framework found; default `print`/`debugPrint` use not audited line-by-line for token leakage |
| Insecure CORS | NOT APPLICABLE (client) | Server-side scope |
| Missing security headers | NOT APPLICABLE (client) | Server-side scope |
| Vulnerable dependencies | NOT VERIFIED | No `flutter pub outdated --mode=null-safety` / dependency-CVE scan was run (no Flutter toolchain available in this environment) — recommend running `flutter pub outdated` and checking pub.dev advisories before release |
| Improper encryption | **FOUND** (SEC-001) | No encryption at rest for the token |
| Public cloud storage | NOT VERIFIED | Server-side (attachment storage backend) |
| Unprotected backups | NOT VERIFIED | Android `allowBackup` flag is set by the generated manifest in CI — not overridden to `false`; combined with SEC-001, an `adb backup` on a debuggable/rooted setup could expose the plaintext token. Recommend explicitly setting `android:allowBackup="false"` (or using backup rules that exclude the prefs file) in the CI manifest-patch step. |
| Unsafe deep links | **FOUND** (SEC-005) | See above |
| Exposed mobile components | NOT VERIFIED | Full manifest not inspectable here (generated fresh by `flutter create` in CI); recommend a one-time manual review of the CI-generated `AndroidManifest.xml` for exported components |
| Reverse-engineering risks | NOT VERIFIED | No obfuscation (`--obfuscate`) flag seen in the release build step; standard Flutter release builds are moderately resistant but not obfuscated by default |
| Rooted/jailbroken device risk | NOT APPLICABLE | No root-detection is implemented or expected for a notes app of this risk profile |

## Summary

- **2 Major findings**: plaintext token storage (SEC-001) and no server-side
  logout revocation (SEC-002) — the token, once created, is very long-lived
  and hard to invalidate short of a server-side admin action.
- **4 Minor findings**: no cert pinning, GET-based OAuth code exchange,
  custom-scheme deep link, no request timeouts.
- **1 reviewed/no-issue item**: shared Firebase project configuration.
- Several categories are legitimately **not verifiable from this repo**
  because the relevant control lives in `kukbook-erp` (rate limiting, session
  storage, SQL safety, CORS) — these are called out rather than assumed safe
  or unsafe.
- No secrets, hardcoded credentials, SQLi/XSS/CSRF-class findings, or
  destructive-exploit-worthy issues were found in the client.
