---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: Bug Fix + Edge Cases + Features
status: shipped
last_updated: "2026-03-05T20:45:00.000Z"
progress:
  total_phases: 11
  completed_phases: 11
  total_plans: 24
  completed_plans: 24
---

# STATE.md — Project Memory

## Current Status
- **Shipped Milestone:** v1.1 — Bug Fix + Edge Cases + Features (2026-03-05)
- **Active Phase:** None — milestone complete
- **Last Updated:** 2026-03-05
- **Last Session:** 2026-03-05

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-05)

**Core value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.
**Current focus:** Planning next milestone

## What's Done (v1.1)
- [x] Phase 1: Rekap Harian Bug Fixes (1 plan) — fixed BUG-001, BUG-002, BUG-003
- [x] Phase 2: Kiosk Scan Cycle Edge Cases (3 plans) — fixed BUG-004, BUG-005, open shifts widget
- [x] Phase 3: Overlay Pill Implementation (4 plans) — persistent floating pill overlay
- [x] Phase 4: PDF Export Engine (1 plan) — PdfReportService with branded summary
- [x] Phase 6: NFC Idle Screen Visual Enhancement (2 plans) — ambient animation, gradient ring, brand logo
- [x] Phase 7: Admin UI System Polish (3 plans) — AppCard, ShimmerSkeleton, AppBadge, AppToast library
- [x] Phase 8: Schedule System Fix (2 plans) — Supabase-first, bulk assign
- [x] Phase 8.1: PDF/CSV Export Fix (2 plans) — color-coded tables, cached export
- [x] Phase 10: Sakit/Izin Direct Input (2 plans) — direct Supabase INSERT, history list
- [x] Phase 11: Employee Badge System (3 plans) — model, avatar widget, CRUD management
- [x] Phase 12: Kiosk Logout Bug Fix (1 plan) — resilient stop(), 5s timeout

## What's Next
Milestone v1.1 shipped. Start next milestone with `/gsd:new-milestone`.

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
