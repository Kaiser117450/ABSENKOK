-- Phase 38: Employee Schedule Read Model
-- Additive employee-scoped current-week schedule read model for the portal
-- Provides: get_portal_schedule_week RPC + supporting indexes
-- Depends on: phase_37_employee_portal_foundation_20260322.sql (resolve_portal_employee)
-- Safe to re-run (IF NOT EXISTS index guards, CREATE OR REPLACE FUNCTION)

-- ── 1. Query-shaped indexes ────────────────────────────────────────────────────

-- Composite index on schedule_entries (employee_id, date) for portal lookups.
-- Partial predicate excludes unassigned custom-name rows (employee_id IS NULL).
CREATE INDEX IF NOT EXISTS idx_schedule_entries_employee_date
  ON schedule_entries (employee_id, date)
  WHERE employee_id IS NOT NULL;

-- Active-schedule header index for efficient current-week header joins.
-- Partial predicate matches the is_active filter used in every portal query.
CREATE INDEX IF NOT EXISTS idx_schedules_outlet_active_dates
  ON schedules (outlet_id, start_date, end_date)
  WHERE is_active = true;

-- ── 2. get_portal_schedule_week RPC ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_portal_schedule_week(reference_date date DEFAULT NULL)
RETURNS TABLE (
  logical_date  date,
  outlet_id     uuid,
  outlet_name   text,
  shift_name    text,
  start_hour    integer,
  start_minute  integer,
  end_hour      integer,
  end_minute    integer,
  is_day_off    boolean,
  ends_next_day boolean,
  notes         text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  -- Resolved employee identity (never accept from caller)
  resolved_employee_id  uuid;

  -- Explicit business-local reference date; one expression, not scattered current_date calls
  effective_date        date;

  -- Monday-start week boundaries (ISO week: Monday = day 1)
  week_start            date;
  week_end              date;
BEGIN
  -- Resolve employee from the authenticated portal session.
  -- This mirrors resolve_portal_employee() but extracts only the id to keep
  -- the join logic below self-contained and avoids a nested SETOF call.
  SELECT epa.employee_id
  INTO resolved_employee_id
  FROM employee_portal_accounts epa
  INNER JOIN employees e ON e.id = epa.employee_id
  WHERE epa.auth_user_id = auth.uid()
    AND e.is_active = true
    AND e.archived_at IS NULL
  LIMIT 1;

  IF resolved_employee_id IS NULL THEN
    RAISE EXCEPTION 'No active employee found for the authenticated portal account';
  END IF;

  -- Determine effective reference date (caller-supplied or database current_date).
  -- Centralised here so all week-boundary logic stays consistent.
  effective_date := COALESCE(reference_date, current_date);

  -- Monday-start week boundary (ISODOW: Mon=1 … Sun=7)
  week_start := effective_date - ((EXTRACT(ISODOW FROM effective_date)::integer) - 1);
  week_end   := week_start + 6;

  -- Main query: schedule_entries -> schedules -> outlets
  -- Filter: resolved employee + current-week date range + active schedule headers only
  -- Order: logical_date asc, then shift start time asc
  RETURN QUERY
  SELECT
    se.date                           AS logical_date,
    o.id                              AS outlet_id,
    o.name                            AS outlet_name,
    (se.shift_slot->>'name')::text    AS shift_name,
    (se.shift_slot->>'start_hour')::integer   AS start_hour,
    (se.shift_slot->>'start_minute')::integer AS start_minute,
    (se.shift_slot->>'end_hour')::integer     AS end_hour,
    (se.shift_slot->>'end_minute')::integer   AS end_minute,
    COALESCE(se.is_day_off, false)    AS is_day_off,
    -- Overnight flag: end_time <= start_time on a non-day-off row.
    -- Matches the existing noon-rule: logical day is anchored to the scheduled start date.
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
    END                               AS ends_next_day,
    se.notes                          AS notes
  FROM schedule_entries se
  INNER JOIN schedules s ON s.id = se.schedule_id
  INNER JOIN outlets o   ON o.id = s.outlet_id
  WHERE se.employee_id = resolved_employee_id
    AND se.date BETWEEN week_start AND week_end
    AND s.is_active = true
  ORDER BY se.date, (se.shift_slot->>'start_hour')::integer, (se.shift_slot->>'start_minute')::integer;
END;
$$;

-- ── 3. Security: revoke public access, grant only to authenticated ─────────────

REVOKE ALL ON FUNCTION get_portal_schedule_week(date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_portal_schedule_week(date) TO authenticated;
