---
phase: 25-dashboard-ui-visualization
plan: 01
subsystem: ui
tags: [fl_chart, dashboard, charts, donut, bar-chart, streak, leaderboard]

requires:
  - phase: 24-core-services-analytics
    provides: AnalyticsService RPCs (getAttendanceRates, getOvertimeFlags), OvertimeAlertRow widget
provides:
  - ChartDashboardScreen with 6 sections (rate summary, donut, weekly trend, overtime, streak leaderboard, outlet comparison)
  - StreakService singleton (getLeaderboard, updateStreak)
  - GoRoute /admin/chart-dashboard
  - Navigation from AdminDashboardScreen via "Lihat Dashboard" button
affects: [25-02-kiosk-streak, admin-dashboard]

tech-stack:
  added: [fl_chart ^0.69.0]
  patterns: [AutomaticKeepAliveClientMixin for long-lived dashboard, Future.wait parallel section loading]

key-files:
  created:
    - lib/services/streak_service.dart
    - lib/screens/admin/chart_dashboard_screen.dart
  modified:
    - pubspec.yaml
    - lib/app.dart
    - lib/screens/admin/admin_dashboard_screen.dart
    - lib/widgets/attendance_rate_card.dart

key-decisions:
  - "fl_chart PieChart with centerSpaceRadius 60 for donut, BarChart for trend and comparison"
  - "Outlet comparison section gated by appState.isAdmin (kepala_gerai cannot see cross-outlet data)"
  - "Replaced AttendanceRateCard placeholder snackbar with actual chart-dashboard navigation"

patterns-established:
  - "AutomaticKeepAliveClientMixin + super.build(context) for kiosk memory safety on dashboard"
  - "Per-section independent error handling with parallel Future.wait loading"

requirements-completed: [DASH-01, DASH-02, DASH-03, DASH-04, GAME-04]

duration: 8min
completed: 2026-03-19
---

# Phase 25 Plan 01: Chart Dashboard Summary

**fl_chart dashboard with donut attendance rate, weekly trend bars, overtime alerts, top-5 streak leaderboard, and admin-only outlet comparison**

## What Was Built

### Task 1: fl_chart + StreakService
- Added `fl_chart: ^0.69.0` dependency
- Created `StreakService` singleton matching AnalyticsService pattern
- `getLeaderboard()`: queries employee_streaks joined with employees, filtered by home_outlet_id
- `updateStreak()`: calls update_employee_streak RPC
- Both methods guard on `supabaseReady`, non-throwing

### Task 2: ChartDashboardScreen + Route
- 6-section scrollable dashboard:
  1. Attendance rate summary card
  2. Donut chart (PieChart) with hadir/tidak hadir legend
  3. Weekly trend bar chart (BarChart) with day labels
  4. Overtime alerts row (reuses OvertimeAlertRow widget)
  5. Top 5 streak leaderboard with ranked rows and fire icons
  6. Outlet comparison grouped bar chart (admin only)
- AutomaticKeepAliveClientMixin for memory safety
- Pull-to-refresh via RefreshIndicator
- GoRoute at `/admin/chart-dashboard` with outletId query param

### Task 3: Admin Navigation
- "Lihat Dashboard" button added to AdminDashboardScreen
- AttendanceRateCard onTap now navigates to chart dashboard (replaced placeholder snackbar)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Icons.pie_chart_outlined typo**
- **Found during:** Task 2
- **Issue:** `Icons.pie_chart_outlined` does not exist in Flutter Material icons
- **Fix:** Changed to `Icons.pie_chart_outline`
- **Files modified:** lib/screens/admin/chart_dashboard_screen.dart

## Verification

- `flutter analyze` on all 4 files: 0 errors
- No `.withOpacity()` usage in chart_dashboard_screen.dart
- fl_chart resolves in pubspec.yaml
- Route registered in app.dart
- AutomaticKeepAliveClientMixin confirmed
- "Lihat Dashboard" button present, placeholder snackbar removed

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 2e5b90d | fl_chart dependency + StreakService singleton |
| 2 | 5268f44 | ChartDashboardScreen with 6 sections + GoRouter route |
| 3 | eceaba1 | Lihat Dashboard button + placeholder snackbar replaced |
