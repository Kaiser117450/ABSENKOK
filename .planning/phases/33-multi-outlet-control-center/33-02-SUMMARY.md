---
phase: 33-multi-outlet-control-center
plan: "02"
subsystem: admin-ui
tags: [central-dashboard, multi-outlet, role-based-routing, widget-tests]
dependency_graph:
  requires: [33-01, 32-02]
  provides: [CentralDashboardScreen, OutletControlCard, role-aware-dashboard-routing]
  affects: [lib/app.dart, lib/screens/admin/admin_dashboard_screen.dart]
tech_stack:
  added: []
  patterns: [injected-loaders-for-testability, role-aware-GoRouter-builder, scrollUntilVisible-in-widget-tests]
key_files:
  created:
    - lib/screens/admin/central_dashboard_screen.dart
    - lib/widgets/outlet_control_card.dart
    - test/screens/admin/central_dashboard_screen_test.dart
  modified:
    - lib/app.dart
    - lib/screens/admin/admin_dashboard_screen.dart
    - lib/screens/admin/admin_shell.dart
decisions:
  - "CentralDashboardScreen uses injected summaryLoader/rowsLoader for widget testability without Supabase"
  - "Drilldown via GoRouter context.push('/admin/outlet-dashboard?outletId=...') — not Navigator"
  - "Lihat Dashboard button disabled when _selectedOutletId is null to prevent empty outletId push"
  - "ProviderScope.containerOf(context).read(appProvider) in GoRouter builder for role check"
  - "scrollUntilVisible used in tests because GridView + ListView exceed default test viewport"
metrics:
  duration: "~25 minutes"
  completed_date: "2026-03-22"
  tasks_completed: 2
  files_changed: 6
---

# Phase 33 Plan 02: Central Admin UI and Role-Aware Routing Summary

**One-liner:** CentralDashboardScreen for full admins with outlet drilldown cards, role-aware GoRouter routing, and AdminDashboardScreen preselection from drilldown.

## What Was Built

### Task 1: CentralDashboardScreen, OutletControlCard, and widget tests

- **`lib/widgets/outlet_control_card.dart`** — Reusable tap target for one outlet rollup row. Shows outlet name, connected/offline/low-battery device counts, daily attendance rate, and a chevron drilldown CTA. Color-coded left accent bar (green = all online, red = any offline).

- **`lib/screens/admin/central_dashboard_screen.dart`** — Admin-only chain-wide control center. Loads `getCentralDashboardSummary` and `getOutletControlCenter` in sequence, displays a 2-column KPI grid and a scrollable list of `OutletControlCard`s. Realtime subscriptions on `attendance_logs`, `employees`, `kiosk_devices`, and `outlets`. Constructor injection (`summaryLoader`, `rowsLoader`, `onOpenOutlet`) enables widget tests without Supabase.

- **`test/screens/admin/central_dashboard_screen_test.dart`** — 6 widget tests: summary heading, KPI card values, outlet card rendering, tap-to-drilldown callback, empty-outlets state, and standalone `OutletControlCard` render. Uses `tester.scrollUntilVisible` because the summary `GridView` pushes outlet cards below the test viewport fold. **All 6 pass.**

### Task 2: Role-aware routing and outlet drilldown

- **`lib/app.dart`** — `/admin/dashboard` builder reads `appProvider` via `ProviderScope.containerOf(context)` and returns `CentralDashboardScreen` for `isAdmin`, `AdminDashboardScreen` for `kepala_gerai`. New `/admin/outlet-dashboard` ShellRoute child builds `AdminDashboardScreen(initialOutletId: queryParam)`.

- **`lib/screens/admin/admin_dashboard_screen.dart`** — Added `initialOutletId` constructor param. On `initState` post-frame callback, kepala_gerai keeps locked `managedOutletId`; full admin with `initialOutletId` pre-selects it. "Lihat Dashboard" button now disabled when `_selectedOutletId` is null instead of pushing an empty string.

- **`lib/screens/admin/admin_shell.dart`** — Added clarifying comment that `/admin/outlet-dashboard` correctly falls through to `return 0` (Dashboard tab).

### Task 3: Checkpoint human-verify

Auto-approved (auto_advance: true). Prerequisites: run `sql/phase_33_central_dashboard_20260322.sql` in Supabase SQL Editor before deploying APK.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `Future.wait` with mixed generic types cast failure**
- **Found during:** Task 1 GREEN phase
- **Issue:** `Future.wait([Future<CentralDashboardSummary?>, Future<List<...>>])` returns `List<Object?>` and the index casts failed at runtime in test
- **Fix:** Sequential `await` with typed locals instead of `Future.wait`
- **Files modified:** `lib/screens/admin/central_dashboard_screen.dart`
- **Commit:** d69ffa6

**2. [Rule 1 - Bug] Widget tests failed: outlet cards below test viewport fold**
- **Found during:** Task 1 test runs
- **Issue:** The `GridView` summary section + headings push outlet cards out of the default 800x600 test viewport
- **Fix:** Added `tester.scrollUntilVisible` in tests for outlet card and empty-state assertions
- **Files modified:** `test/screens/admin/central_dashboard_screen_test.dart`
- **Commit:** d69ffa6

## Self-Check: PASSED

Files exist:
- lib/screens/admin/central_dashboard_screen.dart ✓
- lib/widgets/outlet_control_card.dart ✓
- test/screens/admin/central_dashboard_screen_test.dart ✓

Commits exist:
- d69ffa6 feat(33-02): CentralDashboardScreen, OutletControlCard, and widget tests ✓
- 54c38b0 feat(33-02): role-aware routing and outlet drilldown ✓
