---
phase: 24-core-services-analytics
verified: 2026-03-19T00:00:00Z
status: passed
score: 8/8 must-haves verified
re_verification: false
---

# Phase 24: Core Services Analytics Verification Report

**Phase Goal:** Admin/Kepala Gerai can see attendance rate metrics, overtime flags, and receive missing clock-out notifications — all powered by testable service layer
**Verified:** 2026-03-19
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Admin can see attendance rate card on dashboard with daily/weekly/monthly percentage and concrete counts | VERIFIED | `AttendanceRateCard` inserted in `admin_dashboard_screen.dart` at line 466 between hero header and stat grid; `AnalyticsService.instance.getAttendanceRates()` called in `_loadData()`; RatePeriod enum with daily/weekly/monthly triggers separate date ranges |
| 2 | Admin can toggle between Hari/Minggu/Bulan period on rate card and see updated data | VERIFIED | `ChoiceChip` widgets present for all three periods (lines 189-193); `_onPeriodChanged` calls `_loadData()` on every toggle; each period maps to a distinct date range |
| 3 | Admin can see overtime alert chips when employees exceed 8-hour threshold | VERIFIED | `OvertimeAlertRow` inserted conditionally in dashboard (line 473); `_loadOvertimeFlags()` calls `AnalyticsService.instance.getOvertimeFlags()`; chips visible only when `_overtimeFlags.isNotEmpty` |
| 4 | Rate card shows green accent when rate >= 80%, red when below | VERIFIED | `lib/widgets/attendance_rate_card.dart` line 113: `return rate >= 80 ? AppColors.success : AppColors.danger;` — accent stripe and rate text both color-coded |
| 5 | Admin receives batched notification per outlet when employees have not scanned pulang after 10 hours | VERIFIED | `MissingClockoutService._checkAndNotify()` calls `get_missing_clockouts` RPC with `p_threshold_hours=10`; single notification per outlet with body "N karyawan belum scan pulang di {outlet_name}" |
| 6 | Missing clock-out check runs every 30 minutes via timer in foreground service | VERIFIED | `Timer.periodic(checkInterval, ...)` with `checkInterval = Duration(minutes: 30)` in `missing_clockout_service.dart` line 64+91; `KioskBackgroundService.start()` calls `MissingClockoutService.instance.startPeriodicCheck()` at line 171 |
| 7 | System computes median arrival time per employee per day-of-week from last 30 days | VERIFIED | `get_arrival_patterns` SQL RPC uses `PERCENTILE_CONT(0.5)` grouped by employee and `EXTRACT(DOW FROM scanned_at)` over `p_days=30`; `PatternDetectionService.refreshPatterns()` caches results in `_patterns` map |
| 8 | Admin receives notification when employee is late >5 minutes from their usual pattern | VERIFIED | `isLate()` function checks `diffMinutes > thresholdMinutes` (exclusive >5); `PatternDetectionService.checkAndNotifyIfLate()` fires local notification on channel `absensi_enakko_late_pattern` when condition met |

**Score:** 8/8 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `sql/phase24_rpc_overtime_missing.sql` | `get_overtime_flags` and `get_missing_clockouts` RPC functions | VERIFIED | 147 lines; both `CREATE OR REPLACE FUNCTION` present; `SECURITY DEFINER`; `home_outlet_id` scoping; `GRANT EXECUTE TO authenticated` |
| `lib/services/analytics_service.dart` | AnalyticsService singleton calling Supabase RPCs | VERIFIED | 174 lines; `class AnalyticsService` with private constructor + `static final instance`; 3 RPC methods (`get_attendance_rates`, `get_overtime_flags`, `get_missing_clockouts`); `supabaseReady` guard on all methods |
| `lib/widgets/attendance_rate_card.dart` | Attendance rate card widget | VERIFIED | 315 lines; `class AttendanceRateCard extends StatefulWidget`; `ChoiceChip` period toggle; color-coded accent stripe; loading/empty/error states all present |
| `lib/widgets/overtime_alert_row.dart` | Overtime alert horizontal scroll row | VERIFIED | 70 lines; `class OvertimeAlertRow`; `SizedBox.shrink()` when empty; `ClampingScrollPhysics`; `AppColors.warningLight` chips |
| `test/services/analytics_service_test.dart` | Unit tests for analytics service | VERIFIED | 166 lines; `group('AnalyticsService', ...)` with 4 nested groups covering `AttendanceRateData.fromJson`, `OvertimeFlag.fromJson`, `MissingClockout.fromJson`, singleton guard |
| `lib/services/missing_clockout_service.dart` | Periodic missing clock-out checker with batched notifications | VERIFIED | 177 lines; `class MissingClockoutService`; `Timer.periodic`; `Duration(minutes: 30)`; `absensi_enakko_missing_clockout` channel; `formatNotificationBody` and `shouldNotify` pure static helpers |
| `test/services/missing_clockout_service_test.dart` | Unit tests for notification batching logic | VERIFIED | 86 lines; `group('MissingClockoutService', ...)` with 3 nested groups covering `formatNotificationBody`, `shouldNotify`, `groupByOutlet` |
| `sql/phase24_arrival_patterns.sql` | `get_arrival_patterns` RPC function | VERIFIED | 59 lines; `CREATE OR REPLACE FUNCTION get_arrival_patterns`; `SECURITY DEFINER`; `home_outlet_id`; `PERCENTILE_CONT(0.5)`; `HAVING COUNT(*) >= 5` |
| `lib/services/pattern_detection_service.dart` | Pattern detection service with background isolate | VERIFIED | 201 lines; `class PatternDetectionService`; `compute(analyzePatterns, data)`; `absensi_enakko_late_pattern` channel; `supabaseReady` guard; full implementation (not a stub) |
| `test/services/pattern_detection_test.dart` | Unit tests for median calculation and skip rule | VERIFIED | 125 lines; `group('PatternDetection', ...)` with 4 nested groups covering `computeMedian`, `analyzePatterns`, `isLate`, `formatLateNotification` |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/widgets/attendance_rate_card.dart` | `lib/services/analytics_service.dart` | `AnalyticsService.instance.getAttendanceRates()` | WIRED | Found at line 91: `await AnalyticsService.instance.getAttendanceRates(outletId: ..., start: ..., end: ...)` |
| `lib/services/analytics_service.dart` | Supabase RPC | `SupabaseClientFactory.admin.rpc('get_attendance_rates', ...)` | WIRED | Lines 101-103: multi-line rpc call with correct name `'get_attendance_rates'` |
| `lib/screens/admin/admin_dashboard_screen.dart` | `lib/widgets/attendance_rate_card.dart` | `AttendanceRateCard` widget in CustomScrollView | WIRED | Line 466: `AttendanceRateCard(key: _rateCardKey, outletId: _analyticsOutletId ?? '')` inserted between hero header and stat grid |
| `lib/screens/admin/admin_dashboard_screen.dart` | `lib/widgets/overtime_alert_row.dart` | `OvertimeAlertRow` widget conditional on flags | WIRED | Line 473-477: `if (_overtimeFlags.isNotEmpty) ... OvertimeAlertRow(flags: _overtimeFlags)` |
| `lib/services/missing_clockout_service.dart` | Supabase RPC | `SupabaseClientFactory.admin.rpc('get_missing_clockouts', ...)` | WIRED | Lines 117-120: direct RPC call with `p_outlet_id` and `p_threshold_hours: 10` |
| `lib/services/missing_clockout_service.dart` | `flutter_local_notifications` | `FlutterLocalNotificationsPlugin.show()` | WIRED | Notification fired with `_notifIdBase + i`, `'Karyawan Belum Pulang'` title, batched body |
| `lib/services/kiosk_background_service.dart` | `lib/services/missing_clockout_service.dart` | `Timer.periodic` triggers `MissingClockoutService.check()` | WIRED | Line 13: import; line 171: `startPeriodicCheck()`; line 185: `stopPeriodicCheck()` |
| `lib/services/pattern_detection_service.dart` | Supabase RPC | `SupabaseClientFactory.admin.rpc('get_arrival_patterns', ...)` | WIRED | Lines 118-120: `rpc('get_arrival_patterns', params: {'p_outlet_id': ..., 'p_days': 30})` |
| `lib/services/pattern_detection_service.dart` | `dart:isolate via compute()` | `compute(analyzePatterns, data)` | WIRED | Line 132: `_patterns = await compute(analyzePatterns, data)` — top-level function required for isolate serialization |
| `lib/screens/kiosk/kiosk_scan_screen.dart` | `lib/services/pattern_detection_service.dart` | Fire-and-forget post-scan trigger | WIRED | Lines 188-197: `unawaited(PatternDetectionService.instance.checkAndNotifyIfLate(...).catchError(...))` after masuk scan success; `await` confirmed absent (non-blocking) |
| `lib/services/pattern_detection_service.dart` | `flutter_local_notifications` | Late pattern notification on `absensi_enakko_late_pattern` | WIRED | `_channelId = 'absensi_enakko_late_pattern'`; notification fired in `checkAndNotifyIfLate()` when `isLate()` returns true |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| ANLYT-01 | 24-01 | Admin/Kepala Gerai can see attendance rate card with daily/weekly/monthly hadir percentage and concrete counts | SATISFIED | `AttendanceRateCard` on `AdminDashboardScreen`; calls `get_attendance_rates` RPC; ChoiceChip period toggle confirmed |
| ANLYT-02 | 24-01 | Admin/Kepala Gerai can see overtime tracking — hours worked vs threshold, flagged when exceeding | SATISFIED | `OvertimeAlertRow` on dashboard; `get_overtime_flags` RPC with `p_threshold_hours` param; `AnalyticsService.getOvertimeFlags()` returns `List<OvertimeFlag>` |
| ANLYT-03 | 24-02 | Admin/Kepala Gerai receives notification when employee has not scanned pulang after configurable threshold (default 10 hours) | SATISFIED | `MissingClockoutService._checkAndNotify()` fires notification when `get_missing_clockouts` returns results; `p_threshold_hours=10` default |
| ANLYT-04 | 24-02 | Missing clock-out notifications are batched per outlet ("N karyawan belum pulang di Outlet A") | SATISFIED | `formatNotificationBody(count, outletName)` returns `"$count karyawan belum scan pulang di $outletName"`; one notification per outlet index (`_notifIdBase + i`) |
| SMART-01 | 24-03 | System analyzes last 30 days of masuk timestamps per employee and computes median arrival time per day-of-week | SATISFIED | `get_arrival_patterns` SQL RPC uses `PERCENTILE_CONT(0.5)` grouped by `EXTRACT(DOW FROM scanned_at)` over `p_days=30`; client-side `analyzePatterns()` builds `Map<employeeId, Map<dow, medianSeconds>>` |
| SMART-02 | 24-03 | Admin/Kepala Gerai receives notification when employee is late >5 minutes from their usual pattern time | SATISFIED | `isLate()` with `diffMinutes > thresholdMinutes` (default 5); notification fired with `formatLateNotification()` body on `absensi_enakko_late_pattern` channel |
| SMART-03 | 24-03 | Pattern detection runs in background isolate and caches results — never blocks NFC scan handler | SATISFIED | `compute(analyzePatterns, data)` at line 132; `unawaited()` call in `kiosk_scan_screen.dart`; no `await PatternDetectionService` found in scan screen |
| SMART-04 | 24-03 | Employees with fewer than 5 data points for a day-of-week are skipped (insufficient data) | SATISFIED | `HAVING COUNT(*) >= 5` in `get_arrival_patterns` SQL enforces skip rule at database level; employees below threshold are never returned to the client |

All 8 requirement IDs satisfied. No orphaned requirements detected.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/services/analytics_service.dart` | 109, 139, 165 | `return null` / `return []` | Info | Intentional — these are error-handling returns inside try/catch blocks, not stubs. Each is guarded by `if (result == null)` after a legitimate RPC call. No impact on goal. |

No blockers or warnings found. All `return null` / `return []` occurrences are legitimate error-path returns inside try/catch blocks with prior RPC calls — not stubs.

---

## Human Verification Required

The following behaviors are correct in code but require a real device or Supabase instance to confirm end-to-end:

### 1. Attendance Rate Card Data Accuracy

**Test:** Open AdminDashboardScreen with a live Supabase connection and employees with scan records. Toggle Hari/Minggu/Bulan.
**Expected:** Rate percentage and "Hadir X/Y hari" counts update correctly for each period. Green accent when >=80%, red when below.
**Why human:** Requires live RPC `get_attendance_rates` deployed to Supabase and real attendance_logs data.

### 2. Missing Clock-Out Notification Firing

**Test:** Start a kiosk session. Have an employee scan masuk. Wait 10+ hours (or modify threshold for testing). Confirm notification appears.
**Expected:** Single notification "N karyawan belum scan pulang di [outlet]" appears in device notification tray.
**Why human:** Requires real device with `POST_NOTIFICATIONS` permission, foreground service running, and Supabase RPC `get_missing_clockouts` deployed.

### 3. Late Pattern Notification After Masuk Scan

**Test:** Employee with 5+ historical masuk scans on today's day-of-week performs a masuk scan more than 5 minutes later than their median.
**Expected:** Notification "Budi tiba N menit lebih lambat dari biasanya di Senin" appears within seconds.
**Why human:** Requires live data with 5+ historical data points per day, and `get_arrival_patterns` RPC deployed to Supabase.

### 4. NFC Scan Performance Under Pattern Detection

**Test:** Perform rapid back-to-back NFC masuk scans and confirm scan response stays under 2 seconds.
**Expected:** Success screen appears immediately; pattern detection notification may arrive a few seconds later but does not delay scan UI.
**Why human:** Timing-sensitive behavior; requires physical NFC hardware.

---

## Commit Verification

All commits documented in SUMMARY files were verified present in git log:

| Commit | Description | Verified |
|--------|-------------|---------|
| `1c33d79` | TDD RED: analytics_service_test.dart | Present |
| `30ae5ad` | AnalyticsService + SQL RPC functions | Present |
| `36ed31f` | MissingClockoutService with batched notifications | Present |
| `dfa9e72` | Integrate MissingClockoutService timer into KioskBackgroundService | Present |
| `e8a9850` | PatternDetectionService with compute() isolate + SQL RPC + tests | Present |
| `55acc6f` | Integrate PatternDetectionService into kiosk scan flow | Present |
| `4105ab8` | docs: analytics service layer plan summary | Present |

---

## Summary

Phase 24 fully achieves its goal. All 8 required observable truths are verified with direct code evidence:

- The **AnalyticsService** singleton provides a clean, testable service layer with 3 RPC methods, all guarded by `supabaseReady` and returning null/empty on failure — no crashes possible.
- The **AttendanceRateCard** widget is substantive (315 lines), wired into the dashboard with a working period toggle and color-coded rate display.
- The **OvertimeAlertRow** is properly hidden when empty and shows chips with correct styling.
- The **MissingClockoutService** runs a 30-minute timer in the foreground service and fires correctly batched per-outlet notifications.
- The **PatternDetectionService** is a full implementation (not a stub), uses `compute()` for off-main-thread analysis, and is integrated as fire-and-forget in the kiosk scan screen — NFC scan handling is never blocked.
- All SQL RPCs use `SECURITY DEFINER` with proper `home_outlet_id` outlet scoping and kepala_gerai role checks.
- 34 total unit tests were added across 3 test files (14 + 6 + 14), all covering pure functions and data classes without Supabase mocking.
- All 8 requirement IDs (ANLYT-01 through ANLYT-04, SMART-01 through SMART-04) are satisfied and cross-referenced against REQUIREMENTS.md — all marked Complete.

---

_Verified: 2026-03-19_
_Verifier: Claude (gsd-verifier)_
