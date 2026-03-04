---
phase: 08-schedule-system-fix-supabase-integration
plan: 02
subsystem: ui
tags: [flutter, shift-scheduler, bulk-assign, riverpod, modal-bottom-sheet]

# Dependency graph
requires:
  - phase: 08-01
    provides: Supabase-first schedule load with dual-write save and unsaved draft indicator (_hasUnsavedChanges state variable)
provides:
  - Bulk assign UI with employee selection checkboxes and Select All toggle
  - Shift picker bottom sheet (Pagi/Siang/Sore/Libur)
  - _bulkAssign() method that skips sakit/izin and approved time-off days
  - AppBar bulk mode indicator with employee count subtitle
  - Exit bulk mode via AppBar X button
affects:
  - phase 09
  - shift_scheduler_screen

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bulk mode state pattern: _isBulkMode toggle + _selectedEmployeeIds Set<String>"
    - "Modal bottom sheet for action picker (no dialog route push)"
    - "FAB dual-state: same button changes behavior + color based on mode"

key-files:
  created: []
  modified:
    - lib/screens/admin/shift_scheduler_screen.dart

key-decisions:
  - "Bulk FAB dual-state: when NOT in bulk mode, tap enters bulk mode; when IN bulk mode, tap opens shift picker"
  - "AppBar changes color (orange) and shows X close button in bulk mode — visible affordance for active selection state"
  - "Bulk assign skips both _getSakitIzin() days AND _hasTimeOff() days — consistent with single-cell add behavior"
  - "Bulk assign generates unique IDs with millisecondsSinceEpoch + emp.id + day.day to prevent collisions"

patterns-established:
  - "Dual-state FAB pattern: heroTag='bulk', backgroundColor changes, Icon changes, onPressed switches between _toggleBulkMode / _showBulkAssignSheet"

requirements-completed:
  - REQ-M5-02

# Metrics
duration: 8min
completed: 2026-03-02
---

# Phase 8 Plan 02: Bulk Assign Schedule Summary

**Bulk assign UI for shift scheduler: checklist FAB enters selection mode, Select All header checkbox, individual row checkboxes, and modal bottom sheet shift picker (Pagi/Siang/Sore/Libur) that assigns to all 7 days while skipping sakit/izin/time-off days**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-02T05:25:00Z
- **Completed:** 2026-03-02T05:33:00Z
- **Tasks:** 1 (task 2 is checkpoint:human-verify, pending)
- **Files modified:** 1

## Accomplishments

- Added `_isBulkMode` toggle state + `_selectedEmployeeIds Set<String>` to `_ShiftSchedulerScreenState`
- AppBar switches to orange color with X close button and "N karyawan dipilih" subtitle when in bulk mode
- KARYAWAN column header replaces text with "Semua" Select All checkbox when `_isBulkMode` is true
- Each employee row shows checkbox (with orange active color) on the left when in bulk mode
- Bulk FAB (checklist icon) placed above auto-generate FAB; changes to assignment icon in bulk mode
- `_bulkAssign(ShiftSlot)` replaces all 7 days for selected employees, skips sakit/izin and approved time-off days, sets `_hasUnsavedChanges = true`
- Modal bottom sheet shows 4 colored CircleAvatar shift options (Pagi/Siang/Sore/Libur)
- Shows error snackbar if sheet opened with no employees selected

## Task Commits

Each task was committed atomically:

1. **Task 1: Add employee selection state + Select All checkbox + bulk assign logic** - `328c9fd` (feat)

**Plan metadata:** pending final docs commit

## Files Created/Modified

- `lib/screens/admin/shift_scheduler_screen.dart` - Added bulk assign state, methods, and UI wiring to existing schedule grid

## Decisions Made

- Bulk FAB dual-state: same FAB button changes behavior + color based on `_isBulkMode` (enters mode vs opens picker). Keeps FAB count minimal (2 FABs total).
- AppBar color change (orange) is the primary visual affordance that bulk mode is active — avoids need for separate toolbar.
- Bulk assign skips both `_getSakitIzin()` and `_hasTimeOff()` days for consistency with single-cell behavior.
- Modal bottom sheet (not dialog) chosen for shift picker — lower friction, less overlay stacking.

## Deviations from Plan

None - plan executed exactly as written. All specified methods, state variables, and UI wiring implemented as described.

## Issues Encountered

None. The implementation was straightforward. All bulk assign logic integrated cleanly with existing `_sakitIzinMap` and `_timeOffMap` state that was already loaded in `_loadData()`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Schedule system (Phase 8) is complete pending human verification of the full end-to-end flow (Supabase load + save + bulk assign)
- After verification, Phase 08.1 (export laporan CSV/PDF accuracy fixes) can begin
- Phase 7 (Admin UI System Polish) is unblocked and can run in parallel

---
*Phase: 08-schedule-system-fix-supabase-integration*
*Completed: 2026-03-02*
