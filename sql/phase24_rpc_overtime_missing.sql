-- ============================================================
-- Phase 24: RPC Functions for Overtime Flags and Missing Clock-Outs
-- Safe to run multiple times (CREATE OR REPLACE)
-- Deployed migration: phase_24_overtime_missing_rpc_20260318
-- ============================================================

-- 1. get_overtime_flags: Returns employees who worked longer than threshold today.
--    Compares pulang - masuk duration vs configurable threshold (default 8 hours).
CREATE OR REPLACE FUNCTION get_overtime_flags(
  p_outlet_id UUID,
  p_date DATE DEFAULT CURRENT_DATE,
  p_threshold_hours NUMERIC DEFAULT 8
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT := auth.jwt() -> 'app_metadata' ->> 'app_role';
  v_managed_outlet_id UUID :=
      NULLIF(auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id', '')::UUID;
  v_result JSON;
BEGIN
  IF auth.role() IS NOT NULL THEN
    IF v_role NOT IN ('admin', 'kepala_gerai') THEN
      RAISE EXCEPTION 'Not authorized to read overtime flags';
    END IF;

    IF v_role = 'kepala_gerai' AND v_managed_outlet_id IS DISTINCT FROM p_outlet_id THEN
      RAISE EXCEPTION 'Kepala gerai can only read their managed outlet';
    END IF;
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
  INTO v_result
  FROM (
    SELECT
      e.id AS employee_id,
      e.name AS employee_name,
      ROUND(
        EXTRACT(EPOCH FROM (pulang_log.scanned_at - masuk_log.scanned_at)) / 3600.0,
        2
      ) AS hours_worked,
      ROUND(
        EXTRACT(EPOCH FROM (pulang_log.scanned_at - masuk_log.scanned_at)) / 3600.0
        - p_threshold_hours,
        2
      ) AS overtime_hours
    FROM employees e
    -- Join the masuk log on the given date
    INNER JOIN attendance_logs masuk_log
      ON masuk_log.employee_id = e.id
      AND masuk_log.type = 'masuk'
      AND masuk_log.scanned_at::date = p_date
      AND masuk_log.scan_outlet_id = p_outlet_id
    -- Join the pulang log (latest pulang after masuk)
    INNER JOIN LATERAL (
      SELECT scanned_at
      FROM attendance_logs
      WHERE employee_id = e.id
        AND type = 'pulang'
        AND scanned_at > masuk_log.scanned_at
        AND scanned_at::date = p_date
      ORDER BY scanned_at DESC
      LIMIT 1
    ) pulang_log ON TRUE
    -- Scope to employees whose home outlet matches
    WHERE e.home_outlet_id = p_outlet_id
      AND e.is_active = TRUE
      AND e.archived_at IS NULL
      -- Only include those who exceeded threshold
      AND EXTRACT(EPOCH FROM (pulang_log.scanned_at - masuk_log.scanned_at)) / 3600.0
          > p_threshold_hours
    ORDER BY hours_worked DESC
  ) AS t;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION get_overtime_flags(UUID, DATE, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_overtime_flags(UUID, DATE, NUMERIC) TO authenticated;

-- 2. get_missing_clockouts: Returns employees with masuk today but no subsequent
--    pulang after p_threshold_hours since their masuk time.
CREATE OR REPLACE FUNCTION get_missing_clockouts(
  p_outlet_id UUID,
  p_threshold_hours NUMERIC DEFAULT 10
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT := auth.jwt() -> 'app_metadata' ->> 'app_role';
  v_managed_outlet_id UUID :=
      NULLIF(auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id', '')::UUID;
  v_result JSON;
BEGIN
  IF auth.role() IS NOT NULL THEN
    IF v_role NOT IN ('admin', 'kepala_gerai') THEN
      RAISE EXCEPTION 'Not authorized to read missing clock-outs';
    END IF;

    IF v_role = 'kepala_gerai' AND v_managed_outlet_id IS DISTINCT FROM p_outlet_id THEN
      RAISE EXCEPTION 'Kepala gerai can only read their managed outlet';
    END IF;
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
  INTO v_result
  FROM (
    SELECT
      e.id AS employee_id,
      e.name AS employee_name,
      masuk_log.scanned_at AS masuk_time
    FROM employees e
    INNER JOIN attendance_logs masuk_log
      ON masuk_log.employee_id = e.id
      AND masuk_log.type = 'masuk'
      AND masuk_log.scanned_at::date = CURRENT_DATE
      AND masuk_log.scan_outlet_id = p_outlet_id
      -- masuk happened more than p_threshold_hours ago
      AND masuk_log.scanned_at < NOW() - (INTERVAL '1 hour' * p_threshold_hours)
    -- Scope to this outlet's employees
    WHERE e.home_outlet_id = p_outlet_id
      AND e.is_active = TRUE
      AND e.archived_at IS NULL
      -- Must have no subsequent pulang after this masuk
      AND NOT EXISTS (
        SELECT 1
        FROM attendance_logs pulang_check
        WHERE pulang_check.employee_id = e.id
          AND pulang_check.type = 'pulang'
          AND pulang_check.scanned_at > masuk_log.scanned_at
      )
    ORDER BY masuk_log.scanned_at ASC
  ) AS t;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION get_missing_clockouts(UUID, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_missing_clockouts(UUID, NUMERIC) TO authenticated;
