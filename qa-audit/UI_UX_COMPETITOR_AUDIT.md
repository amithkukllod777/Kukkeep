# UI/UX Competitor Audit — KukKeep

**Important limitation:** this audit did not install or screenshot any
competitor app — comparisons below are based on (a) direct review of
KukKeep's actual UI code (`lib/screens/*.dart`), and (b) the competitor
research's confirmed feature/structure findings (`COMPETITIVE_FEATURE_MATRIX.md`),
not pixel-level visual inspection of competitor screens. Where a comparison
would require having actually used the competitor app, it's marked NOT
VERIFIED and framed as a reasonable general-knowledge expectation rather than
a confirmed observation. No copyrighted competitor visuals were viewed,
copied, or are referenced here beyond publicly-known structural facts (e.g.,
"OneNote uses a notebook/section/page hierarchy").

---

## Screen/workflow: First-time auth (Login/Sign Up)

- **Current experience:** Single unified screen with a Login/Sign Up tab
  switcher, product icon + collage background, identity/password fields,
  primary button, "Continue with Google," legal text, "Powered by Kuklabs."
  Sizing now matches `docs/kuklabs/KUKLABS_DESIGN_TOKENS.json` exactly
  (58h inputs/buttons, 56h tabs, 16 radius, 420 max content width) as of this
  session's earlier logo/auth-standard PR, and is visually benchmarked
  against `docs/kuklabs/APPROVED_LOGIN_REFERENCE.png`.
- **Competitor benchmark:** Google Keep doesn't have its own login screen at
  all — it inherits the Google Account sign-in flow (a system-level, highly
  polished, extremely low-friction experience Google controls, not Keep
  itself). OneNote and Evernote similarly delegate to Microsoft
  Account/Evernote's own account system. NOT VERIFIED in detail (no
  screenshots taken), but it's reasonable to say all three benefit from
  either an OS-level account picker or a mature, long-iterated login screen.
- **Identified problem:** None specific to KukKeep's *screen design* itself
  (it already follows an internally-consistent, well-specified design system)
  — the only structural difference is that KukKeep's auth is a full custom
  screen rather than an OS-level account picker, which is an architectural
  choice (shared Kuklabs account across apps), not a defect.
- **User impact:** Low — the screen is well-built for what it needs to do.
- **Recommendation:** None needed for the screen itself. (Two content-policy
  items — friendly-error consistency, BUG-002 — are functional, not visual,
  and are tracked in `BUG_REPORT.md` instead.)
- **Whether the improvement is visual, functional, or both:** N/A (no
  recommendation).
- **Evidence:** `lib/screens/auth_screen.dart`; `docs/kuklabs/KUKLABS_DESIGN_TOKENS.json`.
- **Priority:** — (no action needed)

---

## Screen/workflow: Main notes list

- **Current experience:** Masonry two-column grid (or single-column list,
  user-toggleable), pinned section first, card-based notes with title,
  preview text/checklist items, labels, reminder chip, attachment count,
  cover image. Search bar embedded in the app bar with highlighted matches.
- **Competitor benchmark:** Google Keep uses the same masonry-card pattern
  KukKeep is explicitly modeled on (per this repo's own code comments) —
  this is a genuine parity match, not an approximation. OneNote and Evernote
  use a notebook/list-based hierarchy instead of a card grid — structurally
  different, not necessarily worse, but slower for pure quick-capture
  scanning (NOT VERIFIED by direct use; this is a reasonable inference from
  the structural difference, not a measured finding).
- **Identified problem:** The search bar looks and reads as a global search
  ("Search your notes") but is actually scoped to the current view
  (BUG-003) — this is a **UX honesty problem**, not just a functional one:
  the affordance promises more than it delivers.
- **User impact:** Medium — users who search from Archive or a label view and
  don't find a note they know exists (because it lives elsewhere) may
  conclude the note was lost, which erodes trust in the app.
- **Recommendation:** Fix BUG-003 (make search global, or add a visible
  "Search everywhere" toggle so the scoping is an explicit choice, not a
  silent limitation).
- **Whether the improvement is visual, functional, or both:** Both — the fix
  is functional, but the affordance (the search hint text) may also need to
  change to accurately reflect the scope if a toggle approach is chosen.
- **Evidence:** `lib/screens/notes_screen.dart:64-91,121-134,291-306`.
- **Priority:** P1 (matches BUG-003's priority).

---

## Screen/workflow: Note editor

- **Current experience:** Single scrollable screen — title, body/checklist,
  AI action chips (Title/Summarize/Clean up/Key points), attachment chips
  (Image/Image+OCR/File/Draw), labels, reminder picker, note-type toggle,
  color palette. Auto-creates the note on first attachment so there's no
  "save first" friction.
- **Competitor benchmark:** Google Keep's note editor is structurally very
  similar (single scrollable card-editing surface); this is a strong parity
  match. OneNote's page editor is richer (free-form canvas, not a linear
  scroll) but heavier to learn; Evernote's is a more traditional rich-text
  editor. NOT VERIFIED by direct use.
- **Identified problem:** Back-navigation silently discards edits on a save
  failure (BUG-001) — this is the most serious UX problem in the app: it
  violates the "prevention of accidental destructive actions" principle the
  audit explicitly asks about, and does so in the single most-used editing
  surface in the app.
- **User impact:** High — potential silent loss of user-authored content,
  the worst possible UX outcome for a notes app whose entire value
  proposition is "your notes are safe here."
- **Recommendation:** Fix BUG-001 (don't pop until save actually succeeds;
  show a clear retry path on failure).
- **Whether the improvement is visual, functional, or both:** Functional.
- **Evidence:** `lib/screens/note_editor_screen.dart:367-433`.
- **Priority:** P0 (matches BUG-001).

---

## Screen/workflow: Settings / Account management

- **Current experience:** Account (read-only name), Theme, "Privacy & Trust"
  (four static marketing tiles), About (product name/version), Logout. No
  workspace switcher, no notification preferences, no data export, no
  account deletion, no Terms/Privacy links.
- **Competitor benchmark:** All three competitors' account-management
  surfaces are richer (they inherit account-provider settings — Google/
  Microsoft/Evernote account pages — which include data export, deletion,
  session management, etc., even if not literally inside the notes app
  itself). NOT VERIFIED by direct use, but reasonable given these are
  mature, large-company account systems.
- **Identified problem:** The Settings screen's own
  `KUKLABS_MASTER_STANDARD.md` §11.1 (a standard this repo itself now
  contains, added in the prior session) specifies a profile order of:
  Kuklabs Account → Workspace/Organisation → Preferences → Notifications →
  Security → Data & Privacy → Help & Support → About → Version → Sign out →
  Danger Zone/Delete Account. The actual Settings screen implements roughly
  3 of these 10 sections in full (Account read-only display, Theme, About)
  and is missing Workspace/Organisation, real Notifications, Security, real
  Data & Privacy (the current "Privacy & Trust" section is marketing copy,
  not controls), Help & Support, and Danger Zone/Delete Account entirely.
  This is a **gap against the app's own already-adopted design standard**,
  not just a competitive one.
- **User impact:** Medium (workspace switching, a real workflow gap) to High
  (missing account/data deletion — see PRODUCTION_READINESS_CHECKLIST.md for
  the Play Store policy angle).
- **Recommendation:** Prioritize adding, in order: (1) account/data deletion
  path, (2) data export, (3) workspace switcher, (4) legal links, (5) a
  proper Notifications section, (6) Security/Help & Support sections as
  time allows.
- **Whether the improvement is visual, functional, or both:** Both —
  new sections need both new controls (functional) and layout following the
  already-adopted design tokens (visual, low effort since the tokens exist).
- **Evidence:** `lib/screens/settings_screen.dart`;
  `docs/kuklabs/KUKLABS_MASTER_STANDARD.md` §11.
- **Priority:** P0–P1 depending on the sub-item (see `REMEDIATION_PLAN.md`).

---

## Screen/workflow: Onboarding

- **Current experience:** No separate onboarding/tutorial — straight from
  auth success into the (possibly empty) notes list, with an empty-state
  hint ("Tap + to add your first note").
- **Competitor benchmark:** Google Keep has similarly minimal onboarding
  (reputation-based, NOT VERIFIED this session) — this is a reasonable
  parity match with the closest direct competitor. Evernote, being a
  heavier app, is understood to have more structured first-run guidance
  (NOT VERIFIED).
- **Identified problem:** None significant — for this app's simplicity
  positioning, minimal onboarding matching Keep's own approach is
  appropriate, not a gap.
- **User impact:** Low.
- **Recommendation:** None required.
- **Priority:** — (no action needed)

---

## General design-consistency observations (not competitor-specific)

- KukKeep's UI is now internally consistent with its own adopted
  `KUKLABS_DESIGN_TOKENS.json` for the auth screen (fixed in the prior
  session) but **other screens (Notes, Note editor, Settings) still use
  ad hoc sizes/colors** (e.g., hardcoded `Colors.black87`, `Colors.grey`,
  assorted `fontSize` values) rather than the shared design tokens. This is
  a design-system consistency gap within the app itself, separate from any
  competitor comparison, worth tracking as its own follow-up (extend the
  Kuklabs design-token adoption from the auth screen to the rest of the app).
- No dark-mode-specific review of every screen was possible without a
  device; `note_editor_screen.dart` explicitly keeps the editor canvas
  light-themed regardless of app theme "so ink stays dark regardless of the
  app's light/dark theme" (see its own code comment) — a deliberate,
  reasonable choice, not a bug.

## Priority summary

| Screen | Problem | Priority |
|---|---|---|
| Note editor | Silent data loss on back-nav save failure (BUG-001) | P0 |
| Settings | Missing account/data deletion, export, workspace switcher, legal links | P0–P1 |
| Notes list | Search affordance overstates its scope (BUG-003) | P1 |
| Auth screen | None | — |
| Onboarding | None | — |
