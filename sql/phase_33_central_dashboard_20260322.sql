-- Phase 33: Multi-Outlet Control Center — Central Dashboard RPCs
-- Additive migration. Safe to re-run (CREATE OR REPLACE).
-- Do NOT modify existing tables or destructive data.

-- ── 1. get_central_dashboard_summary ────────────────────────────────────────
-- Returns one JSON payload with firm-wide KPIs for the given date.
-- Admin-only. Counts only active outlets and active kiosk devices.
-- Offline threshold: last_heartbeat_at < NOW() - INTERVAL '30 minutes' (Phase 32 convention).

CREATE OR REPLACE FUNCTION get_central_dashboard_summary(
  p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role                TEXT := auth.jwt() -> 'app_metadata' ->> 'app_role';
  v_total_outlets       INT  := 0;
  v_connected_devices   INT  := 0;
  v_offline_devices     INT  := 0;
  v_low_battery_devices INT  := 0;
  v_pending_sync_devices INT := 0;
  v_total_employees     INT  := 0;
  v_total_present       INT  := 0;
  v_daily_rate          NUMERIC := 0;
BEGIN
  -- Admin-only gate
  IF auth.role() IS NOT NULL THEN
    IF v_role IS DISTINCT FROM 'admin' THEN
      RAISE EXCEPTION 'Not authorized: admin role required';
    END IF;
  END IF;

  -- Active outlet count
  SELECT COUNT(*)
  INTO v_total_outlets
  FROM outlets
  WHERE is_active = TRUE;

  -- Device health counters (active devices only)
  SELECT
    COUNT(*) FILTER (WHERE last_heartbeat_at >= NOW() - INTERVAL '30 minutes'),
    COUNT(*) FILTER (WHERE last_heartbeat_at IS NULL
                       OR  last_heartbeat_at <  NOW() - INTERVAL '30 minutes'),
    COUNT(*) FILTER (WHERE battery_level < 20),
    COUNT(*) FILTER (WHERE pending_sync_count > 0)
  INTO
    v_connected_devices,
    v_offline_devices,
    v_low_battery_devices,
    v_pending_sync_devices
  FROM kiosk_devices
  WHERE is_active = TRUE;

  -- Firm-wide active employee count (all active outlets)
  SELECT COUNT(*)
  INTO v_total_employees
  FROM employees
  WHERE is_active = TRUE
    AND archived_at IS NULL;

  -- Firm-wide distinct daily presence (masuk) for p_date
  SELECT COUNT(*)
  INTO v_total_present
  FROM (
    SELECT DISTINCT employee_id
    FROM attendance_logs
    WHERE type = 'masuk'
      AND scanned_at::date = p_date
  ) daily_presence;

  v_daily_rate :=
    CASE
      WHEN v_total_employees > 0
        THEN ROUND((v_total_present::NUMERIC / v_total_employees) * 100, 1)
      ELSE 0
    END;

  RETURN json_build_object(
    'total_outlets',          v_total_outlets,
    'connected_devices',      v_connected_devices,
    'offline_devices',        v_offline_devices,
    'low_battery_devices',    v_low_battery_devices,
    'pending_sync_devices',   v_pending_sync_devices,
    'daily_attendance_rate',  v_daily_rate
  );
END;
$$;

REVOKE ALL ON FUNCTION get_central_dashboard_summary(DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_central_dashboard_summary(DATE) TO authenticated;

-- ── 2. get_outlet_control_center ─────────────────────────────────────────────
-- Returns one JSON array row per active outlet with device health + attendance rollup.
-- Admin-only. Excludes archived devices (is_active = FALSE).

CREATE OR REPLACE FUNCTION get_outlet_control_center(
  p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT := auth.jwt() -> 'app_metadata' ->> 'app_role';
BEGIN
  -- Admin-only gate
  IF auth.role() IS NOT NULL THEN
    IF v_role IS DISTINCT FROM 'admin' THEN
      RAISE EXCEPTION 'Not authorized: admin role required';
    END IF;
  END IF;

  RETURN (
    SELECT json_agg(row_data ORDER BY o.name)
    FROM outlets o
    LEFT JOIN LATERAL (
      SELECT
        COUNT(*)                          FILTER (WHERE kd.last_heartbeat_at >= NOW() - INTERVAL '30 minutes') AS connected_devices,
        COUNT(*)                          FILTER (WHERE kd.last_heartbeat_at IS NULL
                                                    OR  kd.last_heartbeat_at <  NOW() - INTERVAL '30 minutes') AS offline_devices,
        COUNT(*)                          FILTER (WHERE kd.battery_level < 20)                                  AS low_battery_devices,
        COUNT(*)                          FILTER (WHERE kd.pending_sync_count > 0)                              AS pending_sync_devices,
        MAX(kd.last_heartbeat_at)                                                                               AS last_heartbeat_at
      FROM kiosk_devices kd
      WHERE kd.outlet_id = o.id
        AND kd.is_active = TRUE
    ) device_stats ON TRUE
    LEFT JOIN LATERAL (
      SELECT
        COUNT(DISTINCT e.id)  AS total_employees
      FROM employees e
      WHERE e.home_outlet_id = o.id
        AND e.is_active = TRUE
        AND e.archived_at IS NULL
    ) emp_stats ON TRUE
    LEFT JOIN LATERAL (
      SELECT
        COUNT(DISTINCT al.employee_id)  AS total_present
      FROM attendance_logs al
      WHERE al.scan_outlet_id = o.id
        AND al.type = 'masuk'
        AND al.scanned_at::date = p_date
    ) att_stats ON TRUE,
    LATERAL (
      SELECT json_build_object(
        'outlet_id',              o.id,
        'outlet_name',            o.name,
        'connected_devices',      COALESCE(device_stats.connected_devices, 0),
        'offline_devices',        COALESCE(device_stats.offline_devices, 0),
        'low_battery_devices',    COALESCE(device_stats.low_battery_devices, 0),
        'pending_sync_devices',   COALESCE(device_stats.pending_sync_devices, 0),
        'daily_attendance_rate',  CASE
                                    WHEN COALESCE(emp_stats.total_employees, 0) > 0
                                      THEN ROUND((COALESCE(att_stats.total_present, 0)::NUMERIC
                                               / emp_stats.total_employees) * 100, 1)
                                    ELSE 0
                                  END,
        'last_heartbeat_at',      device_stats.last_heartbeat_at
      ) AS row_data
    ) row_builder
    WHERE o.is_active = TRUE
  );
END;
$$;

REVOKE ALL ON FUNCTION get_outlet_control_center(DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_outlet_control_center(DATE) TO authenticated;
