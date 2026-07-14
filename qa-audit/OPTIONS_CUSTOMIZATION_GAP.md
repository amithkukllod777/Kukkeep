# Options & Customization Gap Audit — KukKeep

Method: full review of `lib/screens/settings_screen.dart` plus every other
screen's persisted preferences (`SharedPreferences` keys: `kk_theme`,
`kk_grid`, `kk_token`, `kk_company`, `kk_user`). Competitor context drawn from
`qa-audit/COMPETITIVE_FEATURE_MATRIX.md` (Google Keep, Microsoft OneNote,
Evernote — see that file for sourcing/verification levels).

| Configuration option | Current support | Competitor support | Gap | Target user | Business value | Complexity | Recommendation |
|---|---|---|---|---|---|---|---|
| Theme (light/dark/system) | Full — persisted, three-way choice | Keep: OS-linked (PARTIALLY VERIFIED); OneNote: yes; Evernote: yes (not on web) | None — parity | All users | Medium | N/A | Keep as-is |
| Grid vs. list note layout | Full — persisted | Keep: yes (grid/list toggle is a signature Keep feature) | None — parity | All users | Medium | N/A | Keep as-is |
| Workspace/organisation switching | **Missing** post-login (only at initial sign-in) | Not directly comparable — none of the three competitors have a "workspace" concept in the same sense; this is specific to KukKeep's Kuklabs-account multi-company model | Product-specific gap, not a competitive one | Users with 2+ Kuklabs companies | Medium (real workflow blocker for a minority of users) | S–M | Add a switcher row to Settings (see REMEDIATION_PLAN.md) |
| Notification / reminder preferences | **Missing** — no per-note or global mute, no quiet hours, no "reminder sound" choice | Keep: reminders integrate with Google Tasks/Calendar (richer scheduling) — PARTIALLY VERIFIED; OneNote: no native reminders at all (worse than KukKeep here) | Available only through the OS-level "app notification settings," not in-app | Power users with many reminders | Low–Medium | S | Add at minimum a global reminders on/off toggle; consider quiet hours later |
| Branding / themes beyond light-dark | Not applicable — single fixed accent color per Kuklabs brand standard (`#2868F0`), by design | Not a factor for any of the 3 competitors either (all have fixed brand identities) | None | N/A | N/A | N/A | Correctly out of scope — deviating would violate this app's own Kuklabs UI standard (`docs/kuklabs/KUKLABS_MASTER_STANDARD.md`) |
| Language | English only, no l10n scaffold | All three competitors ship in many languages | **Table-stakes gap** for non-English markets | Users outside English-speaking markets | Medium–High (market-dependent) | L | Add `flutter_localizations` + ARB files once a target-language list is decided; not urgent if the initial market is English-only |
| Currency / date-time formats | Date/time formatting uses `intl` with the device locale implicitly via `DateFormat` — not independently configurable, and not really applicable (no currency data in this app) | N/A (not a notes-app concern for any of the three) | None meaningful | N/A | Low | N/A | No action needed |
| Custom fields / templates | **Missing** — no note templates (e.g., "meeting notes," "shopping list" starter templates) | OneNote has templates (notebook/page templates); Keep does not; Evernote has templates in paid tiers | Partial gap vs. OneNote/Evernote | Users who create similar notes repeatedly | Low–Medium | M | Consider a small set of built-in starter templates (e.g., pre-filled checklist for common lists) — a Differentiation Opportunity if AI-generated templates are explored (see COMPETITIVE_ROADMAP.md) |
| Status/label management | Labels exist (add/rename/delete), no color-coding of labels themselves, no folders/notebooks hierarchy | Keep: labels only, no folders (parity); OneNote: full notebook/section/page hierarchy (richer); Evernote: notebooks + tags (richer) | Partial gap vs. OneNote/Evernote's hierarchical organization | Users with large note collections | Medium | M–L | Not urgent — KukKeep's flat-label model matches its closest direct competitor (Keep); a notebook hierarchy would be a larger product decision, not a quick customization fix |
| Automation rules | **Missing** entirely (no auto-archive, auto-label, recurring reminders) | None of the three competitors has strong native automation either (mostly ecosystem-level, e.g., via Power Automate for OneNote) | Low-priority gap — not table-stakes | Power users | Low | L | Not a priority — low value relative to effort per the "Overbuilt Feature" classification |
| Report/export customization | **Missing** — no data export of any kind (see PRODUCTION_READINESS_CHECKLIST.md for the Play policy angle) | Evernote/OneNote/Keep all support some form of export (PDF/HTML/Google Takeout for Keep) | **Table-stakes / compliance gap** | All users, and specifically anyone requesting their data | High (Play policy relevance + basic user trust) | M | Add at minimum a "export my notes" action (even a simple JSON/HTML dump), coordinated with the account-deletion fix |
| Integration settings (Slack/Teams/etc.) | **Missing** | Evernote Advanced tier has Slack/Teams integration (VERIFIED, official compare-plans page) | Low priority — this is a paid-tier Evernote feature, not table-stakes for a free notes app | Team/business users | Low (for KukKeep's current single-user personal-notes positioning) | L | Not recommended now — see COMPETITIVE_ROADMAP.md "Do not build" |
| Privacy settings (granular) | Marketing-only "Privacy & Trust" tiles in Settings (static text, not actual controls) | N/A — direct comparison not meaningful | The "Privacy & Trust" section reads as informational copy, not configurable settings, which could be seen as slightly misleading `Section` labeling | All users | Low | S | Either add real controls here (e.g., analytics opt-out if analytics exist) or relabel the section to make clear it's informational, not a settings panel |
| Security settings (e.g., view active sessions, 2FA) | **Missing** — no in-app way to see active sessions or manage 2FA (2FA is mentioned only as an error case redirecting to the web: "Two-factor is enabled... log in on the web first," `api.dart:114-116`) | Not a differentiator either way vs. the three competitors for a personal notes app | Low priority | Security-conscious users | Low–Medium | M | Track as backlog; not urgent for v1 |
| Data-retention controls | Trash retention is fixed at 30 days (per `notes_screen.dart` UI copy), not user-configurable | Google Keep trash is a fixed 7 days (VERIFIED) — not user-configurable there either | None — matches competitor pattern (fixed, not configurable) | N/A | Low | N/A | No action needed |

## Summary

- The most consequential gaps are **data export** and **account/data
  deletion** (also raised in `PRODUCTION_READINESS_CHECKLIST.md`) — these are
  Table-Stakes/compliance gaps, not nice-to-haves.
- **Localization** is a real Table-Stakes gap for any market beyond
  English-speaking users, but is a deliberate scope decision to make, not an
  oversight to silently fix.
- The **workspace switcher** gap is specific to KukKeep's own multi-company
  architecture (not a competitive gap, since no competitor has this concept),
  but is still a real usability hole for the users it affects.
- Several "gaps" versus OneNote/Evernote (notebooks hierarchy, integrations,
  automation) are **not recommended to build** — they'd move KukKeep away
  from its own positioning as a fast, simple Keep-style app rather than a
  heavier note-taking suite (see `COMPETITIVE_ROADMAP.md`'s "Do not build"
  section for the explicit reasoning).
