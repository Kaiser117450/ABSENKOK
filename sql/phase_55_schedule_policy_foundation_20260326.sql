-- Phase 55: Schedule policy foundation
-- Additive-only patch: preserves legacy shift_slot clock hints while backfilling
-- typed policy keys for the band-first scheduler and recap pipeline.
-- Phase 55 default required hours are explicit here:
--   FULLTIME = 600 minutes
--   PARTTIME = 540 minutes
-- App-layer per-day overrides may still replace required_work_minutes later.

CREATE OR REPLACE FUNCTION public.resolve_schedule_shift_band(shift_slot jsonb)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN upper(coalesce(shift_slot->>'band', '')) IN ('PAGI', 'SIANG', 'SORE', 'LIBUR')
      THEN upper(shift_slot->>'band')
    WHEN upper(coalesce(shift_slot->>'name', '')) IN ('PAGI', 'SIANG', 'SORE', 'LIBUR')
      THEN upper(shift_slot->>'name')
    WHEN upper(replace(coalesce(shift_slot->>'name', ''), ' ', '')) IN ('DAYOFF', 'HARILIBUR')
      THEN 'LIBUR'
    WHEN coalesce(nullif(shift_slot->>'start_hour', '')::integer, 9) >= 14
      THEN 'SORE'
    WHEN coalesce(nullif(shift_slot->>'start_hour', '')::integer, 9) >= 12
      THEN 'SIANG'
    WHEN coalesce(nullif(shift_slot->>'start_hour', '')::integer, 9) = 0
      AND coalesce(nullif(shift_slot->>'end_hour', '')::integer, 0) = 0
      THEN 'LIBUR'
    ELSE 'PAGI'
  END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_schedule_required_work_minutes(
  employee_contract public.employee_contract
)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN employee_contract = 'PARTTIME'::public.employee_contract THEN 540
    ELSE 600
  END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_schedule_late_cutoff_minutes(shift_band text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE upper(coalesce(shift_band, ''))
    WHEN 'PAGI' THEN 420
    WHEN 'SIANG' THEN 600
    WHEN 'SORE' THEN 900
    ELSE 0
  END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_schedule_break_first_deadline_minutes(
  shift_band text,
  employee_contract public.employee_contract
)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN public.resolve_schedule_late_cutoff_minutes(shift_band) = 0 THEN 0
    WHEN employee_contract = 'PARTTIME'::public.employee_contract
      THEN public.resolve_schedule_late_cutoff_minutes(shift_band) + 60
    ELSE public.resolve_schedule_late_cutoff_minutes(shift_band) + 120
  END;
$$;

WITH computed_rows AS (
  SELECT
    se.id,
    coalesce(se.shift_slot, '{}'::jsonb) AS shift_slot,
    public.resolve_schedule_shift_band(coalesce(se.shift_slot, '{}'::jsonb)) AS resolved_band,
    CASE
      WHEN public.resolve_schedule_shift_band(coalesce(se.shift_slot, '{}'::jsonb)) = 'LIBUR' THEN 0
      ELSE coalesce(
        nullif(se.shift_slot->>'required_work_minutes', '')::integer,
        public.resolve_schedule_required_work_minutes(
          coalesce(e.employment_contract, 'FULLTIME'::public.employee_contract)
        )
      )
    END AS resolved_required_work_minutes,
    coalesce(
      nullif(se.shift_slot->>'late_cutoff_hour', '')::integer,
      public.resolve_schedule_late_cutoff_minutes(
        public.resolve_schedule_shift_band(coalesce(se.shift_slot, '{}'::jsonb))
      ) / 60
    ) AS resolved_late_cutoff_hour,
    coalesce(
      nullif(se.shift_slot->>'late_cutoff_minute', '')::integer,
      public.resolve_schedule_late_cutoff_minutes(
        public.resolve_schedule_shift_band(coalesce(se.shift_slot, '{}'::jsonb))
      ) % 60
    ) AS resolved_late_cutoff_minute,
    coalesce(
      nullif(se.shift_slot->>'break_first_deadline_hour', '')::integer,
      public.resolve_schedule_break_first_deadline_minutes(
        public.resolve_schedule_shift_band(coalesce(se.shift_slot, '{}'::jsonb)),
        coalesce(e.employment_contract, 'FULLTIME'::public.employee_contract)
      ) / 60
    ) AS resolved_break_first_deadline_hour,
    coalesce(
      nullif(se.shift_slot->>'break_first_deadline_minute', '')::integer,
      public.resolve_schedule_break_first_deadline_minutes(
        public.resolve_schedule_shift_band(coalesce(se.shift_slot, '{}'::jsonb)),
        coalesce(e.employment_contract, 'FULLTIME'::public.employee_contract)
      ) % 60
    ) AS resolved_break_first_deadline_minute
  FROM schedule_entries se
  INNER JOIN schedules s ON s.id = se.schedule_id
  LEFT JOIN employees e ON e.id = se.employee_id
  WHERE s.is_active = true
)
UPDATE schedule_entries AS se
SET shift_slot = jsonb_set(
  jsonb_set(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          jsonb_set(
            computed_rows.shift_slot,
            '{band}',
            to_jsonb(computed_rows.resolved_band),
            true
          ),
          '{required_work_minutes}',
          to_jsonb(computed_rows.resolved_required_work_minutes),
          true
        ),
        '{late_cutoff_hour}',
        to_jsonb(computed_rows.resolved_late_cutoff_hour),
        true
      ),
      '{late_cutoff_minute}',
      to_jsonb(computed_rows.resolved_late_cutoff_minute),
      true
    ),
    '{break_first_deadline_hour}',
    to_jsonb(computed_rows.resolved_break_first_deadline_hour),
    true
  ),
  '{break_first_deadline_minute}',
  to_jsonb(computed_rows.resolved_break_first_deadline_minute),
  true
)
FROM computed_rows
WHERE se.id = computed_rows.id;
