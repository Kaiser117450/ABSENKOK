---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: Schedule Grid + Landing Website
current_plan: Not started
status: roadmap_complete
stopped_at: Roadmap created — 2 phases (17-18), 20 requirements mapped
last_updated: "2026-03-12T16:00:00.000Z"
progress:
  total_phases: 2
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# STATE.md — Project Memory

## Current Status
- **Active Milestone:** v3.0 — Schedule Grid + Landing Website
- **Active Phase:** Phase 17 (ready to plan)
- **Current Plan:** —
- **Last Updated:** 2026-03-12
- **Last Session:** 2026-03-12T16:00:00Z
- **Stopped At:** Roadmap created — 2 phases, 20 requirements mapped, ready for `/gsd-plan-phase 17`

## Progress

```
v3.0 Schedule Grid + Landing Website — READY TO PLAN
[░░░░░░░░░░] 0/0 plans · 0/2 phases
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
