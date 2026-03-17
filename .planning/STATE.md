---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: Schedule Grid + Landing Website
current_plan: Milestone complete
status: between_milestones
last_updated: "2026-03-18T00:00:00.000Z"
progress:
  total_phases: 3
  completed_phases: 3
  total_plans: 6
  completed_plans: 6
---

# STATE.md — Project Memory

## Current Status
- **Last Milestone:** v3.0 — Schedule Grid + Landing Website — **SHIPPED 2026-03-13**
- **Next Action:** `/gsd:new-milestone` — plan v4.0
- **Last Updated:** 2026-03-18

## Progress

```
v3.0 Schedule Grid + Landing Website — COMPLETE ✅
[██████████] 6/6 plans · 3/3 phases
```

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-18)

**Core value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.
**Current focus:** Planning next milestone

## What Was Shipped

### v3.0 (2026-03-13)
- ✅ Phase 17: Schedule Grid UI Redesign (TableView with pinned headers, extracted widgets, screen integration)
- ✅ Phase 18: ABSENKOK Landing Website (Astro 5 + Tailwind v4, 6 content sections, zero-JS static build)
- ✅ Phase 19: Website Polish — Real Screenshots, About/Architecture Section, 4 SVG Tech Icons

### v2.0 (2026-03-12)
- ✅ Phase 13-16: Soft-archive, CSV Import, Kepala Gerai SQL, Live Activity Pill

### v1.1 (2026-03-05)
- ✅ Phase 1-12: Bug fixes, overlay pill, PDF/CSV reports, kiosk polish, admin UI, badges, logout resilience

## Key Decisions (Cumulative)

| # | Decision | Rationale |
|---|----------|-----------|
| 4 | SharedPreferences over FlutterSecureStorage | Eliminates ANR |
| 11 | two_dimensional_scrollables for grid | Official Flutter team package, pinned headers out-of-box |
| 12 | Cell builders as top-level functions | Composable, importable without widget context |
| 13 | Website in separate repo (absenkok-website/) | Zero coupling with Flutter app |
| 14 | Astro 5 + Tailwind v4 CSS-first config | Zero-JS constraint enforced by framework |
| 15 | Inline SVG tech icons | No icon library, zero bundle overhead |

## Key Constraints
- Production database serving 4 outlets — NO destructive migrations
- Kotlin 1.9.25 — no upgrade (breaks nfc_manager)
- Website: `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\`

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
