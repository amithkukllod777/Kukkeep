# Competitor Selection — KukKeep

## Product category

Quick-capture personal notes app: cards/lists (not documents), checklists,
reminders, colors/labels, photo/file attachments, OCR, drawing, and an
AI "ask your notes" assistant. Free, ad-free, tied to a single shared
account across a small app ecosystem (Kuklabs).

## Target market

- **Primary target users:** individuals wanting a fast, low-friction personal
  notes/reminders app — not teams, not enterprises, not document-authoring
  power users.
- **Primary use cases:** quick capture (shopping lists, reminders, snippets),
  light organization via labels/colors/pinning, occasional photo/file/drawing
  attachments, and asking natural-language questions across your own notes.
- **Geographic market:** not restricted in-app (no locale/region gating
  found); UI is English-only today (see `OPTIONS_CUSTOMIZATION_GAP.md`).
- **Business model:** free, ad-free, monetized indirectly as part of the
  broader Kuklabs ecosystem (no in-app purchases or subscription found in
  this repo).
- **Pricing segment:** free tier only, no paid tier.
- **Supported platforms:** Android only today (iOS explicitly disabled in
  `flutter_launcher_icons` config; no web/desktop build target found in this
  repo).
- **Company/customer size served:** individual consumers, not
  teams/businesses (no collaboration, sharing, or roles/permissions feature
  exists in this app).

## Selected competitor set

No product-owner-approved competitor list was provided, so this set was
selected independently based on the factors above.

| Competitor | Classification | Why it's relevant |
|---|---|---|
| **Google Keep** | Direct competitor / Market leader | Closest 1:1 feature and UX match: card notes, checklists, colors, labels, pinning, reminders, OCR, free/ad-free, Google-Account SSO. This is the app KukKeep is most directly positioned against and most visually modeled on (per this repo's own code comments referencing "Google Keep-style" design throughout). |
| **Microsoft OneNote** | Close substitute | Notebook/page-structured rather than card-based, so it's a substitute for structured note-taking rather than a like-for-like quick-capture rival — but it has directly comparable ink/drawing, OCR, and (as of 2026) AI summarization via Copilot, making it informative for the drawing/OCR/AI comparison specifically. (Microsoft Sticky Notes was considered instead but rejected — see note below.) |
| **Evernote** | Close substitute (legacy leader in relative decline) | Pioneered the "AI assistant with memory over your notes" concept closest to KukKeep's own "AI Memory" feature, and matches attachments/OCR/search closely — but is paid-first with a very limited free tier (50 notes/1GB), unlike KukKeep's fully free model. |

### Note on the Sticky Notes alternative

Microsoft Sticky Notes was evaluated as a possible #2 pick (it's free and
simpler, closer to KukKeep's simplicity). It was rejected in favor of OneNote
because Sticky Notes has no labels, no OCR, no drawing beyond very basic ink,
and no AI features — too thin a feature set to produce a meaningful
comparison across the dimensions this audit needs to cover (OCR, drawing,
AI). OneNote's richer feature set makes for a more informative
"what does a mature competitor do here" comparison, at the acknowledged cost
of being a less direct UX substitute.

## Sources and limitations

- Research performed via live web search on 2026-07-14 (see
  `COMPETITIVE_FEATURE_MATRIX.md` for the full per-claim source/date/
  verification breakdown).
- Several claims are PARTIALLY VERIFIED or NOT VERIFIED rather than
  confirmed on an official page — these are labeled explicitly throughout
  the competitive documents rather than presented as fact.
- No trial/paid accounts were created for any competitor; all findings come
  from public marketing/help pages, official changelogs, and third-party
  reviews.
- This selection compares a **completely free** app (KukKeep) against one
  other completely-free app (Keep), one free-with-optional-paid-bundle app
  (OneNote, bundled into Microsoft 365), and one paid-first app with a very
  limited free tier (Evernote) — this difference in business model is
  called out wherever it affects the fairness of a comparison (e.g., in
  `COMPETITIVE_FEATURE_MATRIX.md`'s pricing section and
  `COMPETITIVE_ROADMAP.md`'s "Do not build" reasoning).
