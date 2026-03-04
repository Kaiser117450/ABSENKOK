---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: milestone
status: in_progress
last_updated: "2026-03-05T00:00:00Z"
progress:
  total_phases: 5
  completed_phases: 2
  total_plans: 10
  completed_plans: 10
---

# STATE.md â€” Project Memory

## Current Status
- **Active Milestone:** M1 â€” Bug Fix + Edge Cases (v1.1)
- **Active Phase:** Phase 8 COMPLETE - awaiting human verification of 08-02
- **Last Updated:** 2026-03-05
- **Last Session:** Completed 08-02-PLAN.md (checkpoint:human-verify pending)

## What's Done
- [x] Codebase mapped â†’ `.planning/codebase/` (7 documents, 1556 lines)
- [x] Project initialized â†’ PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md
- [x] Database analyzed: 4 outlets, 14 employees, 89 attendance logs
- [x] Bugs confirmed from source code + DB data
- [x] **Phase 1 Plan 01 COMPLETE** â€” Fixed BUG-001, BUG-002, BUG-003 in admin_reports_screen.dart
- [x] **Phase 2 Plan 01 COMPLETE** â€” Fixed BUG-005: 24h shift cycle reset (kiosk_scan_screen.dart)
- [x] **Phase 2 Plan 02 COMPLETE** â€” Fixed BUG-004: Belum Pulang state in Rekap Harian (admin_reports_screen.dart)
- [x] **Phase 2 Plan 03 COMPLETE** â€” Admin dashboard Open Shifts widget + manual pulang dialog (admin_dashboard_screen.dart)
- [x] **Phase 2 VERIFIED** â€” 12/12 must-haves pass; gap fix d554797 (belumPulang dayNotes guard)
- [x] **Phase 3 Plan 01 COMPLETE** â€” Overlay payload contract model + tests (`OverlayPillState`, legacy fallback, v1 serializer)
- [x] **Phase 3 Plan 02 COMPLETE** â€” Idempotent overlay controller API + typed service payload updates in `kiosk_background_service.dart`
- [x] **Phase 3 Plan 03 COMPLETE** - Overlay isolate typed state-machine + premium compact pill UI + widget coverage (`overlay_task.dart`, `overlay_pill_widget_test.dart`)
- [x] **Phase 6 Plan 01 COMPLETE** - Dark kiosk idle screen with 3-layer ambient background (gradient, glow, shimmer) using CustomPainter
- [x] **Phase 8 Plan 01 COMPLETE** - Supabase-first schedule load with write-through SQLite cache and unsaved draft indicator
- [x] **Phase 8 Plan 02 COMPLETE** - Bulk assign UI: checklist FAB, Select All header checkbox, individual row checkboxes, shift picker bottom sheet; skips sakit/izin/time-off days

## What's Next
Phase 8 awaiting human verification (build + install + test full flow). After approval, Phase 08.1 (export laporan CSV/PDF accuracy) or Phase 7 (Admin UI Polish) can begin.

## Accumulated Context
### Roadmap Evolution
- Phase 08.1 inserted after Phase 8: Perbaiki export laporan CSV/PDF: akurasi data waktu absen, bedakan export Per Scan vs Rekap Harian, dan sinkronkan format PDF dengan UI laporan (URGENT)

## âš ï¸ Database Safety Rules
- Sistem absensi SEDANG BERJALAN di production (4 gerai, karyawan aktif)
- **WAJIB konfirmasi ke user sebelum setiap perubahan database** (ALTER, DROP, UPDATE massal)
- Boleh tanpa konfirmasi HANYA jika: CREATE TABLE baru, ADD COLUMN nullable, CREATE POLICY, INSERT seed data
- DILARANG: DROP TABLE, DROP COLUMN, ALTER COLUMN type, UPDATE/DELETE data existing tanpa konfirmasi
- Selalu jalankan migration additive (tidak merusak data yang ada)

## Key Decisions Made
1. **Overlay pill approach:** Use existing `flutter_overlay_window` + enhance `overlay_task.dart`.
   Do NOT add `live_activities` package (Android-only app, no iOS needed).
2. **Rekap Harian fix strategy:** Separate fetch for daily summary (no pagination limit).
   Per-scan tab keeps pagination. Two independent data fetches.
3. **24h shift handling:** "Shift day anchor" â€” pulang before noon next day â†’ attached to masuk's date.
4. **PDF:** Use existing `pdf` package already in pubspec.yaml.
5. **No Kotlin upgrade:** Stay on 1.9.25 â€” nfc_manager breaks on 2.x.
6. **Schedule DB:** Schedule screen has been writing to SQLite only â€” Phase 8 fixes Supabase write.
7. **Noon rule threshold:** `< 12` (before noon) â€” pulang at 12:00+ treated as its own day (Phase 1).
8. **sakit/izin badge condition:** Only when `!hasMasukScan` â€” mixed days show normal 4-cell view (Phase 1).
9. **Daily fetch safety valve:** `limit(5000)` on `_loadDailySummaryData()` â€” no `.range()` (Phase 1).
10. **24h kiosk scan window:** Use `.gte('scanned_at', cutoff)` where cutoff = now-24h for shift cycle determination â€” window is the safety net, no isSameDay post-fetch check needed (Phase 2 Plan 01).
11. **belumPulang dayNotes guard:** `dayNotes` extraction must only run for `sakit` and `izin` â€” NOT for `belumPulang` (no sakit/izin row exists to firstWhere on). Fixed in d554797 after verification gap. (Phase 2 Plan 02).
12. **Open Shifts 32h window:** Use 32h (not 24h or yesterday) for open-shifts query to cover overnight shifts starting 22:00+ previous day. (Phase 2 Plan 03).
13. **Manual pulang INSERT:** `is_backup: false` on admin-created pulang records â€” marks as legitimate correction, not offline sync artifact. (Phase 2 Plan 03).
14. **Overlay payload contract isolation:** Keep `OverlayPillState` pure Dart (no Flutter/UI imports) so service isolate and overlay isolate share one contract safely. (Phase 3 Plan 01).
15. **Migration decode strategy:** `fromRaw` parses JSON `v:1` first, then falls back to legacy `outlet|HH:mm` payload to avoid breaking existing senders during rollout. (Phase 3 Plan 01).
16. **Overlay show contract:** `ensureOverlayVisible` now returns deterministic outcomes (`shown`, `permissionDenied`, `showFailed`) for caller-level handling. (Phase 3 Plan 02).

18. **Overlay idle/event contract in UI:** Overlay isolate now treats idle as persistent baseline and event as temporary mode with timer-driven revert, preserving tap expand/minimize independently. (Phase 3 Plan 03).
19. **Overlay verification strategy:** Added stream-injected widget tests for idle/event/toggle/legacy/readability paths so overlay behavior is CI-testable without Android overlay runtime. (Phase 3 Plan 03).
20. **Kiosk dark palette isolation:** Pre-defined all static opacity Color variants as AppColors constants (kioskNfc*) to avoid per-frame allocations in CustomPainter paint(). Used withValues() over deprecated withOpacity(). (Phase 6 Plan 01).
21. **Supabase-first schedule load:** try cloud first, cache to SQLite, fallback only on network error. Auto-generate stays as local draft until explicit Save. (Phase 8 Plan 01).
22. **SQLite date normalization:** split('T')[0] on both save and query paths to match Supabase yyyy-MM-dd format. (Phase 8 Plan 01).
23. **Dual-write save order:** Supabase first, then SQLite cache with correct Supabase-generated ID. SQLite fallback in catch block. (Phase 8 Plan 01).
24. **Bulk assign FAB dual-state:** Same FAB changes behavior+color based on _isBulkMode — enters selection mode vs opens shift picker. AppBar turns orange with X button as affordance. (Phase 8 Plan 02).
25. **Bulk assign skip logic:** Skips both _getSakitIzin() and _hasTimeOff() days — consistent with single-cell add behavior (Phase 8 Plan 02).

## Active Bugs (Priority Order)
1. ~~BUG-001: Rekap Harian â€” sakit/izin shows 4 time cells [CRITICAL]~~ â†’ FIXED Phase 1
2. ~~BUG-002: Rekap Harian â€” --:-- from pagination [CRITICAL]~~ â†’ FIXED Phase 1
3. ~~BUG-003: Cross-day shift grouping [HIGH]~~ â†’ FIXED Phase 1
4. ~~BUG-004: Lupa absen pulang â€” no "Belum Pulang" state [HIGH]~~ â†’ FIXED Phase 2 Plan 02
5. ~~BUG-005: 24h outlet shift cycle reset [MEDIUM]~~ â†’ FIXED Phase 2 Plan 01

## Performance Metrics
| Phase | Plan | Duration | Tasks | Files |
|-------|------|----------|-------|-------|
| 01-rekap-harian-bug-fixes | 01 | 6min | 3 | 2 |
| 02-kiosk-scan-cycle-edge-cases | 01 | 2min | 1 | 1 |
| 02-kiosk-scan-cycle-edge-cases | 02 | ~8min | 2 | 1 |
| 02-kiosk-scan-cycle-edge-cases | 03 | ~20min | 2 | 1 |
| 03-overlay-pill-implementation | 01 | 11 min | 2 | 2 |
| 03-overlay-pill-implementation | 02 | 5 min | 3 | 1 |
| Phase 03-overlay-pill-implementation P03 | 17 min | 3 tasks | 2 files |
| 06-nfc-idle-screen-visual-enhancement | 01 | 9min | 2 | 3 |
| 08-schedule-system-fix-supabase-integration | 01 | 5min | 2 | 2 |
| 08-schedule-system-fix-supabase-integration | 02 | 8min | 1 | 1 |

## Supabase Project
- Project ID: `tmapxdftdhxovthgbhww`
- Region: ap-south-1 (Mumbai)
- Status: ACTIVE_HEALTHY

## File Locations
- Flutter project: `absensi apk/absensi_enakko_flutter/`
- Planning: `absensi apk/absensi_enakko_flutter/.planning/`
- Codebase map: `.planning/codebase/`
- Live activity guide: `absensi apk/liveaction.md`
- Build script: `build_flutter.ps1` (root of projekan/)
