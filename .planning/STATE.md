---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: Schedule Grid + Landing Website
current_plan: Plan 1 of 2 complete
status: in-progress
stopped_at: Completed 19-01-PLAN.md
last_updated: "2026-03-12T19:55:38.909Z"
progress:
  total_phases: 3
  completed_phases: 2
  total_plans: 6
  completed_plans: 5
---

# STATE.md — Project Memory

## Current Status
- **Active Milestone:** v3.0 — Schedule Grid + Landing Website
- **Active Phase:** Phase 19 — Website Polish — Real Screenshots, About/Architecture Section, Tech Icons
- **Current Plan:** Plan 1 of 2 complete
- **Last Updated:** 2026-03-12
- **Last Session:** 2026-03-12T19:55:38.904Z
- **Stopped At:** Completed 19-01-PLAN.md

## Progress

```
v3.0 Schedule Grid + Landing Website — IN PROGRESS
[████████░░] 5/6 plans · 2/3 phases
```

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-12)

**Core value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.
**Current focus:** Phase 19 — Website Polish (Real screenshots, About/Architecture, Tech Icons)

## What's Done (v2.0)
- ✅ Phase 13-16: Archive, CSV Import, Kepala Gerai SQL, Live Activity Pill
- ✅ Release APK built and deployed to tablet

## What's Done (v3.0)
- ✅ Phase 17: Schedule Grid UI Redesign (TableView with pinned headers, extracted widgets, screen integration)
- ✅ Phase 18: ABSENKOK Landing Website (Astro 5 + Tailwind v4, 6 content sections, zero-JS static build)

## What's Next
- Phase 19: Website Polish — Real Screenshots, About/Architecture Section, Tech Icons

### Roadmap Evolution
- Phase 19 added: Website Polish — Real Screenshots, About/Architecture Section, Tech Icons

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
| 27 | Removed unused imports during rendering extraction | dart:io, supabase_flutter, outlet.dart, time_off_request.dart no longer needed |
| 28 | Parent screen keeps state+data, delegates rendering via callbacks | Clean separation: ~943 lines state+data, widgets handle all rendering |
| 29 | Manual npm init to avoid Astro 6; Tailwind v4 via @tailwindcss/vite | npm create astro@latest scaffolds Astro 6; @astrojs/tailwind is v3 only |
| 30 | CSS-only tablet mockup with colored grid cells | More visually interesting than blank placeholder, matches app's schedule grid |
| 31 | Inline SVG icons per feature card | Avoids icon library dependency, keeps zero-JS promise |
| 32 | Replaced 90-line CSS tablet mockup with single Astro Image | Real screenshot more authentic, simpler code |
| 33 | Image pipeline: PNG src/assets → ESM import → Astro Image → WebP dist | 17MB PNG → 65KB WebP (99.6% reduction) |

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
