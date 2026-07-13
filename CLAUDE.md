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

- Login/signup uses the shared KukLabs account. The app talks to the shared
  backend at `https://keep.kuklabs.com` (tRPC over HTTP) — it does **not** have
  its own server or database. The `keep` router + `kuk_keep_*` tables live in
  the shared backend (kukbook-erp), against the one shared MySQL DB.
- Google sign-in = system browser + `kukkeep://auth` deep-link return (server
  OAuth), never an in-app webview and never a per-app Google client.
- UI follows the shared standard: **Inter** font, shared neutral+semantic
  colours, per-product accent (`#2868F0`), no serif in product UI.

## Structure
- `lib/` — Dart source. `lib/screens/` — screens (auth, notes, editor, draw,
  settings, AI memory, OTP). `lib/api.dart` — tRPC client. `lib/google_auth.dart`
  — browser OAuth + deep-link. `lib/note_colors.dart` — design tokens + version.
- `assets/` — launcher icon + logo. `google-services.json` — Firebase config
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
