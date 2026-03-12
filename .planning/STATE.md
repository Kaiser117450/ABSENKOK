---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: Schedule Grid + Landing Website
current_plan: Plan 02 of Phase 17
status: in_progress
stopped_at: Completed 17-01-PLAN.md
last_updated: "2026-03-12T17:08:50.134Z"
progress:
  total_phases: 2
  completed_phases: 0
  total_plans: 2
  completed_plans: 1
---

# STATE.md — Project Memory

## Current Status
- **Active Milestone:** v3.0 — Schedule Grid + Landing Website
- **Active Phase:** Phase 17 — Schedule Grid UI Redesign
- **Current Plan:** Plan 02 of 02 (Phase 17)
- **Last Updated:** 2026-03-12
- **Last Session:** 2026-03-12T17:08:50.130Z
- **Stopped At:** Completed 17-01-PLAN.md

## Progress

```
v3.0 Schedule Grid + Landing Website — IN PROGRESS
[█████░░░░░] 1/2 plans · 0/2 phases
```

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-12)

**Core value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.
**Current focus:** Phase 17 — Schedule Grid UI Redesign

## What's Done (v2.0)
- ✅ Phase 13-16: Archive, CSV Import, Kepala Gerai SQL, Live Activity Pill
- ✅ Release APK built and deployed to tablet

## What's Next
- Phase 17: Schedule Grid UI Redesign (refactor `shift_scheduler_screen.dart` → `TableView` with pinned headers)
- Phase 18: ABSENKOK Landing Website (Astro 5 + Tailwind v4 → Vercel)
- Both phases independent — can be planned/executed in any order

## Accumulated Context

### Key Decisions (v3.0)
| # | Decision | Rationale |
|---|----------|-----------|
| 21 | `two_dimensional_scrollables ^0.3.8` for grid | Official Flutter team package, replaces manual scroll sync |
| 22 | Grid first, website second | Higher risk (existing code refactor) before greenfield |
| 23 | Astro 5 (not 6) + Tailwind v4 | Stable versions, Astro 6 too new |
| 24 | Website in separate repo | Zero coupling with Flutter app |
| 25 | `withValues(alpha:)` over `withOpacity()` | Modern Dart API, avoids deprecation warnings |
| 26 | Cell builders as top-level functions | Composable, importable without widget instantiation |

### Key Constraints
- Production database serving 4 outlets — NO destructive migrations
- Grid redesign: data layer (Supabase + SQLite) UNTOUCHED — rendering layer only
- Website: `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\`
- Kotlin 1.9.25 — no upgrade (breaks nfc_manager)

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
- Website project: `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\`
- Codebase map: `.planning/codebase/`
- Milestones archive: `.planning/milestones/`
- SQL scripts: `sql/`
