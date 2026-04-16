-- Phase 63: Fix stale last_event for sakit-then-no-pulang scenario
--
-- Bug: When an employee clocks in (masuk at 08:30) then gets sick and leaves
-- WITHOUT scanning pulang, admin marks them as sakit via the dialog which
-- anchors scanned_at = 08:00. Because 08:30 > 08:00, ORDER BY scanned_at DESC
-- returns 'masuk' as last_event — not 'sakit'. The next day, with no date
-- filter on last_event, that stale 'masuk' persists and the kiosk shows
-- ISTIRAHAT+PULANG instead of MASUK.
--
-- Root cause: last_event CTE had no date filter — any historical log could
-- pollute the next day's scan context.
--
-- Fix: Scope last_event to today's logical_date (plus yesterday for overnight
-- 24-hour outlets, consistent with the existing v_overnight_lookback_date
-- logic from phase_57). If no log exists for today, last_event = NULL →
-- Flutter shows MASUK (fresh start).

CREATE OR REPLACE FUNCTION public.get_kiosk_scan_context(
  p_employee_id uuid,
  p_outlet_id uuid,
  p_device_id text
)
RETURNS TABLE (
  server_now_utc timestamptz,
  server_now_wita_label text,
  logical_date date,
  last_authoritative_type text,
  last_authoritative_scanned_at timestamptz,
  shift_band text,
  employment_contract text,
  late_cutoff_local text,
  break_first_deadline_local text,
  break_first_eligible boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_server_now_utc timestamptz := statement_timestamp();
  v_server_now_local timestamp without time zone :=
    v_server_now_utc AT TIME ZONE 'Asia/Makassar';
  v_logical_date date := v_server_now_local::date;
  v_overnight_lookback_date date := NULL;
  v_outlet_mode text := NULL;
BEGIN
  IF p_employee_id IS NULL
      OR p_outlet_id IS NULL
      OR COALESCE(BTRIM(p_device_id), '') = '' THEN
    RAISE EXCEPTION 'employee, outlet, and device identifiers are required';
  END IF;

  -- Overnight shift support: For 24-hour outlets, check previous date
  -- when current time is between midnight and 6AM
  IF EXTRACT(HOUR FROM v_server_now_local) < 6 THEN
    SELECT o.operating_mode INTO v_outlet_mode
    FROM public.outlets o WHERE o.id = p_outlet_id;
    IF v_outlet_mode = 'TWENTY_FOUR_HOUR' THEN
      v_overnight_lookback_date := v_logical_date - 1;
    END IF;
  END IF;

  RETURN QUERY
  WITH employee_row AS (
    SELECT
      COALESCE(
        e.employment_contract,
        'FULLTIME'::public.employee_contract
      ) AS employment_contract
    FROM public.employees e
    WHERE e.id = p_employee_id
    LIMIT 1
  ),
  schedule_row AS (
    SELECT
      public.resolve_schedule_shift_band(
        COALESCE(se.shift_slot, '{}'::jsonb)
      ) AS shift_band,
      public.resolve_schedule_late_cutoff_minutes(
        public.resolve_schedule_shift_band(
          COALESCE(se.shift_slot, '{}'::jsonb)
        )
      ) AS late_cutoff_minutes,
      public.resolve_schedule_break_first_deadline_minutes(
        public.resolve_schedule_shift_band(
          COALESCE(se.shift_slot, '{}'::jsonb)
        ),
        COALESCE(
          er.employment_contract,
          'FULLTIME'::public.employee_contract
        )
      ) AS break_first_deadline_minutes
    FROM public.schedule_entries se
    INNER JOIN public.schedules s
      ON s.id = se.schedule_id
    LEFT JOIN employee_row er
      ON true
    WHERE s.is_active = true
      AND s.outlet_id = p_outlet_id
      AND se.employee_id = p_employee_id
      AND (se.date = v_logical_date
           OR (v_overnight_lookback_date IS NOT NULL
               AND se.date = v_overnight_lookback_date))
    ORDER BY se.date DESC, se.id DESC
    LIMIT 1
  ),
  last_event AS (
    SELECT
      al.type,
      al.scanned_at
    FROM public.attendance_logs al
    WHERE al.employee_id = p_employee_id
      AND al.scan_outlet_id = p_outlet_id
      -- FIX: scope to today (+ yesterday for overnight) so stale events
      -- from previous days never bleed into the current day's scan context.
      AND (
        (al.scanned_at AT TIME ZONE 'Asia/Makassar')::date = v_logical_date
        OR (v_overnight_lookback_date IS NOT NULL
            AND (al.scanned_at AT TIME ZONE 'Asia/Makassar')::date = v_overnight_lookback_date)
      )
    ORDER BY al.scanned_at DESC, al.id DESC
    LIMIT 1
  ),
  relevant_counts AS (
    SELECT
      COUNT(*)::integer AS relevant_count
    FROM public.attendance_logs al
    WHERE al.employee_id = p_employee_id
      AND al.scan_outlet_id = p_outlet_id
      AND (al.scanned_at AT TIME ZONE 'Asia/Makassar')::date = v_logical_date
      AND al.type IN ('masuk', 'break', 'pulang', 'kembali')
  )
  SELECT
    v_server_now_utc,
    to_char(v_server_now_local, 'HH24:MI "WITA"'),
    v_logical_date,
    le.type,
    le.scanned_at,
    sr.shift_band,
    COALESCE(
      er.employment_contract,
      'FULLTIME'::public.employee_contract
    )::text,
    CASE
      WHEN sr.late_cutoff_minutes IS NULL THEN NULL
      ELSE LPAD((sr.late_cutoff_minutes / 60)::text, 2, '0')
           || ':' ||
           LPAD((sr.late_cutoff_minutes % 60)::text, 2, '0')
    END AS late_cutoff_local,
    CASE
      WHEN sr.break_first_deadline_minutes IS NULL THEN NULL
      ELSE LPAD((sr.break_first_deadline_minutes / 60)::text, 2, '0')
           || ':' ||
           LPAD((sr.break_first_deadline_minutes % 60)::text, 2, '0')
    END AS break_first_deadline_local,
    CASE
      WHEN COALESCE(rc.relevant_count, 0) > 0 THEN false
      WHEN sr.late_cutoff_minutes IS NULL
        OR sr.break_first_deadline_minutes IS NULL THEN false
      ELSE (
        (EXTRACT(HOUR FROM v_server_now_local)::integer * 60
          + EXTRACT(MINUTE FROM v_server_now_local)::integer)
          > sr.late_cutoff_minutes
        AND
        (EXTRACT(HOUR FROM v_server_now_local)::integer * 60
          + EXTRACT(MINUTE FROM v_server_now_local)::integer)
          <= sr.break_first_deadline_minutes
      )
    END AS break_first_eligible
  FROM relevant_counts rc
  LEFT JOIN employee_row er
    ON true
  LEFT JOIN schedule_row sr
    ON true
  LEFT JOIN last_event le
    ON true;
END;
$$;

REVOKE ALL ON FUNCTION public.get_kiosk_scan_context(uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_kiosk_scan_context(uuid, uuid, text) TO authenticated;
