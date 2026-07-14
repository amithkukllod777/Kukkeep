# Performance Audit — KukKeep

No profiler, emulator, or device was available in this environment, so
**nothing below is a measured result** — every row is a code-based assessment
(static reasoning about what the code will do), explicitly labeled as such
per the audit's "distinguish measured results from code-based assumptions"
requirement. Where a metric simply cannot be assessed from source alone, it's
marked NOT VERIFIED.

| Metric | Observed result | Expected threshold | Status | Bottleneck | Recommendation |
|---|---|---|---|---|---|
| App startup time | NOT MEASURED (code review only: `main()` awaits `Api.instance.load()` (SharedPreferences read) + `loadTheme()` before `runApp`; Firebase/Notifications/GoogleAuth init are deferred until after first frame, which is good practice) | Sub-second cold start on modern hardware | CODE-BASED / PASS-leaning | None obvious from code | None — the deferred-init pattern is already correct |
| Screen load time (Notes list) | NOT MEASURED (code review: `_load()` issues one `keep.list` query per view-open with no pagination) | N/A | CODE-BASED / AT RISK for large accounts | Unbounded full-list fetch — see "Large-data handling" below | Add pagination once note counts grow |
| API response time | NOT VERIFIED (server-side, out of repo scope) | N/A | NOT VERIFIED | N/A | N/A |
| Database query performance | NOT APPLICABLE to this repo | N/A | NOT APPLICABLE | N/A | Server-side (kukbook-erp) |
| Memory usage | NOT MEASURED | N/A | NOT VERIFIED | Potential: `Image.network` with no cache re-decodes images repeatedly (BUG-008) | Add `cached_network_image` |
| CPU usage | NOT MEASURED | N/A | NOT VERIFIED | Drawing canvas repaints on every `onPanUpdate` via `setState` on the whole `_DrawScreenState` (`draw_screen.dart:93-97`) — acceptable for a lightweight sketch tool at typical stroke counts, but `shouldRepaint` on the painter always returns `true` (`draw_screen.dart:220`), meaning every frame repaints all strokes rather than just the new segment | Low priority for a notes app; consider `shouldRepaint` optimization only if user reports lag on long/complex drawings |
| Battery usage | NOT MEASURED | N/A | NOT VERIFIED | `AndroidScheduleMode.exactAllowWhileIdle` (`notifications.dart:61`) is the most battery-costly reliable-delivery mode, used intentionally for reminder accuracy — a reasonable, deliberate trade-off for a reminders feature | None — this is the correct choice for the feature's purpose |
| Network usage | CODE-BASED: every note-editor exit issues a save call regardless of whether anything changed (BUG-005); every list-view screen open re-fetches the full note list with no local cache (no offline support gap, also listed in FEATURE_INVENTORY.md) | N/A | AT RISK | Redundant saves + no cache | Fix BUG-005 (dirty-check before saving); consider an offline-first cache layer |
| Large-data handling | CODE-BASED: `Api.notes()` (`api.dart:218-222`) has no `limit`/`offset`/cursor parameters visible in the call; the full result set is decoded into memory and rendered via a plain `ListView` (not lazy/`ListView.builder`-virtualized per masonry column — see `_masonry`/`_masonry` in `notes_screen.dart:438-449`, which builds a `Column` of ALL cards up front rather than a virtualized list) | Should scale to thousands of notes without a UI hitch | AT RISK for power users | Non-virtualized card list + unbounded fetch | Switch to `ListView.builder`/`GridView.builder` semantics and add pagination to `keep.list` (server-side change too) |
| Concurrent users | NOT APPLICABLE (client) | N/A | NOT APPLICABLE | N/A | Server-side |
| Sustained load / traffic spikes | NOT APPLICABLE (client) | N/A | NOT APPLICABLE | N/A | Server-side |
| Memory leaks | CODE-BASED: `TextEditingController`/`FocusNode` lifecycle in the note editor is disciplined — every added controller/node is disposed on remove/dispose (`note_editor_screen.dart:93-98,119-126`) — no obvious leak found | N/A | PASS (code-based) | None found | None |
| Resource leaks | CODE-BASED: `_cooldownTimer` in `otp_screen.dart` is cancelled in `dispose()` (`otp_screen.dart:28-32`) — correct | N/A | PASS (code-based) | None found | None |
| Timeout behavior | See SEC-007 in `SECURITY_AUDIT.md` — most calls have no timeout | N/A | AT RISK | Missing `.timeout(...)` | Add consistent timeouts |
| Caching effectiveness | No caching layer exists for notes or images | N/A | AT RISK (see above) | N/A | See offline/cache recommendations |
| Slow queries | NOT APPLICABLE (client)/NOT VERIFIED (server) | N/A | NOT VERIFIED | N/A | Server-side |
| Unnecessary API calls | **Confirmed by code review**: BUG-005 (save on every editor exit) | N/A | AT RISK | Same as above | Fix BUG-005 |
| Unnecessary renders | CODE-BASED: `_masonry` rebuilds the full note-card `Column`s on every `setState` in the parent (e.g., toggling a single checklist item calls `setState` at the screen level — `_toggleItem` in `notes_screen.dart:143-147` — which rebuilds every visible card, not just the changed one) | N/A | MINOR AT RISK | Coarse-grained `setState` | Consider narrowing rebuild scope (e.g., per-card `ValueNotifier`) if profiling on a real device shows jank with large lists — not worth doing speculatively without a measured problem |

## Summary

- No performance metric in this table was actually measured (no toolchain/
  device available) — all "AT RISK" statuses are code-based risk assessments,
  not confirmed regressions.
- The most concrete, code-confirmed performance issue is **BUG-005**
  (redundant network write on every editor exit) — cheap to fix.
- The **offline/cache gap** (no local persistence, no image cache, no
  pagination) is the biggest long-term performance and UX risk as note counts
  grow, but is a larger, deliberate architectural investment rather than a
  quick fix — tracked in `REMEDIATION_PLAN.md` as medium/long-term work.
- Recommend a follow-up pass with `flutter run --profile` + DevTools once a
  device/emulator is available, specifically watching: (1) notes-list scroll
  performance with 500+ notes, (2) memory graph while scrolling a
  many-attachment note, (3) frame times while drawing.
