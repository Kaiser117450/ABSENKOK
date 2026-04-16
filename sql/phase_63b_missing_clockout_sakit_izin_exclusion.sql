-- Phase 63b: Exclude sakit/izin employees from missing clockout notifications
--
-- Bug: get_missing_clockouts was flagging employees who had a sakit/izin
-- record on the same day as their masuk, generating false "belum pulang"
-- notifications for employees who legitimately left early due to illness/leave.
--
-- Fix: When an employee has a sakit or izin attendance_log on the same day,
-- that day is treated as a non-work day — masuk/pulang are irrelevant.
-- Exclude these employees from the missing clockout query entirely.

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

  IF v_role IS NULL OR v_role NOT IN ('admin', 'kepala_gerai') THEN
    RAISE EXCEPTION 'Not authorized to read missing clock-outs';
  END IF;

  IF v_role = 'kepala_gerai'
     AND (v_managed_outlet_id IS NULL OR v_managed_outlet_id IS DISTINCT FROM p_outlet_id) THEN
    RAISE EXCEPTION 'Kepala gerai can only read their managed outlet';
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
      -- No pulang after masuk
      AND NOT EXISTS (
        SELECT 1
        FROM public.attendance_logs pulang_check
        WHERE pulang_check.employee_id = e.id
          AND pulang_check.type = 'pulang'
          AND pulang_check.scanned_at > masuk_log.scanned_at
      )
      -- Exclude employees with sakit/izin on the same day —
      -- those days are treated as non-work, masuk/pulang irrelevant.
      AND NOT EXISTS (
        SELECT 1
        FROM public.attendance_logs sakit_check
        WHERE sakit_check.employee_id = e.id
          AND sakit_check.type IN ('sakit', 'izin')
          AND sakit_check.scanned_at::date = CURRENT_DATE
      )
    ORDER BY masuk_log.scanned_at ASC
  ) AS t;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION get_missing_clockouts(UUID, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_missing_clockouts(UUID, NUMERIC) TO authenticated;
