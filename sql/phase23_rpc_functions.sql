-- ============================================================
-- Phase 23: RPC Functions for Dashboard Aggregation (DASH-05)
-- Safe to run multiple times (CREATE OR REPLACE)
-- ============================================================

-- 1. get_attendance_rates: Returns attendance percentage for an outlet
-- in a date range.
CREATE OR REPLACE FUNCTION get_attendance_rates(
  p_outlet_id UUID,
  p_start TIMESTAMPTZ,
  p_end TIMESTAMPTZ
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
  v_total_employees INT := 0;
  v_days INT := 0;
  v_total_present INT := 0;
BEGIN
  IF p_start > p_end THEN
    RAISE EXCEPTION 'p_start must be before or equal to p_end';
  END IF;

  IF auth.role() IS NOT NULL THEN
    IF v_role NOT IN ('admin', 'kepala_gerai') THEN
      RAISE EXCEPTION 'Not authorized to read dashboard aggregates';
    END IF;

    IF v_role = 'kepala_gerai' AND v_managed_outlet_id IS DISTINCT FROM p_outlet_id THEN
      RAISE EXCEPTION 'Kepala gerai can only read their managed outlet';
    END IF;
  END IF;

  SELECT COUNT(*)
  INTO v_total_employees
  FROM employees
  WHERE home_outlet_id = p_outlet_id
    AND is_active = TRUE
    AND archived_at IS NULL;

  v_days := GREATEST(1, (p_end::date - p_start::date) + 1);

  SELECT COUNT(*)
  INTO v_total_present
  FROM (
    SELECT DISTINCT employee_id, scanned_at::date AS scan_date
    FROM attendance_logs
    WHERE scan_outlet_id = p_outlet_id
      AND type = 'masuk'
      AND scanned_at >= p_start
      AND scanned_at <= p_end
  ) daily_presence;

  RETURN json_build_object(
    'total_employees', v_total_employees,
    'days_in_range', v_days,
    'total_present', v_total_present,
    'rate',
      CASE
        WHEN v_total_employees * v_days > 0
          THEN ROUND((v_total_present::NUMERIC / (v_total_employees * v_days)) * 100, 1)
        ELSE 0
      END
  );
END;
$$;

REVOKE ALL ON FUNCTION get_attendance_rates(UUID, TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_attendance_rates(UUID, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;

-- 2. get_weekly_trend: Returns daily masuk counts for the last N days
-- for a single outlet.
CREATE OR REPLACE FUNCTION get_weekly_trend(
  p_outlet_id UUID,
  p_days INT DEFAULT 7
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
  v_days INT := GREATEST(1, LEAST(COALESCE(p_days, 7), 31));
  v_result JSON;
BEGIN
  IF auth.role() IS NOT NULL THEN
    IF v_role NOT IN ('admin', 'kepala_gerai') THEN
      RAISE EXCEPTION 'Not authorized to read dashboard trends';
    END IF;

    IF v_role = 'kepala_gerai' AND v_managed_outlet_id IS DISTINCT FROM p_outlet_id THEN
      RAISE EXCEPTION 'Kepala gerai can only read their managed outlet';
    END IF;
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.date), '[]'::JSON)
  INTO v_result
  FROM (
    SELECT
      day_bucket::date::text AS date,
      COALESCE(log_counts.cnt, 0) AS count
    FROM generate_series(
      CURRENT_DATE - (v_days - 1),
      CURRENT_DATE,
      INTERVAL '1 day'
    ) AS day_bucket
    LEFT JOIN (
      SELECT scanned_at::date AS scan_date, COUNT(DISTINCT employee_id) AS cnt
      FROM attendance_logs
      WHERE scan_outlet_id = p_outlet_id
        AND type = 'masuk'
        AND scanned_at >= CURRENT_DATE - (v_days - 1)
      GROUP BY scanned_at::date
    ) AS log_counts
      ON log_counts.scan_date = day_bucket::date
  ) AS t;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION get_weekly_trend(UUID, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_weekly_trend(UUID, INT) TO authenticated;

-- 3. get_outlet_comparison: Returns attendance rates across active outlets.
-- Admin-only in app usage.
CREATE OR REPLACE FUNCTION get_outlet_comparison(
  p_start TIMESTAMPTZ,
  p_end TIMESTAMPTZ
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT := auth.jwt() -> 'app_metadata' ->> 'app_role';
  v_days INT := 0;
  v_result JSON;
BEGIN
  IF p_start > p_end THEN
    RAISE EXCEPTION 'p_start must be before or equal to p_end';
  END IF;

  IF auth.role() IS NOT NULL AND v_role <> 'admin' THEN
    RAISE EXCEPTION 'Only admin can read outlet comparison';
  END IF;

  v_days := GREATEST(1, (p_end::date - p_start::date) + 1);

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.outlet_name), '[]'::JSON)
  INTO v_result
  FROM (
    SELECT
      o.id AS outlet_id,
      o.name AS outlet_name,
      COALESCE(emp.emp_count, 0) AS total_employees,
      COALESCE(att.present_count, 0) AS total_present,
      CASE
        WHEN COALESCE(emp.emp_count, 0) * v_days > 0
          THEN ROUND((COALESCE(att.present_count, 0)::NUMERIC / (emp.emp_count * v_days)) * 100, 1)
        ELSE 0
      END AS rate
    FROM outlets o
    LEFT JOIN (
      SELECT home_outlet_id AS outlet_id, COUNT(*) AS emp_count
      FROM employees
      WHERE is_active = TRUE
        AND archived_at IS NULL
      GROUP BY home_outlet_id
    ) AS emp
      ON emp.outlet_id = o.id
    LEFT JOIN (
      SELECT scan_outlet_id, COUNT(*) AS present_count
      FROM (
        SELECT DISTINCT employee_id, scan_outlet_id, scanned_at::date AS scan_date
        FROM attendance_logs
        WHERE type = 'masuk'
          AND scanned_at >= p_start
          AND scanned_at <= p_end
      ) AS deduped_presence
      GROUP BY scan_outlet_id
    ) AS att
      ON att.scan_outlet_id = o.id
    WHERE o.is_active = TRUE
  ) AS t;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION get_outlet_comparison(TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_outlet_comparison(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;

-- 4. update_employee_streak: Recalculate and cache streak for one employee.
-- Uses the noon-rule logical day (noon to noon) for night shifts.
CREATE OR REPLACE FUNCTION update_employee_streak(
  p_employee_id UUID
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
  v_employee_outlet_id UUID;
  v_current_streak INT := 0;
  v_longest_streak INT := 0;
  v_last_masuk_date DATE;
BEGIN
  SELECT home_outlet_id
  INTO v_employee_outlet_id
  FROM employees
  WHERE id = p_employee_id;

  IF v_employee_outlet_id IS NULL THEN
    RAISE EXCEPTION 'Employee % not found', p_employee_id;
  END IF;

  IF auth.role() IS NOT NULL THEN
    IF v_role NOT IN ('admin', 'kepala_gerai') THEN
      RAISE EXCEPTION 'Not authorized to update streaks';
    END IF;

    IF v_role = 'kepala_gerai' AND v_managed_outlet_id IS DISTINCT FROM v_employee_outlet_id THEN
      RAISE EXCEPTION 'Kepala gerai can only update streaks for their managed outlet';
    END IF;
  END IF;

  WITH logical_days AS (
    SELECT DISTINCT
      CASE
        WHEN EXTRACT(HOUR FROM scanned_at) >= 12 THEN scanned_at::date
        ELSE (scanned_at - INTERVAL '1 day')::date
      END AS logical_day
    FROM attendance_logs
    WHERE employee_id = p_employee_id
      AND type = 'masuk'
  ),
  grouped_days AS (
    SELECT
      logical_day,
      logical_day + (ROW_NUMBER() OVER (ORDER BY logical_day DESC) * INTERVAL '1 day') AS group_key
    FROM logical_days
  ),
  streaks AS (
    SELECT
      group_key,
      COUNT(*)::INT AS streak_len,
      MAX(logical_day) AS newest_logical_day
    FROM grouped_days
    GROUP BY group_key
  ),
  metrics AS (
    SELECT
      COALESCE((SELECT streak_len FROM streaks ORDER BY newest_logical_day DESC LIMIT 1), 0) AS current_streak,
      COALESCE((SELECT MAX(streak_len) FROM streaks), 0) AS longest_streak,
      (SELECT MAX(logical_day) FROM logical_days) AS last_masuk_date
  )
  SELECT current_streak, longest_streak, last_masuk_date
  INTO v_current_streak, v_longest_streak, v_last_masuk_date
  FROM metrics;

  INSERT INTO employee_streaks (
    employee_id,
    current_streak,
    longest_streak,
    last_masuk_date,
    updated_at
  )
  VALUES (
    p_employee_id,
    v_current_streak,
    v_longest_streak,
    v_last_masuk_date,
    NOW()
  )
  ON CONFLICT (employee_id) DO UPDATE SET
    current_streak = EXCLUDED.current_streak,
    longest_streak = EXCLUDED.longest_streak,
    last_masuk_date = EXCLUDED.last_masuk_date,
    updated_at = NOW();

  RETURN json_build_object(
    'current_streak', v_current_streak,
    'longest_streak', v_longest_streak
  );
END;
$$;

REVOKE ALL ON FUNCTION update_employee_streak(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION update_employee_streak(UUID) TO authenticated;
