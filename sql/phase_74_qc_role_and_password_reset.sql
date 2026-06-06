-- Phase 74 — Read-only QC role + admin password reset
--
-- 1. qc_can_access_outlet(): outlet-scoping helper for the new read-only 'qc'
--    role. Mirrors current_admin_can_access_outlet() but ONLY grants the 'qc'
--    role — deliberately isolated so QC never inherits access to any table
--    whose RLS uses the admin/scoped helper.
-- 2. RLS SELECT policy letting a 'qc' user read attendance_photo_analysis rows
--    for the outlet(s) they are scoped to (the only table gated to admins).
-- 3. admin_list_app_users(): admin-only listing of privileged accounts for the
--    password-reset screen.
--
-- Idempotent: safe to re-run.

-- ---------------------------------------------------------------------------
-- 1. QC outlet-scoping helper
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.qc_can_access_outlet(p_outlet_id uuid)
  RETURNS boolean
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_role TEXT := NULLIF(BTRIM(auth.jwt() -> 'app_metadata' ->> 'app_role'), '');
  v_metadata JSONB := COALESCE(auth.jwt() -> 'app_metadata', '{}'::JSONB);
  v_legacy_outlet_text TEXT :=
      NULLIF(BTRIM(v_metadata ->> 'managed_outlet_id'), '');
  v_candidate TEXT;
  v_allowed_outlets UUID[] := ARRAY[]::UUID[];
  v_uuid_re TEXT :=
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
BEGIN
  IF p_outlet_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Strictly the QC role — no other role gains access through this helper.
  IF v_role IS DISTINCT FROM 'qc' THEN
    RETURN FALSE;
  END IF;

  IF v_legacy_outlet_text ~* v_uuid_re THEN
    v_allowed_outlets := array_append(v_allowed_outlets, v_legacy_outlet_text::UUID);
  END IF;

  IF jsonb_typeof(v_metadata -> 'managed_outlet_ids') = 'array' THEN
    FOR v_candidate IN
      SELECT jsonb_array_elements_text(v_metadata -> 'managed_outlet_ids')
    LOOP
      IF v_candidate ~* v_uuid_re THEN
        v_allowed_outlets := array_append(v_allowed_outlets, v_candidate::UUID);
      END IF;
    END LOOP;
  END IF;

  RETURN p_outlet_id = ANY(v_allowed_outlets);
END;
$$;

GRANT EXECUTE ON FUNCTION public.qc_can_access_outlet(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. QC read access to grooming analysis (scoped to their outlet[s])
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS attendance_photo_analysis_qc_select
  ON public.attendance_photo_analysis;

CREATE POLICY attendance_photo_analysis_qc_select
  ON public.attendance_photo_analysis
  FOR SELECT
  TO authenticated
  USING (
    get_app_role() = 'qc'
    AND EXISTS (
      SELECT 1
      FROM public.attendance_logs al
      WHERE al.id = attendance_photo_analysis.attendance_log_id
        AND public.qc_can_access_outlet(al.scan_outlet_id)
    )
  );

-- ---------------------------------------------------------------------------
-- 3. Admin-only listing of privileged accounts (for password-reset screen)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_app_users()
  RETURNS TABLE(
    user_id uuid,
    email text,
    name text,
    role text,
    managed_outlet_id uuid,
    managed_outlet_ids uuid[],
    must_change_password boolean,
    created_at timestamptz
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_role text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '28000';
  END IF;
  SELECT raw_app_meta_data->>'app_role' INTO v_role
    FROM auth.users WHERE id = auth.uid();
  IF v_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'forbidden: admin only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    u.email::text,
    COALESCE(NULLIF(BTRIM(u.raw_user_meta_data->>'name'), ''), u.email::text),
    u.raw_app_meta_data->>'app_role',
    NULLIF(u.raw_app_meta_data->>'managed_outlet_id', '')::uuid,
    ARRAY(
      SELECT elem::uuid
      FROM jsonb_array_elements_text(
        COALESCE(u.raw_app_meta_data->'managed_outlet_ids', '[]'::jsonb)
      ) AS elem
    ),
    COALESCE((u.raw_app_meta_data->>'must_change_password')::boolean, false),
    u.created_at
  FROM auth.users u
  WHERE u.raw_app_meta_data->>'app_role'
        IN ('admin', 'kepala_gerai', 'area_supervisor', 'qc')
  ORDER BY u.raw_app_meta_data->>'app_role', u.email;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_app_users() TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Accountability audit trail for admin password resets (Phase 74b)
--    Closes the repudiation gap: every reset-user-password call records who
--    reset whom. The Edge Function (service_role) bypasses RLS to insert;
--    only admins may read.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.admin_password_reset_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_user_id  uuid NOT NULL,
  target_email    text,
  target_role     text,
  reset_by        uuid NOT NULL,
  reset_by_email  text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_password_reset_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_password_reset_log_admin_read
  ON public.admin_password_reset_log;

CREATE POLICY admin_password_reset_log_admin_read
  ON public.admin_password_reset_log
  FOR SELECT
  TO authenticated
  USING (get_app_role() = 'admin');

CREATE INDEX IF NOT EXISTS idx_admin_password_reset_log_created_at
  ON public.admin_password_reset_log (created_at DESC);
