---
phase: 17-schedule-grid-ui-redesign
plan: 01
subsystem: ui
tags: [flutter, two_dimensional_scrollables, tableview, grid, widget-extraction]

# Dependency graph
requires:
  - phase: 14-shift-scheduler
    provides: "ShiftSlot, ScheduleEntry, OutletSchedule models and shift_scheduler_screen.dart"
provides:
  - "schedule_cells.dart — 5 cell builder functions (corner, header, employee, shift, _chip)"
  - "schedule_table_view.dart — ScheduleTableView StatelessWidget wrapping TableView.builder"
  - "schedule_legend.dart — ScheduleLegend horizontal chip bar for 6 shift/status types"
  - "two_dimensional_scrollables ^0.3.8 dependency"
affects: [17-02-PLAN, shift-scheduler-screen-integration]

# Tech tracking
tech-stack:
  added: [two_dimensional_scrollables ^0.3.8]
  patterns: [top-level cell builder functions, StatelessWidget wrapper for TableView.builder, pinned headers]

key-files:
  created:
    - lib/screens/admin/widgets/schedule_cells.dart
    - lib/screens/admin/widgets/schedule_table_view.dart
    - lib/screens/admin/widgets/schedule_legend.dart
  modified:
    - pubspec.yaml
    - pubspec.lock

key-decisions:
  - "Used withValues(alpha:) instead of deprecated withOpacity() per analyzer recommendation"
  - "Cell builders are top-level functions (not class methods) for reusability"
  - "Day abbreviation uses Monday=1..Sunday=7 weekday mapping (not modulo trick from plan)"

patterns-established:
  - "Cell builder pattern: top-level functions returning TableViewCell for each cell type"
  - "Widget composition: StatelessWidget receives ALL data + callbacks from parent, no internal state"
  - "Pinned layout: pinnedRowCount=1 + pinnedColumnCount=1 for fixed headers"

requirements-completed: [GRID-01, GRID-03, GRID-04, GRID-05]

# Metrics
duration: 10min
completed: 2026-03-12
---

# Phase 17 Plan 01: Schedule Grid Widget Architecture Summary

**TableView.builder grid with pinned row/column headers, extracted cell builders for 4 cell types, and legend bar using two_dimensional_scrollables ^0.3.8**

## Performance

- **Duration:** 10 min
- **Started:** 2026-03-12T16:56:14Z
- **Completed:** 2026-03-12T17:06:36Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Added `two_dimensional_scrollables ^0.3.8` — official Flutter team package for 2D scrolling grids
- Created 3 new widget files in `lib/screens/admin/widgets/` establishing the rendering layer replacement
- Cell builders handle all 4 cell types: corner (bulk-mode checkbox), header (day name/number), employee (name/leave/actions), shift (colored chips with tap handlers)
- ScheduleTableView configured with `DiagonalDragBehavior.free` for tablet two-axis scrolling
- All files pass `flutter analyze` with 0 issues

## Task Commits

Each task was committed atomically:

1. **Task 1: Add dependency + create cell builders and legend widget** - `3c56814` (feat)
2. **Task 2: Create ScheduleTableView widget with TableView.builder** - `18d4169` (feat)

**Plan metadata:** (pending — docs commit after SUMMARY)

## Files Created/Modified
- `pubspec.yaml` — Added two_dimensional_scrollables ^0.3.8 dependency
- `lib/screens/admin/widgets/schedule_cells.dart` (303 lines) — 5 cell builder functions: buildCornerCell, buildHeaderCell, buildEmployeeCell, buildShiftCell, _chip
- `lib/screens/admin/widgets/schedule_table_view.dart` (161 lines) — ScheduleTableView StatelessWidget wrapping TableView.builder with pinned row/column
- `lib/screens/admin/widgets/schedule_legend.dart` (49 lines) — ScheduleLegend horizontal bar with 6 shift/status color chips

## Decisions Made
- Used `withValues(alpha:)` instead of deprecated `withOpacity()` — analyzer flagged 7 deprecation warnings, fixed to match modern Dart API
- Day abbreviation index: `dayNames[date.weekday - 1]` (Monday=1..Sunday=7) instead of the modulo trick in the plan — simpler and matches Dart's `DateTime.weekday` convention
- Cell builders as top-level functions (not a class) to keep them composable and importable without widget instantiation

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed deprecated withOpacity() calls to withValues(alpha:)**
- **Found during:** Task 1 (cell builders and legend verification)
- **Issue:** Flutter analyzer flagged `withOpacity()` as deprecated in Dart 3.x — 7 occurrences across schedule_cells.dart and schedule_legend.dart
- **Fix:** Replaced all `color.withOpacity(X)` with `color.withValues(alpha: X)` per analyzer guidance
- **Files modified:** lib/screens/admin/widgets/schedule_cells.dart, lib/screens/admin/widgets/schedule_legend.dart
- **Verification:** `flutter analyze` reports 0 issues after fix
- **Committed in:** 3c56814 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug — deprecated API)
**Impact on plan:** Essential fix for zero-warning builds. No scope creep.

## Issues Encountered
None — plan executed smoothly after the withOpacity deprecation fix.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- All 3 widget files are compilable and analyzable, ready for integration in Plan 02
- Plan 02 will wire ScheduleTableView + ScheduleLegend into shift_scheduler_screen.dart, replacing the old manual grid

---
*Phase: 17-schedule-grid-ui-redesign*
*Completed: 2026-03-12*

## Self-Check: PASSED
- All 4 artifacts found on disk
- Both task commits verified in git history
- Line count minimums met (303/150, 161/100, 49/40)
