-- Phase 58: Dynamic Shift Roles Table
-- Moves hardcoded role list from Flutter app to Supabase database
-- so admin can add/remove roles without updating the APK.

CREATE TABLE IF NOT EXISTS public.shift_roles (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL UNIQUE,
  outlet_mode_filter text DEFAULT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.shift_roles IS 'Dynamic shift role definitions. Fetched by Flutter app to populate role selectors.';
COMMENT ON COLUMN public.shift_roles.outlet_mode_filter IS 'NULL = available in all outlets. TWENTY_FOUR_HOUR = only shown for 24-hour outlets.';

ALTER TABLE public.shift_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "shift_roles_select" ON public.shift_roles;
CREATE POLICY "shift_roles_select" ON public.shift_roles
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "shift_roles_admin_insert" ON public.shift_roles;
CREATE POLICY "shift_roles_admin_insert" ON public.shift_roles
  FOR INSERT TO authenticated
  WITH CHECK (
    COALESCE(
      (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'app_role'),
      (current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'app_role')
    ) = 'admin'
  );

DROP POLICY IF EXISTS "shift_roles_admin_update" ON public.shift_roles;
CREATE POLICY "shift_roles_admin_update" ON public.shift_roles
  FOR UPDATE TO authenticated
  USING (
    COALESCE(
      (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'app_role'),
      (current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'app_role')
    ) = 'admin'
  )
  WITH CHECK (
    COALESCE(
      (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'app_role'),
      (current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'app_role')
    ) = 'admin'
  );

DROP POLICY IF EXISTS "shift_roles_admin_delete" ON public.shift_roles;
CREATE POLICY "shift_roles_admin_delete" ON public.shift_roles
  FOR DELETE TO authenticated
  USING (
    COALESCE(
      (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'app_role'),
      (current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'app_role')
    ) = 'admin'
  );

INSERT INTO public.shift_roles (name, outlet_mode_filter, sort_order) VALUES
  ('Kasir', NULL, 1),
  ('Assambler', NULL, 2),
  ('Housekeeping', NULL, 3),
  ('Checker', NULL, 4),
  ('Ayam', NULL, 5),
  ('Kitchen', NULL, 6),
  ('Kopi', 'TWENTY_FOUR_HOUR', 7)
ON CONFLICT (name) DO NOTHING;
