---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: milestone
status: unknown
last_updated: "2026-03-05T12:02:05.691Z"
progress:
  total_phases: 12
  completed_phases: 8
  total_plans: 24
  completed_plans: 23
---

# STATE.md â€” Project Memory

## Current Status
- **Active Milestone:** M1 -- Bug Fix + Edge Cases (v1.1)
- **Active Phase:** Phase 11 -- Employee Badge System (Plan 02 complete)
- **Last Updated:** 2026-03-05
- **Last Session:** 2026-03-05T11:41:27Z

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
- [x] **Phase 08.1 Plan 01 COMPLETE** - PDF stats DTOs, summary Page 1 builder, multi-page layout for Rekap Harian
- [x] **Phase 08.1 Plan 02 COMPLETE** - Color-coded status/type cells in PDF tables; cached _dailyRows for export; 'Hadir' label fix
- [x] **Phase 07 Plan 01 COMPLETE** - Created reusable widget library (AppCard, ShimmerSkeleton, AppEmptyState, AppBadge, AppToast) + badge color palette
- [x] **Phase 07 Plan 02 COMPLETE** - Applied widget library to admin_dashboard_screen + bottom nav polish
- [x] **Phase 07 Plan 03 COMPLETE** - Applied widget library to employees, reports, outlets, sakit_izin: AppCard, ShimmerSkeleton, AppEmptyState, AppToast
- [x] **Phase 06 Plan 02 COMPLETE** - Gradient NFC ring (_GradientRingPainter), monospace clock (GoogleFonts.robotoMono), premium light-weight instruction typography
- [x] **Phase 10 Plan 01 COMPLETE** - Direct Supabase INSERT for sakit/izin with edit mode, duplicate prevention, 30-day backdating, 08:00 time anchor
- [x] **Phase 10 Plan 02 COMPLETE** - Sakit/izin history list screen with edit/delete actions, employee card popup menu navigation
- [x] **Phase 11 Plan 01 COMPLETE** - EmployeeBadge model, BadgeService singleton, BadgeAvatar widget (solid/gradient/glow ring + emoji chip)
- [x] **Phase 11 Plan 02 COMPLETE** - BadgeAvatar integrated across 6 avatar surfaces, badge label in kiosk scan success, badge emoji in overlay pill, Badge column in PDF summary

## What's Next
Phase 11 Plan 02 complete (badge display integration). Plan 03 remaining in Phase 11.
Next: `/gsd:execute-phase 11` (Plan 03 — Badge management CRUD)

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
26. **PDF summary page optional param:** AttendanceDailyPdfStats is optional on generateAndShareAttendanceDailyPdf — backward-compatible, Per Scan PDF unaffected. Stats DTOs co-located in pdf_service.dart. Summary page (A4 portrait) prepended before existing data MultiPage (A4 landscape). (Phase 08.1 Plan 01).
27. **Manual pw.Table for PDF color cells:** pw.TableHelper.fromTextArray does not support per-cell text color — replaced with manual pw.Table in both Rekap Harian and Per Scan PDF methods. (Phase 08.1 Plan 02).
28. **Cached _dailyRows for export:** _exportCsv() and _exportPdf() use _dailyRows cache when non-empty, fallback to Supabase fetch only when cache is empty. (Phase 08.1 Plan 02).
29. **AppCard zero-padding for complex cards:** Employee and outlet cards use `padding: EdgeInsets.zero` on AppCard to preserve internal color bars and avatar layouts. (Phase 7 Plan 03).
30. **Shimmer composites match target layout:** Each shimmer builder replicates the target content's visual structure (avatar+text rows, icon+text+trailing) for believable loading skeletons. (Phase 7 Plan 03).
31. **Button/dialog spinners preserved:** CircularProgressIndicator inside ElevatedButton and dialog actions are kept as action-in-progress indicators -- only main loading states replaced with shimmer. (Phase 7 Plan 03).
32. **Gradient ring SweepGradient + pulse glow:** _GradientRingPainter uses SweepGradient for ring stroke and Color.fromRGBO for dynamic-opacity inner glow tied to _pulseAnim value. (Phase 6 Plan 02).
33. **Monospace clock font:** GoogleFonts.robotoMono(w300) for time display -- consistent character width prevents layout shifts on second ticks. (Phase 6 Plan 02).
34. **Sakit/izin direct Supabase INSERT:** Admin operations use SupabaseClientFactory.admin directly, not SQLite offline queue. Immediate visibility in reports. SQLite fallback only on network failure. (Phase 10 Plan 01).
35. **scanned_at 08:00 anchor for sakit/izin:** Backdated sakit/izin records use 08:00 local time (not current time) to ensure correct date bucketing in Rekap Harian. (Phase 10 Plan 01).
36. **Duplicate check non-blocking on error:** _checkDuplicate() returns false on network failure -- better to allow potential duplicate than block user. In edit mode, skips check when date unchanged. (Phase 10 Plan 01).
37. **Sakit/izin delete type safety guard:** Only records with type sakit or izin can be deleted -- prevents accidental deletion of masuk/pulang records even if record somehow appears in the list. (Phase 10 Plan 02).
38. **History screen via Navigator.push:** SakitIzinListScreen accessed via Navigator.push from popup menu, not GoRouter -- consistent with modal drill-down pattern across admin screens. (Phase 10 Plan 02).
39. **Badge activeBadgeId copyWith pattern:** Uses `??` (not sentinel) -- clearing badge is done via BadgeService.unassignBadge() which updates Supabase directly, not copyWith. (Phase 11 Plan 01).
40. **BadgeService singleton pattern:** Static singleton (`BadgeService._()` + `static final instance`) with in-memory Map cache for small reference tables (<20 rows). (Phase 11 Plan 01).
41. **Badge ring rendering technique:** solid=BoxDecoration border, gradient=CustomPaint SweepGradient, glow=BoxDecoration+BoxShadow. Ring width scales in 3 tiers: >=52dp (3px), >=40dp (2.5px), <40dp (2px). (Phase 11 Plan 01).

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
| Phase 08.1-perbaiki-export-laporan-csv-pdf P01 | 9min | 2 tasks | 2 files |
| Phase 08.1-perbaiki-export-laporan-csv-pdf P02 | 10min | 2 tasks | 2 files |
| Phase 04-pdf-export-engine P01 | 8min | 2 tasks | 4 files |
| Phase 07-admin-ui-system-polish P01 | 2min | 1 tasks | 6 files |
| Phase 07-admin-ui-system-polish P02 | ~5min | 1 tasks | 3 files |
| Phase 07-admin-ui-system-polish P03 | 8min | 2 tasks | 4 files |
| 06-nfc-idle-screen-visual-enhancement | 02 | 5min | 1 | 1 |
| 10-sakit-izin-direct-input | 01 | 5min | 1 | 1 |
| Phase 10 P02 | 5min | 2 tasks | 2 files |
| Phase 11 P01 | 3min | 3 tasks | 4 files |
| Phase 11 P02 | 13min | 4 tasks | 7 files |

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
