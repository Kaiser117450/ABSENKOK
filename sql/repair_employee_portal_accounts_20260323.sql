-- Recovery: restore employee_portal_accounts and backfill mappings from auth.users
-- Context:
--   Portal RPCs exist in production, but public.employee_portal_accounts is missing.
--   Hidden auth emails use employee+<employee_uuid>@portal.absenkok.internal, so
--   most mappings can be reconstructed safely from auth.users.
-- Safe to re-run:
--   - CREATE TABLE/INDEX IF NOT EXISTS
--   - Policy creation guarded
--   - Backfill uses ON CONFLICT on employee_id

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

WITH portal_auth AS (
  SELECT
    u.id AS auth_user_id,
    u.email AS auth_email,
    CASE
      WHEN split_part(split_part(u.email, '@', 1), '+', 2) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN split_part(split_part(u.email, '@', 1), '+', 2)::uuid
      ELSE NULL
    END AS employee_id,
    COALESCE(u.created_at, now()) AS auth_created_at
  FROM auth.users u
  WHERE u.email LIKE 'employee+%@portal.absenkok.internal'
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
FROM portal_auth pa
INNER JOIN employees e ON e.id = pa.employee_id
WHERE pa.employee_id IS NOT NULL
  AND e.is_active = true
  AND e.archived_at IS NULL
ON CONFLICT (employee_id) DO UPDATE
SET
  auth_user_id = EXCLUDED.auth_user_id,
  auth_email = EXCLUDED.auth_email,
  updated_at = now();
