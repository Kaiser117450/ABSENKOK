-- Phase 39 follow-up: Portal read-path hardening
-- Goal: remove service-role reads from portal search + schedule loading
-- Strategy:
--   1. Improve public search RPC so the website can call it with anon/authenticated sessions
--   2. Add an authenticated portal schedule overview RPC for the current + next ISO week
-- Safe to re-run (IF NOT EXISTS guards, CREATE OR REPLACE FUNCTION)

-- ── 1. Search normalization + indexes ─────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE OR REPLACE FUNCTION normalize_portal_search_text(input_text text)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
SET search_path = public
AS $$
  SELECT lower(trim(regexp_replace(input_text, '\s+', ' ', 'g')));
$$;

ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS portal_search_name text
    GENERATED ALWAYS AS (normalize_portal_search_text(name)) STORED;

CREATE INDEX IF NOT EXISTS employees_portal_search_prefix_idx
  ON employees (portal_search_name text_pattern_ops)
  WHERE is_active = true AND archived_at IS NULL;

CREATE INDEX IF NOT EXISTS employees_portal_search_trgm_idx
  ON employees USING gin (portal_search_name gin_trgm_ops)
  WHERE is_active = true AND archived_at IS NULL;

-- ── 2. Public-safe employee search RPC ───────────────────────────────────────

CREATE OR REPLACE FUNCTION search_portal_employees(
  search_text text,
  limit_count integer DEFAULT 8
)
RETURNS TABLE (
  employee_id uuid,
  employee_name text,
  home_outlet_id uuid,
  home_outlet_name text,
  "position" text,
  photo_url text,
  active_badge_id uuid
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_query text;
BEGIN
  normalized_query := normalize_portal_search_text(search_text);

  IF char_length(normalized_query) < 2 THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH prefix_matches AS (
    SELECT
      e.id              AS employee_id,
      e.name            AS employee_name,
      e.home_outlet_id  AS home_outlet_id,
      o.name            AS home_outlet_name,
      e.position        AS position,
      e.photo_url       AS photo_url,
      e.active_badge_id AS active_badge_id,
      1                 AS match_rank
    FROM employees e
    LEFT JOIN outlets o ON o.id = e.home_outlet_id
    WHERE e.is_active = true
      AND e.archived_at IS NULL
      AND e.portal_search_name LIKE (normalized_query || '%')
    ORDER BY e.portal_search_name
    LIMIT limit_count
  ),
  trgm_matches AS (
    SELECT
      e.id              AS employee_id,
      e.name            AS employee_name,
      e.home_outlet_id  AS home_outlet_id,
      o.name            AS home_outlet_name,
      e.position        AS position,
      e.photo_url       AS photo_url,
      e.active_badge_id AS active_badge_id,
      2                 AS match_rank
    FROM employees e
    LEFT JOIN outlets o ON o.id = e.home_outlet_id
    WHERE e.is_active = true
      AND e.archived_at IS NULL
      AND char_length(normalized_query) >= 3
      AND e.portal_search_name % normalized_query
      AND e.id NOT IN (SELECT pm.employee_id FROM prefix_matches pm)
    ORDER BY similarity(e.portal_search_name, normalized_query) DESC, e.name
    LIMIT limit_count
  )
  SELECT
    combined.employee_id,
    combined.employee_name,
    combined.home_outlet_id,
    combined.home_outlet_name,
    combined.position,
    combined.photo_url,
    combined.active_badge_id
  FROM (
    SELECT * FROM prefix_matches
    UNION ALL
    SELECT * FROM trgm_matches
  ) combined
  ORDER BY combined.match_rank, combined.employee_name
  LIMIT limit_count;
END;
$$;

REVOKE ALL ON FUNCTION search_portal_employees(text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION search_portal_employees(text, integer) TO anon, authenticated;

-- resolve_portal_employee should only be callable from authenticated sessions.
REVOKE ALL ON FUNCTION resolve_portal_employee() FROM PUBLIC;
REVOKE ALL ON FUNCTION resolve_portal_employee() FROM anon;
REVOKE ALL ON FUNCTION resolve_portal_employee() FROM authenticated;
GRANT EXECUTE ON FUNCTION resolve_portal_employee() TO authenticated;

-- ── 3. Portal schedule overview RPC (current + next ISO week) ───────────────

CREATE OR REPLACE FUNCTION get_portal_schedule_overview(reference_date date DEFAULT NULL)
RETURNS TABLE (
  logical_date date,
  outlet_id uuid,
  outlet_name text,
  shift_name text,
  start_hour integer,
  start_minute integer,
  end_hour integer,
  end_minute integer,
  is_day_off boolean,
  ends_next_day boolean,
  entry_status text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  resolved_employee_id uuid;
  effective_date date;
  week_start date;
  horizon_end date;
BEGIN
  SELECT r.employee_id
  INTO resolved_employee_id
  FROM resolve_portal_employee() AS r
  LIMIT 1;

  IF resolved_employee_id IS NULL THEN
    RAISE EXCEPTION 'No active employee found for this portal account';
  END IF;

  effective_date := COALESCE(reference_date, current_date);
  week_start := effective_date - ((EXTRACT(ISODOW FROM effective_date)::integer) - 1);
  horizon_end := week_start + 13;

  RETURN QUERY
  WITH schedule_rows AS (
    SELECT
      se.date AS logical_date,
      o.id AS outlet_id,
      o.name AS outlet_name,
      (se.shift_slot->>'name')::text AS shift_name,
      (se.shift_slot->>'start_hour')::integer AS start_hour,
      (se.shift_slot->>'start_minute')::integer AS start_minute,
      (se.shift_slot->>'end_hour')::integer AS end_hour,
      (se.shift_slot->>'end_minute')::integer AS end_minute,
      COALESCE(se.is_day_off, false) AS is_day_off,
      CASE
        WHEN COALESCE(se.is_day_off, false) THEN false
        WHEN make_time(
               (se.shift_slot->>'end_hour')::integer,
               (se.shift_slot->>'end_minute')::integer,
               0
             ) <= make_time(
                    (se.shift_slot->>'start_hour')::integer,
                    (se.shift_slot->>'start_minute')::integer,
                    0
                  ) THEN true
        ELSE false
      END AS ends_next_day,
      CASE
        WHEN COALESCE(se.is_day_off, false) THEN 'libur'
        ELSE 'normal'
      END AS base_status,
      NULLIF(btrim(se.notes), '') AS schedule_notes
    FROM schedule_entries se
    INNER JOIN schedules s ON s.id = se.schedule_id
    INNER JOIN outlets o ON o.id = s.outlet_id
    WHERE se.employee_id = resolved_employee_id
      AND se.date BETWEEN week_start AND horizon_end
      AND s.is_active = true
  ),
  attendance_status AS (
    SELECT
      ((al.scanned_at AT TIME ZONE 'Asia/Makassar')::date) AS logical_date,
      CASE
        WHEN bool_or(al.type = 'sakit') THEN 'sakit'
        WHEN bool_or(al.type = 'izin') THEN 'izin'
        ELSE NULL
      END AS entry_status,
      string_agg(DISTINCT NULLIF(btrim(al.notes), ''), ' | ')
        FILTER (WHERE al.notes IS NOT NULL AND btrim(al.notes) <> '') AS attendance_notes
    FROM attendance_logs al
    WHERE al.employee_id = resolved_employee_id
      AND al.type = ANY (ARRAY['sakit', 'izin'])
      AND ((al.scanned_at AT TIME ZONE 'Asia/Makassar')::date) BETWEEN week_start AND horizon_end
    GROUP BY ((al.scanned_at AT TIME ZONE 'Asia/Makassar')::date)
  ),
  scheduled AS (
    SELECT
      sr.logical_date,
      sr.outlet_id,
      sr.outlet_name,
      sr.shift_name,
      sr.start_hour,
      sr.start_minute,
      sr.end_hour,
      sr.end_minute,
      sr.is_day_off,
      sr.ends_next_day,
      COALESCE(ast.entry_status, sr.base_status) AS entry_status,
      NULLIF(concat_ws(' | ', sr.schedule_notes, ast.attendance_notes), '') AS notes
    FROM schedule_rows sr
    LEFT JOIN attendance_status ast ON ast.logical_date = sr.logical_date
  ),
  status_only AS (
    SELECT
      ast.logical_date,
      NULL::uuid AS outlet_id,
      NULL::text AS outlet_name,
      NULL::text AS shift_name,
      NULL::integer AS start_hour,
      NULL::integer AS start_minute,
      NULL::integer AS end_hour,
      NULL::integer AS end_minute,
      true AS is_day_off,
      false AS ends_next_day,
      ast.entry_status,
      ast.attendance_notes AS notes
    FROM attendance_status ast
    WHERE NOT EXISTS (
      SELECT 1
      FROM schedule_rows sr
      WHERE sr.logical_date = ast.logical_date
    )
  )
  SELECT
    merged.logical_date,
    merged.outlet_id,
    merged.outlet_name,
    merged.shift_name,
    merged.start_hour,
    merged.start_minute,
    merged.end_hour,
    merged.end_minute,
    merged.is_day_off,
    merged.ends_next_day,
    merged.entry_status,
    merged.notes
  FROM (
    SELECT * FROM scheduled
    UNION ALL
    SELECT * FROM status_only
  ) merged
  ORDER BY
    merged.logical_date,
    merged.start_hour NULLS FIRST,
    merged.start_minute NULLS FIRST;
END;
$$;

REVOKE ALL ON FUNCTION get_portal_schedule_overview(date) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_portal_schedule_overview(date) FROM anon;
REVOKE ALL ON FUNCTION get_portal_schedule_overview(date) FROM authenticated;
GRANT EXECUTE ON FUNCTION get_portal_schedule_overview(date) TO authenticated;
