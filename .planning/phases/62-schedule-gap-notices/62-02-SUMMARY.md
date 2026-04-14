---
phase: 62-schedule-gap-notices
plan: 02
subsystem: ui
tags: [dashboard, schedule, notice, bottom-sheet, flutter]
requires:
  - phase: 62-01
    provides: typed schedule-gap notice service and dashboard-ready notice contract
provides:
  - outlet-scoped dashboard quick action for empty schedule follow-up
  - lightweight schedule-gap detail sheet with scheduler CTA
  - focused widget coverage for quick-action visibility and sheet copy
affects: [62-phase-complete, 63-export-parity-re-lock, admin-dashboard]
tech-stack:
  added: []
  patterns:
    - dashboard notice visibility depends on one resolved outlet plus typed notice count
    - notice detail stays in a lightweight bottom sheet and reuses existing scheduler navigation
key-files:
  created:
    - lib/screens/admin/widgets/admin_schedule_gap_notice_sheet.dart
    - test/screens/admin/admin_dashboard_schedule_gap_test.dart
  modified:
    - lib/screens/admin/admin_dashboard_screen.dart
key-decisions:
  - "The dashboard notice surface stays a quick action plus bottom sheet, reusing `_openShiftScheduler()` instead of adding inline schedule editing."
  - "Notice refresh uses a fixed recent lookback window and reloads when operators return from the scheduler."
patterns-established:
  - "Kepala gerai notice visibility is outlet-scoped through the existing dashboard outlet resolution, while full admin must have one selected outlet."
  - "Schedule-gap follow-up remains informational and separate from recap, pending, and export flows."
requirements-completed: [SCHED-05]
duration: 17 min
completed: 2026-04-01
---

# Phase 62 Plan 02: Dashboard Schedule-Gap Surface Summary

**The admin dashboard now exposes outlet-scoped `Jadwal Kosong` follow-up notices as a lightweight quick action and detail sheet that routes operators straight into the existing scheduler flow.**

## Performance

- **Duration:** 17 min
- **Started:** 2026-04-01T15:09:00+08:00
- **Completed:** 2026-04-01T15:26:00+08:00
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Wired `AdminDashboardScreen` to load recent strict recap rows, attendance logs, and outlet roster for one resolved outlet, then build schedule-gap notices through `ScheduleGapNoticeService`.
- Added a new `Jadwal\nKosong` quick action with count badge plus `AdminScheduleGapNoticeSheet` that shows employee/date follow-up rows and the locked `Buka Jadwal` CTA.
- Added widget coverage for quick-action visibility, full-admin outlet gating, scoped sheet content, locked helper copy, and scheduler callback behavior.

## Task Commits

Workspace commits were intentionally skipped for this plan because `lib/screens/admin/admin_dashboard_screen.dart` already had unrelated unstaged local modifications before Phase 62 execution started. A normal commit would have captured more than the requested phase work.

1. **Task 1: Add outlet-scoped schedule-gap notice state and quick-action wiring to the dashboard** - not committed (dirty tracked workspace)
2. **Task 2: Add focused widget coverage for dashboard notice visibility, outlet scope, and scheduler CTA** - not committed (dirty tracked workspace)

## Files Created/Modified

- `lib/screens/admin/admin_dashboard_screen.dart` - Loads outlet-scoped notice data, shows the quick action, opens the sheet, and refreshes after returning from the scheduler.
- `lib/screens/admin/widgets/admin_schedule_gap_notice_sheet.dart` - Presentational quick action and detail sheet for schedule-gap follow-up rows.
- `test/screens/admin/admin_dashboard_schedule_gap_test.dart` - Widget coverage for quick-action visibility, scope gating, locked copy, and scheduler CTA behavior.

## Decisions Made

- The dashboard notice surface reuses the existing scheduler route instead of inventing new inline editing state, keeping the UI lightweight and operational.
- Notice loading stays single-outlet-first: kepala gerai uses `managedOutletId`, while full admin only sees the affordance when one outlet is selected.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Focused regression needed a sheet text assertion fix**
- **Found during:** Task 2 (widget verification)
- **Issue:** The scope assertion expected `Outlet Utama` as an exact standalone text, but the row renders outlet name and date in one combined line.
- **Fix:** Switched the assertion to `textContaining('Outlet Utama')` so the test matches the actual lightweight row presentation.
- **Files modified:** `test/screens/admin/admin_dashboard_schedule_gap_test.dart`
- **Verification:** Focused Phase 62 regression batch passed after the assertion update
- **Committed in:** not committed

**2. [Rule 3 - Blocking] New Phase 62 files were normalized to package imports**
- **Found during:** Final regression review
- **Issue:** Mixed library URIs can create duplicate enum types in this repo when full-suite compilation traverses both `package:` and `lib/...` imports.
- **Fix:** Normalized the new notice service and sheet widget to `package:absensi_enakko_flutter/...` imports.
- **Files modified:** `lib/services/schedule_gap_notice_service.dart`, `lib/screens/admin/widgets/admin_schedule_gap_notice_sheet.dart`
- **Verification:** Focused Phase 62 regression batch still passed after import normalization
- **Committed in:** not committed

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both changes were verification/environment fixes only. The shipped UI scope stayed exactly within the phase contract.

## Issues Encountered

- The repository-wide `flutter test` suite still fails on unrelated baseline issues outside Phase 62, including a missing `PayrollRecapTab` symbol in `test/screens/admin/admin_reports_payroll_matrix_test.dart` and existing mixed-import enum mismatches in older files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 62 now has both plans implemented and focused regression coverage for the notice flow.
- Phase 63 can focus on spreadsheet/PDF parity re-lock without reopening schedule-gap detection or dashboard follow-up semantics.

## Self-Check: PASSED

- Verified `C:\flutter\bin\flutter.bat test test/services/schedule_gap_notice_service_test.dart test/screens/admin/admin_dashboard_schedule_gap_test.dart test/services/admin_policy_recap_dataset_service_test.dart` passes.
- Verified the dashboard notice flow remains non-blocking and reuses the existing scheduler path.

---
*Phase: 62-schedule-gap-notices*
*Completed: 2026-04-01*
