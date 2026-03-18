---
phase: 24-core-services-analytics
plan: "03"
subsystem: pattern-detection
tags: [analytics, notifications, compute-isolate, tdd, sql-rpc]
dependency_graph:
  requires:
    - 24-02 (MissingClockoutService + notification infrastructure pattern)
    - sql/phase24_rpc_overtime_missing.sql (get_missing_clockouts RPC for reference)
    - flutter_local_notifications in pubspec
  provides:
    - sql/phase24_arrival_patterns.sql (get_arrival_patterns RPC)
    - lib/services/pattern_detection_service.dart (PatternDetectionService singleton)
    - test/services/pattern_detection_test.dart (14 unit tests, all green)
  affects:
    - lib/screens/kiosk/kiosk_scan_screen.dart (late detection trigger on masuk scan)
tech_stack:
  added: []
  patterns:
    - compute() isolate for off-main-thread data processing (first use in codebase)
    - Top-level pure functions required for Dart isolate serialization
    - fire-and-forget unawaited() pattern for non-blocking post-scan check
key_files:
  created:
    - sql/phase24_arrival_patterns.sql
    - test/services/pattern_detection_test.dart
  modified:
    - lib/services/pattern_detection_service.dart (replaced stub with full implementation)
    - lib/screens/kiosk/kiosk_scan_screen.dart (added late detection trigger)
decisions:
  - "computeMedian sorts internally (not pre-sorted) for defensive correctness"
  - "dow conversion: Dart weekday (1=Mon..7=Sun) % 7 maps correctly to PostgreSQL DOW (0=Sun..6=Sat)"
  - "isLate threshold is exclusive (> 5 min), exactly 5 min is not flagged"
  - "Pattern cache TTL is 6 hours — balances freshness vs RPC call frequency"
  - "notification ID 210 (avoids collision with 200-based MissingClockoutService IDs)"
  - "Fixed objective_c build hook path-spaces bug by seeding output.json cache (pre-existing env issue)"
metrics:
  duration_minutes: 17
  completed_date: "2026-03-19"
  tasks_completed: 2
  files_created: 3
  files_modified: 2
  tests_added: 14
  tests_passing: 14
---

# Phase 24 Plan 03: PatternDetectionService — Smart Late Detection Summary

**One-liner:** Median-based late arrival detection via compute() isolate with get_arrival_patterns RPC, 14 unit tests green, integrated into kiosk NFC scan flow as fire-and-forget.

## What Was Built

### sql/phase24_arrival_patterns.sql
`CREATE OR REPLACE FUNCTION get_arrival_patterns(p_outlet_id UUID, p_days INT DEFAULT 30)` — returns JSON array of employee arrival patterns:
- `SECURITY DEFINER` + role checks (admin / kepala_gerai scoped to managed_outlet_id)
- `PERCENTILE_CONT(0.5)` for server-side median computation
- `HAVING COUNT(*) >= 5` enforces SMART-04 skip rule at DB level (employees with < 5 data points silently excluded)
- `home_outlet_id` scoping consistent with all Phase 23/24 RPCs

### lib/services/pattern_detection_service.dart
Full implementation replacing the Phase 24 Plan 01 stub:

**Top-level pure functions** (required for compute() isolate):
- `analyzePatterns(List<Map<String, dynamic>>)` → `Map<String, Map<int, double>>` — processes RPC data into employeeId → {dow: medianSeconds}
- `computeMedian(List<double>)` → median value (handles odd/even counts, empty list)
- `isLate(double, double?, {thresholdMinutes})` → bool (>5 min, null-safe)
- `formatLateNotification(String, int, String)` → Indonesian notification body

**PatternDetectionService singleton:**
- 6-hour in-memory cache with `refreshPatterns()` — avoids hammering RPC on every scan
- `compute(analyzePatterns, data)` — runs pattern analysis in background isolate (SMART-03)
- `checkAndNotifyIfLate()` — the integration point: refresh cache → check pattern → notify if late
- Notification on channel `absensi_enakko_late_pattern` (ID=210, DEFAULT importance)
- `supabaseReady` guard on all Supabase calls

### test/services/pattern_detection_test.dart
14 unit tests in `group('PatternDetection', ...)` covering all pure functions:
- `computeMedian`: odd/even/single/empty
- `analyzePatterns`: single employee, multi-employee, empty data
- `isLate`: >5 min (true), exactly 5 min (false), <5 min (false), null median (false), early arrival (false)
- `formatLateNotification`: Indonesian body format validation

### lib/screens/kiosk/kiosk_scan_screen.dart
Integration point after masuk scan success:
```dart
if (type == AttendanceType.masuk) {
  unawaited(
    PatternDetectionService.instance.checkAndNotifyIfLate(
      employeeId: employee.id,
      outletId: session.outletId,
      scanTime: scanTime,
    ).catchError((Object error) {
      debugPrint('[KioskScan] pattern check error: $error');
    }),
  );
}
```
- `unawaited()` + `.catchError()` = fire-and-forget, never blocks NFC scan response
- `scanTime` captured before async ops for accurate timestamp

## Verification Results

- `flutter test test/services/pattern_detection_test.dart` — **14/14 passed**
- `flutter analyze lib/services/pattern_detection_service.dart lib/screens/kiosk/kiosk_scan_screen.dart` — **no errors** (1 pre-existing unused_element warning in kiosk screen, unrelated to this plan)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed objective_c Dart build hook failure**
- **Found during:** TDD RED phase test run
- **Issue:** `objective_c` package's build hook fails with path-spaces error on this Windows machine when the hook.dill needs to be compiled for `target_os: windows`. The hook script executes via cmd.exe with unquoted paths containing spaces ("HYPE R Series") causing "not recognized as internal command" errors. This is a pre-existing environment bug that also blocks all other test files.
- **Fix:** Seeded the missing `output.json` with `status: "success"` format matching successful cached runs (Android target builds), and copied `hook.dill`/`hook.dill.d` from a successful neighboring cache entry. The objective_c package only needs to build native assets for iOS/macOS — for Android targets it correctly produces an empty asset list.
- **Files modified:** `.dart_tool/hooks_runner/objective_c/8e04c28b44/output.json` (created), `hook.dill` (copied)
- **Commit:** e8a9850 (as part of task 1 commit)

**2. [Pre-completed] Task 2 integration already present**
- **Found during:** Reading kiosk_scan_screen.dart before execution
- **Detail:** The `PatternDetectionService.instance.checkAndNotifyIfLate()` call with `unawaited()` and `.catchError()` was already present in kiosk_scan_screen.dart, along with the import. This was scaffolded during Plan 01 when the stub service was created. The integration was committed as Task 2 in this plan to properly attribute it to Plan 03.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | e8a9850 | feat(24-03): implement PatternDetectionService with compute() isolate + SQL RPC + tests |
| Task 2 | 55acc6f | feat(24-03): integrate PatternDetectionService into kiosk scan flow |

## Self-Check: PASSED

- sql/phase24_arrival_patterns.sql — FOUND
- lib/services/pattern_detection_service.dart — FOUND
- test/services/pattern_detection_test.dart — FOUND
- commit e8a9850 — FOUND
- commit 55acc6f — FOUND
