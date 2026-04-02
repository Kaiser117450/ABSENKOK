-- Recovery: restore employee_portal_accounts without widening portal identity trust
-- This additive repair script preserves the passwordless portal flow, but it only
-- restores mappings for auth users that already prove the expected employee_portal
-- identity. Ambiguous or conflicting rows are intentionally skipped for manual review.
-- Safe to re-run:
--   - CREATE TABLE/INDEX IF NOT EXISTS
--   - Policy creation guarded
--   - Backfill skips conflicting rows and never overwrites auth_user_id

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

CREATE INDEX IF NOT EXISTS idx_portal_accounts_auth_user
  ON employee_portal_accounts (auth_user_id);

ALTER TABLE employee_portal_accounts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policy WHERE polname = 'admin_read_employee_portal_accounts'
  ) THEN
    CREATE POLICY admin_read_employee_portal_accounts ON employee_portal_accounts
      FOR SELECT USING (get_app_role() = 'admin');
  END IF;
END $$;

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

REVOKE ALL ON employee_portal_accounts FROM PUBLIC;
GRANT SELECT ON employee_portal_accounts TO authenticated;

WITH candidate_portal_auth AS (
  SELECT
    u.id AS auth_user_id,
    lower(u.email) AS auth_email,
    CASE
      WHEN split_part(split_part(lower(u.email), '@', 1), '+', 2) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN split_part(split_part(lower(u.email), '@', 1), '+', 2)::uuid
      ELSE NULL
    END AS hidden_email_employee_id,
    CASE
      WHEN COALESCE(u.raw_app_meta_data->>'employee_id', '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN (u.raw_app_meta_data->>'employee_id')::uuid
      ELSE NULL
    END AS metadata_employee_id,
    COALESCE(u.created_at, now()) AS auth_created_at
  FROM auth.users u
  WHERE lower(u.email) LIKE 'employee+%@portal.absenkok.internal'
    AND u.email_confirmed_at IS NOT NULL
    AND COALESCE(u.raw_app_meta_data->>'app_role', '') = 'employee_portal'
),
restorable_portal_auth AS (
  SELECT
    pa.auth_user_id,
    pa.auth_email,
    pa.hidden_email_employee_id AS employee_id,
    pa.auth_created_at
  FROM candidate_portal_auth pa
  WHERE pa.hidden_email_employee_id IS NOT NULL
    AND pa.metadata_employee_id = pa.hidden_email_employee_id
)
INSERT INTO employee_portal_accounts (
  employee_id,
  auth_user_id,
  auth_email,
  enabled_at,
  provisioned_by,
  last_password_reset_at,
  created_at,
  updated_at
)
SELECT
  e.id,
  pa.auth_user_id,
  pa.auth_email,
  pa.auth_created_at,
  NULL,
  NULL,
  pa.auth_created_at,
  now()
FROM restorable_portal_auth pa
INNER JOIN employees e ON e.id = pa.employee_id
WHERE e.is_active = true
  AND e.archived_at IS NULL
  -- Skip rows where a different employee already owns this auth user or auth email.
  AND NOT EXISTS (
    SELECT 1
    FROM employee_portal_accounts existing
    WHERE existing.auth_user_id = pa.auth_user_id
      AND existing.employee_id <> e.id
  )
  AND NOT EXISTS (
    SELECT 1
    FROM employee_portal_accounts existing
    WHERE existing.auth_email = pa.auth_email
      AND existing.employee_id <> e.id
  )
ON CONFLICT (employee_id) DO UPDATE
SET
  auth_email = EXCLUDED.auth_email,
  updated_at = now()
WHERE EXCLUDED.auth_user_id = employee_portal_accounts.auth_user_id;
