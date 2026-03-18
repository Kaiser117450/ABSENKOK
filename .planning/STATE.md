---
gsd_state_version: 1.0
milestone: v4.0
milestone_name: Smart Attendance + Admin Dashboard
current_plan: Not started
status: roadmap_complete
last_updated: "2026-03-18T07:00:00.000Z"
progress:
  total_phases: 4
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# STATE.md — Project Memory

## Current Status
- **Milestone:** v4.0 — Smart Attendance + Admin Dashboard
- **Phase:** 23 of 26 (Bug Fix + Database Foundation) — ready to plan
- **Current Plan:** --
- **Last Updated:** 2026-03-18 — Roadmap created for v4.0

## Progress

```
v4.0 Smart Attendance + Admin Dashboard — READY TO PLAN
[░░░░░░░░░░] 0% · 0/4 phases
```

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-18)

**Core value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.
**Current focus:** Phase 23 — Bug Fix + Database Foundation

## What Was Shipped

### v3.1 (Released, 2026-03-18)
- Phase 20: Biometric Login
- Phase 21: Badge Color Picker
- Phase 22: Production Release (GitHub Release v3.1 with ABSENKOK-v3.1.0.apk)

### v3.0 (2026-03-13)
- Phase 17-19: Schedule Grid, Landing Website, Website Polish

### v2.0 (2026-03-12)
- Phase 13-16: Soft-archive, CSV Import, Kepala Gerai SQL, Live Activity Pill

### v1.1 (2026-03-05)
- Phase 1-12: Bug fixes, overlay pill, PDF/CSV reports, kiosk polish, admin UI, badges, logout resilience

## Key Decisions (Cumulative)

| # | Decision | Rationale |
|---|----------|-----------|
| 4 | SharedPreferences over FlutterSecureStorage | Eliminates ANR |
| 11 | two_dimensional_scrollables for grid | Official Flutter team package |
| 20 | Keep biometric_enabled on logout, clear remembered role | User shouldn't re-enable after re-login |
| 22 | Keep badge color storage as #RRGGBB strings | Allows visual picker UI without changing badge model |

## Key Constraints
- Production database serving 4 outlets — NO destructive migrations
- Kotlin 1.9.25 — no upgrade (breaks nfc_manager)
- Android only — no iOS target

### Open Blockers
- None

## Accumulated Context
- NFC double-scan crash is a production bug — must fix before new features
- All dashboard aggregations must use Supabase RPC (server-side), not fetch-all-in-Dart
- Streak calculation must use existing noon-rule (noon-to-noon logical days)
- Pattern detection must run in background isolate, never block NFC scan
- service_role key must NEVER be in APK — Edge Function required for user creation
- fl_chart is the single new dependency for v4.0

## Database Safety Rules
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
