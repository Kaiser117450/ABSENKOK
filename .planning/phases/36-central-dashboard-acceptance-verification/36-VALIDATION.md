---
phase: 36
slug: central-dashboard-acceptance-verification
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-22
---

# Phase 36 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Existing Flutter tests + PowerShell static checks + live Supabase SQL verification |
| **Config file** | `pubspec.yaml` plus planning artifacts in `.planning/phases/36-central-dashboard-acceptance-verification/` |
| **Quick run command** | `powershell -Command "Select-String -Path 'lib/app.dart','lib/screens/admin/central_dashboard_screen.dart','lib/screens/admin/admin_dashboard_screen.dart','lib/services/analytics_service.dart','sql/phase_33_central_dashboard_20260322.sql' -Pattern 'CentralDashboardScreen','/admin/outlet-dashboard','initialOutletId','get_central_dashboard_summary','get_outlet_control_center' | Measure-Object | Select-Object -ExpandProperty Count"` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test test/services/analytics_service_test.dart test/screens/admin/central_dashboard_screen_test.dart` |
| **Estimated runtime** | ~35 seconds for local checks plus manual live checkpoints |

---

## Sampling Rate

- **After every task commit:** Run the quick static check command
- **After every plan wave:** Run `C:\flutter\bin\flutter.bat test test/services/analytics_service_test.dart test/screens/admin/central_dashboard_screen_test.dart`
- **Before `$gsd-verify-work`:** Full live evidence plus the targeted central-dashboard tests must be green
- **Max feedback latency:** 35 seconds for local checks; each live checkpoint should be recorded immediately after execution

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 36-01-01 | 01 | 1 | ADMIN-01 | static | `powershell -Command "Select-String -Path '.planning/phases/36-central-dashboard-acceptance-verification/36-VALIDATION.md' -Pattern 'Prerequisite Check','Direct chain-wide KPI summary query','Direct outlet rollup comparison query','Evidence Log' | Measure-Object | Select-Object -ExpandProperty Count"` | ✅ | ⬜ pending |
| 36-01-02 | 01 | 1 | ADMIN-01 | manual | Review phases 34 and 35 evidence, then verify full-admin landing plus outlet drilldown in the live app | N/A | ⬜ pending |
| 36-01-03 | 01 | 1 | ADMIN-01 | manual | Verify `kepala_gerai` remains outlet-scoped and does not see the central rollup screen | N/A | ⬜ pending |
| 36-02-01 | 02 | 2 | ADMIN-01, ADMIN-02 | manual | Run the direct summary and outlet-rollup SQL queries, then compare them with the visible central-dashboard values | N/A | ⬜ pending |
| 36-02-02 | 02 | 2 | ADMIN-01, ADMIN-02 | static | `powershell -Command "Select-String -Path '.planning/REQUIREMENTS.md','.planning/STATE.md','.planning/phases/33-multi-outlet-control-center/33-VALIDATION.md','.planning/phases/36-central-dashboard-acceptance-verification/36-VALIDATION.md' -Pattern 'ADMIN-01','ADMIN-02','Approval:','Phase 36' | Measure-Object | Select-Object -ExpandProperty Count"` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all local automation needs for this phase.

No new test scaffolding is required before execution. The only non-local prerequisites are:

- one full-admin account
- one `kepala_gerai` account
- live central-dashboard data in Supabase after phases 34 and 35

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full admin lands on the central dashboard and drills into the right outlet | ADMIN-01 | Requires real auth role, route resolution, and live UI state | 1. Sign in as full admin 2. Open `/admin/dashboard` 3. Confirm central KPI cards appear 4. Tap an outlet card 5. Confirm the outlet dashboard opens with the correct outlet preselected |
| `kepala_gerai` remains outlet-scoped | ADMIN-01 | Requires real role metadata and runtime route behavior | 1. Sign in as `kepala_gerai` 2. Open `/admin/dashboard` 3. Confirm no central rollup UI is shown 4. Confirm the dashboard remains scoped to the managed outlet |
| Displayed KPI cards match live Supabase data | ADMIN-01, ADMIN-02 | Needs live production rows and a direct SQL cross-check | 1. Capture the visible central-dashboard values 2. Run the direct summary query 3. Compare the values field-by-field 4. Record any mismatch instead of marking the requirement complete |
| Displayed outlet rows match live Supabase rollups | ADMIN-01, ADMIN-02 | Needs live outlet/device/attendance data | 1. Capture one or more outlet row values 2. Run the direct outlet rollup query 3. Compare counts, attendance rate, and recent heartbeat values 4. Record the evidence in `36-VALIDATION.md` |

---

## Operator Notes

### Prerequisite Check

- Review `.planning/phases/34-v6-supabase-rollout-evidence/34-VALIDATION.md`
- Review `.planning/phases/35-multi-device-acceptance-verification/35-VALIDATION.md`
- If a minimal live function check is needed before proceeding:

```sql
SELECT proname
FROM pg_proc
WHERE proname IN ('get_central_dashboard_summary', 'get_outlet_control_center')
ORDER BY proname;
```

### Direct Chain-Wide KPI Summary Query

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

### Direct Outlet Rollup Comparison Query

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

### Troubleshooting-Only RPC Output

```sql
SELECT get_central_dashboard_summary(CURRENT_DATE);
SELECT jsonb_pretty(get_outlet_control_center(CURRENT_DATE)::jsonb);
```

---

## Evidence Log

### 36-01-02 Full-Admin Landing and Drilldown

- Full-admin account used: `<fill during execution>`
- Central dashboard visible: `<yes / no>`
- Tapped outlet ID or name: `<fill during execution>`
- Outlet dashboard preselected outlet: `<fill during execution>`
- Result: `<approved / blocked>`
- Notes: `<fill during execution>`

### 36-01-03 Kepala-Gerai Role Gate

- Kepala-gerai account used: `<fill during execution>`
- Managed outlet: `<fill during execution>`
- Central rollup hidden: `<yes / no>`
- Dashboard stayed outlet-scoped: `<yes / no>`
- Result: `<approved / blocked>`
- Notes: `<fill during execution>`

### 36-02-01 Live KPI Comparison

- UI KPI snapshot: `<fill during execution>`
- Summary query snapshot: `<fill during execution>`
- Outlet row comparison snapshot: `<fill during execution>`
- Query timestamp: `<fill during execution>`
- Result: `<approved / blocked>`
- Notes: `<fill during execution>`

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or explicit live checkpoint coverage
- [ ] Sampling continuity: no 3 consecutive tasks without static/test support
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 35s for local checks
- [ ] `nyquist_compliant: true` set in frontmatter after executed proof is recorded

**Approval:** pending
