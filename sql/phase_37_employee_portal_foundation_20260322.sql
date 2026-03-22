-- Phase 37: Employee Portal Foundation
-- Portal account table, indexed name-search RPC, and employee identity resolver RPC
-- Additive migration: does NOT modify existing employee data destructively
-- Safe to re-run (IF NOT EXISTS guards, CREATE OR REPLACE FUNCTION)

-- ── 1. Search normalization helper ────────────────────────────────────────────

CREATE OR REPLACE FUNCTION normalize_portal_search_text(input_text text)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
SET search_path = public
AS $$
  SELECT lower(trim(regexp_replace(input_text, '\s+', ' ', 'g')));
$$;

-- Add normalized search column to employees (if not already present)
ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS portal_search_name text
    GENERATED ALWAYS AS (normalize_portal_search_text(name)) STORED;

-- ── 2. Indexes for fast login search ─────────────────────────────────────────

-- pg_trgm extension for trigram GIN index
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- B-tree prefix index for left-anchored LIKE 'query%' matching
CREATE INDEX IF NOT EXISTS employees_portal_search_prefix_idx
  ON employees (portal_search_name text_pattern_ops)
  WHERE is_active = true AND archived_at IS NULL;

-- Trigram GIN index for fuzzy fallback matching (3+ character queries)
CREATE INDEX IF NOT EXISTS employees_portal_search_trgm_idx
  ON employees USING gin (portal_search_name gin_trgm_ops)
  WHERE is_active = true AND archived_at IS NULL;

-- ── 3. employee_portal_accounts table ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS employee_portal_accounts (
  employee_id             uuid PRIMARY KEY REFERENCES employees(id) ON DELETE CASCADE,
  auth_user_id            uuid UNIQUE NOT NULL,
  auth_email              text UNIQUE NOT NULL,
  enabled_at              timestamptz NOT NULL DEFAULT now(),
  provisioned_by          uuid NULL,
  last_password_reset_at  timestamptz NULL,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

-- Index for auth_user_id lookups (resolver RPC)
CREATE INDEX IF NOT EXISTS idx_portal_accounts_auth_user
  ON employee_portal_accounts (auth_user_id);

-- Enable RLS
ALTER TABLE employee_portal_accounts ENABLE ROW LEVEL SECURITY;

-- Admin can read all portal accounts
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policy WHERE polname = 'admin_read_employee_portal_accounts'
  ) THEN
    CREATE POLICY admin_read_employee_portal_accounts ON employee_portal_accounts
      FOR SELECT USING (get_app_role() = 'admin');
  END IF;
END $$;

-- Employee portal users can only read their own mapping
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policy WHERE polname = 'employee_portal_read_own_account'
  ) THEN
    CREATE POLICY employee_portal_read_own_account ON employee_portal_accounts
      FOR SELECT USING (
        auth_user_id = auth.uid()
        AND get_app_role() = 'employee_portal'
      );
  END IF;
END $$;

-- No direct anon writes — all writes go through SECURITY DEFINER Edge Function
REVOKE ALL ON employee_portal_accounts FROM PUBLIC;
GRANT SELECT ON employee_portal_accounts TO authenticated;

-- ── 4. search_portal_employees RPC ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION search_portal_employees(
  search_text   text,
  limit_count   integer DEFAULT 8
)
RETURNS TABLE (
  employee_id     uuid,
  employee_name   text,
  home_outlet_id  uuid,
  home_outlet_name text,
  position        text,
  photo_url       text,
  active_badge_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_query text;
BEGIN
  -- Normalize once
  normalized_query := normalize_portal_search_text(search_text);

  -- Return empty result for too-short queries (less than 2 characters)
  IF char_length(normalized_query) < 2 THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH prefix_matches AS (
    -- Prefer left-anchored prefix matches first
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
    INNER JOIN employee_portal_accounts epa ON epa.employee_id = e.id
    WHERE e.is_active = true
      AND e.archived_at IS NULL
      AND e.portal_search_name LIKE (normalized_query || '%')
    ORDER BY e.portal_search_name
    LIMIT limit_count
  ),
  trgm_matches AS (
    -- Trigram fallback only for queries >= 3 characters
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
    INNER JOIN employee_portal_accounts epa ON epa.employee_id = e.id
    WHERE e.is_active = true
      AND e.archived_at IS NULL
      AND char_length(normalized_query) >= 3
      AND e.portal_search_name % normalized_query
      AND e.id NOT IN (SELECT pm.employee_id FROM prefix_matches pm)
    ORDER BY similarity(e.portal_search_name, normalized_query) DESC
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
GRANT EXECUTE ON FUNCTION search_portal_employees(text, integer) TO authenticated;

-- ── 5. resolve_portal_employee RPC ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION resolve_portal_employee()
RETURNS TABLE (
  employee_id     uuid,
  employee_name   text,
  position        text,
  home_outlet_id  uuid,
  home_outlet_name text,
  photo_url       text,
  active_badge_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_uid    uuid;
  match_count   integer;
BEGIN
  caller_uid := auth.uid();

  IF caller_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Count matching active employee rows for this auth user
  SELECT COUNT(*)
  INTO match_count
  FROM employee_portal_accounts epa
  INNER JOIN employees e ON e.id = epa.employee_id
  WHERE epa.auth_user_id = caller_uid
    AND e.is_active = true
    AND e.archived_at IS NULL;

  IF match_count = 0 THEN
    RAISE EXCEPTION 'No active employee found for this portal account';
  END IF;

  IF match_count > 1 THEN
    RAISE EXCEPTION 'Ambiguous portal identity: multiple active employees mapped to this account';
  END IF;

  RETURN QUERY
  SELECT
    e.id              AS employee_id,
    e.name            AS employee_name,
    e.position        AS position,
    e.home_outlet_id  AS home_outlet_id,
    o.name            AS home_outlet_name,
    e.photo_url       AS photo_url,
    e.active_badge_id AS active_badge_id
  FROM employee_portal_accounts epa
  INNER JOIN employees e ON e.id = epa.employee_id
  LEFT JOIN outlets o ON o.id = e.home_outlet_id
  WHERE epa.auth_user_id = caller_uid
    AND e.is_active = true
    AND e.archived_at IS NULL;
END;
$$;

REVOKE ALL ON FUNCTION resolve_portal_employee() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION resolve_portal_employee() TO authenticated;
