-- ============================================================
-- Phase 51: Admin session trust hardening for legacy analytics RPCs
-- Additive migration. Safe to re-run with CREATE OR REPLACE.
-- Closes null-claim privilege bypasses in dashboard and analytics role guards.
-- ============================================================

CREATE OR REPLACE FUNCTION public.current_admin_can_access_outlet(
  p_outlet_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT := NULLIF(BTRIM(auth.jwt() -> 'app_metadata' ->> 'app_role'), '');
  v_metadata JSONB := COALESCE(auth.jwt() -> 'app_metadata', '{}'::JSONB);
  v_legacy_outlet_text TEXT :=
      NULLIF(BTRIM(v_metadata ->> 'managed_outlet_id'), '');
  v_candidate TEXT;
  v_allowed_outlets UUID[] := ARRAY[]::UUID[];
BEGIN
  IF p_outlet_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF v_role = 'admin' THEN
    RETURN TRUE;
  END IF;

  IF v_role NOT IN ('kepala_gerai', 'area_supervisor') THEN
    RETURN FALSE;
  END IF;

  IF v_legacy_outlet_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
    v_allowed_outlets := array_append(v_allowed_outlets, v_legacy_outlet_text::UUID);
  END IF;

  IF jsonb_typeof(v_metadata -> 'managed_outlet_ids') = 'array' THEN
    FOR v_candidate IN
      SELECT jsonb_array_elements_text(v_metadata -> 'managed_outlet_ids')
    LOOP
      IF v_candidate ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
        v_allowed_outlets := array_append(v_allowed_outlets, v_candidate::UUID);
      END IF;
    END LOOP;
  END IF;

  RETURN p_outlet_id = ANY(v_allowed_outlets);
END;
$$;

REVOKE ALL ON FUNCTION public.current_admin_can_access_outlet(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_admin_can_access_outlet(UUID) TO authenticated;

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
  v_auth_role TEXT := auth.role();
  v_role TEXT := NULLIF(BTRIM(auth.jwt() -> 'app_metadata' ->> 'app_role'), '');
  v_managed_outlet_text TEXT := NULLIF(BTRIM(auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id'), '');
  v_managed_outlet_id UUID := NULL;
  v_total_employees INT := 0;
  v_days INT := 0;
  v_total_present INT := 0;
BEGIN
  IF v_managed_outlet_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
    v_managed_outlet_id := v_managed_outlet_text::UUID;
  END IF;

  IF p_start > p_end THEN
    RAISE EXCEPTION 'p_start must be before or equal to p_end';
  END IF;

  IF v_auth_role IS DISTINCT FROM 'authenticated' THEN
    RAISE EXCEPTION 'Not authorized to read dashboard aggregates';
  END IF;

  IF v_role IS NULL OR v_role NOT IN ('admin', 'kepala_gerai', 'area_supervisor') THEN
    RAISE EXCEPTION 'Not authorized to read dashboard aggregates';
  END IF;

  IF v_role IN ('kepala_gerai', 'area_supervisor')
     AND NOT public.current_admin_can_access_outlet(p_outlet_id) THEN
    RAISE EXCEPTION 'Scoped admin can only read assigned outlets';
  END IF;

  SELECT COUNT(*)
  INTO v_total_employees
  FROM public.employees
  WHERE home_outlet_id = p_outlet_id
    AND is_active = TRUE
    AND archived_at IS NULL;

  v_days := GREATEST(1, (p_end::date - p_start::date) + 1);

  SELECT COUNT(*)
  INTO v_total_present
  FROM (
    SELECT DISTINCT employee_id, scanned_at::date AS scan_date
    FROM public.attendance_logs
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
  v_auth_role TEXT := auth.role();
  v_role TEXT := NULLIF(BTRIM(auth.jwt() -> 'app_metadata' ->> 'app_role'), '');
  v_managed_outlet_text TEXT := NULLIF(BTRIM(auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id'), '');
  v_managed_outlet_id UUID := NULL;
  v_days INT := GREATEST(1, LEAST(COALESCE(p_days, 7), 31));
  v_result JSON;
BEGIN
  IF v_managed_outlet_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
    v_managed_outlet_id := v_managed_outlet_text::UUID;
  END IF;

  IF v_auth_role IS DISTINCT FROM 'authenticated' THEN
    RAISE EXCEPTION 'Not authorized to read dashboard trends';
  END IF;

  IF v_role IS NULL OR v_role NOT IN ('admin', 'kepala_gerai', 'area_supervisor') THEN
    RAISE EXCEPTION 'Not authorized to read dashboard trends';
  END IF;

  IF v_role IN ('kepala_gerai', 'area_supervisor')
     AND NOT public.current_admin_can_access_outlet(p_outlet_id) THEN
    RAISE EXCEPTION 'Scoped admin can only read assigned outlets';
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
      FROM public.attendance_logs
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
  v_auth_role TEXT := auth.role();
  v_role TEXT := NULLIF(BTRIM(auth.jwt() -> 'app_metadata' ->> 'app_role'), '');
  v_days INT := 0;
  v_result JSON;
BEGIN
  IF p_start > p_end THEN
    RAISE EXCEPTION 'p_start must be before or equal to p_end';
  END IF;

  IF v_auth_role IS DISTINCT FROM 'authenticated' THEN
    RAISE EXCEPTION 'Only admin can read outlet comparison';
  END IF;

  IF v_role IS DISTINCT FROM 'admin' THEN
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
    FROM public.outlets o
    LEFT JOIN (
      SELECT home_outlet_id AS outlet_id, COUNT(*) AS emp_count
      FROM public.employees
      WHERE is_active = TRUE
        AND archived_at IS NULL
      GROUP BY home_outlet_id
    ) AS emp
      ON emp.outlet_id = o.id
    LEFT JOIN (
      SELECT scan_outlet_id, COUNT(*) AS present_count
      FROM (
        SELECT DISTINCT employee_id, scan_outlet_id, scanned_at::date AS scan_date
        FROM public.attendance_logs
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
  v_auth_role TEXT := auth.role();
  v_role TEXT := NULLIF(BTRIM(auth.jwt() -> 'app_metadata' ->> 'app_role'), '');
  v_managed_outlet_text TEXT := NULLIF(BTRIM(auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id'), '');
  v_managed_outlet_id UUID := NULL;
  v_employee_outlet_id UUID;
  v_current_streak INT := 0;
  v_longest_streak INT := 0;
  v_last_masuk_date DATE;
BEGIN
  IF v_managed_outlet_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
    v_managed_outlet_id := v_managed_outlet_text::UUID;
  END IF;

  SELECT home_outlet_id
  INTO v_employee_outlet_id
  FROM public.employees
  WHERE id = p_employee_id;

  IF v_employee_outlet_id IS NULL THEN
    RAISE EXCEPTION 'Employee % not found', p_employee_id;
  END IF;

  IF v_auth_role IS DISTINCT FROM 'authenticated' THEN
    RAISE EXCEPTION 'Not authorized to update streaks';
  END IF;

  IF v_role IS NULL OR v_role NOT IN ('admin', 'kepala_gerai', 'area_supervisor') THEN
    RAISE EXCEPTION 'Not authorized to update streaks';
  END IF;

  IF v_role IN ('kepala_gerai', 'area_supervisor')
     AND NOT public.current_admin_can_access_outlet(v_employee_outlet_id) THEN
    RAISE EXCEPTION 'Scoped admin can only update streaks for assigned outlets';
  END IF;

  WITH logical_days AS (
    SELECT DISTINCT
      CASE
        WHEN EXTRACT(HOUR FROM scanned_at) >= 12 THEN scanned_at::date
        ELSE (scanned_at - INTERVAL '1 day')::date
      END AS logical_day
    FROM public.attendance_logs
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

  INSERT INTO public.employee_streaks (
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

-- 5. get_overtime_flags: Returns employees who worked longer than threshold today.
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
  v_auth_role TEXT := auth.role();
  v_role TEXT := NULLIF(BTRIM(auth.jwt() -> 'app_metadata' ->> 'app_role'), '');
  v_managed_outlet_text TEXT := NULLIF(BTRIM(auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id'), '');
  v_managed_outlet_id UUID := NULL;
  v_result JSON;
BEGIN
  IF v_managed_outlet_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
    v_managed_outlet_id := v_managed_outlet_text::UUID;
  END IF;

  IF v_auth_role IS DISTINCT FROM 'authenticated' THEN
    RAISE EXCEPTION 'Not authorized to read overtime flags';
  END IF;

  IF v_role IS NULL OR v_role NOT IN ('admin', 'kepala_gerai', 'area_supervisor') THEN
    RAISE EXCEPTION 'Not authorized to read overtime flags';
  END IF;

  IF v_role IN ('kepala_gerai', 'area_supervisor')
     AND NOT public.current_admin_can_access_outlet(p_outlet_id) THEN
    RAISE EXCEPTION 'Scoped admin can only read assigned outlets';
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
    FROM public.employees e
    INNER JOIN public.attendance_logs masuk_log
      ON masuk_log.employee_id = e.id
      AND masuk_log.type = 'masuk'
      AND masuk_log.scanned_at::date = p_date
      AND masuk_log.scan_outlet_id = p_outlet_id
    INNER JOIN LATERAL (
      SELECT scanned_at
      FROM public.attendance_logs
      WHERE employee_id = e.id
        AND type = 'pulang'
        AND scanned_at > masuk_log.scanned_at
        AND scanned_at::date = p_date
      ORDER BY scanned_at DESC
      LIMIT 1
    ) pulang_log ON TRUE
    WHERE e.home_outlet_id = p_outlet_id
      AND e.is_active = TRUE
      AND e.archived_at IS NULL
      AND EXTRACT(EPOCH FROM (pulang_log.scanned_at - masuk_log.scanned_at)) / 3600.0
          > p_threshold_hours
    ORDER BY hours_worked DESC
  ) AS t;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION get_overtime_flags(UUID, DATE, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_overtime_flags(UUID, DATE, NUMERIC) TO authenticated;

-- 6. get_missing_clockouts: Returns employees with masuk today but no subsequent
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
  v_auth_role TEXT := auth.role();
  v_role TEXT := NULLIF(BTRIM(auth.jwt() -> 'app_metadata' ->> 'app_role'), '');
  v_managed_outlet_text TEXT := NULLIF(BTRIM(auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id'), '');
  v_managed_outlet_id UUID := NULL;
  v_result JSON;
BEGIN
  IF v_managed_outlet_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
    v_managed_outlet_id := v_managed_outlet_text::UUID;
  END IF;

  IF v_auth_role IS DISTINCT FROM 'authenticated' THEN
    RAISE EXCEPTION 'Not authorized to read missing clock-outs';
  END IF;

  IF v_role IS NULL OR v_role NOT IN ('admin', 'kepala_gerai', 'area_supervisor') THEN
    RAISE EXCEPTION 'Not authorized to read missing clock-outs';
  END IF;

  IF v_role IN ('kepala_gerai', 'area_supervisor')
     AND NOT public.current_admin_can_access_outlet(p_outlet_id) THEN
    RAISE EXCEPTION 'Scoped admin can only read assigned outlets';
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
  INTO v_result
  FROM (
    SELECT
      e.id AS employee_id,
      e.name AS employee_name,
      masuk_log.scanned_at AS masuk_time
    FROM public.employees e
    INNER JOIN public.attendance_logs masuk_log
      ON masuk_log.employee_id = e.id
      AND masuk_log.type = 'masuk'
      AND masuk_log.scanned_at::date = CURRENT_DATE
      AND masuk_log.scan_outlet_id = p_outlet_id
      AND masuk_log.scanned_at < NOW() - (INTERVAL '1 hour' * p_threshold_hours)
    WHERE e.home_outlet_id = p_outlet_id
      AND e.is_active = TRUE
      AND e.archived_at IS NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public.attendance_logs pulang_check
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

-- 7. get_arrival_patterns: Returns median arrival time per employee per day-of-week.
-- Only returns entries with 5+ data points.
CREATE OR REPLACE FUNCTION get_arrival_patterns(
  p_outlet_id UUID,
  p_days INT DEFAULT 30
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_role TEXT := auth.role();
  v_role TEXT := NULLIF(BTRIM(auth.jwt() -> 'app_metadata' ->> 'app_role'), '');
  v_managed_outlet_text TEXT := NULLIF(BTRIM(auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id'), '');
  v_managed_outlet_id UUID := NULL;
BEGIN
  IF v_managed_outlet_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
    v_managed_outlet_id := v_managed_outlet_text::UUID;
  END IF;

  IF v_auth_role IS DISTINCT FROM 'authenticated' THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF v_role IS NULL OR v_role NOT IN ('admin', 'kepala_gerai', 'area_supervisor') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF v_role IN ('kepala_gerai', 'area_supervisor')
     AND NOT public.current_admin_can_access_outlet(p_outlet_id) THEN
    RAISE EXCEPTION 'Scoped admin can only access assigned outlets';
  END IF;

  RETURN (
    SELECT json_agg(row_to_json(t))
    FROM (
      SELECT
        e.id AS employee_id,
        e.name AS employee_name,
        EXTRACT(DOW FROM al.scanned_at) AS day_of_week,
        COUNT(*) AS data_points,
        PERCENTILE_CONT(0.5) WITHIN GROUP (
          ORDER BY EXTRACT(EPOCH FROM al.scanned_at::time)
        ) AS median_seconds
      FROM public.employees e
      JOIN public.attendance_logs al ON al.employee_id = e.id
      WHERE e.home_outlet_id = p_outlet_id
        AND e.is_active = TRUE
        AND e.archived_at IS NULL
        AND al.type = 'masuk'
        AND al.scanned_at >= (CURRENT_DATE - p_days)
        AND al.scan_outlet_id = p_outlet_id
      GROUP BY e.id, e.name, EXTRACT(DOW FROM al.scanned_at)
      HAVING COUNT(*) >= 5
    ) t
  );
END;
$$;

REVOKE ALL ON FUNCTION get_arrival_patterns(UUID, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_arrival_patterns(UUID, INT) TO authenticated;
