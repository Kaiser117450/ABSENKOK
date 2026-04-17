-- Phase 64: Public website leaderboard read model
-- Goal: expose a narrow, aggregate-only leaderboard dataset for the Astro
-- website without requiring a service-role key in the web runtime.
--
-- Depends on:
--   - phase_23_employee_streaks.sql / phase_51_admin_session_trust_20260325.sql
--   - phase_57_strict_recap_evaluation_engine_20260327.sql

CREATE OR REPLACE FUNCTION public.get_site_leaderboard(
  p_reference_date date DEFAULT NULL
)
RETURNS TABLE (
  employee_id uuid,
  employee_name text,
  employee_position text,
  home_outlet_id uuid,
  home_outlet_name text,
  measured_days integer,
  safe_days integer,
  issue_days integer,
  neutral_days integer,
  overtime_only_days integer,
  late_count integer,
  absence_count integer,
  short_work_count integer,
  excess_break_count integer,
  overtime_count integer,
  unresolved_count integer,
  current_streak integer,
  longest_streak integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH effective AS (
    SELECT COALESCE(
      p_reference_date,
      (statement_timestamp() AT TIME ZONE 'Asia/Makassar')::date
    ) AS reference_date
  ),
  boundaries AS (
    SELECT
      reference_date,
      date_trunc('month', reference_date)::date AS month_start
    FROM effective
  ),
  recap_rows AS (
    SELECT recap.*
    FROM boundaries b
    CROSS JOIN public.outlets o
    CROSS JOIN LATERAL public.get_admin_schedule_policy_recap(
      o.id,
      b.month_start,
      b.reference_date
    ) AS recap
  ),
  classified_rows AS (
    SELECT
      rr.*,
      (
        'late' = ANY(COALESCE(rr.detail_signals, ARRAY[]::text[]))
        OR 'short_work' = ANY(COALESCE(rr.detail_signals, ARRAY[]::text[]))
        OR 'excess_break' = ANY(COALESCE(rr.detail_signals, ARRAY[]::text[]))
        OR 'absence' = ANY(COALESCE(rr.detail_signals, ARRAY[]::text[]))
        OR 'belum_absen_pulang' = ANY(COALESCE(rr.detail_signals, ARRAY[]::text[]))
        OR rr.primary_status IN ('absence', 'belum_absen_pulang')
        OR rr.attendance_status = 'tidak_hadir'
      ) AS is_issue_day,
      (
        'overtime' = ANY(COALESCE(rr.detail_signals, ARRAY[]::text[]))
        OR rr.primary_status = 'overtime'
      ) AS is_overtime_day
    FROM recap_rows rr
  ),
  employee_rollup AS (
    SELECT
      e.id AS employee_id,
      e.name AS employee_name,
      e.position AS employee_position,
      e.home_outlet_id,
      ho.name AS home_outlet_name,
      COUNT(cr.employee_id)::integer AS measured_days,
      COUNT(*) FILTER (
        WHERE cr.attendance_status = 'hadir'
          AND COALESCE(cr.logical_day_complete, true)
          AND NOT cr.is_issue_day
          AND NOT cr.is_overtime_day
      )::integer AS safe_days,
      COUNT(*) FILTER (WHERE cr.is_issue_day)::integer AS issue_days,
      COUNT(*) FILTER (
        WHERE NOT cr.is_issue_day
          AND NOT cr.is_overtime_day
          AND NOT (
            cr.attendance_status = 'hadir'
            AND COALESCE(cr.logical_day_complete, true)
          )
      )::integer AS neutral_days,
      COUNT(*) FILTER (
        WHERE NOT cr.is_issue_day
          AND cr.is_overtime_day
      )::integer AS overtime_only_days,
      COUNT(*) FILTER (
        WHERE 'late' = ANY(COALESCE(cr.detail_signals, ARRAY[]::text[]))
      )::integer AS late_count,
      COUNT(*) FILTER (
        WHERE 'absence' = ANY(COALESCE(cr.detail_signals, ARRAY[]::text[]))
          OR cr.primary_status = 'absence'
          OR cr.attendance_status = 'tidak_hadir'
      )::integer AS absence_count,
      COUNT(*) FILTER (
        WHERE 'short_work' = ANY(COALESCE(cr.detail_signals, ARRAY[]::text[]))
      )::integer AS short_work_count,
      COUNT(*) FILTER (
        WHERE 'excess_break' = ANY(COALESCE(cr.detail_signals, ARRAY[]::text[]))
      )::integer AS excess_break_count,
      COUNT(*) FILTER (
        WHERE 'overtime' = ANY(COALESCE(cr.detail_signals, ARRAY[]::text[]))
          OR cr.primary_status = 'overtime'
      )::integer AS overtime_count,
      COUNT(*) FILTER (
        WHERE 'belum_absen_pulang' = ANY(COALESCE(cr.detail_signals, ARRAY[]::text[]))
          OR cr.primary_status = 'belum_absen_pulang'
      )::integer AS unresolved_count
    FROM public.employees e
    LEFT JOIN public.outlets ho
      ON ho.id = e.home_outlet_id
    LEFT JOIN classified_rows cr
      ON cr.employee_id = e.id
    WHERE e.is_active = true
      AND e.archived_at IS NULL
    GROUP BY
      e.id,
      e.name,
      e.position,
      e.home_outlet_id,
      ho.name
  )
  SELECT
    er.employee_id,
    er.employee_name,
    er.employee_position,
    er.home_outlet_id,
    er.home_outlet_name,
    er.measured_days,
    er.safe_days,
    er.issue_days,
    er.neutral_days,
    er.overtime_only_days,
    er.late_count,
    er.absence_count,
    er.short_work_count,
    er.excess_break_count,
    er.overtime_count,
    er.unresolved_count,
    COALESCE(es.current_streak, 0)::integer AS current_streak,
    COALESCE(es.longest_streak, 0)::integer AS longest_streak
  FROM employee_rollup er
  LEFT JOIN public.employee_streaks es
    ON es.employee_id = er.employee_id
  ORDER BY er.employee_name ASC;
$$;

REVOKE ALL ON FUNCTION public.get_site_leaderboard(date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_site_leaderboard(date) TO supabase_read_only_user;
GRANT EXECUTE ON FUNCTION public.get_site_leaderboard(date) TO anon;
GRANT EXECUTE ON FUNCTION public.get_site_leaderboard(date) TO authenticated;
