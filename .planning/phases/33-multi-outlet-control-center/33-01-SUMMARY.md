---
phase: 33-multi-outlet-control-center
plan: "01"
subsystem: analytics-data-layer
tags: [analytics, rpc, sql, tdd, central-dashboard]
dependency_graph:
  requires: [phase-31-kiosk-devices, phase-23-rpc-functions]
  provides: [central-dashboard-data-layer]
  affects: [analytics_service, admin-dashboard-routing]
tech_stack:
  added: []
  patterns: [SECURITY DEFINER RPC, supabaseReady guard, fromJson coercion]
key_files:
  created:
    - sql/phase_33_central_dashboard_20260322.sql
  modified:
    - lib/services/analytics_service.dart
    - test/services/analytics_service_test.dart
decisions:
  - "Admin-only gate in both RPCs uses app_metadata.app_role = 'admin'"
  - "Offline threshold kept at 30 minutes to match Phase 32 KioskDevice.isOnline convention"
  - "Attendance math reuses Phase 23 semantics: distinct employee_id per date with type='masuk'"
  - "get_outlet_control_center uses LATERAL joins for composable per-outlet aggregation"
metrics:
  duration_minutes: 25
  completed_date: "2026-03-22"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 2
---

# Phase 33 Plan 01: Central Dashboard Data Layer Summary

**One-liner:** SECURITY DEFINER RPCs for chain-wide device health + attendance KPIs, with matching Dart model parsers and 8 new unit tests in AnalyticsService.

## What Was Built

### Task 1: AnalyticsService extension (TDD)

Added two data classes and two service methods to `lib/services/analytics_service.dart`:

- `CentralDashboardSummary` — parses 6-field JSON payload from `get_central_dashboard_summary`
- `OutletControlCenterRow` — parses 8-field JSON payload (with nullable `lastHeartbeatAt`) from `get_outlet_control_center`
- `getCentralDashboardSummary({required DateTime date})` — guarded with `supabaseReady`, returns null on failure
- `getOutletControlCenter({required DateTime date})` — guarded with `supabaseReady`, returns empty list on failure

8 new tests added to `test/services/analytics_service_test.dart`:
- Standard JSON parsing for both models
- int-to-double coercion for `dailyAttendanceRate`
- Nullable `lastHeartbeatAt` handling
- `supabaseReady == false` guard behavior for both methods

### Task 2: SQL migration

`sql/phase_33_central_dashboard_20260322.sql` defines two additive SECURITY DEFINER RPCs:

**`get_central_dashboard_summary(p_date DATE DEFAULT CURRENT_DATE) RETURNS JSON`**
- Counts active outlets
- Counts connected/offline/low-battery/pending-sync devices (active only, 30-min threshold)
- Computes firm-wide daily attendance rate using Phase 23 semantics (distinct masuk / active employees)
- Admin-only gate via `app_metadata.app_role`

**`get_outlet_control_center(p_date DATE DEFAULT CURRENT_DATE) RETURNS JSON`**
- Returns JSON array: one row per active outlet
- Per-outlet: connected/offline/low-battery/pending-sync device counts + daily attendance rate + last heartbeat timestamp
- Uses LATERAL joins for composable aggregation
- Excludes archived devices (`is_active = FALSE`)
- Admin-only gate

Both functions use `SET search_path = public`, `REVOKE ALL FROM PUBLIC`, `GRANT EXECUTE TO authenticated`.

## Deviations from Plan

None — plan executed exactly as written.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | d8b6cc1 | feat(33-01): extend AnalyticsService with central dashboard models and methods |
| 2 | 1c0d603 | feat(33-01): add SQL migration for central dashboard RPCs |

## Self-Check: PASSED

- lib/services/analytics_service.dart — FOUND
- sql/phase_33_central_dashboard_20260322.sql — FOUND
- test/services/analytics_service_test.dart — FOUND
- Commit d8b6cc1 — FOUND
- Commit 1c0d603 — FOUND
- All 22 tests passed
