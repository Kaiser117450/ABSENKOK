---
phase: 10-sakit-izin-direct-input
plan: 01
subsystem: admin
tags: [supabase, attendance, sakit-izin, admin-panel]

requires:
  - phase: 01-rekap-harian-bug-fixes
    provides: sakit/izin badge rendering in Rekap Harian
provides:
  - Direct Supabase INSERT for admin sakit/izin records (immediate visibility)
  - Edit mode for existing sakit/izin records via existingLog parameter
  - Duplicate prevention for same employee+date sakit/izin entries
  - 30-day backdated date range for historical entries
affects: [admin-employees-screen, sakit-izin-list-screen]

tech-stack:
  added: []
  patterns:
    - "Direct Supabase insert with SQLite offline fallback for admin operations"
    - "Edit mode via optional existingLog constructor parameter"

key-files:
  created: []
  modified:
    - lib/screens/admin/sakit_izin_dialog.dart

key-decisions:
  - "Direct Supabase INSERT primary, SQLite queue fallback only on network failure"
  - "scanned_at anchored at 08:00 local time for correct Rekap Harian date bucketing"
  - "Duplicate check skipped in edit mode when date unchanged"

patterns-established:
  - "Admin operations use SupabaseClientFactory.admin directly (not offline queue)"

requirements-completed: [REQ-M5-04]

duration: 5min
completed: 2026-03-05
---

# Phase 10 Plan 01: Direct Supabase Insert + Edit Mode for Sakit/Izin Summary

**Direct Supabase INSERT for admin sakit/izin records with edit mode, duplicate prevention, and 30-day backdated date range**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-05T06:30:00Z
- **Completed:** 2026-03-05T06:35:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Replaced SQLite offline queue with direct `SupabaseClientFactory.admin` INSERT for immediate visibility in Rekap Harian
- Added edit mode via optional `existingLog` parameter that pre-fills type, date, and notes
- Added `_checkDuplicate()` that queries Supabase before insert to prevent double entries
- Anchored `scanned_at` at 08:00 local time (was using current time) for correct date bucketing
- Extended date picker from 7 to 30 days back for historical entries
- Dynamic UI: header shows "Edit Sakit/Izin" and button shows "Perbarui" in edit mode

## Task Commits

Each task was committed atomically:

1. **Task 1: Convert insert path to direct Supabase + add duplicate check + extend date range** - `caf166f` (feat)

## Files Created/Modified
- `lib/screens/admin/sakit_izin_dialog.dart` - Direct Supabase insert, edit mode, duplicate check, 30-day date range, 08:00 time anchor

## Decisions Made
1. **Direct Supabase INSERT primary**: Admin panel always requires network (Supabase auth), so direct insert is more reliable than SQLite queue. Immediate visibility in reports.
2. **08:00 local time anchor**: Previous code used `now().hour/minute` which was wrong for backdated entries. 08:00 ensures the record falls within the correct day bucket in Rekap Harian.
3. **Duplicate check non-blocking on error**: If duplicate check query fails (network), we don't block the user. Better to allow a potential duplicate than fail silently.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 10 Plan 01 complete. Edit mode is wired at the dialog level.
- Next plans can add sakit/izin history list screen and delete capability.
- The `existingLog` parameter is ready for callers to use when opening the dialog in edit mode.

---
*Phase: 10-sakit-izin-direct-input*
*Completed: 2026-03-05*
