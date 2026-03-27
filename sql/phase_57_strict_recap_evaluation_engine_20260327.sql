-- Phase 57: Strict Recap Evaluation Engine
-- Additive-only patch: replaces the admin recap RPC with one canonical
-- overnight-safe strict evaluation engine while preserving the Phase 55/56
-- compatibility fields.
--
-- IMPORTANT: Review and apply manually in Supabase SQL Editor.
-- Requires explicit user approval before production execution.

CREATE OR REPLACE FUNCTION public.is_strict_recap_manager_exempt(
  position_text text
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  normalized_position text;
BEGIN
  normalized_position := lower(
    regexp_replace(COALESCE(position_text, ''), '[^a-z0-9]+', ' ', 'g')
  );

  RETURN normalized_position LIKE '%kepala toko%'
    OR normalized_position LIKE '%kepala gerai%';
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_strict_recap_break_allowance_minutes(
  employee_contract public.employee_contract,
  is_overtime boolean
)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF COALESCE(is_overtime, false) THEN
    RETURN 120;
  END IF;

  IF COALESCE(employee_contract, 'FULLTIME'::public.employee_contract) =
      'PARTTIME'::public.employee_contract THEN
    RETURN 60;
  END IF;

  RETURN 120;
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_strict_recap_primary_status(
  detail_signals text[],
  schedule_status text,
  is_manager_exempt boolean
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  signals text[] := COALESCE(detail_signals, ARRAY[]::text[]);
  normalized_schedule text := COALESCE(schedule_status, '');
BEGIN
  IF normalized_schedule IN ('sakit', 'izin', 'cuti', 'libur', 'belum_masuk') THEN
    RETURN normalized_schedule;
  END IF;

  IF 'absence' = ANY(signals) THEN
    RETURN 'absence';
  END IF;

  IF 'belum_absen_pulang' = ANY(signals) THEN
    RETURN 'belum_absen_pulang';
  END IF;

  IF NOT COALESCE(is_manager_exempt, false)
      AND 'short_work' = ANY(signals) THEN
    RETURN 'short_work';
  END IF;

  IF NOT COALESCE(is_manager_exempt, false)
      AND 'excess_break' = ANY(signals) THEN
    RETURN 'excess_break';
  END IF;

  IF NOT COALESCE(is_manager_exempt, false)
      AND 'late' = ANY(signals) THEN
    RETURN 'late';
  END IF;

  IF 'overtime' = ANY(signals) THEN
    RETURN 'overtime';
  END IF;

  IF 'active_incomplete' = ANY(signals) THEN
    RETURN 'active_incomplete';
  END IF;

  IF 'hadir_tanpa_jadwal' = ANY(signals) THEN
    RETURN 'hadir_tanpa_jadwal';
  END IF;

  IF COALESCE(is_manager_exempt, false)
      AND (
        'late' = ANY(signals)
        OR 'short_work' = ANY(signals)
        OR 'excess_break' = ANY(signals)
        OR 'exempt_manager' = ANY(signals)
      ) THEN
    RETURN 'exempt_manager';
  END IF;

  RETURN 'hadir';
END;
$$;

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
  notes text,
  primary_status text,
  primary_severity text,
  detail_signals text[],
  detail_notes text[],
  is_manager_exempt boolean,
  manager_position text,
  logical_day_complete boolean,
  incomplete_reason text,
  net_work_minutes integer,
  total_break_minutes integer,
  overtime_minutes integer,
  short_work_minutes integer,
  excess_break_minutes integer,
  paired_break_count integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  business_now_local timestamp without time zone :=
    statement_timestamp() AT TIME ZONE 'Asia/Makassar';
  business_today date := business_now_local::date;
BEGIN
  IF p_outlet_id IS NULL OR p_start_date IS NULL OR p_end_date IS NULL THEN
    RAISE EXCEPTION 'Outlet, start date, and end date are required';
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
      e.position AS manager_position,
      COALESCE(
        e.employment_contract,
        'FULLTIME'::public.employee_contract
      ) AS employee_contract,
      o.id AS outlet_id,
      o.name AS outlet_name,
      o.operating_mode,
      public.resolve_schedule_shift_band(COALESCE(se.shift_slot, '{}'::jsonb)) AS shift_band,
      CASE
        WHEN COALESCE(se.status::text, 'normal') IN ('sakit', 'izin', 'cuti', 'libur')
          THEN COALESCE(se.status::text, 'normal')
        WHEN COALESCE(se.is_day_off, false)
          OR public.resolve_schedule_shift_band(COALESCE(se.shift_slot, '{}'::jsonb)) = 'LIBUR'
          THEN 'libur'
        ELSE 'scheduled'
      END AS schedule_status,
      CASE
        WHEN COALESCE(se.status::text, 'normal') IN ('sakit', 'izin', 'cuti', 'libur')
          OR COALESCE(se.is_day_off, false)
          OR public.resolve_schedule_shift_band(COALESCE(se.shift_slot, '{}'::jsonb)) = 'LIBUR'
        THEN 0
        ELSE COALESCE(
          NULLIF(se.shift_slot->>'required_work_minutes', '')::integer,
          public.resolve_schedule_required_work_minutes(
            COALESCE(
              e.employment_contract,
              'FULLTIME'::public.employee_contract
            )
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
          COALESCE(
            e.employment_contract,
            'FULLTIME'::public.employee_contract
          )
        )
      END AS break_first_deadline_minutes,
      NULLIF(BTRIM(se.notes), '') AS schedule_notes
    FROM public.schedule_entries se
    INNER JOIN public.schedules s
      ON s.id = se.schedule_id
    INNER JOIN public.employees e
      ON e.id = se.employee_id
    INNER JOIN public.outlets o
      ON o.id = s.outlet_id
    WHERE s.is_active = true
      AND s.outlet_id = p_outlet_id
      AND se.date BETWEEN p_start_date AND p_end_date
      AND e.is_active = true
      AND e.archived_at IS NULL
  ),
  timeoff_rows AS (
    SELECT
      (al.scanned_at AT TIME ZONE 'Asia/Makassar')::date AS logical_date,
      al.employee_id,
      e.name AS employee_name,
      e.position AS manager_position,
      COALESCE(
        e.employment_contract,
        'FULLTIME'::public.employee_contract
      ) AS employee_contract,
      o.id AS outlet_id,
      o.name AS outlet_name,
      o.operating_mode,
      bool_or(al.type = 'sakit') AS has_sakit,
      bool_or(al.type = 'izin') AS has_izin,
      string_agg(
        DISTINCT NULLIF(BTRIM(al.notes), ''),
        ' | '
      ) FILTER (WHERE al.notes IS NOT NULL AND BTRIM(al.notes) <> '') AS timeoff_notes
    FROM public.attendance_logs al
    INNER JOIN public.employees e
      ON e.id = al.employee_id
    INNER JOIN public.outlets o
      ON o.id = al.scan_outlet_id
    WHERE al.scan_outlet_id = p_outlet_id
      AND al.scanned_at >= (p_start_date::timestamp AT TIME ZONE 'Asia/Makassar')
      AND al.scanned_at < ((p_end_date + 1)::timestamp AT TIME ZONE 'Asia/Makassar')
      AND al.type IN ('sakit', 'izin')
      AND e.is_active = true
      AND e.archived_at IS NULL
    GROUP BY
      (al.scanned_at AT TIME ZONE 'Asia/Makassar')::date,
      al.employee_id,
      e.name,
      e.position,
      e.employment_contract,
      o.id,
      o.name,
      o.operating_mode
  ),
  raw_events AS (
    SELECT
      al.id,
      al.employee_id,
      e.name AS employee_name,
      e.position AS manager_position,
      COALESCE(
        e.employment_contract,
        'FULLTIME'::public.employee_contract
      ) AS employee_contract,
      o.id AS outlet_id,
      o.name AS outlet_name,
      o.operating_mode,
      al.type,
      COALESCE(al.initial_scan_intent, 'none') AS initial_scan_intent,
      COALESCE(al.capture_mode, 'live') AS capture_mode,
      COALESCE(al.requires_admin_review, false) AS requires_admin_review,
      al.scanned_at AT TIME ZONE 'Asia/Makassar' AS scanned_local,
      (al.scanned_at AT TIME ZONE 'Asia/Makassar')::date AS local_date,
      NULLIF(BTRIM(al.notes), '') AS note_text,
      SUM(
        CASE WHEN al.type = 'masuk' THEN 1 ELSE 0 END
      ) OVER (
        PARTITION BY al.employee_id, al.scan_outlet_id
        ORDER BY al.scanned_at, al.id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS chain_seed
    FROM public.attendance_logs al
    INNER JOIN public.employees e
      ON e.id = al.employee_id
    INNER JOIN public.outlets o
      ON o.id = al.scan_outlet_id
    WHERE al.scan_outlet_id = p_outlet_id
      AND al.scanned_at >= ((p_start_date - 1)::timestamp AT TIME ZONE 'Asia/Makassar')
      AND al.scanned_at < ((p_end_date + 2)::timestamp AT TIME ZONE 'Asia/Makassar')
      AND al.type IN ('masuk', 'break', 'kembali', 'pulang')
      AND e.is_active = true
      AND e.archived_at IS NULL
  ),
  attendance_events AS (
    SELECT
      re.*,
      CASE
        WHEN re.operating_mode = 'TWENTY_FOUR_HOUR'::public.outlet_operating_mode THEN
          concat(
            re.employee_id::text,
            ':',
            re.outlet_id::text,
            ':',
            CASE
              WHEN re.chain_seed = 0 THEN to_char(re.local_date, 'YYYYMMDD')
              ELSE lpad(re.chain_seed::text, 6, '0')
            END
          )
        ELSE concat(
          re.employee_id::text,
          ':',
          re.outlet_id::text,
          ':',
          to_char(re.local_date, 'YYYYMMDD')
        )
      END AS logical_chain_id
    FROM raw_events re
  ),
  event_order AS (
    SELECT
      ae.*,
      COUNT(*) FILTER (WHERE ae.type = 'break') OVER (
        PARTITION BY ae.logical_chain_id
        ORDER BY ae.scanned_local, ae.id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS break_seq,
      COUNT(*) FILTER (WHERE ae.type = 'kembali') OVER (
        PARTITION BY ae.logical_chain_id
        ORDER BY ae.scanned_local, ae.id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS kembali_seq
    FROM attendance_events ae
  ),
  break_rows AS (
    SELECT
      eo.logical_chain_id,
      eo.id AS break_id,
      eo.break_seq,
      eo.scanned_local AS break_local
    FROM event_order eo
    WHERE eo.type = 'break'
  ),
  kembali_rows AS (
    SELECT
      eo.logical_chain_id,
      eo.id AS kembali_id,
      eo.kembali_seq,
      eo.scanned_local AS kembali_local
    FROM event_order eo
    WHERE eo.type = 'kembali'
  ),
  break_pairs AS (
    SELECT
      br.logical_chain_id,
      br.break_id,
      kr.kembali_id,
      CASE
        WHEN kr.kembali_local IS NULL THEN NULL
        ELSE GREATEST(
          floor(extract(epoch FROM (kr.kembali_local - br.break_local)) / 60)::integer,
          0
        )
      END AS break_minutes
    FROM break_rows br
    LEFT JOIN kembali_rows kr
      ON kr.logical_chain_id = br.logical_chain_id
     AND kr.kembali_seq = br.break_seq
     AND kr.kembali_local >= br.break_local
  ),
  chain_rollup_base AS (
    SELECT
      eo.logical_chain_id,
      eo.employee_id,
      eo.employee_name,
      eo.manager_position,
      eo.employee_contract,
      eo.outlet_id,
      eo.outlet_name,
      eo.operating_mode,
      MIN(eo.scanned_local) AS chain_started_local,
      MIN(eo.scanned_local) FILTER (WHERE eo.type = 'masuk') AS first_masuk_local,
      MIN(eo.scanned_local) FILTER (WHERE eo.type = 'break') AS first_break_local,
      MAX(eo.scanned_local) FILTER (WHERE eo.type = 'pulang') AS final_pulang_local,
      MAX(eo.scanned_local) AS last_event_local,
      (ARRAY_AGG(eo.type ORDER BY eo.scanned_local DESC, eo.id DESC))[1] AS last_event_type,
      (ARRAY_AGG(eo.initial_scan_intent ORDER BY eo.scanned_local, eo.id))[1] AS first_initial_scan_intent,
      bool_or(eo.requires_admin_review) AS requires_admin_review,
      bool_or(eo.capture_mode = 'queued') AS has_queued_event,
      COUNT(*)::integer AS event_count,
      COUNT(*) FILTER (WHERE eo.type = 'break')::integer AS break_event_count,
      COUNT(*) FILTER (WHERE eo.type = 'kembali')::integer AS kembali_event_count,
      COALESCE(SUM(bp.break_minutes), 0)::integer AS total_break_minutes,
      COUNT(bp.kembali_id)::integer AS paired_break_count,
      string_agg(DISTINCT eo.note_text, ' | ')
        FILTER (WHERE eo.note_text IS NOT NULL) AS attendance_notes
    FROM event_order eo
    LEFT JOIN break_pairs bp
      ON bp.break_id = eo.id
    GROUP BY
      eo.logical_chain_id,
      eo.employee_id,
      eo.employee_name,
      eo.manager_position,
      eo.employee_contract,
      eo.outlet_id,
      eo.outlet_name,
      eo.operating_mode
  ),
  chain_rollup AS (
    SELECT
      crb.*,
      CASE
        WHEN crb.operating_mode = 'TWENTY_FOUR_HOUR'::public.outlet_operating_mode
          THEN COALESCE(crb.first_masuk_local::date, crb.chain_started_local::date)
        ELSE crb.chain_started_local::date
      END AS logical_date,
      LEAD(COALESCE(crb.first_masuk_local, crb.chain_started_local)) OVER (
        PARTITION BY crb.employee_id, crb.outlet_id
        ORDER BY COALESCE(crb.first_masuk_local, crb.chain_started_local),
                 crb.logical_chain_id
      ) AS next_chain_started_local
    FROM chain_rollup_base crb
  ),
  attendance_day_rows AS (
    SELECT
      cr.logical_date,
      cr.employee_id,
      cr.employee_name,
      cr.manager_position,
      cr.employee_contract,
      cr.outlet_id,
      cr.outlet_name,
      cr.operating_mode,
      MIN(COALESCE(cr.first_masuk_local, cr.chain_started_local)) AS first_scan_local,
      MIN(cr.first_break_local) AS first_break_local,
      MAX(cr.final_pulang_local) AS last_pulang_local,
      MAX(cr.last_event_local) AS last_event_local,
      (ARRAY_AGG(cr.last_event_type ORDER BY cr.last_event_local DESC, cr.logical_chain_id DESC))[1] AS last_event_type,
      bool_or(cr.first_initial_scan_intent = 'break_first') AS break_first_confirmed,
      bool_or(cr.requires_admin_review) AS requires_admin_review,
      bool_or(cr.has_queued_event) AS has_queued_event,
      bool_or(cr.break_event_count > cr.paired_break_count) AS has_unmatched_break,
      bool_or(cr.final_pulang_local IS NULL) AS has_open_chain,
      bool_or(cr.first_masuk_local IS NOT NULL) AS has_masuk,
      SUM(cr.event_count)::integer AS relevant_event_count,
      SUM(cr.total_break_minutes)::integer AS total_break_minutes,
      SUM(cr.paired_break_count)::integer AS paired_break_count,
      SUM(
        CASE
          WHEN cr.first_masuk_local IS NOT NULL
              AND cr.final_pulang_local IS NOT NULL
            THEN GREATEST(
              floor(extract(epoch FROM (cr.final_pulang_local - cr.first_masuk_local)) / 60)::integer
                - cr.total_break_minutes,
              0
            )
          ELSE 0
        END
      )::integer AS net_work_minutes,
      bool_and(
        CASE
          WHEN cr.final_pulang_local IS NOT NULL THEN true
          WHEN cr.operating_mode = 'TWENTY_FOUR_HOUR'::public.outlet_operating_mode
              AND cr.next_chain_started_local IS NOT NULL THEN true
          WHEN cr.operating_mode = 'TWENTY_FOUR_HOUR'::public.outlet_operating_mode
              AND business_today > (cr.logical_date + 1) THEN true
          WHEN cr.operating_mode <> 'TWENTY_FOUR_HOUR'::public.outlet_operating_mode
              AND business_today > cr.logical_date THEN true
          ELSE false
        END
      ) AS logical_day_complete,
      string_agg(DISTINCT cr.attendance_notes, ' | ')
        FILTER (WHERE cr.attendance_notes IS NOT NULL AND cr.attendance_notes <> '') AS attendance_notes
    FROM chain_rollup cr
    WHERE cr.logical_date BETWEEN p_start_date AND p_end_date
    GROUP BY
      cr.logical_date,
      cr.employee_id,
      cr.employee_name,
      cr.manager_position,
      cr.employee_contract,
      cr.outlet_id,
      cr.outlet_name,
      cr.operating_mode
  ),
  merged_keys AS (
    SELECT sr.logical_date, sr.employee_id
    FROM schedule_rows sr
    UNION
    SELECT ar.logical_date, ar.employee_id
    FROM attendance_day_rows ar
    UNION
    SELECT tr.logical_date, tr.employee_id
    FROM timeoff_rows tr
  ),
  merged AS (
    SELECT
      mk.logical_date,
      mk.employee_id,
      COALESCE(sr.employee_name, ar.employee_name, tr.employee_name) AS employee_name,
      COALESCE(sr.manager_position, ar.manager_position, tr.manager_position) AS manager_position,
      COALESCE(
        sr.employee_contract,
        ar.employee_contract,
        tr.employee_contract,
        'FULLTIME'::public.employee_contract
      ) AS employee_contract,
      COALESCE(sr.outlet_id, ar.outlet_id, tr.outlet_id, p_outlet_id) AS outlet_id,
      COALESCE(sr.outlet_name, ar.outlet_name, tr.outlet_name) AS outlet_name,
      COALESCE(
        sr.operating_mode,
        ar.operating_mode,
        tr.operating_mode,
        'NORMAL'::public.outlet_operating_mode
      ) AS operating_mode,
      sr.shift_band,
      sr.schedule_status,
      sr.required_work_minutes AS scheduled_required_work_minutes,
      sr.late_cutoff_minutes,
      sr.break_first_deadline_minutes,
      sr.schedule_notes,
      COALESCE(tr.has_sakit, false) AS has_sakit,
      COALESCE(tr.has_izin, false) AS has_izin,
      tr.timeoff_notes,
      ar.first_scan_local,
      ar.first_break_local,
      ar.last_pulang_local,
      ar.last_event_local,
      ar.last_event_type,
      COALESCE(ar.break_first_confirmed, false) AS break_first_confirmed,
      COALESCE(ar.requires_admin_review, false) AS requires_admin_review,
      COALESCE(ar.has_queued_event, false) AS has_queued_event,
      COALESCE(ar.has_unmatched_break, false) AS has_unmatched_break,
      COALESCE(ar.has_open_chain, false) AS has_open_chain,
      COALESCE(ar.has_masuk, false) AS has_masuk,
      COALESCE(ar.relevant_event_count, 0) AS relevant_event_count,
      COALESCE(ar.total_break_minutes, 0) AS total_break_minutes,
      COALESCE(ar.paired_break_count, 0) AS paired_break_count,
      COALESCE(ar.net_work_minutes, 0) AS net_work_minutes,
      COALESCE(
        ar.logical_day_complete,
        CASE
          WHEN mk.logical_date < business_today THEN true
          ELSE false
        END
      ) AS logical_day_complete,
      ar.attendance_notes
    FROM merged_keys mk
    LEFT JOIN schedule_rows sr
      ON sr.logical_date = mk.logical_date
     AND sr.employee_id = mk.employee_id
    LEFT JOIN attendance_day_rows ar
      ON ar.logical_date = mk.logical_date
     AND ar.employee_id = mk.employee_id
    LEFT JOIN timeoff_rows tr
      ON tr.logical_date = mk.logical_date
     AND tr.employee_id = mk.employee_id
  )
  SELECT
    m.logical_date,
    m.employee_id,
    m.employee_name,
    m.outlet_id,
    m.outlet_name,
    m.shift_band,
    policy.required_work_minutes,
    normalized.late_cutoff_local,
    normalized.break_first_deadline_local,
    policy.attendance_status,
    policy.late_kind,
    flags.has_late AS is_late,
    flags.break_first_eligible,
    m.break_first_confirmed,
    m.first_scan_local,
    m.first_break_local,
    m.last_pulang_local,
    NULLIF(
      concat_ws(
        ' | ',
        array_to_string(detail_payload.detail_notes, ' | '),
        m.schedule_notes,
        m.attendance_notes,
        m.timeoff_notes
      ),
      ''
    ) AS notes,
    policy.primary_status,
    policy.primary_severity,
    detail_payload.detail_signals,
    detail_payload.detail_notes,
    normalized.is_manager_exempt,
    m.manager_position,
    m.logical_day_complete,
    policy.incomplete_reason,
    m.net_work_minutes,
    m.total_break_minutes,
    metrics.overtime_minutes,
    metrics.short_work_minutes,
    metrics.excess_break_minutes,
    m.paired_break_count
  FROM merged m
  CROSS JOIN LATERAL (
    SELECT
      public.is_strict_recap_manager_exempt(m.manager_position) AS is_manager_exempt,
      CASE
        WHEN m.has_sakit OR m.schedule_status = 'sakit' THEN 'sakit'
        WHEN m.has_izin OR m.schedule_status = 'izin' THEN 'izin'
        WHEN m.schedule_status = 'cuti' THEN 'cuti'
        WHEN m.schedule_status = 'libur' THEN 'libur'
        WHEN COALESCE(m.relevant_event_count, 0) = 0
            AND m.schedule_status = 'scheduled'
            AND m.logical_day_complete THEN 'absence'
        WHEN COALESCE(m.relevant_event_count, 0) = 0
            AND m.schedule_status = 'scheduled'
            AND NOT m.logical_day_complete THEN 'belum_masuk'
        WHEN m.schedule_status = 'scheduled' THEN 'scheduled'
        ELSE 'unscheduled'
      END AS schedule_status_resolved,
      CASE
        WHEN m.schedule_status IN ('sakit', 'izin', 'cuti', 'libur') THEN 0
        ELSE COALESCE(
          m.scheduled_required_work_minutes,
          public.resolve_schedule_required_work_minutes(m.employee_contract)
        )
      END AS required_work_minutes,
      CASE
        WHEN m.late_cutoff_minutes IS NULL THEN NULL
        ELSE lpad((m.late_cutoff_minutes / 60)::text, 2, '0')
             || ':' ||
             lpad((m.late_cutoff_minutes % 60)::text, 2, '0')
      END AS late_cutoff_local,
      CASE
        WHEN m.break_first_deadline_minutes IS NULL THEN NULL
        ELSE lpad((m.break_first_deadline_minutes / 60)::text, 2, '0')
             || ':' ||
             lpad((m.break_first_deadline_minutes % 60)::text, 2, '0')
      END AS break_first_deadline_local
  ) normalized
  CROSS JOIN LATERAL (
    SELECT
      GREATEST(m.net_work_minutes - normalized.required_work_minutes, 0) AS overtime_minutes,
      public.resolve_strict_recap_break_allowance_minutes(
        m.employee_contract,
        m.net_work_minutes > normalized.required_work_minutes
      ) AS allowed_break_minutes
  ) break_policy
  CROSS JOIN LATERAL (
    SELECT
      break_policy.overtime_minutes,
      GREATEST(normalized.required_work_minutes - m.net_work_minutes, 0) AS short_work_minutes,
      GREATEST(m.total_break_minutes - break_policy.allowed_break_minutes, 0) AS excess_break_minutes
  ) metrics
  CROSS JOIN LATERAL (
    SELECT
      COALESCE(m.relevant_event_count, 0) > 0 AS has_attendance,
      (
        COALESCE(m.relevant_event_count, 0) > 0
        AND m.first_scan_local IS NOT NULL
        AND m.late_cutoff_minutes IS NOT NULL
        AND (
          extract(hour FROM m.first_scan_local)::integer * 60
          + extract(minute FROM m.first_scan_local)::integer
        ) > m.late_cutoff_minutes
      ) AS has_late,
      (
        COALESCE(m.relevant_event_count, 0) > 0
        AND NOT m.break_first_confirmed
        AND m.first_scan_local IS NOT NULL
        AND m.late_cutoff_minutes IS NOT NULL
        AND m.break_first_deadline_minutes IS NOT NULL
        AND (
          extract(hour FROM m.first_scan_local)::integer * 60
          + extract(minute FROM m.first_scan_local)::integer
        ) > m.late_cutoff_minutes
        AND (
          extract(hour FROM m.first_scan_local)::integer * 60
          + extract(minute FROM m.first_scan_local)::integer
        ) <= m.break_first_deadline_minutes
      ) AS break_first_eligible,
      normalized.schedule_status_resolved = 'absence' AS has_absence,
      (
        normalized.schedule_status_resolved = 'unscheduled'
        AND COALESCE(m.relevant_event_count, 0) > 0
      ) AS has_unscheduled_attendance,
      (
        COALESCE(m.relevant_event_count, 0) > 0
        AND m.logical_day_complete
        AND (
          m.last_pulang_local IS NULL
          OR m.has_unmatched_break
          OR m.last_event_type IS DISTINCT FROM 'pulang'
        )
      ) AS has_belum_absen_pulang,
      (
        COALESCE(m.relevant_event_count, 0) > 0
        AND NOT m.logical_day_complete
        AND (
          m.has_open_chain
          OR m.has_unmatched_break
          OR m.last_pulang_local IS NULL
        )
      ) AS has_active_incomplete,
      (
        COALESCE(m.relevant_event_count, 0) > 0
        AND m.logical_day_complete
        AND metrics.short_work_minutes > 0
        AND NOT (
          m.last_pulang_local IS NULL
          OR m.has_unmatched_break
          OR m.last_event_type IS DISTINCT FROM 'pulang'
        )
      ) AS has_short_work,
      (
        COALESCE(m.relevant_event_count, 0) > 0
        AND m.logical_day_complete
        AND metrics.excess_break_minutes > 0
        AND NOT (
          m.last_pulang_local IS NULL
          OR m.has_unmatched_break
          OR m.last_event_type IS DISTINCT FROM 'pulang'
        )
      ) AS has_excess_break,
      (
        COALESCE(m.relevant_event_count, 0) > 0
        AND metrics.overtime_minutes > 0
      ) AS has_overtime
  ) flags
  CROSS JOIN LATERAL (
    SELECT
      ARRAY_REMOVE(
        ARRAY[
          CASE WHEN flags.has_late THEN 'late' END,
          CASE WHEN flags.has_short_work THEN 'short_work' END,
          CASE WHEN flags.has_excess_break THEN 'excess_break' END,
          CASE WHEN flags.has_overtime THEN 'overtime' END,
          CASE WHEN flags.has_absence THEN 'absence' END,
          CASE
            WHEN normalized.is_manager_exempt
                AND (flags.has_late OR flags.has_short_work OR flags.has_excess_break)
              THEN 'exempt_manager'
          END,
          CASE WHEN flags.has_unscheduled_attendance THEN 'hadir_tanpa_jadwal' END,
          CASE WHEN flags.has_belum_absen_pulang THEN 'belum_absen_pulang' END,
          CASE WHEN flags.has_active_incomplete THEN 'active_incomplete' END,
          CASE WHEN m.break_first_confirmed THEN 'break_first_confirmed' END
        ],
        NULL
      )::text[] AS detail_signals,
      ARRAY_REMOVE(
        ARRAY[
          CASE
            WHEN flags.has_late
              THEN format(
                'Terlambat: masuk %s, batas %s.',
                COALESCE(to_char(m.first_scan_local, 'HH24:MI'), '--:--'),
                COALESCE(normalized.late_cutoff_local, '--:--')
              )
          END,
          CASE
            WHEN flags.has_short_work
              THEN format(
                'Kurang %s menit dari target kerja.',
                metrics.short_work_minutes::text
              )
          END,
          CASE
            WHEN flags.has_excess_break
              THEN format(
                'Istirahat melebihi batas %s menit.',
                break_policy.allowed_break_minutes::text
              )
          END,
          CASE
            WHEN flags.has_overtime
              THEN format(
                'Lembur %s menit di atas target kerja.',
                metrics.overtime_minutes::text
              )
          END,
          CASE
            WHEN flags.has_absence
              THEN 'Tidak ada scan pada logical day yang sudah selesai.'
          END,
          CASE
            WHEN normalized.is_manager_exempt
                AND (flags.has_late OR flags.has_short_work OR flags.has_excess_break)
              THEN format(
                'Posisi %s exempt dari penalti merah telat, kurang jam, dan istirahat berlebih.',
                COALESCE(m.manager_position, 'manager')
              )
          END,
          CASE
            WHEN flags.has_unscheduled_attendance
              THEN 'Hadir tanpa jadwal; threshold kontrak tetap diterapkan.'
          END,
          CASE
            WHEN flags.has_belum_absen_pulang
              THEN 'Chain selesai tanpa kembali atau clock-out yang cocok.'
          END,
          CASE
            WHEN flags.has_active_incomplete
              THEN 'Hari masih berjalan; hasil final menunggu chain selesai.'
          END,
          CASE
            WHEN m.break_first_confirmed
              THEN 'Scan pertama dikonfirmasi sebagai break-first.'
          END,
          CASE
            WHEN m.requires_admin_review
              THEN 'Scan replay memerlukan review admin.'
          END
        ],
        NULL
      )::text[] AS detail_notes
  ) detail_payload
  CROSS JOIN LATERAL (
    SELECT
      public.resolve_strict_recap_primary_status(
        detail_payload.detail_signals,
        normalized.schedule_status_resolved,
        normalized.is_manager_exempt
      ) AS primary_status,
      CASE
        WHEN flags.has_active_incomplete THEN
          CASE
            WHEN m.has_unmatched_break THEN 'awaiting_break_return'
            WHEN m.last_pulang_local IS NULL THEN 'awaiting_clock_out'
            ELSE 'awaiting_chain_completion'
          END
        WHEN flags.has_belum_absen_pulang THEN
          CASE
            WHEN m.has_unmatched_break THEN 'missing_break_return'
            WHEN m.last_pulang_local IS NULL THEN 'missing_clock_out'
            ELSE 'incomplete_historical_chain'
          END
        ELSE NULL
      END AS incomplete_reason
  ) primary_status_eval
  CROSS JOIN LATERAL (
    SELECT
      normalized.required_work_minutes AS required_work_minutes,
      primary_status_eval.primary_status AS primary_status,
      CASE
        WHEN primary_status_eval.primary_status IN (
          'late',
          'short_work',
          'excess_break',
          'absence',
          'belum_absen_pulang'
        ) THEN 'red'
        WHEN primary_status_eval.primary_status = 'overtime' THEN 'yellow'
        ELSE 'info'
      END AS primary_severity,
      CASE
        WHEN primary_status_eval.primary_status = 'absence' THEN 'tidak_hadir'
        WHEN primary_status_eval.primary_status = 'belum_masuk' THEN 'belum_masuk'
        WHEN primary_status_eval.primary_status IN ('sakit', 'izin', 'cuti', 'libur')
          THEN primary_status_eval.primary_status
        WHEN flags.has_unscheduled_attendance THEN 'hadir_tanpa_jadwal'
        WHEN flags.has_attendance THEN 'hadir'
        ELSE NULL
      END AS attendance_status,
      CASE
        WHEN m.break_first_confirmed THEN 'break_first_confirmed'
        WHEN flags.break_first_eligible THEN 'break_first_eligible'
        WHEN flags.has_late THEN 'normal'
        ELSE 'none'
      END AS late_kind,
      primary_status_eval.incomplete_reason AS incomplete_reason
  ) policy
  ORDER BY
    m.logical_date DESC,
    m.employee_name,
    m.employee_id;
END;
$$;

REVOKE ALL ON FUNCTION public.get_admin_schedule_policy_recap(uuid, date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_admin_schedule_policy_recap(uuid, date, date) TO authenticated;
