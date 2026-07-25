# KukKeep Web Clipper (browser extension)

A minimal **Manifest V3** browser extension (Chrome / Edge / Brave) that saves
the current page — title, selected text, and URL — to KukKeep as a new note.

It talks to the same shared backend as the app (`https://keep.kuklabs.com`,
tRPC over HTTP) and authenticates with the existing **Kuklabs account session
cookie** — no separate login. You must be signed in at `keep.kuklabs.com` in
the same browser.

## How it works
- `host_permissions` for `https://keep.kuklabs.com/*` let the extension call the
  API cross-origin (no CORS setup needed) and send the session cookie
  (`credentials: 'include'`).
- The popup pre-fills the note from the active tab (title + current selection +
  URL), then calls `keep.create` (resolving the user's first company for the
  `x-company-id` header, mirroring the web app).
- The request/response format mirrors `lib/api.dart` exactly: batch envelope
  `{"0":{"json": <input>}}`, result at `[0].result.data.json`.

## Load it (unpacked, for testing)
1. Open `chrome://extensions`, enable **Developer mode**.
2. **Load unpacked** → select this `browser-extension/` folder.
3. Sign in at `https://keep.kuklabs.com`.
4. Click the toolbar icon on any page → edit → **Save to KukKeep**.

## Notes / follow-ups
- **Icons:** bundled in `icons/` (16/48/128, generated from the KukKeep app icon)
  and wired into `manifest.json` — the toolbar button is branded.
- **Store publishing** (Chrome Web Store) is a manual step and is out of scope
  for the app repo. To publish: zip this folder and upload it in the Chrome Web
  Store Developer Dashboard.
- Kept intentionally dependency-free (plain HTML/CSS/JS) so it needs no build.
