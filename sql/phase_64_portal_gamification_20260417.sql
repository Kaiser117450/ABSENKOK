-- Phase 64: Portal Gamification (Streak Read + Cross-Outlet Leaderboard)
-- Goal: Add two additive RPCs that back the portal home streak card and
--       the new `/portal/leaderboard` page. Both are employee-identity
--       scoped through `resolve_portal_employee()` so no page ever
--       supplies an employee_id.
--
-- Depends on:
--   phase_37_employee_portal_foundation_20260322.sql  (resolve_portal_employee)
--   phase_39_portal_read_path_hardening_20260323.sql  (authenticated ACL)
--   phase_42_portal_attendance_recap_20260323.sql     (idx_attendance_logs_employee_recap)
--   phase_46_portal_streak_read_20260403.sql          (employee_streaks RLS)
--   phase23_employee_streaks.sql                      (employee_streaks table)
--
-- Safe to re-run: CREATE OR REPLACE FUNCTION guards.

-- ── 1. get_portal_streak — authenticated self-read wrapper ──────────────────
--
-- Returns the authenticated employee's streak row. Also returns zeros when
-- no streak row exists yet so the portal never has to branch on missing
-- rows. SECURITY DEFINER because the portal account may be new and the
-- streak row may have been created by the admin-only update RPC; the
-- resolve gate enforces identity.

CREATE OR REPLACE FUNCTION get_portal_streak()
RETURNS TABLE (
  current_streak integer,
  longest_streak integer,
  last_masuk_date date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  resolved_employee_id uuid;
BEGIN
  SELECT r.employee_id INTO resolved_employee_id
  FROM resolve_portal_employee() AS r LIMIT 1;

  IF resolved_employee_id IS NULL THEN
    RAISE EXCEPTION 'No active employee found for this portal account';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(es.current_streak, 0)::integer,
    COALESCE(es.longest_streak, 0)::integer,
    es.last_masuk_date
  FROM employee_streaks es
  WHERE es.employee_id = resolved_employee_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::integer, 0::integer, NULL::date;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION get_portal_streak() FROM PUBLIC;
REVOKE ALL ON FUNCTION get_portal_streak() FROM anon;
GRANT EXECUTE ON FUNCTION get_portal_streak() TO authenticated;

-- ── 2. get_portal_leaderboard — cross-outlet aggregate metrics ──────────────
--
-- Purpose:
--   Returns one row per active employee with:
--     - public identity (name, position, outlet, photo)
--     - streak fields (current, longest)
--     - window aggregates across `window_days` days
--     - sparkline array of daily status codes in ascending date order
--
--   The SQL side intentionally returns RAW COUNTS and leaves the final
--   score formula to the portal TypeScript so the weighting is auditable
--   in version control and testable in isolation.
--
-- Security:
--   - SECURITY DEFINER so we can read across all active employees.
--   - The caller MUST be an authenticated portal employee; anonymous
--     sessions raise an exception.
--   - No raw scan timestamps are returned. Only aggregate counts and
--     per-day status codes ('hadir', 'tidak_hadir', 'libur', ...).
--   - `window_days` is clamped to [1, 30] to bound the working set.
--
-- Status taxonomy (same as phase 42):
--   hadir, sakit, izin, libur, belum_pulang, sedang_bekerja,
--   tidak_hadir, belum_masuk, none (unscheduled no-scan day)
--
-- Derived flags (late / short_work / excess_break):
--   - `late`         — first_masuk_at > shift_start + 15m grace
--   - `short_work`   — work_minutes < expected_shift_minutes − 60m grace
--   - `excess_break` — total_break_minutes > 90m

CREATE OR REPLACE FUNCTION get_portal_leaderboard(
  reference_date date    DEFAULT NULL,
  window_days    integer DEFAULT 14
)
RETURNS TABLE (
  employee_id        uuid,
  employee_name      text,
  position           text,
  outlet_id          uuid,
  outlet_name        text,
  photo_url          text,
  current_streak     integer,
  longest_streak     integer,
  hadir_count        integer,
  tidak_hadir_count  integer,
  belum_pulang_count integer,
  sakit_count        integer,
  izin_count         integer,
  late_count         integer,
  short_work_count   integer,
  excess_break_count integer,
  sparkline          text[]
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  resolved_employee_id uuid;
  effective_date       date;
  window_start         date;
  bounded_window       integer;
BEGIN
  -- Authenticated-only gate. The portal middleware already prevents anon
  -- requests, but we enforce it again at the database boundary.
  SELECT r.employee_id INTO resolved_employee_id
  FROM resolve_portal_employee() AS r LIMIT 1;

  IF resolved_employee_id IS NULL THEN
    RAISE EXCEPTION 'No active employee found for this portal account';
  END IF;

  bounded_window := GREATEST(1, LEAST(COALESCE(window_days, 14), 30));
  effective_date := COALESCE(reference_date, (NOW() AT TIME ZONE 'Asia/Makassar')::date);
  window_start   := effective_date - (bounded_window - 1);

  RETURN QUERY
  WITH
  active_employees AS (
    SELECT e.id, e.name, e.position, e.home_outlet_id, e.photo_url
    FROM employees e
    WHERE e.is_active = true
      AND e.archived_at IS NULL
  ),
  raw_logs AS (
    SELECT
      al.employee_id,
      al.type,
      (al.scanned_at AT TIME ZONE 'Asia/Makassar')::date AS local_date,
      (al.scanned_at AT TIME ZONE 'Asia/Makassar')       AS local_ts,
      EXTRACT(HOUR FROM (al.scanned_at AT TIME ZONE 'Asia/Makassar'))::integer AS local_hour
    FROM attendance_logs al
    INNER JOIN active_employees ae ON ae.id = al.employee_id
    -- Fetch one day earlier for overnight pulang repair.
    WHERE al.scanned_at >= ((window_start - 1)::timestamptz AT TIME ZONE 'Asia/Makassar')
      AND al.scanned_at <  ((effective_date + 1)::timestamptz AT TIME ZONE 'Asia/Makassar')
  ),
  -- Overnight pulang repair (per-employee, mirrors phase 42).
  dates_with_masuk AS (
    SELECT DISTINCT employee_id, local_date FROM raw_logs WHERE type = 'masuk'
  ),
  orphan_pulang_days AS (
    SELECT DISTINCT rl.employee_id, rl.local_date AS orphan_date
    FROM raw_logs rl
    WHERE rl.type = 'pulang' AND rl.local_hour < 12
      AND NOT EXISTS (
        SELECT 1 FROM dates_with_masuk dwm
        WHERE dwm.employee_id = rl.employee_id AND dwm.local_date = rl.local_date
      )
      AND EXISTS (
        SELECT 1 FROM dates_with_masuk dwm
        WHERE dwm.employee_id = rl.employee_id AND dwm.local_date = rl.local_date - 1
      )
  ),
  repaired_logs AS (
    SELECT
      rl.employee_id, rl.type, rl.local_ts,
      CASE
        WHEN rl.type = 'pulang' AND rl.local_hour < 12
          AND EXISTS (
            SELECT 1 FROM orphan_pulang_days opd
            WHERE opd.employee_id = rl.employee_id AND opd.orphan_date = rl.local_date
          )
        THEN rl.local_date - 1
        ELSE rl.local_date
      END AS logical_date
    FROM raw_logs rl
  ),
  day_facts AS (
    SELECT
      rl.employee_id,
      rl.logical_date,
      COUNT(*)::integer                                         AS scan_count,
      MIN(rl.local_ts) FILTER (WHERE rl.type = 'masuk')         AS first_masuk_at,
      MIN(rl.local_ts) FILTER (WHERE rl.type = 'break')         AS first_break_at,
      MAX(rl.local_ts) FILTER (WHERE rl.type = 'kembali')       AS last_kembali_at,
      MAX(rl.local_ts) FILTER (WHERE rl.type = 'pulang')        AS last_pulang_at,
      bool_or(rl.type = 'sakit')                                AS has_sakit,
      bool_or(rl.type = 'izin')                                 AS has_izin,
      CASE
        WHEN MIN(rl.local_ts) FILTER (WHERE rl.type = 'break') IS NOT NULL
          AND MAX(rl.local_ts) FILTER (WHERE rl.type = 'kembali') IS NOT NULL
        THEN EXTRACT(EPOCH FROM (
               MAX(rl.local_ts) FILTER (WHERE rl.type = 'kembali')
               - MIN(rl.local_ts) FILTER (WHERE rl.type = 'break')
             ))::integer / 60
        ELSE 0
      END                                                       AS total_break_minutes
    FROM repaired_logs rl
    WHERE rl.logical_date BETWEEN window_start AND effective_date
    GROUP BY rl.employee_id, rl.logical_date
  ),
  schedule_rows AS (
    SELECT
      se.employee_id,
      se.date                                                   AS logical_date,
      COALESCE(se.is_day_off, false)                            AS is_day_off,
      (se.shift_slot->>'start_hour')::integer                   AS start_hour,
      (se.shift_slot->>'start_minute')::integer                 AS start_minute,
      (se.shift_slot->>'end_hour')::integer                     AS end_hour,
      (se.shift_slot->>'end_minute')::integer                   AS end_minute
    FROM schedule_entries se
    INNER JOIN schedules s       ON s.id = se.schedule_id
    INNER JOIN active_employees ae ON ae.id = se.employee_id
    WHERE se.date BETWEEN window_start AND effective_date
      AND s.is_active = true
  ),
  merged AS (
    SELECT
      COALESCE(sr.employee_id, df.employee_id)    AS employee_id,
      COALESCE(sr.logical_date, df.logical_date)  AS logical_date,
      (sr.employee_id IS NOT NULL)                AS has_schedule,
      COALESCE(sr.is_day_off, false)              AS is_day_off,
      sr.start_hour,
      sr.start_minute,
      sr.end_hour,
      sr.end_minute,
      df.scan_count,
      df.first_masuk_at,
      df.last_pulang_at,
      df.total_break_minutes,
      df.has_sakit,
      df.has_izin,
      -- Net work minutes (masuk → pulang minus break envelope), clamped to zero.
      CASE
        WHEN df.first_masuk_at IS NOT NULL AND df.last_pulang_at IS NOT NULL
        THEN GREATEST(
               0,
               EXTRACT(EPOCH FROM (df.last_pulang_at - df.first_masuk_at))::integer / 60
               - COALESCE(df.total_break_minutes, 0)
             )::integer
        ELSE NULL
      END                                         AS work_minutes,
      -- Expected shift minutes; handles overnight shifts by adding 24h rollover.
      CASE
        WHEN sr.start_hour IS NOT NULL AND sr.end_hour IS NOT NULL
        THEN
          (CASE
             WHEN make_time(sr.end_hour, sr.end_minute, 0)
                  <= make_time(sr.start_hour, sr.start_minute, 0)
             THEN 24 * 60 + sr.end_hour * 60 + sr.end_minute
             ELSE       sr.end_hour * 60 + sr.end_minute
           END) - (sr.start_hour * 60 + sr.start_minute)
        ELSE NULL
      END                                         AS expected_shift_minutes
    FROM schedule_rows sr
    FULL OUTER JOIN day_facts df
      ON df.employee_id = sr.employee_id
     AND df.logical_date = sr.logical_date
  ),
  with_status AS (
    SELECT
      m.employee_id,
      m.logical_date,
      CASE
        WHEN COALESCE(m.has_sakit, false)                                  THEN 'sakit'
        WHEN COALESCE(m.has_izin, false)                                   THEN 'izin'
        WHEN m.is_day_off                                                  THEN 'libur'
        WHEN m.first_masuk_at IS NOT NULL AND m.last_pulang_at IS NOT NULL THEN 'hadir'
        WHEN m.first_masuk_at IS NOT NULL AND m.last_pulang_at IS NULL
          AND m.logical_date < effective_date                              THEN 'belum_pulang'
        WHEN m.first_masuk_at IS NOT NULL AND m.last_pulang_at IS NULL
          AND m.logical_date = effective_date                              THEN 'sedang_bekerja'
        WHEN m.has_schedule AND NOT m.is_day_off
          AND COALESCE(m.scan_count, 0) = 0
          AND m.logical_date < effective_date                              THEN 'tidak_hadir'
        WHEN m.has_schedule AND NOT m.is_day_off
          AND COALESCE(m.scan_count, 0) = 0
          AND m.logical_date = effective_date                              THEN 'belum_masuk'
        WHEN NOT m.has_schedule AND COALESCE(m.scan_count, 0) > 0          THEN 'hadir'
        ELSE 'none'
      END                                         AS day_status,
      -- Late flag: first masuk after shift_start + 15m grace.
      CASE
        WHEN m.first_masuk_at IS NOT NULL AND m.start_hour IS NOT NULL
          AND m.first_masuk_at >
              (m.logical_date::timestamp
               + ((m.start_hour * 60 + m.start_minute + 15) * interval '1 minute'))
        THEN true
        ELSE false
      END                                         AS is_late_flag,
      -- Short-work flag: completed day with work_minutes under expected - 60m.
      CASE
        WHEN m.work_minutes IS NOT NULL AND m.expected_shift_minutes IS NOT NULL
          AND m.work_minutes < (m.expected_shift_minutes - 60)
        THEN true
        ELSE false
      END                                         AS is_short_work_flag,
      -- Excess-break flag: outer envelope exceeds 90 minutes.
      (COALESCE(m.total_break_minutes, 0) > 90)   AS is_excess_break_flag
    FROM merged m
    WHERE m.has_schedule OR COALESCE(m.scan_count, 0) > 0
  ),
  per_employee AS (
    SELECT
      ws.employee_id,
      COUNT(*) FILTER (WHERE ws.day_status = 'hadir')::integer         AS hadir_count,
      COUNT(*) FILTER (WHERE ws.day_status = 'tidak_hadir')::integer   AS tidak_hadir_count,
      COUNT(*) FILTER (WHERE ws.day_status = 'belum_pulang')::integer  AS belum_pulang_count,
      COUNT(*) FILTER (WHERE ws.day_status = 'sakit')::integer         AS sakit_count,
      COUNT(*) FILTER (WHERE ws.day_status = 'izin')::integer          AS izin_count,
      COUNT(*) FILTER (WHERE ws.is_late_flag)::integer                 AS late_count,
      COUNT(*) FILTER (WHERE ws.is_short_work_flag)::integer           AS short_work_count,
      COUNT(*) FILTER (WHERE ws.is_excess_break_flag)::integer         AS excess_break_count,
      array_agg(ws.day_status ORDER BY ws.logical_date ASC)            AS sparkline
    FROM with_status ws
    GROUP BY ws.employee_id
  )
  SELECT
    ae.id                                          AS employee_id,
    ae.name                                        AS employee_name,
    ae.position                                    AS position,
    o.id                                           AS outlet_id,
    o.name                                         AS outlet_name,
    ae.photo_url                                   AS photo_url,
    COALESCE(es.current_streak, 0)::integer        AS current_streak,
    COALESCE(es.longest_streak, 0)::integer        AS longest_streak,
    COALESCE(pe.hadir_count, 0)::integer           AS hadir_count,
    COALESCE(pe.tidak_hadir_count, 0)::integer     AS tidak_hadir_count,
    COALESCE(pe.belum_pulang_count, 0)::integer    AS belum_pulang_count,
    COALESCE(pe.sakit_count, 0)::integer           AS sakit_count,
    COALESCE(pe.izin_count, 0)::integer            AS izin_count,
    COALESCE(pe.late_count, 0)::integer            AS late_count,
    COALESCE(pe.short_work_count, 0)::integer      AS short_work_count,
    COALESCE(pe.excess_break_count, 0)::integer    AS excess_break_count,
    COALESCE(pe.sparkline, ARRAY[]::text[])        AS sparkline
  FROM active_employees ae
  LEFT JOIN outlets o           ON o.id = ae.home_outlet_id
  LEFT JOIN employee_streaks es ON es.employee_id = ae.id
  LEFT JOIN per_employee pe     ON pe.employee_id = ae.id
  -- Include employees only if they have window activity or an active streak —
  -- keeps the leaderboard focused on people who are actively in rotation.
  WHERE COALESCE(pe.hadir_count, 0)       > 0
     OR COALESCE(pe.tidak_hadir_count, 0) > 0
     OR COALESCE(pe.belum_pulang_count, 0) > 0
     OR COALESCE(pe.sakit_count, 0)       > 0
     OR COALESCE(pe.izin_count, 0)        > 0
     OR COALESCE(es.current_streak, 0)    > 0;

END;
$$;

REVOKE ALL ON FUNCTION get_portal_leaderboard(date, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_portal_leaderboard(date, integer) FROM anon;
GRANT EXECUTE ON FUNCTION get_portal_leaderboard(date, integer) TO authenticated;
