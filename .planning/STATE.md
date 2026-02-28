# STATE.md — Project Memory

## Current Status
- **Active Milestone:** M1 — Bug Fix + Edge Cases (v1.1)
- **Active Phase:** Phase 1 COMPLETE — Phase 2 ready to begin
- **Last Updated:** 2026-03-01
- **Last Session:** Completed 01-01-PLAN.md (Rekap Harian Bug Fixes)

## What's Done
- [x] Codebase mapped → `.planning/codebase/` (7 documents, 1556 lines)
- [x] Project initialized → PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md
- [x] Database analyzed: 4 outlets, 14 employees, 89 attendance logs
- [x] Bugs confirmed from source code + DB data
- [x] **Phase 1 Plan 01 COMPLETE** — Fixed BUG-001, BUG-002, BUG-003 in admin_reports_screen.dart

## What's Next
Phase 2: BUG-004 (Lupa absen pulang — "Belum Pulang" state) + BUG-005 (24h shift cycle reset)

## ⚠️ Database Safety Rules
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
3. **24h shift handling:** "Shift day anchor" — pulang before noon next day → attached to masuk's date.
4. **PDF:** Use existing `pdf` package already in pubspec.yaml.
5. **No Kotlin upgrade:** Stay on 1.9.25 — nfc_manager breaks on 2.x.
6. **Schedule DB:** Schedule screen has been writing to SQLite only — Phase 8 fixes Supabase write.
7. **Noon rule threshold:** `< 12` (before noon) — pulang at 12:00+ treated as its own day (Phase 1).
8. **sakit/izin badge condition:** Only when `!hasMasukScan` — mixed days show normal 4-cell view (Phase 1).
9. **Daily fetch safety valve:** `limit(5000)` on `_loadDailySummaryData()` — no `.range()` (Phase 1).

## Active Bugs (Priority Order)
1. ~~BUG-001: Rekap Harian — sakit/izin shows 4 time cells [CRITICAL]~~ → FIXED Phase 1
2. ~~BUG-002: Rekap Harian — --:-- from pagination [CRITICAL]~~ → FIXED Phase 1
3. ~~BUG-003: Cross-day shift grouping [HIGH]~~ → FIXED Phase 1
4. BUG-004: Lupa absen pulang — no "Belum Pulang" state [HIGH] → Phase 2
5. BUG-005: 24h outlet shift cycle reset [MEDIUM] → Phase 2

## Performance Metrics
| Phase | Plan | Duration | Tasks | Files |
|-------|------|----------|-------|-------|
| 01-rekap-harian-bug-fixes | 01 | 6min | 3 | 2 |

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
