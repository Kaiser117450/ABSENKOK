-- Phase 56: Server-Time Scan Authority
-- Additive-only patch: introduces authoritative kiosk scan RPCs, preserves
-- existing attendance rows, and upgrades recap truth without destructive
-- rewrites.
--
-- IMPORTANT: Review and apply manually in Supabase SQL Editor.
-- Requires explicit user approval before production execution.

-- 1. Add authoritative capture and replay provenance columns.

ALTER TABLE public.attendance_logs
  ADD COLUMN IF NOT EXISTS device_captured_at timestamptz;

ALTER TABLE public.attendance_logs
  ADD COLUMN IF NOT EXISTS capture_mode text NOT NULL DEFAULT 'live';

ALTER TABLE public.attendance_logs
  ADD COLUMN IF NOT EXISTS queue_order bigint;

ALTER TABLE public.attendance_logs
  ADD COLUMN IF NOT EXISTS initial_scan_intent text NOT NULL DEFAULT 'none';

ALTER TABLE public.attendance_logs
  ADD COLUMN IF NOT EXISTS requires_admin_review boolean NOT NULL DEFAULT false;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'attendance_logs_capture_mode_check'
  ) THEN
    ALTER TABLE public.attendance_logs
      ADD CONSTRAINT attendance_logs_capture_mode_check
      CHECK (capture_mode IN ('live', 'queued'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'attendance_logs_initial_scan_intent_check'
  ) THEN
    ALTER TABLE public.attendance_logs
      ADD CONSTRAINT attendance_logs_initial_scan_intent_check
      CHECK (initial_scan_intent IN ('none', 'break_first'));
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_logs_local_id_unique
  ON public.attendance_logs (local_id)
  WHERE local_id IS NOT NULL;

-- 2. Lightweight authoritative context RPC for kiosk action resolution.

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
BEGIN
  IF p_employee_id IS NULL
      OR p_outlet_id IS NULL
      OR COALESCE(BTRIM(p_device_id), '') = '' THEN
    RAISE EXCEPTION 'employee, outlet, and device identifiers are required';
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
      AND se.date = v_logical_date
    ORDER BY se.id DESC
    LIMIT 1
  ),
  last_event AS (
    SELECT
      al.type,
      al.scanned_at
    FROM public.attendance_logs al
    WHERE al.employee_id = p_employee_id
      AND al.scan_outlet_id = p_outlet_id
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

-- 3. Authoritative scan insert RPC.

CREATE OR REPLACE FUNCTION public.record_kiosk_scan(
  p_employee_id uuid,
  p_outlet_id uuid,
  p_device_id text,
  p_type text,
  p_local_id text DEFAULT NULL,
  p_capture_mode text DEFAULT 'live',
  p_device_captured_at timestamptz DEFAULT NULL,
  p_queue_order bigint DEFAULT NULL,
  p_initial_scan_intent text DEFAULT 'none',
  p_is_backup boolean DEFAULT false,
  p_notes text DEFAULT NULL,
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL
)
RETURNS TABLE (
  authority_state text,
  scanned_at_utc timestamptz,
  scanned_at_wita_label text,
  recorded_type text,
  initial_scan_intent text,
  requires_admin_review boolean
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_scanned_at_utc timestamptz;
  v_scanned_at_local timestamp without time zone;
  v_effective_local timestamp without time zone;
  v_effective_logical_date date;
  v_employee_contract public.employee_contract := 'FULLTIME'::public.employee_contract;
  v_shift_band text;
  v_late_cutoff_minutes integer;
  v_break_first_deadline_minutes integer;
  v_previous_queue_order bigint;
  v_prior_relevant_count integer := 0;
  v_requires_admin_review boolean := false;
BEGIN
  IF p_employee_id IS NULL
      OR p_outlet_id IS NULL
      OR COALESCE(BTRIM(p_device_id), '') = ''
      OR COALESCE(BTRIM(p_type), '') = '' THEN
    RAISE EXCEPTION 'employee, outlet, device, and type are required';
  END IF;

  IF p_type NOT IN ('masuk', 'break', 'pulang', 'kembali', 'sakit', 'izin') THEN
    RAISE EXCEPTION 'Unsupported attendance type: %', p_type;
  END IF;

  IF p_capture_mode NOT IN ('live', 'queued') THEN
    RAISE EXCEPTION 'Unsupported capture mode: %', p_capture_mode;
  END IF;

  IF p_initial_scan_intent NOT IN ('none', 'break_first') THEN
    RAISE EXCEPTION 'Unsupported initial scan intent: %', p_initial_scan_intent;
  END IF;

  IF p_local_id IS NOT NULL THEN
    RETURN QUERY
    SELECT
      'duplicate_local_id'::text,
      al.scanned_at,
      to_char(al.scanned_at AT TIME ZONE 'Asia/Makassar', 'HH24:MI "WITA"'),
      al.type,
      COALESCE(al.initial_scan_intent, 'none'),
      COALESCE(al.requires_admin_review, false)
    FROM public.attendance_logs al
    WHERE al.local_id = p_local_id
    ORDER BY al.scanned_at DESC, al.id DESC
    LIMIT 1;

    IF FOUND THEN
      RETURN;
    END IF;
  END IF;

  v_scanned_at_utc := statement_timestamp();
  v_scanned_at_local := v_scanned_at_utc AT TIME ZONE 'Asia/Makassar';
  v_effective_local := COALESCE(
    p_device_captured_at AT TIME ZONE 'Asia/Makassar',
    v_scanned_at_local
  );
  v_effective_logical_date := v_effective_local::date;

  SELECT
    COALESCE(er.employment_contract, 'FULLTIME'::public.employee_contract),
    sr.shift_band,
    sr.late_cutoff_minutes,
    sr.break_first_deadline_minutes
  INTO
    v_employee_contract,
    v_shift_band,
    v_late_cutoff_minutes,
    v_break_first_deadline_minutes
  FROM (
    SELECT
      COALESCE(
        e.employment_contract,
        'FULLTIME'::public.employee_contract
      ) AS employment_contract
    FROM public.employees e
    WHERE e.id = p_employee_id
    LIMIT 1
  ) er
  LEFT JOIN LATERAL (
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
    WHERE s.is_active = true
      AND s.outlet_id = p_outlet_id
      AND se.employee_id = p_employee_id
      AND se.date = v_effective_logical_date
    ORDER BY se.id DESC
    LIMIT 1
  ) sr
    ON true;

  IF p_capture_mode = 'queued' THEN
    SELECT MAX(al.queue_order)
    INTO v_previous_queue_order
    FROM public.attendance_logs al
    WHERE al.device_id = p_device_id
      AND al.scan_outlet_id = p_outlet_id
      AND al.queue_order IS NOT NULL;

    SELECT COUNT(*)::integer
    INTO v_prior_relevant_count
    FROM public.attendance_logs al
    WHERE al.employee_id = p_employee_id
      AND al.scan_outlet_id = p_outlet_id
      AND (al.scanned_at AT TIME ZONE 'Asia/Makassar')::date = v_effective_logical_date
      AND al.type IN ('masuk', 'break', 'pulang', 'kembali');

    IF p_queue_order IS NULL OR p_device_captured_at IS NULL THEN
      v_requires_admin_review := true;
    END IF;

    IF p_queue_order IS NOT NULL
        AND COALESCE(v_previous_queue_order, 0) >= p_queue_order THEN
      v_requires_admin_review := true;
    END IF;

    IF p_initial_scan_intent = 'break_first' THEN
      IF v_prior_relevant_count > 0
          OR v_late_cutoff_minutes IS NULL
          OR v_break_first_deadline_minutes IS NULL THEN
        v_requires_admin_review := true;
      ELSE
        v_requires_admin_review := v_requires_admin_review OR NOT (
          (EXTRACT(HOUR FROM v_effective_local)::integer * 60
            + EXTRACT(MINUTE FROM v_effective_local)::integer)
            > v_late_cutoff_minutes
          AND
          (EXTRACT(HOUR FROM v_effective_local)::integer * 60
            + EXTRACT(MINUTE FROM v_effective_local)::integer)
            <= v_break_first_deadline_minutes
        );
      END IF;
    END IF;
  END IF;

  INSERT INTO public.attendance_logs (
    employee_id,
    scan_outlet_id,
    type,
    lat,
    lng,
    device_id,
    scanned_at,
    synced_at,
    local_id,
    is_backup,
    notes,
    device_captured_at,
    capture_mode,
    queue_order,
    initial_scan_intent,
    requires_admin_review
  )
  VALUES (
    p_employee_id,
    p_outlet_id,
    p_type,
    p_lat,
    p_lng,
    p_device_id,
    v_scanned_at_utc,
    v_scanned_at_utc,
    p_local_id,
    COALESCE(p_is_backup, false),
    NULLIF(BTRIM(p_notes), ''),
    p_device_captured_at,
    p_capture_mode,
    p_queue_order,
    p_initial_scan_intent,
    v_requires_admin_review
  );

  RETURN QUERY
  SELECT
    CASE
      WHEN p_capture_mode = 'queued' THEN 'queued_reconciled'
      ELSE 'live_confirmed'
    END AS authority_state,
    v_scanned_at_utc,
    to_char(v_scanned_at_local, 'HH24:MI "WITA"'),
    p_type,
    p_initial_scan_intent,
    v_requires_admin_review;
END;
$$;

REVOKE ALL ON FUNCTION public.record_kiosk_scan(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  timestamptz,
  bigint,
  text,
  boolean,
  text,
  double precision,
  double precision
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_kiosk_scan(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  timestamptz,
  bigint,
  text,
  boolean,
  text,
  double precision,
  double precision
) TO authenticated;

-- 4. Upgrade the Phase 55 admin recap contract so break_first_confirmed is
-- derived from stored Phase 56 intent instead of a placeholder false.

CREATE OR REPLACE FUNCTION public.get_admin_schedule_policy_recap(
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
  business_today date := (statement_timestamp() AT TIME ZONE 'Asia/Makassar')::date;
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
    FROM public.schedule_entries se
    INNER JOIN public.schedules s ON s.id = se.schedule_id
    INNER JOIN public.employees e ON e.id = se.employee_id
    INNER JOIN public.outlets o ON o.id = s.outlet_id
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
      MIN(al.scanned_at AT TIME ZONE 'Asia/Makassar')
        FILTER (WHERE al.type = 'break') AS first_break_local,
      MAX(al.scanned_at AT TIME ZONE 'Asia/Makassar')
        FILTER (WHERE al.type = 'pulang') AS last_pulang_local,
      bool_or(al.type = 'sakit') AS has_sakit,
      bool_or(al.type = 'izin') AS has_izin,
      (
        array_agg(
          COALESCE(al.initial_scan_intent, 'none')
          ORDER BY al.scanned_at, al.id
        ) FILTER (WHERE al.type IN ('masuk', 'break', 'kembali', 'pulang'))
      )[1] AS first_relevant_initial_intent,
      string_agg(
        DISTINCT NULLIF(BTRIM(al.notes), ''),
        ' | '
      ) FILTER (WHERE al.notes IS NOT NULL AND BTRIM(al.notes) <> '') AS attendance_notes
    FROM public.attendance_logs al
    INNER JOIN public.employees e ON e.id = al.employee_id
    INNER JOIN public.outlets o ON o.id = al.scan_outlet_id
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
      ar.first_relevant_initial_intent,
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
        AND COALESCE(m.first_relevant_initial_intent, 'none') = 'break_first'
      THEN 'break_first_confirmed'
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
      WHEN COALESCE(m.first_relevant_initial_intent, 'none') = 'break_first'
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
    CASE
      WHEN COALESCE(m.has_sakit, false) OR m.schedule_status = 'sakit'
        OR COALESCE(m.has_izin, false) OR m.schedule_status = 'izin'
        OR m.schedule_status IN ('cuti', 'libur')
        OR m.schedule_employee_name IS NULL
        OR COALESCE(m.scan_count, 0) = 0
      THEN false
      WHEN COALESCE(m.first_relevant_initial_intent, 'none') = 'break_first'
      THEN true
      ELSE false
    END AS break_first_confirmed,
    m.first_scan_local,
    m.first_break_local,
    m.last_pulang_local,
    NULLIF(
      concat_ws(' | ', m.schedule_notes, m.attendance_notes),
      ''
    ) AS notes
  FROM merged m
  ORDER BY
    m.logical_date DESC,
    COALESCE(m.schedule_employee_name, m.attendance_employee_name),
    m.employee_id;
END;
$$;

REVOKE ALL ON FUNCTION public.get_admin_schedule_policy_recap(uuid, date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_admin_schedule_policy_recap(uuid, date, date) TO authenticated;
