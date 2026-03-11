---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Admin Tools + Live Activity
current_plan: 3 of 3 in Phase 13
status: unknown
stopped_at: Completed 13-02-PLAN.md
last_updated: "2026-03-11T15:19:56.638Z"
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 3
  completed_plans: 3
---

# STATE.md — Project Memory

## Current Status
- **Active Milestone:** v2.0 — Admin Tools + Live Activity
- **Active Phase:** Phase 13 — Soft-Archive Karyawan + Riwayat
- **Current Plan:** 3 of 3 in Phase 13
- **Last Updated:** 2026-03-11
- **Last Session:** 2026-03-11T15:19:56.634Z
- **Stopped At:** Completed 13-02-PLAN.md

## Progress

```
v2.0 Admin Tools + Live Activity
[████████████████████] 3/3 plans in Phase 13 · 1/4 phases
```

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-11)

**Core value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.
**Current focus:** Phase 13 COMPLETE — All 3 plans executed (archive model, UI action, riwayat screen)

## What's Done (v2.0)
- ✅ Research completed (HIGH confidence across all 4 areas)
- ✅ Requirements defined (17 requirements across 4 categories)
- ✅ Roadmap created (4 phases: 13-16)
- ✅ Phase 13 Plan 01: archived_at column + Employee model archivedAt field
- ✅ Phase 13 Plan 02: Archive action in admin employee UI + is_active filter + Arsip nav
- ✅ Phase 13 Plan 03: Riwayat Karyawan screen + route registration

## What's Next
Phase 13 complete. Ready for Phase 14 planning.

## Accumulated Context

### Key Decisions (v2.0)
| # | Decision | Rationale |
|---|----------|-----------|
| 11 | Archive first, Live Activity last | Data model change is foundational; overlay is isolated and complex |
| 12 | Only 2 new packages (csv + file_picker) | Minimize new dependencies; leverage v1.1 architecture |
| 13 | Kepala Gerai = SQL script only, zero Flutter code | 4 outlets doesn't justify admin UI; SQL script is faster and safer |
| 14 | Overlay data flow via shareData() only | Overlay runs in separate isolate — cannot access main Supabase client |
| 15 | Additive migrations only | Production DB at 4 outlets — all new columns NULLABLE or with DEFAULT |
| 16 | archivedAt as DateTime? not String | Type-safe timestamp handling for future archive/restore date comparisons |
| 17 | ZONA BERBAHAYA pattern for destructive archive action | Clear separation from normal edit form; archive is irreversible-feeling |

### Key Constraints
- Production database serving 4 outlets, 14 employees — NO destructive migrations
- `is_active` field already exists on employees table — archive extends this
- Overlay isolate: data via `FlutterOverlayWindow.shareData()` string serialization only
- Kotlin 1.9.25 — no upgrade (breaks nfc_manager)
- minSdk 24, compileSdk 35, targetSdk 35

### Research Flags
- Phase 16 (Live Activity) may need deeper research during planning: overlay memory profiling, OEM battery optimization, Supabase Realtime reconnection behavior
- Phases 13-15: standard patterns, no additional research needed

### Open Blockers
- None

## ⚠️ Database Safety Rules
- Sistem absensi SEDANG BERJALAN di production (4 gerai, karyawan aktif)
- **WAJIB konfirmasi ke user sebelum setiap perubahan database** (ALTER, DROP, UPDATE massal)
- Boleh tanpa konfirmasi HANYA jika: CREATE TABLE baru, ADD COLUMN nullable, CREATE POLICY, INSERT seed data
- DILARANG: DROP TABLE, DROP COLUMN, ALTER COLUMN type, UPDATE/DELETE data existing tanpa konfirmasi
- Selalu jalankan migration additive (tidak merusak data yang ada)

## Supabase Project
- Project ID: `tmapxdftdhxovthgbhww`
- Region: ap-south-1 (Mumbai)
- Status: ACTIVE_HEALTHY

## File Locations
- Flutter project: `absensi apk/absensi_enakko_flutter/`
- Planning: `absensi apk/absensi_enakko_flutter/.planning/`
- Codebase map: `.planning/codebase/`
- Milestones archive: `.planning/milestones/`
- Research: `.planning/research/SUMMARY.md`
- Live activity guide: `absensi apk/liveaction.md`
- Build script: `build_flutter.ps1` (root of projekan/)
