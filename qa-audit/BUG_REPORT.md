# Bug Report — KukKeep (Flutter, Android)

All bugs below were found by **static code review** (no running device/emulator
was available in this environment — see `TEST_COVERAGE_MATRIX.md`). "Steps to
reproduce" describe the code path that causes each bug; they have not been
manually re-run on a device. Security-flavored bugs are cross-referenced to
`SECURITY_AUDIT.md` rather than duplicated in full.

---

### BUG-001 — Note editor silently discards unsaved edits when the back-button save fails

- **Module:** Notes / Note editor
- **Environment:** Any Android device, any network condition where the save
  request errors (offline, server 5xx, timeout)
- **Preconditions:** User opens an existing note, edits it, then presses the
  system/hardware back button while offline or the server is unreachable
- **Steps to reproduce:**
  1. Open an existing note, change the title or body
  2. Disable network (or the server call otherwise throws)
  3. Press back
- **Expected result:** The user is warned the save failed and can retry or
  explicitly choose to discard the edit
- **Actual result:** `_onBack()` (`lib/screens/note_editor_screen.dart:425-433`)
  calls `await _save()`; `_save()`'s catch block (`:406-411`) swallows the
  error (shows a raw-text snackbar, sets `_saving = false`, **does not
  rethrow and does not pop**) and returns normally. Control returns to
  `_onBack()`, which unconditionally pops the screen
  (`Navigator.pop(context, _noteId != null)`) regardless of whether the save
  actually succeeded — the edit is lost with only a fleeting snackbar as
  evidence.
- **Severity:** Critical (data loss)
- **Priority:** P0 — fix before next release
- **Evidence:** `lib/screens/note_editor_screen.dart:367-433`
- **Probable root cause:** `_save()`'s failure path and `_onBack()`'s pop
  decision aren't connected — `_onBack` doesn't check whether `_save`
  actually succeeded.
- **Recommended fix:** Have `_save()` return a `bool` (or rethrow), and have
  `_onBack()` only pop when it's true; on failure, stay on the editor and
  keep the snackbar/retry visible.
- **Regression risk:** Low — the change is local to `_onBack`/`_save`'s return
  contract.

---

### BUG-002 — Raw exception text shown to users in 19 call sites outside the auth screens

- **Module:** Notes, Note editor, AI Memory, OTP verification
- **Environment:** Any
- **Preconditions:** Any network/API error while using notes, editing, OCR/
  attachment upload, AI actions, or OTP verify/resend
- **Steps to reproduce:** Trigger any error in these flows (e.g., go offline
  and try to trash a note, or attach a file while the server 500s)
- **Expected result:** A friendly, approved message per
  `docs/kuklabs/KUKLABS_AUTH_CONTENT_TEMPLATES.json` / this app's own
  `lib/auth_messages.dart` (added in the previous session's PR for the auth
  screens only)
- **Actual result:** `e.toString()` is passed straight into a `SnackBar`/error
  `Text` in 19 places. For a plain `ApiError` this is usually already a
  reasonably clean server message, but for anything else (a `TypeError`, a
  `FormatException`, a raw `SocketException`, a Dart `Exception` — none of
  which are sanitized) the user sees framework-shaped text, violating this
  app's own KUKLABS_MASTER_STANDARD.md §8.7 rule ("never show raw JSON, stack
  traces, or framework errors").
- **Severity:** Major (systemic policy violation, not a crash)
- **Priority:** P1
- **Evidence:**
  `lib/screens/otp_screen.dart:58,72`;
  `lib/screens/notes_screen.dart:87,155,171,176,191,207,223,237`;
  `lib/screens/ai_memory_screen.dart:28`;
  `lib/screens/note_editor_screen.dart:262,280,301,331,350,409,420,481`
- **Probable root cause:** `friendlyAuthError()` (in `lib/auth_messages.dart`)
  was introduced only for the auth flow in the prior change; it was never
  rolled out to the rest of the app's error-handling call sites.
- **Recommended fix:** Add a general-purpose `friendlyError(Object e)` (or
  widen `friendlyAuthError` for non-auth use) and route all 19 sites through
  it.
- **Regression risk:** Low — message-text-only change, no control-flow impact.

---

### BUG-003 — Search only covers the currently open view, not all notes

- **Module:** Notes / Search
- **Environment:** Any
- **Preconditions:** Notes exist in more than one view (e.g., some in Archive,
  some live)
- **Steps to reproduce:** Open "Notes", search for text that exists only in an
  archived note
- **Expected result (per Google Keep-parity intent stated in this app's own
  code comments):** the note is found
- **Actual result:** `_filtered` (`lib/screens/notes_screen.dart:121-134`)
  filters only `_notes`, which `_load()` populates from the **current view's**
  query (`archived`/`trashed` flags) — so a search box that looks global
  actually only searches whatever view is open.
- **Severity:** Minor
- **Priority:** P2
- **Evidence:** `lib/screens/notes_screen.dart:64-91, 121-134`
- **Probable root cause:** Search reuses the view's already-loaded list
  instead of issuing its own unscoped query.
- **Recommended fix:** Either (a) make search issue a dedicated
  cross-view query when the search box is non-empty, or (b) if scoping is
  intentional, add a visible "Search everywhere" toggle so it isn't a silent
  surprise.
- **Regression risk:** Low.

---

### BUG-004 — Logout does not revoke the session server-side

- **Module:** Auth / Session management
- **Severity:** Major (security)
- **Priority:** P1
- **Details:** See `SECURITY_AUDIT.md` SEC-002 for the full write-up.
  `Api.logout()` (`lib/api.dart:43-51`) only clears local `SharedPreferences`;
  no HTTP call is made to invalidate the Bearer token server-side.
- **Evidence:** `lib/api.dart:43-51`

---

### BUG-005 — Every note-editor exit triggers a network write, even with no changes

- **Module:** Notes / Note editor
- **Environment:** Any
- **Steps to reproduce:** Open an existing note, change nothing, press back
- **Expected result:** No network call (nothing changed)
- **Actual result:** `_onBack()` always calls `_save()`, which always calls
  `updateNote(...)` for an existing note — a PUT-equivalent tRPC mutation
  fires on every exit regardless of whether any field changed.
- **Severity:** Minor (efficiency/battery/data usage, not correctness)
- **Priority:** P3
- **Evidence:** `lib/screens/note_editor_screen.dart:367-391, 425-433`
- **Probable root cause:** No dirty-tracking; `_save` doesn't diff against the
  originally-loaded note.
- **Recommended fix:** Track a dirty flag (or compare the built payload
  against the original) and skip the network call when nothing changed.
- **Regression risk:** Low.

---

### BUG-006 — FCM device token is fetched but never registered with the backend

- **Module:** Notifications / Push
- **Environment:** Any
- **Actual result:** `Push.init()` (`lib/push.dart:18-40`) calls
  `fm.getToken()` and stores it in a local (non-persisted) instance variable
  that is never sent to any API endpoint. Only the shared `kukkeep-all`
  broadcast topic is subscribed to.
- **Severity:** Minor (feature gap, likely intentional per the file's own
  docstring — "so notifications can be sent from the Firebase console to all
  KukKeep devices" — but it means **no per-user targeted push** is possible
  today, e.g. "someone commented on your shared note")
- **Priority:** P3 (only relevant if/when personalized push is planned)
- **Evidence:** `lib/push.dart:16-25`
- **Recommended fix:** If per-user push is ever needed, send `token` to a
  backend endpoint keyed by the logged-in user/company.
- **Regression risk:** N/A (no behavior change today).

---

### BUG-007 — Icon-only controls lack accessible labels

- **Module:** All screens (Notes, Note editor, Settings, Draw)
- **Environment:** TalkBack / screen-reader users
- **Actual result:** Pin, archive, delete, drag-reorder handle, color swatches,
  AI action chips, and the grid/list toggle are `Icon`/`InkWell`/
  `GestureDetector` combinations with no `Semantics`/`tooltip` in most cases
  (the grid/list toggle is the one exception — it has a `tooltip`). A
  TalkBack user hears "button" with no indication of its function.
- **Severity:** Minor (accessibility)
- **Priority:** P2
- **Evidence:** e.g. `lib/screens/notes_screen.dart:510-511,556-565`;
  `lib/screens/note_editor_screen.dart:499-501,692-704`
- **Recommended fix:** Add `tooltip`/`Semantics(label: ...)` to every
  icon-only interactive element; provide a non-drag reorder alternative
  (e.g., "Move up"/"Move down" actions) for the checklist drag handle.
- **Regression risk:** Low.

---

### BUG-008 — Attachment/cover images have no disk cache

- **Module:** Notes, Note editor
- **Actual result:** `Image.network(...)` is used directly for cover images
  and attachment thumbnails (`notes_screen.dart:493`,
  `note_editor_screen.dart:618`) with no `cached_network_image` (or
  equivalent) — images re-fetch on every rebuild/scroll and are unavailable
  offline even if previously viewed.
- **Severity:** Minor (performance + offline UX)
- **Priority:** P2
- **Evidence:** `lib/screens/notes_screen.dart:493-503`;
  `lib/screens/note_editor_screen.dart:616-620`
- **Recommended fix:** Adopt `cached_network_image` for both call sites.
- **Regression risk:** Low (additive dependency).

---

### BUG-009 — `use_build_context_synchronously` lint disabled project-wide

- **Module:** Build/lint configuration
- **Actual result:** `analysis_options.yaml` sets
  `use_build_context_synchronously: false`, removing the compiler's warning
  for using a `BuildContext` after an `await` without a `mounted` check. Most
  current call sites do guard with `if (mounted)`, but the safety net is gone
  for all future changes.
- **Severity:** Cosmetic/Minor (no confirmed live defect from this today —
  spot-checked several async call sites and found `mounted` guards in place)
- **Priority:** P3
- **Evidence:** `analysis_options.yaml:5`
- **Recommended fix:** Re-enable the lint and fix any resulting warnings; it's
  cheap insurance against a real crash-class bug later.
- **Regression risk:** None (lint-only change surfaces new warnings, doesn't
  change behavior by itself).

---

### BUG-010 — No draft autosave while typing

- **Module:** Note editor
- **Actual result:** Edits exist only in `TextEditingController`s until an
  explicit Save/back; an OS-level app kill (low memory, swipe-away) while
  composing a note loses everything typed since the note was opened/last
  saved.
- **Severity:** Minor
- **Priority:** P3
- **Evidence:** `lib/screens/note_editor_screen.dart` (no periodic/debounced
  save found)
- **Recommended fix:** Debounced autosave (e.g., every N seconds of
  inactivity) mirroring Google Keep's behavior.
- **Regression risk:** Low–Medium (needs care to avoid the BUG-005-style
  "save on every keystroke" cost — should debounce and dirty-check).

---

### BUG-011 — No workspace/company switcher after initial login

- **Module:** Auth / Notes
- **Actual result:** `_pickCompany()` (`auth_screen.dart`) only appears at
  login when a user has 2+ companies. There is no equivalent control in
  Settings to switch companies later in the session.
- **Severity:** Minor–Medium (feature gap; blocks a real workflow for
  multi-workspace users, but doesn't corrupt data)
- **Priority:** P2
- **Evidence:** `lib/screens/auth_screen.dart:123-142`;
  `lib/screens/settings_screen.dart` (no switcher present)
- **Recommended fix:** Add a workspace row to Settings that reopens the same
  company picker.
- **Regression risk:** Low (additive).

---

## Severity/priority summary

| ID | Title | Severity | Priority |
|---|---|---|---|
| BUG-001 | Silent data loss on back-nav save failure | Critical | P0 |
| BUG-002 | Raw error text in 19 non-auth call sites | Major | P1 |
| BUG-004 | Logout doesn't revoke server session | Major | P1 |
| BUG-003 | Search scoped to current view only | Minor | P2 |
| BUG-007 | Icon-only controls lack accessible labels | Minor | P2 |
| BUG-008 | No disk cache for attachment images | Minor | P2 |
| BUG-011 | No workspace switcher after login | Minor–Medium | P2 |
| BUG-005 | Unconditional save on every editor exit | Minor | P3 |
| BUG-006 | FCM token never registered (broadcast-only push) | Minor | P3 |
| BUG-009 | `use_build_context_synchronously` lint disabled | Cosmetic/Minor | P3 |
| BUG-010 | No draft autosave | Minor | P3 |

No Blocker-severity bugs were found. One Critical (data loss) bug (BUG-001)
and two Major bugs (BUG-002, BUG-004) should be fixed before the next Play
Store release; see `REMEDIATION_PLAN.md`.
