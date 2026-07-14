# CLAUDE.md — KukKeep (Flutter app)

This repository is the **native KukKeep mobile app** (Flutter/Android). The
pubspec.yaml is at the repo root; the native `android/` scaffolding is generated
fresh in CI by `flutter create`, so only `lib/`, `assets/`, `pubspec.yaml` and
`google-services.json` are committed here.

Package id: `com.kuklabs.keep` · Domain: keep.kuklabs.com

## ⚠️ KUKLABS IDENTITY & INFRA (MANDATORY)
This app follows the Kuklabs identity + infrastructure mandate — see
`KUKLABS_IDENTITY.md` in this repo (and the fuller standard in kukbook-erp).
**One Kuklabs Account (central AuthKit), one shared identity DB, one Google
Cloud/Firebase project.** Never build separate auth, users table, password
system, session system, Firebase project or Google OAuth client for this app.

- Login/signup uses the shared Kuklabs account. The app talks to the shared
  backend at `https://keep.kuklabs.com` (tRPC over HTTP) — it does **not** have
  its own server or database. The `keep` router + `kuk_keep_*` tables live in
  the shared backend (kukbook-erp), against the one shared MySQL DB.
- Google sign-in = system browser + `kukkeep://auth` deep-link return (server
  OAuth), never an in-app webview and never a per-app Google client.
- UI follows the shared standard: **Inter** font, shared neutral+semantic
  colours, per-product accent (`#2868F0`), no serif in product UI.

## ⚠️ KUKLABS UI/AUTH STANDARD (MANDATORY)
Before changing authentication, branding, navigation, profile, app version
display, content or shared UI, read `docs/kuklabs/`:
`KUKLABS_MASTER_STANDARD.md` (full standard) · `KUKLABS_AGENT_INSTRUCTIONS.md` ·
`KUKLABS_BRAND_CONFIG.json` (this app's product values) ·
`KUKLABS_DESIGN_TOKENS.json` (sizes/colours) ·
`KUKLABS_AUTH_CONTENT_TEMPLATES.json` (approved copy) ·
`APPROVED_LOGIN_REFERENCE.png` (visual baseline) · `DEVELOPER_HANDOFF.md`.
Canonical source of truth: `amithkukllod777/kukbook-erp`. Only the product
icon, name, tagline, accent colour and product-specific modules may change —
never the auth shell, control sizes, Google button rules, error-message
policy, profile structure or version-display format.

## Structure
- `lib/` — Dart source. `lib/screens/` — screens (auth, notes, editor, draw,
  settings, AI memory, OTP). `lib/api.dart` — tRPC client. `lib/google_auth.dart`
  — browser OAuth + deep-link. `lib/auth_messages.dart` — approved auth
  content + friendly-error mapping (`docs/kuklabs/KUKLABS_AUTH_CONTENT_TEMPLATES.json`).
  `lib/note_colors.dart` — design tokens + version/build.
- `assets/icon.png` (launcher icon source) and `assets/logo.png` (in-app
  wordmark icon, transparent) are the product icon — regenerate both together
  from the same master mark. `google-services.json` — Firebase config
  (public client config).

## Build (GitHub Actions → releases)
- **APK** (testing): run `build-flutter-apk.yml` → published to the
  `flutter-latest` release.
- **Signed AAB** (Play Store): run `build-play-aab.yml` → published to the
  `aab-latest` release. Requires 4 repo Secrets:
  `KUKKEEP_KEYSTORE_BASE64`, `KUKKEEP_STORE_PASSWORD`, `KUKKEEP_KEY_PASSWORD`,
  `KUKKEEP_KEY_ALIAS`. The upload keystore is stable — never regenerate it, and
  never commit it.
- Bump `version:` in `pubspec.yaml` (and `kAppVersion` in `lib/note_colors.dart`)
  each release; the `+N` build number must increase for every Play upload.

## Play Store
See `PLAY_STORE_LISTING.md` for copy-paste listing content.
