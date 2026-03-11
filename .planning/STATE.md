---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Admin Tools + Live Activity
status: defining_requirements
last_updated: "2026-03-11T13:20:00.000Z"
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# STATE.md — Project Memory

## Current Status
- **Active Milestone:** v2.0 — Admin Tools + Live Activity
- **Active Phase:** None — defining requirements
- **Last Updated:** 2026-03-11
- **Last Session:** 2026-03-11

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-11)

**Core value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.
**Current focus:** Defining requirements for v2.0

## What's Done (v2.0)
(Nothing yet — milestone just started)

## What's Next
Define requirements and create roadmap for v2.0.

## Accumulated Context
### Key Decisions (carried forward)
See PROJECT.md Key Decisions table for complete list.

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
- Live activity guide: `absensi apk/liveaction.md`
- Build script: `build_flutter.ps1` (root of projekan/)
