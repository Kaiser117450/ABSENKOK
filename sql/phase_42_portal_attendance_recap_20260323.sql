-- Phase 42: Portal Attendance Recap Read Model
-- Goal: Additive employee-scoped portal attendance recap RPC + supporting index
-- Depends on:
--   phase_38_employee_schedule_read_model_20260322.sql (schedule_entries index, schedules index)
--   phase_39_portal_read_path_hardening_20260323.sql   (resolve_portal_employee, authenticated ACL)
-- Safe to re-run (IF NOT EXISTS index guard, CREATE OR REPLACE FUNCTION)

-- ── 1. Query-shaped attendance index for employee-scoped recap reads ────────────

-- Composite index on attendance_logs (employee_id, scanned_at, type).
-- Supports the recap window scan that filters by employee and time range,
-- then groups by attendance type to build per-day day facts.
CREATE INDEX IF NOT EXISTS idx_attendance_logs_employee_recap
  ON attendance_logs (employee_id, scanned_at, type)
  WHERE employee_id IS NOT NULL;

-- ── 2. get_portal_attendance_recap RPC ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_portal_attendance_recap(reference_date date DEFAULT NULL)
RETURNS TABLE (
  logical_date        date,
  has_schedule        boolean,
  is_day_off          boolean,
  outlet_id           uuid,
  outlet_name         text,
  shift_name          text,
  start_hour          integer,
  start_minute        integer,
  end_hour            integer,
  end_minute          integer,
  ends_next_day       boolean,
  attendance_status   text,
  first_masuk_at      timestamptz,
  first_break_at      timestamptz,
  last_kembali_at     timestamptz,
  last_pulang_at      timestamptz,
  total_break_minutes integer,
  work_minutes        integer,
  scan_count          integer,
  notes               text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  resolved_employee_id  uuid;
  effective_date        date;
  month_start           date;
  history_start         date;
BEGIN
  -- Resolve the employee from the authenticated portal session.
  -- Never accepts employee_id, outlet_id, or any other caller-controlled identity.
  SELECT r.employee_id
  INTO resolved_employee_id
  FROM resolve_portal_employee() AS r
  LIMIT 1;

  IF resolved_employee_id IS NULL THEN
    RAISE EXCEPTION 'No active employee found for this portal account';
  END IF;

  -- Business-local reference date (WITA = Asia/Makassar, UTC+8).
  -- Caller may supply a reference date to support server-side rendering without UTC drift.
  effective_date := COALESCE(reference_date, (NOW() AT TIME ZONE 'Asia/Makassar')::date);

  -- History horizon: covers month-to-date counts AND at least 14 days of recent history.
  -- history_start = earlier of month_start or effective_date - 13 days.
  month_start   := date_trunc('month', effective_date)::date;
  history_start := LEAST(month_start, effective_date - 13);

  RETURN QUERY
  WITH

  -- ── Raw attendance facts for this employee within the recap window ──────────
  raw_logs AS (
    SELECT
      al.id,
      al.type,
      al.scanned_at,
      al.scan_outlet_id,
      al.notes,
      -- Local business date for each scan (WITA)
      (al.scanned_at AT TIME ZONE 'Asia/Makassar')::date AS local_date,
      (al.scanned_at AT TIME ZONE 'Asia/Makassar')        AS local_ts,
      EXTRACT(HOUR FROM (al.scanned_at AT TIME ZONE 'Asia/Makassar'))::integer AS local_hour
    FROM attendance_logs al
    WHERE al.employee_id = resolved_employee_id
      -- Fetch one extra day before history_start to support overnight pulang repair.
      AND al.scanned_at >= ((history_start - 1)::timestamptz AT TIME ZONE 'Asia/Makassar')
      AND al.scanned_at <  ((effective_date  + 1)::timestamptz AT TIME ZONE 'Asia/Makassar')
  ),

  -- ── Overnight pulang repair ────────────────────────────────────────────────
  -- Mirrors the shipped admin Rekap Harian logic:
  --   Orphan next-day pulang scans before noon are re-attached to the prior
  --   logical day ONLY when the prior day already has a masuk scan.
  --   This is NOT a blanket "hour < 12 means yesterday" rule — it only fires
  --   when the current day has no masuk scan (orphan group) and the pulang is
  --   before noon.
  --
  -- Step 1: Find which local_dates have a masuk scan.
  dates_with_masuk AS (
    SELECT DISTINCT local_date
    FROM raw_logs
    WHERE type = 'masuk'
  ),

  -- Step 2: Find orphan pulang groups — days with pulang before noon and no masuk.
  orphan_pulang_days AS (
    SELECT DISTINCT local_date AS orphan_date
    FROM raw_logs
    WHERE type = 'pulang'
      AND local_hour < 12
      AND local_date NOT IN (SELECT local_date FROM dates_with_masuk)
      -- Prior day (the repair target) must have a masuk to be valid.
      AND (local_date - 1) IN (SELECT local_date FROM dates_with_masuk)
  ),

  -- Step 3: Build the repaired log view: reassign orphan pulang scans to prior day.
  repaired_logs AS (
    SELECT
      rl.type,
      rl.scanned_at,
      rl.scan_outlet_id,
      rl.notes,
      rl.local_ts,
      CASE
        WHEN rl.type = 'pulang'
          AND rl.local_hour < 12
          AND rl.local_date IN (SELECT orphan_date FROM orphan_pulang_days)
        THEN rl.local_date - 1  -- repair: move to prior logical day
        ELSE rl.local_date
      END AS logical_date
    FROM raw_logs rl
  ),

  -- ── Per-logical-day attendance day facts ──────────────────────────────────
  day_facts AS (
    SELECT
      rl.logical_date,
      COUNT(*)::integer                                            AS scan_count,
      MIN(rl.local_ts) FILTER (WHERE rl.type = 'masuk')           AS first_masuk_at,
      MIN(rl.local_ts) FILTER (WHERE rl.type = 'break')           AS first_break_at,
      MAX(rl.local_ts) FILTER (WHERE rl.type = 'kembali')         AS last_kembali_at,
      MAX(rl.local_ts) FILTER (WHERE rl.type = 'pulang')          AS last_pulang_at,
      bool_or(rl.type = 'sakit')                                  AS has_sakit,
      bool_or(rl.type = 'izin')                                   AS has_izin,
      -- Total break duration: sum of paired (break → kembali) intervals.
      -- Approximated here as: each break scan is paired with the next kembali scan
      -- on the same day. We use a simple aggregate: (count of kembali - count of break)
      -- is not reliable for partial pairs, so we calculate from first_break / last_kembali
      -- as the outer envelope when both are present, else 0.
      -- This matches the admin Rekap Harian approximation (total_break ≈ outer envelope).
      CASE
        WHEN MIN(rl.local_ts) FILTER (WHERE rl.type = 'break') IS NOT NULL
          AND MAX(rl.local_ts) FILTER (WHERE rl.type = 'kembali') IS NOT NULL
        THEN EXTRACT(EPOCH FROM (
               MAX(rl.local_ts) FILTER (WHERE rl.type = 'kembali')
               - MIN(rl.local_ts) FILTER (WHERE rl.type = 'break')
             ))::integer / 60
        ELSE 0
      END                                                          AS total_break_minutes,
      string_agg(
        DISTINCT NULLIF(btrim(rl.notes), ''),
        ' | '
      ) FILTER (WHERE rl.notes IS NOT NULL AND btrim(rl.notes) <> '')
                                                                   AS attendance_notes
    FROM repaired_logs rl
    WHERE rl.logical_date BETWEEN history_start AND effective_date
    GROUP BY rl.logical_date
  ),

  -- ── Schedule context: one row per scheduled logical day ───────────────────
  schedule_rows AS (
    SELECT
      se.date                                                       AS logical_date,
      o.id                                                          AS outlet_id,
      o.name                                                        AS outlet_name,
      (se.shift_slot->>'name')::text                                AS shift_name,
      (se.shift_slot->>'start_hour')::integer                       AS start_hour,
      (se.shift_slot->>'start_minute')::integer                     AS start_minute,
      (se.shift_slot->>'end_hour')::integer                         AS end_hour,
      (se.shift_slot->>'end_minute')::integer                       AS end_minute,
      COALESCE(se.is_day_off, false)                                AS is_day_off,
      CASE
        WHEN COALESCE(se.is_day_off, false) THEN false
        WHEN make_time(
               (se.shift_slot->>'end_hour')::integer,
               (se.shift_slot->>'end_minute')::integer, 0
             ) <= make_time(
                    (se.shift_slot->>'start_hour')::integer,
                    (se.shift_slot->>'start_minute')::integer, 0
                  ) THEN true
        ELSE false
      END                                                           AS ends_next_day,
      NULLIF(btrim(se.notes), '')                                   AS schedule_notes
    FROM schedule_entries se
    INNER JOIN schedules s ON s.id = se.schedule_id
    INNER JOIN outlets o   ON o.id = s.outlet_id
    WHERE se.employee_id = resolved_employee_id
      AND se.date BETWEEN history_start AND effective_date
      AND s.is_active = true
  ),

  -- ── Merge: full outer join of schedule rows and attendance day facts ───────
  -- Preserves:
  --   - scheduled days with attendance
  --   - scheduled days without attendance (no-scan days)
  --   - attendance-only days when logs exist without a matching schedule row
  merged AS (
    SELECT
      COALESCE(sr.logical_date, df.logical_date)    AS logical_date,
      (sr.logical_date IS NOT NULL)                 AS has_schedule,
      COALESCE(sr.is_day_off, false)                AS is_day_off,
      sr.outlet_id,
      sr.outlet_name,
      sr.shift_name,
      sr.start_hour,
      sr.start_minute,
      sr.end_hour,
      sr.end_minute,
      COALESCE(sr.ends_next_day, false)             AS ends_next_day,
      df.scan_count,
      df.first_masuk_at,
      df.first_break_at,
      df.last_kembali_at,
      df.last_pulang_at,
      df.total_break_minutes,
      df.has_sakit,
      df.has_izin,
      -- work_minutes: masuk → pulang minus total_break, clamped to zero.
      CASE
        WHEN df.first_masuk_at IS NOT NULL AND df.last_pulang_at IS NOT NULL
        THEN GREATEST(
               0,
               EXTRACT(EPOCH FROM (df.last_pulang_at - df.first_masuk_at))::integer / 60
               - COALESCE(df.total_break_minutes, 0)
             )::integer
        ELSE NULL
      END                                           AS work_minutes,
      NULLIF(
        concat_ws(' | ', sr.schedule_notes, df.attendance_notes),
        ''
      )                                             AS notes
    FROM schedule_rows sr
    FULL OUTER JOIN day_facts df ON df.logical_date = sr.logical_date
  ),

  -- ── Day-status derivation ──────────────────────────────────────────────────
  -- Covers:
  --   hadir          — present with masuk and pulang
  --   sakit          — sakit scan logged
  --   izin           — izin scan logged
  --   belum_pulang   — has masuk but no pulang yet; suppressed for the active day
  --                    so that the current workday is not falsely flagged incomplete
  --   tidak_hadir    — scheduled workday with no attendance at all
  --   libur          — scheduled day-off
  --   (null)         — unscheduled day with no attendance (should not appear in output)
  with_status AS (
    SELECT
      m.logical_date,
      m.has_schedule,
      m.is_day_off,
      m.outlet_id,
      m.outlet_name,
      m.shift_name,
      m.start_hour,
      m.start_minute,
      m.end_hour,
      m.end_minute,
      m.ends_next_day,
      CASE
        WHEN COALESCE(m.has_sakit, false)                              THEN 'sakit'
        WHEN COALESCE(m.has_izin, false)                               THEN 'izin'
        WHEN m.is_day_off                                              THEN 'libur'
        WHEN m.first_masuk_at IS NOT NULL AND m.last_pulang_at IS NOT NULL
                                                                       THEN 'hadir'
        -- belum_pulang: has masuk but no pulang yet.
        -- Suppressed for the current effective_date to avoid false alarms
        -- while the employee may still be working.
        WHEN m.first_masuk_at IS NOT NULL
          AND m.last_pulang_at IS NULL
          AND m.logical_date < effective_date                          THEN 'belum_pulang'
        WHEN m.first_masuk_at IS NOT NULL
          AND m.last_pulang_at IS NULL
          AND m.logical_date = effective_date                          THEN 'sedang_bekerja'
        WHEN m.has_schedule AND NOT m.is_day_off
          AND COALESCE(m.scan_count, 0) = 0
          AND m.logical_date < effective_date                          THEN 'tidak_hadir'
        WHEN m.has_schedule AND NOT m.is_day_off
          AND COALESCE(m.scan_count, 0) = 0
          AND m.logical_date = effective_date                          THEN 'belum_masuk'
        WHEN NOT m.has_schedule AND COALESCE(m.scan_count, 0) > 0     THEN 'hadir'
        ELSE NULL
      END                                                              AS attendance_status,
      m.first_masuk_at,
      m.first_break_at,
      m.last_kembali_at,
      m.last_pulang_at,
      COALESCE(m.total_break_minutes, 0)::integer                     AS total_break_minutes,
      m.work_minutes,
      COALESCE(m.scan_count, 0)::integer                              AS scan_count,
      m.notes
    FROM merged m
    -- Exclude days with no schedule and no attendance (ghost rows from FULL OUTER JOIN edge).
    WHERE m.has_schedule OR COALESCE(m.scan_count, 0) > 0
  )

  SELECT
    ws.logical_date,
    ws.has_schedule,
    ws.is_day_off,
    ws.outlet_id,
    ws.outlet_name,
    ws.shift_name,
    ws.start_hour,
    ws.start_minute,
    ws.end_hour,
    ws.end_minute,
    ws.ends_next_day,
    ws.attendance_status,
    ws.first_masuk_at,
    ws.first_break_at,
    ws.last_kembali_at,
    ws.last_pulang_at,
    ws.total_break_minutes,
    ws.work_minutes,
    ws.scan_count,
    ws.notes
  FROM with_status ws
  ORDER BY ws.logical_date DESC;

END;
$$;

-- ── 3. Security: revoke public access, grant only to authenticated ───────────

REVOKE ALL ON FUNCTION get_portal_attendance_recap(date) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_portal_attendance_recap(date) FROM anon;
GRANT EXECUTE ON FUNCTION get_portal_attendance_recap(date) TO authenticated;
