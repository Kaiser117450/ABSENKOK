---
phase: 07-admin-ui-system-polish
plan: 03
subsystem: ui
tags: [flutter, widgets, app-card, shimmer-skeleton, app-empty-state, app-toast, admin-screens, visual-consistency]

# Dependency graph
requires:
  - phase: 07-admin-ui-system-polish plan 01
    provides: AppCard, ShimmerSkeleton, AppEmptyState, AppBadge, AppToast widget library
provides:
  - All 4 remaining admin files (employees, reports, outlets, sakit_izin) use shared widget library
  - Visual consistency: same card styling, shimmer loading, toast notifications, empty states
  - Zero raw SnackBar calls across all admin screens
  - Zero standalone CircularProgressIndicator for main loading states
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - AppCard with padding EdgeInsets.zero for complex card layouts with internal color bars
    - ShimmerSkeleton composite rows matching target content layout (avatar+text for employees, icon+text for reports)
    - AppEmptyState in scrollable ListView wrapper to support pull-to-refresh on empty states
    - AppToast.success/error/info replacing all ScaffoldMessenger.showSnackBar calls

key-files:
  created: []
  modified:
    - lib/screens/admin/admin_employees_screen.dart
    - lib/screens/admin/admin_reports_screen.dart
    - lib/screens/admin/admin_outlets_screen.dart
    - lib/screens/admin/sakit_izin_dialog.dart

key-decisions:
  - "Employee card uses AppCard with padding:EdgeInsets.zero to preserve internal left color bar + avatar layout"
  - "Report shimmer uses 6 rows matching _ReportTile layout (circle+text+trailing) for believable loading skeleton"
  - "CircularProgressIndicator inside buttons/dialogs preserved (action-in-progress) -- only main loading states replaced"
  - "Outlets _buildEmpty wraps AppEmptyState + add-button in Column for combined empty+action UX"
  - "Fixed outlets _toggleActive error handler that incorrectly used AppToast.success for failure"
  - "Removed stray duplicate _buildOutletShimmer from _ActionBtn class (was inside wrong class body)"
  - "Removed unused supabase_client.dart import from sakit_izin_dialog.dart"

patterns-established:
  - "All admin screens use shared widget library: AppCard, ShimmerSkeleton, AppEmptyState, AppToast"
  - "Toast replaces SnackBar universally across admin UI"
  - "Shimmer composites match target content layout for believable loading states"

requirements-completed: [PHASE7-EMPLOYEES-POLISH, PHASE7-REPORTS-POLISH, PHASE7-OUTLETS-POLISH, PHASE7-EMPTY-STATE, PHASE7-BADGE]

# Metrics
duration: 8min
completed: 2026-03-05
---

# Phase 7 Plan 03: Admin Screen Polish -- Employees, Reports, Outlets, SakitIzin Summary

**Applied widget library (AppCard, ShimmerSkeleton, AppEmptyState, AppToast) across 4 remaining admin files, eliminating all raw SnackBar and inline loading/empty states for full visual consistency**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-05T05:00:00Z
- **Completed:** 2026-03-05T05:08:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Employees screen: AppCard for employee rows, 5-row shimmer skeleton for loading, AppEmptyState for empty list
- Reports screen: AppToast replaces 4 SnackBar calls, shimmer loading for main+rekap states, AppEmptyState for initial/empty/rekap states, AppCard for _ReportTile
- Outlets screen: AppCard for _OutletCard, AppEmptyState for empty state, fixed error toast using wrong method, removed stray duplicate shimmer method
- SakitIzin dialog: AppToast replaces SnackBar, cleaned unused import
- Zero raw SnackBar remaining across all 4 files
- `flutter analyze lib/screens/admin/` passes -- 0 errors, 0 warnings (only info-level deprecation)

## Task Commits

Each task was committed atomically:

1. **Task 1: Polish admin_employees_screen with AppCard, ShimmerSkeleton, AppEmptyState** - `319b833` (feat)
2. **Task 2: Polish reports, outlets, sakit_izin with widget library** - `6639b91` (feat)

**Plan metadata:** [to be set by final commit]

## Files Created/Modified
- `lib/screens/admin/admin_employees_screen.dart` - Added AppCard/ShimmerSkeleton/AppEmptyState imports; replaced inline Container with AppCard in _EmployeeCard; replaced CircularProgressIndicator with _buildEmployeeListShimmer(); replaced inline empty state with AppEmptyState
- `lib/screens/admin/admin_reports_screen.dart` - Added AppCard/ShimmerSkeleton/AppEmptyState/AppToast imports; replaced 4 SnackBar calls with AppToast; replaced main+rekap loading with _buildReportShimmer(); replaced 3 empty states with AppEmptyState; replaced _ReportTile Container with AppCard
- `lib/screens/admin/admin_outlets_screen.dart` - Added AppEmptyState import; replaced _buildEmpty with AppEmptyState; replaced _OutletCard Container with AppCard; fixed error toast (success->error); removed stray duplicate _buildOutletShimmer
- `lib/screens/admin/sakit_izin_dialog.dart` - Added AppToast import; replaced SnackBar with AppToast.success; removed unused supabase_client import

## Decisions Made
- Employee AppCard uses `padding: EdgeInsets.zero` because the card has internal colored left bar that needs to align with card edges
- CircularProgressIndicator kept inside buttons/dialogs (save button spinner, NFC scan spinner) as these are action-in-progress indicators, not main loading states
- Report shimmer matches _ReportTile layout (circle icon + name/outlet text + timestamp) for believable skeleton
- Fixed a pre-existing bug: outlets `_toggleActive` error handler was using `AppToast.success` for failure messages
- Removed stray `_buildOutletShimmer` duplicate that was erroneously inside `_ActionBtn` class body

## Deviations from Plan

### Auto-fixed Issues

**1. [Bug Fix] Outlets error toast using wrong method**
- **Found during:** Task 2 (admin_outlets_screen.dart)
- **Issue:** `_toggleActive` catch block used `AppToast.success` for error message "Gagal: $e"
- **Fix:** Changed to `AppToast.error`
- **Files modified:** lib/screens/admin/admin_outlets_screen.dart
- **Verification:** Code review confirms correct usage
- **Committed in:** 6639b91

**2. [Cleanup] Removed stray duplicate _buildOutletShimmer**
- **Found during:** Task 2 (admin_outlets_screen.dart)
- **Issue:** `_buildOutletShimmer` was duplicated inside `_ActionBtn` class body (unreachable, triggered warning)
- **Fix:** Removed the duplicate method
- **Files modified:** lib/screens/admin/admin_outlets_screen.dart
- **Verification:** flutter analyze passes with no warnings
- **Committed in:** 6639b91

**3. [Cleanup] Removed unused import in sakit_izin_dialog**
- **Found during:** Task 2 (sakit_izin_dialog.dart)
- **Issue:** `supabase_client.dart` import was unused (pre-existing)
- **Fix:** Removed the import
- **Files modified:** lib/screens/admin/sakit_izin_dialog.dart
- **Verification:** flutter analyze passes
- **Committed in:** 6639b91

---

**Total deviations:** 3 auto-fixed (1 bug fix, 2 cleanup)
**Impact on plan:** All fixes improve correctness/cleanliness. No scope creep.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 7 (Admin UI System Polish) is now complete: all 3 plans executed
- All admin screens use consistent widget library
- Ready for next milestone phase

## Self-Check: PASSED
- FOUND: lib/screens/admin/admin_employees_screen.dart contains AppCard
- FOUND: lib/screens/admin/admin_reports_screen.dart contains AppToast
- FOUND: lib/screens/admin/admin_outlets_screen.dart contains AppEmptyState
- FOUND: lib/screens/admin/admin_employees_screen.dart imports shimmer_skeleton
- FOUND: lib/screens/admin/admin_outlets_screen.dart imports app_empty_state
- NO showSnackBar in any of the 4 files
- flutter analyze lib/screens/admin/ passes (0 errors, 0 warnings)

---
*Phase: 07-admin-ui-system-polish*
*Completed: 2026-03-05*
