---
phase: 24-core-services-analytics
plan: 01
subsystem: analytics
tags: [flutter, supabase, rpc, dart, analytics, attendance, overtime, dashboard]

# Dependency graph
requires:
  - phase: 23-database-foundation
    provides: get_attendance_rates RPC, attendance_logs schema, employees.home_outlet_id
provides:
  - AnalyticsService singleton with getAttendanceRates, getOvertimeFlags, getMissingClockouts
  - AttendanceRateData, OvertimeFlag, MissingClockout data classes
  - get_overtime_flags SQL RPC (SECURITY DEFINER, kepala_gerai scoped)
  - get_missing_clockouts SQL RPC (SECURITY DEFINER, kepala_gerai scoped)
  - AttendanceRateCard widget (ChoiceChip period toggle, color-coded, empty/error/loading states)
  - OvertimeAlertRow widget (horizontal scroll chips, warningLight, ClampingScrollPhysics)
  - PatternDetectionService stub (unblocks kiosk_scan_screen compilation)
  - 14 passing unit tests for data class parsing and singleton guard behavior
affects:
  - 24-02-plan (uses AnalyticsService.getMissingClockouts)
  - 24-03-plan (uses PatternDetectionService stub to build on)
  - 25-dashboard-ui (uses AttendanceRateCard, OvertimeAlertRow, AnalyticsService)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AnalyticsService singleton: same pattern as BadgeService (private constructor + static final instance)"
    - "All Supabase methods guard on supabaseReady global bool and return null/empty on failure"
    - "SQL RPCs use SECURITY DEFINER + home_outlet_id for kepala_gerai outlet scoping"
    - "TDD: RED commit (failing tests) -> GREEN commit (implementation) flow"

key-files:
  created:
    - lib/services/analytics_service.dart
    - lib/services/pattern_detection_service.dart
    - lib/widgets/attendance_rate_card.dart
    - lib/widgets/overtime_alert_row.dart
    - sql/phase24_rpc_overtime_missing.sql
    - test/services/analytics_service_test.dart
  modified:
    - lib/screens/admin/admin_dashboard_screen.dart (already had imports/integration from 24-02 prep)

key-decisions:
  - "Use time-based overtime threshold (default 8h) instead of schedule-aware comparison — avoids SQLite/Supabase join complexity"
  - "PatternDetectionService is a stub in Plan 01 — kiosk_scan_screen already imports it, so it must exist to compile"
  - "Replace iconsax_flutter with Material Icons.timer_outlined in OvertimeAlertRow — iconsax_flutter not in pubspec.yaml"
  - "RPC calls use multi-line format (rpc name on next line) for readability — functionally identical"

patterns-established:
  - "Analytics service layer: singleton + supabaseReady guard + try/catch + debugPrint"
  - "Widget refresh pattern: public Future<void> refresh() delegates to _loadData() for parent pull-to-refresh"
  - "Empty state vs null data: check both totalEmployees==0 AND totalPresent==0 for true empty state"

requirements-completed: [ANLYT-01, ANLYT-02]

# Metrics
duration: 15min
completed: 2026-03-19
---

# Phase 24 Plan 01: Analytics Service Layer + Attendance Rate Card Summary

**AnalyticsService singleton + 2 SQL RPCs (overtime/missing clockouts) + AttendanceRateCard + OvertimeAlertRow widgets with dashboard integration and 14 passing unit tests**

## Performance

- **Duration:** 15 min
- **Started:** 2026-03-18T19:15:17Z
- **Completed:** 2026-03-19T03:30:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- AnalyticsService singleton with 3 RPC methods, supabaseReady guard, non-throwing error handling
- SQL migration script with get_overtime_flags and get_missing_clockouts (SECURITY DEFINER, kepala_gerai scoped via home_outlet_id)
- AttendanceRateCard with Hari/Minggu/Bulan ChoiceChip toggle, color-coded accent stripe (>=80% green / <80% red), proper loading/empty/error states
- OvertimeAlertRow with ClampingScrollPhysics, warningLight chips, SizedBox.shrink() when empty
- 14 unit tests covering data class parsing (fromJson), int-to-double coercion, and supabaseReady=false guard
- PatternDetectionService stub added to unblock kiosk_scan_screen compilation

## Task Commits

Each task was committed atomically:

1. **TDD RED: analytics_service_test.dart** - `1c33d79` (test)
2. **Task 1: AnalyticsService + SQL + PatternDetection stub** - `30ae5ad` (feat)
3. **Task 2: AttendanceRateCard + OvertimeAlertRow** - already committed in 36ed31f (feat, from 24-02 prep session)

## Files Created/Modified
- `lib/services/analytics_service.dart` - AnalyticsService singleton, AttendanceRateData/OvertimeFlag/MissingClockout data classes
- `lib/services/pattern_detection_service.dart` - PatternDetectionService stub (checkAndNotifyIfLate no-op)
- `lib/widgets/attendance_rate_card.dart` - StatefulWidget with period toggle, color-coded rate display
- `lib/widgets/overtime_alert_row.dart` - Horizontal scroll chips with warningLight background
- `sql/phase24_rpc_overtime_missing.sql` - get_overtime_flags + get_missing_clockouts RPCs
- `test/services/analytics_service_test.dart` - 14 tests covering fromJson and singleton behavior

## Decisions Made
- Time-based overtime threshold (8h default) instead of schedule-aware comparison — avoids SQLite/Supabase cross-system join complexity
- PatternDetectionService created as stub because kiosk_scan_screen.dart already imports it (pre-written integration code)
- `Iconsax.timer_1` replaced with `Icons.timer_outlined` — iconsax_flutter is not in pubspec.yaml dependencies
- RPC calls formatted with name on next line (multi-line) for readability; functionally identical to single-line

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created PatternDetectionService stub**
- **Found during:** Task 1 (running tests)
- **Issue:** `lib/screens/kiosk/kiosk_scan_screen.dart` already imports `pattern_detection_service.dart` which didn't exist, causing compile failure for all tests
- **Fix:** Created stub with `checkAndNotifyIfLate` no-op method (full implementation deferred to Plan 03)
- **Files modified:** lib/services/pattern_detection_service.dart (created)
- **Verification:** Tests compile and pass without this import error
- **Committed in:** 30ae5ad (Task 1 commit)

**2. [Rule 3 - Blocking] Replaced iconsax_flutter with Material Icons in OvertimeAlertRow**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** `iconsax_flutter` package referenced in overtime_alert_row.dart but not declared in pubspec.yaml
- **Fix:** Replaced `Iconsax.timer_1` with `Icons.timer_outlined` from Material library
- **Files modified:** lib/widgets/overtime_alert_row.dart
- **Verification:** `flutter analyze lib/widgets/overtime_alert_row.dart` shows no issues
- **Committed in:** Part of widget rewrite (36ed31f)

---

**Total deviations:** 2 auto-fixed (both Rule 3 - blocking)
**Impact on plan:** Both fixes necessary for compilation. No scope creep. PatternDetectionService stub is the correct approach since Plan 03 provides the full implementation.

## Issues Encountered
- Widget files (attendance_rate_card.dart, overtime_alert_row.dart) were pre-created by a previous session's 24-02 execution as Rule 3 stubs. They already contained the correct spec-compliant implementation, so only the analytics_service.dart and SQL file needed to be created from scratch.
- Admin dashboard screen already had all imports and integration code for the new widgets (also pre-written in 24-02 session).

## User Setup Required
None — SQL RPCs are included in sql/phase24_rpc_overtime_missing.sql for deployment, but deployment was already confirmed as applied in STATE.md (migration `phase_24_overtime_missing_rpc_20260318`).

## Next Phase Readiness
- AnalyticsService is the service layer foundation needed by Plan 02 (MissingClockoutService) and Plan 03 (PatternDetectionService)
- AttendanceRateCard renders on AdminDashboardScreen between hero header and stat grid
- OvertimeAlertRow shows overtime chips from live RPC data
- Phase 25 (Dashboard UI + Visualization) can use AnalyticsService + these widgets as its foundation

---
*Phase: 24-core-services-analytics*
*Completed: 2026-03-19*
