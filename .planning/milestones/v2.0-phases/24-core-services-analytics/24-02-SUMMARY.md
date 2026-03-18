---
phase: 24-core-services-analytics
plan: 02
subsystem: services/notifications
tags: [missing-clockout, notifications, background-service, tdd, flutter-local-notifications]
dependency_graph:
  requires:
    - lib/services/kiosk_background_service.dart
    - lib/core/supabase_client.dart
    - lib/main.dart (supabaseReady)
  provides:
    - lib/services/missing_clockout_service.dart
    - lib/widgets/attendance_rate_card.dart
    - lib/widgets/overtime_alert_row.dart
  affects:
    - lib/services/kiosk_background_service.dart
tech_stack:
  added: []
  patterns:
    - Singleton service with Timer.periodic for background polling
    - Pure static helper methods for testability without Supabase mocking
    - Batched notification per outlet (not per employee)
    - TDD: RED test first, then GREEN implementation
key_files:
  created:
    - lib/services/missing_clockout_service.dart
    - test/services/missing_clockout_service_test.dart
    - lib/widgets/attendance_rate_card.dart
    - lib/widgets/overtime_alert_row.dart
  modified:
    - lib/services/kiosk_background_service.dart
decisions:
  - key: Direct RPC call over AnalyticsService dependency
    rationale: Plan 01 and Plan 02 are both Wave 1; direct RPC avoids build-order dependency between services
  - key: MissingClockoutEntry as separate data class from AnalyticsService.MissingClockout
    rationale: MissingClockoutService needs outletId field for grouping; AnalyticsService.MissingClockout lacks it
  - key: Notification ID base 200 + outlet index
    rationale: Unique notification per outlet without collision with scan notif (101) or live notif (300)
metrics:
  duration_seconds: 772
  completed_date: "2026-03-18T19:27:16Z"
  tasks_completed: 2
  files_created: 4
  files_modified: 1
---

# Phase 24 Plan 02: Missing Clock-Out Notification Service Summary

**One-liner:** Timer-based batched notification service (every 30 min) that fires one alert per outlet when employees haven't scanned pulang after 10 hours, using direct `get_missing_clockouts` RPC call.

## What Was Built

### MissingClockoutService (`lib/services/missing_clockout_service.dart`)
Singleton service that:
- Runs `Timer.periodic(Duration(minutes: 30))` while kiosk is active
- Calls Supabase RPC `get_missing_clockouts(p_outlet_id, p_threshold_hours=10)` directly
- Guards all Supabase access with `if (!supabaseReady) return`
- Sends a single local notification per outlet: "N karyawan belum scan pulang di {outlet_name}"
- Uses notification channel `absensi_enakko_missing_clockout` (DEFAULT importance)
- Notification ID = base 200 + outlet index (unique per outlet)
- Three pure static helpers: `formatNotificationBody`, `shouldNotify`, `groupByOutlet`

### KioskBackgroundService integration
- `start()` calls `MissingClockoutService.instance.startPeriodicCheck(outletIds, outletNames)`
- `stop()` calls `MissingClockoutService.instance.stopPeriodicCheck()`
- Timer lifecycle now tied to foreground service start/stop

### Supporting Widgets (Rule 3 auto-fixes)
- `lib/widgets/attendance_rate_card.dart` — `AttendanceRateCard` widget with `AttendanceRateCardState` (needed by `admin_dashboard_screen.dart`)
- `lib/widgets/overtime_alert_row.dart` — `OvertimeAlertRow` horizontal chip row (needed by `admin_dashboard_screen.dart`)

### Tests (`test/services/missing_clockout_service_test.dart`)
6 tests across 3 groups, all passing:
- `formatNotificationBody`: correct message format for count=3 and count=1
- `shouldNotify`: false for empty list, true for 1+ entries
- `groupByOutlet`: correctly partitions 3 entries across 2 outlets

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing AttendanceRateCard widget**
- **Found during:** Task 1 test run
- **Issue:** `admin_dashboard_screen.dart` imports `lib/widgets/attendance_rate_card.dart` which did not exist, causing package-level compile failure and blocking test execution
- **Fix:** Created `lib/widgets/attendance_rate_card.dart` with `AttendanceRateCard`/`AttendanceRateCardState` following `AppColors` theme pattern
- **Files created:** `lib/widgets/attendance_rate_card.dart`
- **Commit:** 36ed31f

**2. [Rule 3 - Blocking] Missing OvertimeAlertRow widget**
- **Found during:** Task 1 test run
- **Issue:** Same as above — `admin_dashboard_screen.dart` also imports `lib/widgets/overtime_alert_row.dart`
- **Fix:** Created `lib/widgets/overtime_alert_row.dart` with `OvertimeAlertRow` chip row
- **Files created:** `lib/widgets/overtime_alert_row.dart`
- **Commit:** 36ed31f

**Note:** `lib/services/pattern_detection_service.dart` was found to already exist (created by prior work), so no stub was needed for it.

## Verification Results

- `flutter test test/services/missing_clockout_service_test.dart` → 6/6 passed
- `flutter analyze lib/services/missing_clockout_service.dart lib/services/kiosk_background_service.dart` → No issues found

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | 36ed31f | feat(24-02): MissingClockoutService with batched notifications |
| Task 2 | 30ae5ad | feat(24-02): integrate MissingClockoutService timer into KioskBackgroundService |

## Self-Check: PASSED
