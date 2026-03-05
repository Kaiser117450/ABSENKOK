---
phase: 02-kiosk-scan-cycle-edge-cases
plan: "03"
subsystem: ui
tags: [flutter, supabase, admin-dashboard, attendance]

# Dependency graph
requires:
  - phase: 01-rekap-harian-bug-fixes
    provides: _DailySummary structure and DailySummaryStatus patterns
provides:
  - Admin dashboard Open Shifts widget surfacing employees who clocked in but not out
  - _manualPulang dialog for admin to close open shifts with audit notes
  - 32h window Supabase query for overnight shift detection
affects:
  - phase 9 (badge system — employee display patterns)
  - phase 7 (admin UI polish — dashboard card patterns)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - supabaseReady guard on all Supabase calls
    - 32h window for overnight shift queries (vs calendar-day yesterday)
    - SliverToBoxAdapter for dashboard widget injection

key-files:
  created: []
  modified:
    - lib/screens/admin/admin_dashboard_screen.dart

key-decisions:
  - "32h window (not 24h or yesterday) for open shifts query — covers overnight shifts starting 22:00+ previous day"
  - "Client-side filtering by masuk+no-pulang pattern — dataset is small (14 employees), no SQL procedure needed"
  - "Default pulang timestamp = DateTime.now() — admin edits notes but not time (simpler UX)"
  - "Widget hidden via SizedBox.shrink() when no open shifts — no empty state needed for happy path"
  - "is_backup: false on manual pulang INSERT — marks it as a legitimate admin correction, not an offline sync"

patterns-established:
  - "Open shifts pattern: query .gte(32h window) then client-filter for masuk-only entries"
  - "Manual record insertion: use SupabaseClientFactory.admin with notes field for audit trail"

requirements-completed:
  - REQ-M1-04

# Metrics
duration: 20min
completed: 2026-03-01
---

# Phase 2 Plan 03: Open Shifts Dashboard Widget Summary

**Admin dashboard Open Shifts widget with 32h-window query, employee list, and manual pulang dialog with audit notes**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-03-01
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- `_OpenShift` data class + `_loadOpenShifts()` with `supabaseReady` guard and 32-hour cutoff window
- `_manualPulang(_OpenShift)` — AlertDialog with optional notes field, INSERT to `attendance_logs` with `is_backup: false`
- `_buildOpenShiftsWidget()` — amber card, hidden when list empty, per-employee rows with elapsed hours + "Tutup Shift" button
- Wired into `build()` slivers via `SliverToBoxAdapter` between `_buildStatGrid()` and `_buildQuickActions()`

## Task Commits

Each task was committed atomically:

1. **Task 1: Add _OpenShift class, state, _loadOpenShifts, _manualPulang** - `9734500` (feat)
2. **Task 2: Add _buildOpenShiftsWidget and wire into build() slivers** - `b77717b` (feat)

## Files Created/Modified
- `lib/screens/admin/admin_dashboard_screen.dart` — Added _OpenShift model, open shifts state/methods, and dashboard widget

## Decisions Made
- 32-hour window chosen over calendar-day "yesterday" to avoid missing overnight shifts (22:00+ start time)
- Widget uses `SizedBox.shrink()` when empty — no empty state copy needed, clean UX for normal days
- Manual pulang uses `DateTime.now()` for timestamp — admin provides context via notes field

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Missing Import] Added missing supabaseReady import**
- **Found during:** Task 1 (_loadOpenShifts implementation)
- **Issue:** `supabaseReady` global bool from `main.dart` not imported in dashboard screen
- **Fix:** Added `import '../../main.dart' show supabaseReady;`
- **Files modified:** lib/screens/admin/admin_dashboard_screen.dart
- **Committed in:** `9734500` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (missing import)
**Impact on plan:** Necessary for compilation. No scope creep.

## Issues Encountered
- SUMMARY.md creation was blocked by tool permission denial mid-execution. Created manually by orchestrator. All code commits completed successfully.

## Next Phase Readiness
- Phase 2 complete: all 5 bugs (BUG-001 through BUG-005) resolved
- Ready for Phase 3: Floating Pill Live Activity overlay
- Admin dashboard now has full open-shifts visibility for production use

---
*Phase: 02-kiosk-scan-cycle-edge-cases*
*Completed: 2026-03-01*
