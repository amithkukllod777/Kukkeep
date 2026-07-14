# Competitive Roadmap — KukKeep

Built from `COMPETITIVE_FEATURE_MATRIX.md`, `OPTIONS_CUSTOMIZATION_GAP.md`,
and `UI_UX_COMPETITOR_AUDIT.md`. Scored qualitatively (this audit did not have
usage-analytics access to compute the numeric 1-5 scales precisely; scores
below are reasoned estimates, flagged as such).

## Immediate (this release / before next Play submission)

### 1. Fix the note-editor silent data-loss bug (BUG-001)
- **Problem:** Users can lose unsaved edits with no clear warning.
- **Evidence:** `BUG_REPORT.md` BUG-001, `UI_UX_COMPETITOR_AUDIT.md`.
- **Expected user value:** High — trust in "my notes are safe" is the core
  promise of this product category.
- **Competitive value:** Table-stakes — no competitor should be expected to
  ship this bug; it's not a feature gap so much as a correctness bar every
  competitor already clears.
- **Dependencies:** None.
- **Estimated complexity:** S.
- **Success metric:** Zero reports of "my note disappeared" after release;
  a new widget test (see MISSING_TESTS.md #1) passes.
- **Validation method:** Manual airplane-mode test + the new automated test.

### 2. Add data export + account/data deletion
- **Problem:** No in-app export or deletion path; plausible Google Play
  policy compliance risk.
- **Evidence:** `PRODUCTION_READINESS_CHECKLIST.md`, `COMPETITIVE_FEATURE_MATRIX.md`
  (import/export row).
- **Expected user value:** Medium day-to-day, but High for the users who
  specifically need it (data portability, right-to-delete requests).
- **Competitive value:** Table-Stakes Gap — all three competitors support
  some export path, and Play policy expects an in-app deletion path for apps
  with in-app account creation.
- **Dependencies:** A `kukbook-erp` backend endpoint for account/data
  deletion if one doesn't already exist.
- **Estimated complexity:** M (export) + M–L (deletion, needs backend
  coordination).
- **Success metric:** Play Console Data Safety declaration matches actual
  in-app capability; a support ticket volume decrease for "how do I delete my
  account" requests (if currently tracked — NOT VERIFIED whether it is).
- **Validation method:** Manual walkthrough of both flows; policy review
  against Google's published Account Deletion requirements.

## Next release

### 3. Fix view-scoped search (BUG-003)
- **Problem:** Search silently only covers the current view.
- **Evidence:** `BUG_REPORT.md` BUG-003, `COMPETITIVE_FEATURE_MATRIX.md` (search row).
- **Expected user value:** Medium-High — searching for a note and not
  finding it (because it's technically "found" but the view is wrong) is a
  trust-eroding experience.
- **Competitive value:** Table-Stakes — every competitor's search is global.
- **Dependencies:** None (client-side fix, or a minor server query change if
  a true cross-view query is preferred over client-side re-fetch).
- **Estimated complexity:** M.
- **Success metric:** A search from any view surfaces matches from all
  non-trashed notes.
- **Validation method:** Manual test + a new unit test on the extracted
  filter function (see MISSING_TESTS.md #7).

### 4. Route all error messages through a friendly-error policy (BUG-002)
- **Problem:** 19 call sites still show raw exception text, inconsistent
  with the app's own adopted Kuklabs error-message policy.
- **Evidence:** `BUG_REPORT.md` BUG-002.
- **Expected user value:** Medium (fewer confusing error messages).
- **Competitive value:** Table-Stakes / brand-consistency — this is about
  matching KukKeep's *own* stated design standard, not a competitor feature.
- **Dependencies:** None.
- **Estimated complexity:** M.
- **Success metric:** Zero raw `Exception`/`TRPCClientError`-shaped strings
  visible in any snackbar/error text during manual testing.
- **Validation method:** Manual fault-injection (offline mode) on every
  screen; extend the existing `auth_messages_test.dart` pattern.

### 5. Complete the Settings screen against the Kuklabs profile standard
- **Problem:** Settings implements ~3 of the 10 sections specified in this
  app's own `docs/kuklabs/KUKLABS_MASTER_STANDARD.md` §11.
- **Evidence:** `UI_UX_COMPETITOR_AUDIT.md` (Settings section).
- **Expected user value:** Medium (workspace switching is a real blocker for
  multi-company users; legal links and notification prefs are smaller wins).
- **Competitive value:** Mostly about internal consistency, not competitor
  parity (no competitor has KukKeep's exact multi-workspace model).
- **Dependencies:** None beyond the account-deletion backend work above.
- **Estimated complexity:** M.
- **Success metric:** All 10 §11.1 sections present (even if some are
  minimal in v1).
- **Validation method:** Manual side-by-side check against the standard doc.

## Next quarter

### 6. Offline-first local cache
- **Problem:** No offline support at all — the single biggest confirmed
  competitive gap.
- **Evidence:** `COMPETITIVE_FEATURE_MATRIX.md` ("Offline support" row,
  Table-Stakes Gap / Competitive Disadvantage).
- **Expected user value:** High — "my notes app doesn't work without
  internet" is a frequent, visible failure mode (e.g., subway commutes,
  airplane mode, poor rural signal).
- **Competitive value:** High — closes a Table-Stakes Gap against two of
  three verified-offline competitors (OneNote, Evernote) and likely a third
  (Keep).
- **Dependencies:** A local persistence layer (`drift`/`sqflite`/`hive`) and
  a sync/conflict-resolution strategy; likely needs backend coordination for
  incremental sync endpoints.
- **Estimated complexity:** XL.
- **Success metric:** Notes remain viewable/editable in airplane mode and
  sync correctly on reconnect, including conflict handling for concurrent
  edits from two devices.
- **Validation method:** Manual offline/reconnect testing across multiple
  scenarios (create offline, edit offline, conflict from a second device).

### 7. iOS build
- **Problem:** Android-only; every verified competitor covers iOS.
- **Evidence:** `COMPETITIVE_FEATURE_MATRIX.md` ("Mobile support" row).
- **Expected user value:** High for the excluded iOS user base (unmeasured
  fraction of the target market — NOT VERIFIED what % of the target market is
  iOS).
- **Competitive value:** High — closes a Competitive Disadvantage against
  all three competitors simultaneously.
- **Dependencies:** Apple Developer account, iOS-specific review of every
  plugin used (`flutter_local_notifications`, `image_picker`, `file_picker`,
  `firebase_messaging`, `app_links` all support iOS, so this is primarily a
  build/signing/App Store-review effort, not a rewrite — NOT VERIFIED without
  actually attempting the build).
- **Estimated complexity:** L.
- **Success metric:** A signed iOS build passes App Store review and is
  live.
- **Validation method:** TestFlight beta, then App Store submission.

### 8. Add basic bulk actions (multi-select archive/trash/label)
- **Problem:** No multi-select actions; Google Keep and both other
  competitors have this.
- **Evidence:** `COMPETITIVE_FEATURE_MATRIX.md` ("Bulk actions" row).
- **Expected user value:** Medium (most valuable for trash/archive cleanup
  on accounts with many notes).
- **Competitive value:** Parity Opportunity.
- **Dependencies:** None.
- **Estimated complexity:** M.
- **Success metric:** Users can select 2+ notes and archive/trash/label them
  in one action.
- **Validation method:** Manual test.

## Long-term opportunities

### 9. Localization
- **Problem:** English-only; all three competitors support many languages.
- **Evidence:** `COMPETITIVE_FEATURE_MATRIX.md`, `OPTIONS_CUSTOMIZATION_GAP.md`.
- **Expected user value:** High, but only for non-English-speaking target
  markets — a product decision on target geography is needed first.
- **Competitive value:** Table-Stakes Gap conditional on market expansion.
- **Dependencies:** Decision on target languages; translation resourcing.
- **Estimated complexity:** L.
- **Success metric:** Full UI translated and reviewed for at least one
  additional language with no text overflow/truncation.
- **Validation method:** Manual QA pass per added locale.

### 10. Note templates
- **Problem:** No starter templates; OneNote and Evernote have them (Keep
  does not).
- **Evidence:** `OPTIONS_CUSTOMIZATION_GAP.md`, `COMPETITIVE_FEATURE_MATRIX.md`.
- **Expected user value:** Low–Medium.
- **Competitive value:** Parity Opportunity vs. OneNote/Evernote only — not
  a gap vs. the closest direct competitor (Keep), so this is optional
  polish, not urgent.
- **Dependencies:** None.
- **Estimated complexity:** M.
- **Success metric:** N/A (optional enhancement — no hard success bar).
- **Validation method:** N/A.

### 11. Deepen the AI Memory differentiator
- **Problem/opportunity:** KukKeep's native, free AI-over-your-notes feature
  is a genuine differentiator today (see `COMPETITIVE_FEATURE_MATRIX.md`
  "Native AI" row) but its real-world answer quality could not be verified
  in this audit (server-dependent, out of repo scope).
- **Evidence:** Competitor research shows Keep's equivalent requires the
  separate Gemini app, Evernote's is paid-gated, OneNote's is Copilot-gated
  — KukKeep is uniquely positioned if quality holds up.
- **Expected user value:** High, if quality is genuinely good.
- **Competitive value:** High — this is KukKeep's clearest Differentiation
  Opportunity, not just a parity item.
- **Dependencies:** Backend (kukbook-erp) work to keep improving answer
  quality; user-facing quality measurement (e.g., thumbs up/down on AI
  answers) to actually know how well it's working.
- **Estimated complexity:** L (ongoing).
- **Success metric:** A measurable "was this helpful" rate on AI answers
  (doesn't exist today — would need to be built).
- **Validation method:** In-app feedback mechanism once built; currently
  NOT MEASURABLE.

## Do not build (explicitly, with reasoning)

- **Notebook/folder hierarchy** (matching OneNote/Evernote) — would move
  KukKeep away from its Keep-style quick-capture positioning, which is
  exactly the positioning where KukKeep's simplicity is a strength, not a
  weakness (Low-Value Competitor Feature relative to KukKeep's own identity).
- **Team/business collaboration features** (shared notebooks, roles/
  permissions, Slack/Teams integrations à la Evernote Advanced) — KukKeep is
  positioned as a personal-notes app; building enterprise collaboration
  features would be Overbuilt relative to the current product's audience and
  would compete against KukBook/other Kuklabs products' own likely
  positioning rather than complementing them.
- **A public developer API/webhooks** — no evidence any of the three
  competitors differentiate meaningfully on this for the personal-notes
  segment KukKeep targets; low expected value for the effort (Low-Value
  Competitor Feature).
- **Matching Evernote's paid-tier pricing model** — Evernote's restrictive
  free tier (50 notes/1GB) is a documented pain point, not something to
  emulate; KukKeep's fully-free model is a strength to protect, not a gap to
  close (see `COMPETITIVE_FEATURE_MATRIX.md` "Pricing-plan limitations" row).
