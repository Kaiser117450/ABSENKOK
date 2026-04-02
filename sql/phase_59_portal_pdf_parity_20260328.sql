-- Phase 59: Portal + PDF parity contract
-- Goal: add portal-safe parity RPCs that expose the same contract-aware and
-- overnight-safe outcome semantics already used by the strict admin recap.
--
-- IMPORTANT:
-- - additive only
-- - do not execute in production without explicit user approval
-- - safe to re-run via CREATE OR REPLACE FUNCTION

CREATE OR REPLACE FUNCTION public.portal_shift_band_label(
  shift_band text,
  attendance_status text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN attendance_status = 'libur' THEN 'Libur'
    WHEN attendance_status = 'sakit' THEN 'Sakit'
    WHEN attendance_status = 'izin' THEN 'Izin'
    WHEN attendance_status = 'cuti' THEN 'Cuti'
    WHEN upper(coalesce(shift_band, '')) = 'PAGI' THEN 'Pagi'
    WHEN upper(coalesce(shift_band, '')) = 'SIANG' THEN 'Siang'
    WHEN upper(coalesce(shift_band, '')) = 'SORE' THEN 'Sore'
    WHEN upper(coalesce(shift_band, '')) = 'LIBUR' THEN 'Libur'
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION public.portal_strict_outcome_label(
  strict_primary_status text,
  attendance_status text,
  is_in_progress boolean DEFAULT false
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN strict_primary_status = 'late' THEN 'Terlambat'
    WHEN strict_primary_status = 'short_work' THEN 'Kurang jam kerja'
    WHEN strict_primary_status = 'excess_break' THEN 'Istirahat berlebih'
    WHEN strict_primary_status = 'overtime' THEN 'Lembur'
    WHEN strict_primary_status = 'absence' THEN 'Tidak hadir'
    WHEN strict_primary_status = 'exempt_manager' THEN 'Manager exempt'
    WHEN strict_primary_status = 'hadir_tanpa_jadwal' THEN 'Hadir tanpa jadwal'
    WHEN strict_primary_status = 'belum_absen_pulang' THEN 'Belum absen pulang'
    WHEN strict_primary_status = 'active_incomplete' THEN 'Sedang berjalan'
    WHEN strict_primary_status = 'belum_masuk' THEN 'Belum masuk'
    WHEN attendance_status = 'sakit' THEN 'Sakit'
    WHEN attendance_status = 'izin' THEN 'Izin'
    WHEN attendance_status = 'cuti' THEN 'Cuti'
    WHEN attendance_status = 'libur' THEN 'Libur'
    WHEN attendance_status = 'hadir_tanpa_jadwal' THEN 'Hadir tanpa jadwal'
    WHEN is_in_progress THEN 'Sedang berjalan'
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION public.portal_strict_signal_tags(
  detail_signals text[]
)
RETURNS text[]
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  WITH mapped AS (
    SELECT
      signal_value,
      ordinality,
      CASE signal_value
        WHEN 'late' THEN 'TLT'
        WHEN 'short_work' THEN 'KJG'
        WHEN 'excess_break' THEN 'BRK'
        WHEN 'absence' THEN 'ABS'
        WHEN 'overtime' THEN 'OT'
        WHEN 'exempt_manager' THEN 'ME'
        ELSE NULL
      END AS tag
    FROM unnest(coalesce(detail_signals, ARRAY[]::text[]))
      WITH ORDINALITY AS mapped_signal(signal_value, ordinality)
  )
  SELECT coalesce(
    (
      SELECT array_agg(mapped.tag ORDER BY mapped.ordinality)
      FROM mapped
      WHERE mapped.tag IS NOT NULL
    ),
    ARRAY[]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.portal_strict_helper_copy(
  strict_primary_status text,
  attendance_status text,
  detail_notes text[]
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT coalesce(
    (
      SELECT note
      FROM unnest(coalesce(detail_notes, ARRAY[]::text[])) AS note
      WHERE note IS NOT NULL
        AND btrim(note) <> ''
      LIMIT 1
    ),
    CASE
      WHEN strict_primary_status = 'late' THEN 'Jam masuk hari ini tercatat melewati batas shift.'
      WHEN strict_primary_status = 'short_work' THEN 'Jam kerja yang tercatat masih di bawah target kontrak.'
      WHEN strict_primary_status = 'excess_break' THEN 'Total istirahat hari ini melewati batas yang diizinkan.'
      WHEN strict_primary_status = 'overtime' THEN 'Jam kerja hari ini melebihi target kontrak.'
      WHEN strict_primary_status = 'absence' THEN 'Tidak ada scan pada hari kerja yang sudah selesai.'
      WHEN strict_primary_status = 'exempt_manager' THEN 'Kehadiran tetap tercatat, tetapi posisi manajerial tidak dikenai penalti merah.'
      WHEN strict_primary_status = 'hadir_tanpa_jadwal' THEN 'Kehadiran tetap tercatat walau jadwal belum tersedia untuk hari ini.'
      WHEN strict_primary_status = 'belum_absen_pulang' THEN 'Hari kerja sudah selesai, tetapi absensi pulang belum tercatat.'
      WHEN strict_primary_status = 'active_incomplete' THEN 'Hari kerja masih berjalan. Target dan sisa waktu akan diperbarui sampai chain selesai.'
      WHEN strict_primary_status = 'belum_masuk' THEN 'Hari kerja hari ini belum memiliki scan masuk.'
      WHEN attendance_status = 'sakit' THEN 'Karyawan tercatat sakit pada hari tersebut.'
      WHEN attendance_status = 'izin' THEN 'Karyawan tercatat izin pada hari tersebut.'
      WHEN attendance_status = 'cuti' THEN 'Karyawan tercatat cuti pada hari tersebut.'
      WHEN attendance_status = 'libur' THEN 'Hari tersebut tidak memiliki target kerja.'
      ELSE NULL
    END
  );
$$;

CREATE OR REPLACE FUNCTION public.get_portal_attendance_parity_recap(
  reference_date date DEFAULT NULL
)
RETURNS TABLE (
  logical_date date,
  attendance_status text,
  outlet_id uuid,
  outlet_name text,
  shift_band_label text,
  required_work_minutes integer,
  worked_minutes integer,
  remaining_work_minutes integer,
  strict_primary_status text,
  strict_outcome_label text,
  short_tags text[],
  helper_copy text,
  is_in_progress boolean,
  is_compatibility_mode boolean,
  first_masuk_at timestamp without time zone,
  first_break_at timestamp without time zone,
  last_kembali_at timestamp without time zone,
  last_pulang_at timestamp without time zone,
  total_break_minutes integer,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  resolved_employee_id uuid;
  resolved_home_outlet_id uuid;
  effective_date date;
  month_start date;
  history_start date;
BEGIN
  SELECT
    r.employee_id,
    r.home_outlet_id
  INTO
    resolved_employee_id,
    resolved_home_outlet_id
  FROM resolve_portal_employee() AS r
  LIMIT 1;

  IF resolved_employee_id IS NULL THEN
    RAISE EXCEPTION 'No active employee found for this portal account';
  END IF;

  effective_date := COALESCE(reference_date, (NOW() AT TIME ZONE 'Asia/Makassar')::date);
  month_start := date_trunc('month', effective_date)::date;
  history_start := LEAST(month_start, effective_date - 13);

  RETURN QUERY
  WITH candidate_outlets AS (
    SELECT DISTINCT outlet_id
    FROM (
      SELECT s.outlet_id
      FROM schedule_entries se
      INNER JOIN schedules s ON s.id = se.schedule_id
      WHERE se.employee_id = resolved_employee_id
        AND s.is_active = true
        AND se.date BETWEEN history_start AND effective_date

      UNION ALL

      SELECT al.scan_outlet_id AS outlet_id
      FROM attendance_logs al
      WHERE al.employee_id = resolved_employee_id
        AND al.scan_outlet_id IS NOT NULL
        AND al.scanned_at >= ((history_start - 1)::timestamp AT TIME ZONE 'Asia/Makassar')
        AND al.scanned_at < ((effective_date + 1)::timestamp AT TIME ZONE 'Asia/Makassar')

      UNION ALL

      SELECT resolved_home_outlet_id
    ) raw_outlets
    WHERE outlet_id IS NOT NULL
  ),
  strict_rows AS (
    SELECT recap.*
    FROM candidate_outlets co
    CROSS JOIN LATERAL public.get_admin_schedule_policy_recap(
      co.outlet_id,
      history_start,
      effective_date
    ) recap
    WHERE recap.employee_id = resolved_employee_id
  ),
  legacy_timestamp_rows AS (
    SELECT
      logical_date,
      first_break_at,
      last_kembali_at
    FROM public.get_portal_attendance_recap(effective_date)
  ),
  deduped_rows AS (
    SELECT DISTINCT ON (logical_date)
      logical_date,
      attendance_status,
      outlet_id,
      outlet_name,
      shift_band,
      required_work_minutes,
      net_work_minutes,
      primary_status,
      detail_signals,
      detail_notes,
      logical_day_complete,
      first_scan_local,
      first_break_local,
      last_pulang_local,
      total_break_minutes,
      notes
    FROM strict_rows
    ORDER BY
      logical_date,
      CASE
        WHEN first_scan_local IS NOT NULL OR last_pulang_local IS NOT NULL THEN 0
        WHEN primary_status IS NOT NULL THEN 1
        ELSE 2
      END,
      outlet_name NULLS LAST
  )
  SELECT
    dr.logical_date,
    dr.attendance_status,
    dr.outlet_id,
    dr.outlet_name,
    public.portal_shift_band_label(dr.shift_band, dr.attendance_status) AS shift_band_label,
    dr.required_work_minutes,
    dr.net_work_minutes AS worked_minutes,
    CASE
      WHEN dr.required_work_minutes IS NULL THEN NULL
      ELSE GREATEST(dr.required_work_minutes - coalesce(dr.net_work_minutes, 0), 0)
    END AS remaining_work_minutes,
    dr.primary_status AS strict_primary_status,
    public.portal_strict_outcome_label(
      dr.primary_status,
      dr.attendance_status,
      NOT dr.logical_day_complete
    ) AS strict_outcome_label,
    public.portal_strict_signal_tags(dr.detail_signals) AS short_tags,
    public.portal_strict_helper_copy(
      dr.primary_status,
      dr.attendance_status,
      dr.detail_notes
    ) AS helper_copy,
    NOT dr.logical_day_complete AS is_in_progress,
    (
      dr.shift_band IS NULL
      AND dr.attendance_status = 'hadir_tanpa_jadwal'
    ) AS is_compatibility_mode,
    dr.first_scan_local AS first_masuk_at,
    coalesce(ltr.first_break_at, dr.first_break_local) AS first_break_at,
    ltr.last_kembali_at,
    dr.last_pulang_local AS last_pulang_at,
    coalesce(dr.total_break_minutes, 0)::integer AS total_break_minutes,
    dr.notes
  FROM deduped_rows dr
  LEFT JOIN legacy_timestamp_rows ltr
    ON ltr.logical_date = dr.logical_date
  ORDER BY dr.logical_date DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_portal_attendance_parity_recap(date) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_portal_attendance_parity_recap(date) FROM anon;
REVOKE ALL ON FUNCTION public.get_portal_attendance_parity_recap(date) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.get_portal_attendance_parity_recap(date) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_portal_schedule_parity_overview(
  reference_date date DEFAULT NULL
)
RETURNS TABLE (
  logical_date date,
  outlet_id uuid,
  outlet_name text,
  shift_band_label text,
  required_work_minutes integer,
  worked_minutes integer,
  remaining_work_minutes integer,
  attendance_status text,
  strict_primary_status text,
  strict_outcome_label text,
  short_tags text[],
  helper_copy text,
  is_in_progress boolean,
  is_compatibility_mode boolean,
  is_day_off boolean,
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

  effective_date := COALESCE(reference_date, (NOW() AT TIME ZONE 'Asia/Makassar')::date);
  week_start := effective_date - ((EXTRACT(ISODOW FROM effective_date)::integer) - 1);
  horizon_end := week_start + 13;

  RETURN QUERY
  WITH schedule_rows AS (
    SELECT
      se.date AS logical_date,
      o.id AS outlet_id,
      o.name AS outlet_name,
      public.resolve_schedule_shift_band(coalesce(se.shift_slot, '{}'::jsonb)) AS shift_band,
      CASE
        WHEN coalesce(se.status::text, 'normal') IN ('sakit', 'izin', 'cuti', 'libur')
          THEN coalesce(se.status::text, 'normal')
        WHEN coalesce(se.is_day_off, false)
          OR public.resolve_schedule_shift_band(coalesce(se.shift_slot, '{}'::jsonb)) = 'LIBUR'
          THEN 'libur'
        ELSE 'scheduled'
      END AS attendance_status,
      CASE
        WHEN coalesce(se.status::text, 'normal') IN ('sakit', 'izin', 'cuti', 'libur')
          OR coalesce(se.is_day_off, false)
          OR public.resolve_schedule_shift_band(coalesce(se.shift_slot, '{}'::jsonb)) = 'LIBUR'
        THEN 0
        ELSE coalesce(
          nullif(se.shift_slot->>'required_work_minutes', '')::integer,
          public.resolve_schedule_required_work_minutes(
            coalesce(e.employment_contract, 'FULLTIME'::public.employee_contract)
          )
        )
      END AS required_work_minutes,
      coalesce(se.is_day_off, false)
        OR public.resolve_schedule_shift_band(coalesce(se.shift_slot, '{}'::jsonb)) = 'LIBUR'
        AS is_day_off,
      nullif(
        concat_ws(
          ' | ',
          nullif(btrim(se.notes), ''),
          nullif(btrim(se.shift_slot->>'name'), '')
        ),
        ''
      ) AS notes
    FROM schedule_entries se
    INNER JOIN schedules s ON s.id = se.schedule_id
    INNER JOIN employees e ON e.id = se.employee_id
    INNER JOIN outlets o ON o.id = s.outlet_id
    WHERE se.employee_id = resolved_employee_id
      AND s.is_active = true
      AND se.date BETWEEN week_start AND horizon_end
  ),
  parity_rows AS (
    SELECT *
    FROM public.get_portal_attendance_parity_recap(effective_date)
    WHERE logical_date BETWEEN week_start AND horizon_end
  ),
  merged_rows AS (
    SELECT
      coalesce(sr.logical_date, pr.logical_date) AS logical_date,
      coalesce(sr.outlet_id, pr.outlet_id) AS outlet_id,
      coalesce(sr.outlet_name, pr.outlet_name) AS outlet_name,
      coalesce(
        public.portal_shift_band_label(sr.shift_band, sr.attendance_status),
        pr.shift_band_label
      ) AS shift_band_label,
      coalesce(sr.required_work_minutes, pr.required_work_minutes) AS required_work_minutes,
      pr.worked_minutes,
      pr.remaining_work_minutes,
      coalesce(pr.attendance_status, sr.attendance_status) AS attendance_status,
      pr.strict_primary_status,
      coalesce(
        pr.strict_outcome_label,
        public.portal_strict_outcome_label(NULL, sr.attendance_status, false)
      ) AS strict_outcome_label,
      coalesce(pr.short_tags, ARRAY[]::text[]) AS short_tags,
      coalesce(
        pr.helper_copy,
        CASE
          WHEN sr.attendance_status = 'libur' THEN 'Hari tersebut tidak memiliki target kerja.'
          WHEN sr.attendance_status = 'sakit' THEN 'Karyawan tercatat sakit pada hari tersebut.'
          WHEN sr.attendance_status = 'izin' THEN 'Karyawan tercatat izin pada hari tersebut.'
          WHEN sr.attendance_status = 'cuti' THEN 'Karyawan tercatat cuti pada hari tersebut.'
          ELSE NULL
        END
      ) AS helper_copy,
      coalesce(pr.is_in_progress, false) AS is_in_progress,
      coalesce(pr.is_compatibility_mode, false) AS is_compatibility_mode,
      coalesce(sr.is_day_off, coalesce(pr.attendance_status, '') = 'libur', false) AS is_day_off,
      nullif(concat_ws(' | ', sr.notes, pr.notes), '') AS notes
    FROM schedule_rows sr
    FULL OUTER JOIN parity_rows pr
      ON pr.logical_date = sr.logical_date
  )
  SELECT
    mr.logical_date,
    mr.outlet_id,
    mr.outlet_name,
    mr.shift_band_label,
    mr.required_work_minutes,
    mr.worked_minutes,
    mr.remaining_work_minutes,
    mr.attendance_status,
    mr.strict_primary_status,
    mr.strict_outcome_label,
    mr.short_tags,
    mr.helper_copy,
    mr.is_in_progress,
    mr.is_compatibility_mode,
    mr.is_day_off,
    mr.notes
  FROM merged_rows mr
  ORDER BY mr.logical_date ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_portal_schedule_parity_overview(date) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_portal_schedule_parity_overview(date) FROM anon;
REVOKE ALL ON FUNCTION public.get_portal_schedule_parity_overview(date) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.get_portal_schedule_parity_overview(date) TO authenticated;
