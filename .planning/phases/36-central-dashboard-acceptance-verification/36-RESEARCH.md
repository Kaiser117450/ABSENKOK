# Phase 36: Central Dashboard Acceptance Verification - Research

**Researched:** 2026-03-22
**Domain:** Live central-dashboard acceptance verification for role-aware routing and chain-wide KPI fidelity
**Confidence:** HIGH (grounded in the current codebase, phase 33 implementation artifacts, and the milestone audit gaps)

---

## Summary

Phase 36 is the final acceptance-proof phase for the central admin control center. The repository already contains the `CentralDashboardScreen`, role-aware routing in `app.dart`, drilldown into `AdminDashboardScreen`, and the Phase 33 RPC/data-contract layer. The audit failure is not about missing implementation anymore; it is about missing live evidence that the right roles see the right screens and that the displayed KPI values match live production data.

The correct planning posture is:

1. Treat Phase 34 rollout evidence and Phase 35 outlet-level proof as prerequisites
2. Verify full-admin landing, outlet drilldown, and kepala-gerai scoping with real accounts
3. Compare displayed central-dashboard numbers against direct Supabase queries, not only the same RPC output the UI already uses
4. Update validation and requirement artifacts only after the proof is concrete

**Primary recommendation:** Split execution into two plans: first capture routing and role-gating proof, then verify live KPI fidelity and synchronize the milestone artifacts.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ADMIN-01 | Admin Central Dashboard aggregates and displays health/status for ALL outlets in one view. | `CentralDashboardScreen` and outlet drilldown routing already exist; the missing piece is live proof that full admins see the central view while `kepala_gerai` stays outlet-scoped. |
| ADMIN-02 | Admin Central Dashboard displays aggregate firm-wide daily attendance rate. | `get_central_dashboard_summary` and `get_outlet_control_center` already compute the rollups; the missing piece is live comparison between displayed values and direct Supabase data. |

---

## Current State Analysis

### 1. Phase 36 depends on earlier evidence, not new schema or UI work

Phase 36 depends on:

- Phase 34 proving the SQL rollout happened
- Phase 35 proving the underlying outlet/device data path is live

Without those prerequisites, central-dashboard verification becomes ambiguous because the central rollups consume the same `kiosk_devices` data model and the same production rollout chain.

### 2. The role-aware routing path already exists in app code

The core route logic is already present:

- `/admin/dashboard` returns `CentralDashboardScreen` for `admin`
- `/admin/dashboard` returns `AdminDashboardScreen` for `kepala_gerai`
- `/admin/outlet-dashboard?outletId=...` drills into `AdminDashboardScreen(initialOutletId: ...)`
- `AdminDashboardScreen` gives `managedOutletId` precedence for `kepala_gerai`

This means Phase 36 should verify live routing behavior rather than redesign navigation.

### 3. The data path is also already implemented and tested locally

The implementation already exists:

- `AnalyticsService.getCentralDashboardSummary()`
- `AnalyticsService.getOutletControlCenter()`
- `CentralDashboardScreen` KPI cards and outlet list
- `test/services/analytics_service_test.dart`
- `test/screens/admin/central_dashboard_screen_test.dart`

The missing proof is that the production dashboard values match live Supabase data and that the role-aware flow works end-to-end outside widget tests.

### 4. The audit gap is explicit and narrow

The milestone audit calls out one remaining central flow:

- full admin central dashboard and outlet drilldown with live attendance data

That means the plan should focus on:

- full admin landing proof
- outlet drilldown proof
- kepala-gerai outlet-scoped proof
- live KPI comparison proof

It should not re-open feature design work that Phase 33 already completed.

### 5. Phase 33 validation debt must be closed directly

`33-VALIDATION.md` still reads as a draft with manual production checks pending. If Phase 36 finishes only in a new phase-local note and never updates Phase 33 validation, the audit will remain harder to interpret than it should be.

---

## Project Constraints That Must Shape the Plan

From `STATE.md`, the audit, and the surrounding phases:

- production data is live and should be treated as the source of truth
- earlier rollout and outlet-level proof should be reviewed before central checks begin
- Phase 36 should avoid speculative app-code changes unless live proof exposes a defect
- requirements must not be marked complete from implementation-only evidence

Operationally, this means the plan should:

- front-load prerequisite review of phases 34 and 35
- compare UI values against direct Supabase queries rather than only calling the same RPCs
- record role, route, outlet, and timestamp evidence in a dedicated validation artifact
- move Phase 33 validation out of draft only when the proof is complete

---

## Recommended Execution Strategy

### Step 1: Lock the prerequisite evidence before central checks

Execution should review both:

- `.planning/phases/34-v6-supabase-rollout-evidence/34-VALIDATION.md`
- `.planning/phases/35-multi-device-acceptance-verification/35-VALIDATION.md`

If rollout or outlet-level proof is still unclear, Phase 36 should stop and route back instead of producing uncertain central-dashboard evidence.

### Step 2: Build one operator-facing acceptance packet

Before any manual testing, Phase 36 should consolidate:

- prerequisite review
- full-admin landing and drilldown steps
- kepala-gerai outlet-scoped steps
- direct KPI comparison queries
- evidence placeholders for outlet names, roles, KPI snapshots, and timestamps

This keeps the operator from improvising the central checks.

### Step 3: Verify full-admin landing and drilldown first

ADMIN-01 is not only about a route existing in code. The proof must show that:

1. a full admin lands on `CentralDashboardScreen`
2. central KPI cards and outlet rollup cards appear
3. tapping one outlet opens the outlet dashboard with the correct outlet preselected

If the drilldown opens the wrong outlet or loses the outlet context, ADMIN-01 is not satisfied.

### Step 4: Verify kepala-gerai scoping independently

The role proof is incomplete if only the full-admin path is tested. Phase 36 should separately prove that `kepala_gerai`:

- does not see the central rollup screen
- remains on outlet-scoped dashboard behavior
- stays limited to the managed outlet

### Step 5: Compare displayed KPI values against direct Supabase queries

The clean acceptance proof is to compare what the UI shows against direct SQL queries over:

- `outlets`
- `kiosk_devices`
- `employees`
- `attendance_logs`

Do not rely only on `get_central_dashboard_summary()` or `get_outlet_control_center()` as the proof, because the UI already depends on those RPCs. Use direct aggregation queries to validate the deployed data path independently.

### Step 6: Synchronize planning artifacts only after proof exists

After all role and KPI evidence succeeds, execution should update:

- `33-VALIDATION.md`
- `36-VALIDATION.md`
- `REQUIREMENTS.md`
- `STATE.md`

It should not rewrite the audit file directly. A fresh audit should derive the new state from the updated evidence.

---

## Verification Queries to Reuse During Execution

### Prerequisite review

First review:

- `.planning/phases/34-v6-supabase-rollout-evidence/34-VALIDATION.md`
- `.planning/phases/35-multi-device-acceptance-verification/35-VALIDATION.md`

If a minimal live function check is needed before continuing:

```sql
SELECT proname
FROM pg_proc
WHERE proname IN ('get_central_dashboard_summary', 'get_outlet_control_center')
ORDER BY proname;
```

### Direct chain-wide KPI summary query

```sql
WITH totals AS (
  SELECT COUNT(*) AS total_employees
  FROM employees
  WHERE is_active = TRUE
    AND archived_at IS NULL
),
present AS (
  SELECT COUNT(*) AS total_present
  FROM (
    SELECT DISTINCT employee_id
    FROM attendance_logs
    WHERE type = 'masuk'
      AND scanned_at::date = CURRENT_DATE
  ) daily_presence
)
SELECT
  (SELECT COUNT(*) FROM outlets WHERE is_active = TRUE) AS total_outlets,
  (SELECT COUNT(*) FROM kiosk_devices
   WHERE is_active = TRUE
     AND last_heartbeat_at >= NOW() - INTERVAL '30 minutes') AS connected_devices,
  (SELECT COUNT(*) FROM kiosk_devices
   WHERE is_active = TRUE
     AND (last_heartbeat_at IS NULL OR last_heartbeat_at < NOW() - INTERVAL '30 minutes')) AS offline_devices,
  (SELECT COUNT(*) FROM kiosk_devices
   WHERE is_active = TRUE
     AND battery_level < 20) AS low_battery_devices,
  (SELECT COUNT(*) FROM kiosk_devices
   WHERE is_active = TRUE
     AND pending_sync_count > 0) AS pending_sync_devices,
  CASE
    WHEN totals.total_employees > 0
      THEN ROUND((present.total_present::NUMERIC / totals.total_employees) * 100, 1)
    ELSE 0
  END AS daily_attendance_rate
FROM totals, present;
```

### Direct outlet rollup comparison query

```sql
WITH device_stats AS (
  SELECT
    outlet_id,
    COUNT(*) FILTER (WHERE is_active = TRUE
                     AND last_heartbeat_at >= NOW() - INTERVAL '30 minutes') AS connected_devices,
    COUNT(*) FILTER (WHERE is_active = TRUE
                     AND (last_heartbeat_at IS NULL OR last_heartbeat_at < NOW() - INTERVAL '30 minutes')) AS offline_devices,
    COUNT(*) FILTER (WHERE is_active = TRUE AND battery_level < 20) AS low_battery_devices,
    COUNT(*) FILTER (WHERE is_active = TRUE AND pending_sync_count > 0) AS pending_sync_devices,
    MAX(last_heartbeat_at) FILTER (WHERE is_active = TRUE) AS last_heartbeat_at
  FROM kiosk_devices
  GROUP BY outlet_id
),
employee_stats AS (
  SELECT
    home_outlet_id AS outlet_id,
    COUNT(*) AS total_employees
  FROM employees
  WHERE is_active = TRUE
    AND archived_at IS NULL
  GROUP BY home_outlet_id
),
attendance_stats AS (
  SELECT
    scan_outlet_id AS outlet_id,
    COUNT(DISTINCT employee_id) AS total_present
  FROM attendance_logs
  WHERE type = 'masuk'
    AND scanned_at::date = CURRENT_DATE
  GROUP BY scan_outlet_id
)
SELECT
  o.id AS outlet_id,
  o.name AS outlet_name,
  COALESCE(ds.connected_devices, 0) AS connected_devices,
  COALESCE(ds.offline_devices, 0) AS offline_devices,
  COALESCE(ds.low_battery_devices, 0) AS low_battery_devices,
  COALESCE(ds.pending_sync_devices, 0) AS pending_sync_devices,
  CASE
    WHEN COALESCE(es.total_employees, 0) > 0
      THEN ROUND((COALESCE(att.total_present, 0)::NUMERIC / es.total_employees) * 100, 1)
    ELSE 0
  END AS daily_attendance_rate,
  ds.last_heartbeat_at
FROM outlets o
LEFT JOIN device_stats ds ON ds.outlet_id = o.id
LEFT JOIN employee_stats es ON es.outlet_id = o.id
LEFT JOIN attendance_stats att ON att.outlet_id = o.id
WHERE o.is_active = TRUE
ORDER BY o.name;
```

### Troubleshooting-only RPC output

Use these only to debug mismatches, not as the primary proof:

```sql
SELECT get_central_dashboard_summary(CURRENT_DATE);
SELECT jsonb_pretty(get_outlet_control_center(CURRENT_DATE)::jsonb);
```

---

## Pitfalls

### Pitfall 1: Treating Phase 35 as optional

The central dashboard reads the same live device data path proven in Phase 35. If that proof is missing, central discrepancies become hard to interpret.

### Pitfall 2: Verifying only the full-admin path

ADMIN-01 is role-aware. The acceptance proof is incomplete if `kepala_gerai` scoping is not checked separately.

### Pitfall 3: Comparing the UI only to the same RPC output it already uses

That confirms consistency with itself, not fidelity to the underlying production data. Direct SQL comparison is the stronger proof.

### Pitfall 4: Ignoring outlet drilldown preselection

The drilldown is part of the user-facing flow. Opening an outlet detail screen without the correct preselected outlet does not satisfy the phase goal cleanly.

### Pitfall 5: Updating ADMIN requirements before Phase 33 validation is closed

If `REQUIREMENTS.md` flips to complete while `33-VALIDATION.md` still reads like a draft, the next audit remains harder to trust.

---

## Validation Architecture

### Dimension 1: Prerequisite integrity

- Phase 34 and Phase 35 evidence is reviewed before central checks begin
- central RPCs are present in production

### Dimension 2: Role-aware routing integrity

- full admin lands on the central screen
- `kepala_gerai` remains outlet-scoped
- route outcomes match role expectations

### Dimension 3: Drilldown integrity

- tapping one outlet opens the outlet dashboard
- the opened dashboard is preselected to the tapped outlet

### Dimension 4: Live data fidelity

- displayed KPI cards match direct summary queries
- displayed outlet rows match direct outlet rollup queries
- attendance-rate comparison tolerates only normal rounding differences

### Dimension 5: Evidence integrity

- validation artifacts record actual roles, routes, outlets, and timestamps
- ADMIN requirements flip to complete only after live proof exists
- stale Phase 33 draft validation status is explicitly closed

### Recommended task split

- Plan 01: prerequisite packet + routing/role proof
- Plan 02: KPI comparison + planning artifact synchronization

This keeps routing verification in wave 1 and only lets requirement/document synchronization happen after the data comparison succeeds.

---

## Sources

### Primary

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/STATE.md`
- `.planning/v6.0-MILESTONE-AUDIT.md`
- `.planning/phases/33-multi-outlet-control-center/33-VALIDATION.md`
- `.planning/phases/33-multi-outlet-control-center/33-02-SUMMARY.md`
- `.planning/phases/34-v6-supabase-rollout-evidence/34-VALIDATION.md`
- `.planning/phases/35-multi-device-acceptance-verification/35-VALIDATION.md`
- `lib/app.dart`
- `lib/screens/admin/central_dashboard_screen.dart`
- `lib/screens/admin/admin_dashboard_screen.dart`
- `lib/screens/admin/admin_shell.dart`
- `lib/services/analytics_service.dart`
- `sql/phase_33_central_dashboard_20260322.sql`
