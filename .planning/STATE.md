---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Admin Tools + Live Activity
status: roadmap_complete
last_updated: "2026-03-11T14:00:00.000Z"
progress:
  total_phases: 4
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# STATE.md — Project Memory

## Current Status
- **Active Milestone:** v2.0 — Admin Tools + Live Activity
- **Active Phase:** Phase 13 — Soft-Archive Karyawan + Riwayat (next up)
- **Last Updated:** 2026-03-11
- **Last Session:** 2026-03-11

## Progress

```
v2.0 Admin Tools + Live Activity
[░░░░░░░░░░░░░░░░░░░░] 0/4 phases · 0% complete
```

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-11)

**Core value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.
**Current focus:** v2.0 roadmap complete — ready to plan Phase 13 (Soft-Archive Karyawan)

## What's Done (v2.0)
- ✅ Research completed (HIGH confidence across all 4 areas)
- ✅ Requirements defined (17 requirements across 4 categories)
- ✅ Roadmap created (4 phases: 13-16)

## What's Next
Plan Phase 13: Soft-Archive Karyawan + Riwayat
- Foundation phase — modifies Employee data model that all subsequent phases depend on
- 6 requirements: ARCH-01 through ARCH-06
- Key deliverables: DB migration, archive/restore actions, Riwayat Karyawan page, NFC exclusion, query audit

## Accumulated Context

### Key Decisions (v2.0)
| # | Decision | Rationale |
|---|----------|-----------|
| 11 | Archive first, Live Activity last | Data model change is foundational; overlay is isolated and complex |
| 12 | Only 2 new packages (csv + file_picker) | Minimize new dependencies; leverage v1.1 architecture |
| 13 | Kepala Gerai = SQL script only, zero Flutter code | 4 outlets doesn't justify admin UI; SQL script is faster and safer |
| 14 | Overlay data flow via shareData() only | Overlay runs in separate isolate — cannot access main Supabase client |
| 15 | Additive migrations only | Production DB at 4 outlets — all new columns NULLABLE or with DEFAULT |

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
