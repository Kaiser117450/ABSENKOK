-- Phase 55: Admin schedule policy recap
-- Additive admin-facing recap RPC for typed lateness / absence policy.
-- Consumes the band-first policy keys backfilled by phase_55_schedule_policy_foundation_20260326.sql.
-- Break-first confirmation is intentionally left as a future signal:
--   Phase 56 will own the explicit confirmation flow, so this patch keeps
--   break_first_confirmed false until a later phase persists that signal.

CREATE INDEX IF NOT EXISTS idx_attendance_logs_outlet_policy_recap
  ON attendance_logs (scan_outlet_id, employee_id, scanned_at, type)
  WHERE scan_outlet_id IS NOT NULL
    AND employee_id IS NOT NULL;

CREATE OR REPLACE FUNCTION get_admin_schedule_policy_recap(
  p_outlet_id uuid,
  p_start_date date,
  p_end_date date
)
RETURNS TABLE (
  logical_date date,
  employee_id uuid,
  employee_name text,
  outlet_id uuid,
  outlet_name text,
  shift_band text,
  required_work_minutes integer,
  late_cutoff_local text,
  break_first_deadline_local text,
  attendance_status text,
  late_kind text,
  is_late boolean,
  break_first_eligible boolean,
  break_first_confirmed boolean,
  first_scan_local timestamp without time zone,
  first_break_local timestamp without time zone,
  last_pulang_local timestamp without time zone,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  business_today date := (NOW() AT TIME ZONE 'Asia/Makassar')::date;
BEGIN
  IF p_start_date IS NULL OR p_end_date IS NULL THEN
    RAISE EXCEPTION 'Start date and end date are required';
  END IF;

  IF p_end_date < p_start_date THEN
    RAISE EXCEPTION 'End date must be on or after start date';
  END IF;

  RETURN QUERY
  WITH schedule_rows AS (
    SELECT
      se.date AS logical_date,
      se.employee_id,
      e.name AS employee_name,
      o.id AS outlet_id,
      o.name AS outlet_name,
      public.resolve_schedule_shift_band(COALESCE(se.shift_slot, '{}'::jsonb)) AS shift_band,
      CASE
        WHEN COALESCE(se.status::text, 'normal') IN ('sakit', 'izin', 'cuti', 'libur')
          THEN COALESCE(se.status::text, 'normal')
        WHEN COALESCE(se.is_day_off, false) THEN 'libur'
        WHEN public.resolve_schedule_shift_band(COALESCE(se.shift_slot, '{}'::jsonb)) = 'LIBUR'
          THEN 'libur'
        ELSE 'normal'
      END AS schedule_status,
      CASE
        WHEN COALESCE(se.status::text, 'normal') IN ('sakit', 'izin', 'cuti', 'libur')
          OR COALESCE(se.is_day_off, false)
          OR public.resolve_schedule_shift_band(COALESCE(se.shift_slot, '{}'::jsonb)) = 'LIBUR'
        THEN 0
        ELSE COALESCE(
          NULLIF(se.shift_slot->>'required_work_minutes', '')::integer,
          public.resolve_schedule_required_work_minutes(
            COALESCE(e.employment_contract, 'FULLTIME'::public.employee_contract)
          )
        )
      END AS required_work_minutes,
      CASE
        WHEN COALESCE(se.status::text, 'normal') IN ('sakit', 'izin', 'cuti', 'libur')
          OR COALESCE(se.is_day_off, false)
          OR public.resolve_schedule_shift_band(COALESCE(se.shift_slot, '{}'::jsonb)) = 'LIBUR'
        THEN NULL
        ELSE public.resolve_schedule_late_cutoff_minutes(
          public.resolve_schedule_shift_band(COALESCE(se.shift_slot, '{}'::jsonb))
        )
      END AS late_cutoff_minutes,
      CASE
        WHEN COALESCE(se.status::text, 'normal') IN ('sakit', 'izin', 'cuti', 'libur')
          OR COALESCE(se.is_day_off, false)
          OR public.resolve_schedule_shift_band(COALESCE(se.shift_slot, '{}'::jsonb)) = 'LIBUR'
        THEN NULL
        ELSE public.resolve_schedule_break_first_deadline_minutes(
          public.resolve_schedule_shift_band(COALESCE(se.shift_slot, '{}'::jsonb)),
          COALESCE(e.employment_contract, 'FULLTIME'::public.employee_contract)
        )
      END AS break_first_deadline_minutes,
      NULLIF(BTRIM(se.notes), '') AS schedule_notes
    FROM schedule_entries se
    INNER JOIN schedules s ON s.id = se.schedule_id
    INNER JOIN employees e ON e.id = se.employee_id
    INNER JOIN outlets o ON o.id = s.outlet_id
    WHERE s.is_active = true
      AND s.outlet_id = p_outlet_id
      AND se.date BETWEEN p_start_date AND p_end_date
      AND e.is_active = true
      AND e.archived_at IS NULL
  ),
  attendance_rows AS (
    SELECT
      (al.scanned_at AT TIME ZONE 'Asia/Makassar')::date AS logical_date,
      al.employee_id,
      e.name AS employee_name,
      o.id AS outlet_id,
      o.name AS outlet_name,
      COUNT(*)::integer AS scan_count,
      MIN(al.scanned_at AT TIME ZONE 'Asia/Makassar') AS first_scan_local,
      MIN(al.scanned_at AT TIME ZONE 'Asia/Makassar') FILTER (WHERE al.type = 'break') AS first_break_local,
      MAX(al.scanned_at AT TIME ZONE 'Asia/Makassar') FILTER (WHERE al.type = 'pulang') AS last_pulang_local,
      bool_or(al.type = 'sakit') AS has_sakit,
      bool_or(al.type = 'izin') AS has_izin,
      string_agg(
        DISTINCT NULLIF(BTRIM(al.notes), ''),
        ' | '
      ) FILTER (WHERE al.notes IS NOT NULL AND BTRIM(al.notes) <> '') AS attendance_notes
    FROM attendance_logs al
    INNER JOIN employees e ON e.id = al.employee_id
    INNER JOIN outlets o ON o.id = al.scan_outlet_id
    WHERE al.scan_outlet_id = p_outlet_id
      AND al.scanned_at >= (p_start_date::timestamp AT TIME ZONE 'Asia/Makassar')
      AND al.scanned_at < ((p_end_date + 1)::timestamp AT TIME ZONE 'Asia/Makassar')
      AND e.is_active = true
      AND e.archived_at IS NULL
    GROUP BY
      (al.scanned_at AT TIME ZONE 'Asia/Makassar')::date,
      al.employee_id,
      e.name,
      o.id,
      o.name
  ),
  merged_keys AS (
    SELECT logical_date, employee_id FROM schedule_rows
    UNION
    SELECT logical_date, employee_id FROM attendance_rows
  ),
  merged AS (
    SELECT
      k.logical_date,
      k.employee_id,
      sr.employee_name AS schedule_employee_name,
      ar.employee_name AS attendance_employee_name,
      sr.outlet_id AS schedule_outlet_id,
      ar.outlet_id AS attendance_outlet_id,
      sr.outlet_name AS schedule_outlet_name,
      ar.outlet_name AS attendance_outlet_name,
      sr.shift_band,
      sr.schedule_status,
      sr.required_work_minutes,
      sr.late_cutoff_minutes,
      sr.break_first_deadline_minutes,
      ar.scan_count,
      ar.first_scan_local,
      ar.first_break_local,
      ar.last_pulang_local,
      ar.has_sakit,
      ar.has_izin,
      sr.schedule_notes,
      ar.attendance_notes
    FROM merged_keys k
    LEFT JOIN schedule_rows sr
      ON sr.logical_date = k.logical_date
     AND sr.employee_id = k.employee_id
    LEFT JOIN attendance_rows ar
      ON ar.logical_date = k.logical_date
     AND ar.employee_id = k.employee_id
  )
  SELECT
    m.logical_date,
    m.employee_id,
    COALESCE(m.schedule_employee_name, m.attendance_employee_name) AS employee_name,
    COALESCE(m.schedule_outlet_id, m.attendance_outlet_id, p_outlet_id) AS outlet_id,
    COALESCE(m.schedule_outlet_name, m.attendance_outlet_name) AS outlet_name,
    m.shift_band,
    m.required_work_minutes,
    CASE
      WHEN m.late_cutoff_minutes IS NULL THEN NULL
      ELSE LPAD((m.late_cutoff_minutes / 60)::text, 2, '0')
           || ':' ||
           LPAD((m.late_cutoff_minutes % 60)::text, 2, '0')
    END AS late_cutoff_local,
    CASE
      WHEN m.break_first_deadline_minutes IS NULL THEN NULL
      ELSE LPAD((m.break_first_deadline_minutes / 60)::text, 2, '0')
           || ':' ||
           LPAD((m.break_first_deadline_minutes % 60)::text, 2, '0')
    END AS break_first_deadline_local,
    CASE
      WHEN COALESCE(m.has_sakit, false) OR m.schedule_status = 'sakit' THEN 'sakit'
      WHEN COALESCE(m.has_izin, false) OR m.schedule_status = 'izin' THEN 'izin'
      WHEN m.schedule_status = 'cuti' THEN 'cuti'
      WHEN m.schedule_status = 'libur' THEN 'libur'
      WHEN m.schedule_employee_name IS NOT NULL
        AND COALESCE(m.scan_count, 0) = 0
        AND m.logical_date < business_today THEN 'tidak_hadir'
      WHEN m.schedule_employee_name IS NOT NULL
        AND COALESCE(m.scan_count, 0) = 0
        AND m.logical_date >= business_today THEN 'belum_masuk'
      WHEN m.schedule_employee_name IS NOT NULL
        AND COALESCE(m.scan_count, 0) > 0 THEN 'hadir'
      WHEN m.schedule_employee_name IS NULL
        AND COALESCE(m.scan_count, 0) > 0 THEN 'hadir_tanpa_jadwal'
      ELSE NULL
    END AS attendance_status,
    CASE
      WHEN COALESCE(m.has_sakit, false) OR m.schedule_status = 'sakit'
        OR COALESCE(m.has_izin, false) OR m.schedule_status = 'izin'
        OR m.schedule_status IN ('cuti', 'libur')
        OR m.schedule_employee_name IS NULL
        OR COALESCE(m.scan_count, 0) = 0
      THEN 'none'
      WHEN m.first_scan_local IS NOT NULL
        AND m.late_cutoff_minutes IS NOT NULL
        AND (EXTRACT(HOUR FROM m.first_scan_local)::integer * 60
             + EXTRACT(MINUTE FROM m.first_scan_local)::integer) > m.late_cutoff_minutes
        AND m.break_first_deadline_minutes IS NOT NULL
        AND (EXTRACT(HOUR FROM m.first_scan_local)::integer * 60
             + EXTRACT(MINUTE FROM m.first_scan_local)::integer) <= m.break_first_deadline_minutes
      THEN 'break_first_eligible'
      WHEN m.first_scan_local IS NOT NULL
        AND m.late_cutoff_minutes IS NOT NULL
        AND (EXTRACT(HOUR FROM m.first_scan_local)::integer * 60
             + EXTRACT(MINUTE FROM m.first_scan_local)::integer) > m.late_cutoff_minutes
      THEN 'normal'
      ELSE 'none'
    END AS late_kind,
    CASE
      WHEN COALESCE(m.has_sakit, false) OR m.schedule_status = 'sakit'
        OR COALESCE(m.has_izin, false) OR m.schedule_status = 'izin'
        OR m.schedule_status IN ('cuti', 'libur')
        OR m.schedule_employee_name IS NULL
        OR COALESCE(m.scan_count, 0) = 0
      THEN false
      WHEN m.first_scan_local IS NOT NULL
        AND m.late_cutoff_minutes IS NOT NULL
        AND (EXTRACT(HOUR FROM m.first_scan_local)::integer * 60
             + EXTRACT(MINUTE FROM m.first_scan_local)::integer) > m.late_cutoff_minutes
      THEN true
      ELSE false
    END AS is_late,
    CASE
      WHEN COALESCE(m.has_sakit, false) OR m.schedule_status = 'sakit'
        OR COALESCE(m.has_izin, false) OR m.schedule_status = 'izin'
        OR m.schedule_status IN ('cuti', 'libur')
        OR m.schedule_employee_name IS NULL
        OR COALESCE(m.scan_count, 0) = 0
      THEN false
      WHEN m.first_scan_local IS NOT NULL
        AND m.late_cutoff_minutes IS NOT NULL
        AND (EXTRACT(HOUR FROM m.first_scan_local)::integer * 60
             + EXTRACT(MINUTE FROM m.first_scan_local)::integer) > m.late_cutoff_minutes
        AND m.break_first_deadline_minutes IS NOT NULL
        AND (EXTRACT(HOUR FROM m.first_scan_local)::integer * 60
             + EXTRACT(MINUTE FROM m.first_scan_local)::integer) <= m.break_first_deadline_minutes
      THEN true
      ELSE false
    END AS break_first_eligible,
    false AS break_first_confirmed,
    m.first_scan_local,
    m.first_break_local,
    m.last_pulang_local,
    NULLIF(
      concat_ws(' | ', m.schedule_notes, m.attendance_notes),
      ''
    ) AS notes
  FROM merged m
  ORDER BY m.logical_date DESC, COALESCE(m.schedule_employee_name, m.attendance_employee_name), m.employee_id;
END;
$$;

REVOKE ALL ON FUNCTION get_admin_schedule_policy_recap(uuid, date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_admin_schedule_policy_recap(uuid, date, date) TO authenticated;
