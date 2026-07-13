# KukKeep — Google Play Store listing

Copy-paste content for the Play Console listing. Package: `com.kuklabs.keep`.

## App name (max 30 characters)
```
KukKeep: Notes & Reminders
```

## Short description (max 80 characters)
```
Fast notes, checklists & reminders with AI — synced to your KukLabs account.
```

## Full description (max 4000 characters)
```
KukKeep is a fast, clean notes app for everything you want to remember — quick
notes, checklists, and reminders that stay in sync through your one KukLabs
account across every device and every Kuk app.

Capture a thought in seconds, turn any note into a checklist, set a reminder,
and let AI help you clean up, summarise, and find things later. No clutter, no
ads — just your notes, ready when you need them.

WHAT YOU CAN DO

• Notes & checklists — write freely or make a tick-list; check items off and
  completed ones move to the bottom automatically.
• Reminders — get a notification at the exact time you choose, even after a
  restart.
• Colours & labels — organise notes with colours and labels, pin the important
  ones to the top.
• Images, files & drawing — attach photos and documents, or sketch a quick
  drawing right inside a note.
• Scan text from images (OCR) — snap a photo and pull the text straight into a
  note.
• AI Memory — ask a question in plain language and KukKeep finds the answer
  from your own notes. One tap can also summarise a note, tidy it up, suggest a
  title, or pull out key points.
• Search that highlights — find any note instantly, with your search words
  highlighted in the results.
• Archive & Trash — archive notes you don't need now; deleted notes stay in
  Trash for 30 days so nothing is lost by accident.
• Light & dark mode — comfortable in any lighting.

ONE KUKLABS ACCOUNT

Sign in with email or Google using your single KukLabs account — the same login
works across KukBook, KukKeep and the whole Kuklabs ecosystem. Your notes are
tied to your account and sync automatically.

PRIVACY

Your notes belong to you. KukKeep shows no ads and doesn't sell your data.
Sign-in is protected by your KukLabs account.

KukKeep is a Kuklabs product. Learn more at keep.kuklabs.com.
```

## Category & tags
- **Category:** Productivity
- **Tags:** notes, checklist, reminders, to-do, notebook

## Contact & policy
- **Email:** support@kuklabs.com
- **Website:** https://keep.kuklabs.com
- **Privacy Policy:** https://kuklabs.com/privacy
- **Terms of Use:** https://kuklabs.com/terms

## Content rating
- Target: **Everyone** (no violence, no mature content). Answer the Play rating
  questionnaire with "No" to all sensitive-content questions.

## Release notes — "What's new" (max 500 characters)
```
• Brand-new KukLabs sign-in screen — Login/Sign Up in one place, Continue with Google.
• Cleaner notes, checklists that move done items to the bottom, and search that highlights matches.
• Attach images/files, sketch drawings, scan text from photos (OCR).
• AI Memory: ask questions across your notes; summarise, tidy up, and title in one tap.
• Reminders that fire on time, light & dark mode.
```

## Data safety (Play Console → App content → Data safety)
Declare the following (collected, tied to the user, for app functionality — not
shared with third parties, not for ads):
- **Personal info:** Name, Email address — for account sign-in.
- **App activity / User content:** Notes, checklists, photos/files you attach —
  stored to provide sync.
- Data is encrypted in transit (HTTPS). Users can request deletion via
  support@kuklabs.com / their KukLabs account.

## Graphics you still need to upload (binary assets — prepare separately)
- **App icon:** 512×512 PNG (the KukKeep checklist icon).
- **Feature graphic:** 1024×500 PNG/JPG.
- **Phone screenshots:** at least 2 (min 320px, max 3840px; 16:9 or 9:16). Use
  the auth screen, notes grid, a checklist, and the AI Memory screen.
- (Optional) 7-inch / 10-inch tablet screenshots.

## Build & versioning notes
- Upload the signed **.aab** produced by the `build-kukkeep-aab` workflow.
- Each new Play upload needs a higher **versionCode**. That comes from the
  pubspec build number (`version: 2.2.1+34` → versionCode 34). Bump the `+N`
  before every new release build.
- Signing uses the KukLabs upload keystore (kept in repo Secrets). Enable
  **Play App Signing** (default) when creating the app so the upload key is
  recoverable.
