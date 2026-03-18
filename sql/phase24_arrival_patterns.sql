-- ============================================================
-- Phase 24 Plan 03: Arrival Pattern RPC for Smart Late Detection (SMART-01..04)
-- Safe to run multiple times (CREATE OR REPLACE)
-- ============================================================

-- get_arrival_patterns: Returns median arrival time per employee per day-of-week.
-- Only returns entries with 5+ data points (SMART-04 skip rule enforced via HAVING).
-- Used by PatternDetectionService to detect late arrivals post-NFC scan.
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
  v_role TEXT := auth.jwt() -> 'app_metadata' ->> 'app_role';
  v_managed UUID := NULLIF(auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id', '')::UUID;
BEGIN
  IF auth.role() IS NOT NULL THEN
    IF v_role NOT IN ('admin', 'kepala_gerai') THEN
      RAISE EXCEPTION 'Not authorized';
    END IF;
    IF v_role = 'kepala_gerai' AND v_managed IS DISTINCT FROM p_outlet_id THEN
      RAISE EXCEPTION 'Kepala gerai can only access managed outlet';
    END IF;
  END IF;

  RETURN (
    SELECT json_agg(row_to_json(t))
    FROM (
      SELECT
        e.id AS employee_id,
        e.name AS employee_name,
        EXTRACT(DOW FROM al.scanned_at) AS day_of_week,
        COUNT(*) AS data_points,
        -- median of time-of-day in seconds since midnight
        PERCENTILE_CONT(0.5) WITHIN GROUP (
          ORDER BY EXTRACT(EPOCH FROM al.scanned_at::time)
        ) AS median_seconds
      FROM employees e
      JOIN attendance_logs al ON al.employee_id = e.id
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
