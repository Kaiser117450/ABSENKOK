---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: Schedule Grid + Landing Website
current_plan: Not started
status: defining_requirements
stopped_at: Milestone v3.0 started — defining requirements
last_updated: "2026-03-12T15:42:00.000Z"
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# STATE.md — Project Memory

## Current Status
- **Active Milestone:** v3.0 — Schedule Grid + Landing Website
- **Active Phase:** None (defining requirements)
- **Current Plan:** —
- **Last Updated:** 2026-03-12
- **Last Session:** 2026-03-12T15:42:00Z
- **Stopped At:** Milestone v3.0 started — defining requirements

## Progress

```
v3.0 Schedule Grid + Landing Website — DEFINING REQUIREMENTS
[░░░░░░░░░░] 0/0 plans · 0/0 phases
```

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-12)

**Core value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.
**Current focus:** Milestone v2.0 complete and archived. Ready for next milestone.

## What's Done (v2.0)
- ✅ Phase 13: Soft-Archive Karyawan + Riwayat (3 plans, archive/restore/history)
- ✅ Phase 14: Batch CSV Import (2 plans, service + wizard UI)
- ✅ Phase 15: Kepala Gerai SQL Setup (SQL scripts)
- ✅ Phase 16: Persistent Live Activity Pill (2 plans, LiveContentProvider + overlay wiring)
- ✅ Bug fixes: UI overflow, CSV template outlet names
- ✅ Release APK built and deployed to tablet

## What's Next
Start next milestone with `/gsd-new-milestone`

## Accumulated Context

### Key Decisions (v2.0)
| # | Decision | Rationale |
|---|----------|-----------|
| 11 | Archive first, Live Activity last | Data model change is foundational |
| 12 | Only 2 new packages (csv + file_picker) | Minimize dependencies |
| 13 | Kepala Gerai = SQL script only | 4 outlets doesn't justify admin UI |
| 14 | Overlay data via shareData() only | Separate isolate can't access Supabase |
| 15 | Additive migrations only | Production DB at 4 outlets |
| 16 | archivedAt as DateTime? | Type-safe timestamp handling |
| 17 | ZONA BERBAHAYA pattern | Clear separation for destructive actions |
| 18 | Pure-function CSV validation | Testable without Supabase |
| 19 | Custom step indicator wizard | Lighter than Material Stepper |
| 20 | Injectable callbacks for LiveContentProvider | Clean testability |

### Key Constraints
- Production database serving 4 outlets, 14 employees — NO destructive migrations
- Overlay isolate: data via `FlutterOverlayWindow.shareData()` string serialization only
- Kotlin 1.9.25 — no upgrade (breaks nfc_manager)
- minSdk 24, compileSdk 35, targetSdk 35

### Open Blockers
- None

## ⚠️ Database Safety Rules
- Sistem absensi SEDANG BERJALAN di production (4 gerai, karyawan aktif)
- **WAJIB konfirmasi ke user sebelum setiap perubahan database**
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
- SQL scripts: `sql/`
