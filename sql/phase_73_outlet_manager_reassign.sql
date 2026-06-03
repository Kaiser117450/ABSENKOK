-- sql/phase_73_outlet_manager_reassign.sql
-- Phase 73: Admin can reassign an outlet manager (kepala gerai / area
-- supervisor) to a different outlet when they relocate ("ganti wilayah").
--
-- The manager's scope lives in auth.users.raw_app_meta_data
-- (managed_outlet_id + managed_outlet_ids). These RPCs are admin-only
-- (SECURITY DEFINER) since editing auth.users needs elevated rights.
-- Note: the change takes effect after the manager's next token refresh / login.

BEGIN;

-- List all outlet managers with their current scope (admin-only).
CREATE OR REPLACE FUNCTION public.admin_list_outlet_managers()
RETURNS TABLE(
  user_id            uuid,
  email              text,
  role               text,
  managed_outlet_id  uuid,
  managed_outlet_ids uuid[]
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
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
    u.raw_app_meta_data->>'app_role',
    NULLIF(u.raw_app_meta_data->>'managed_outlet_id', '')::uuid,
    ARRAY(
      SELECT elem::uuid
      FROM jsonb_array_elements_text(
        COALESCE(u.raw_app_meta_data->'managed_outlet_ids', '[]'::jsonb)
      ) AS elem
    )
  FROM auth.users u
  WHERE u.raw_app_meta_data->>'app_role' IN ('kepala_gerai', 'area_supervisor')
  ORDER BY u.email;
END;
$$;

-- Reassign a manager's outlet scope (admin-only). First id becomes the primary.
CREATE OR REPLACE FUNCTION public.admin_reassign_outlet_manager(
  p_user_id    uuid,
  p_outlet_ids uuid[]
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role        text;
  v_target_role text;
  v_primary     uuid;
  v_count       integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '28000';
  END IF;
  SELECT raw_app_meta_data->>'app_role' INTO v_role
    FROM auth.users WHERE id = auth.uid();
  IF v_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'forbidden: admin only' USING ERRCODE = '42501';
  END IF;

  IF p_outlet_ids IS NULL OR array_length(p_outlet_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'at least one outlet is required' USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_count FROM public.outlets WHERE id = ANY(p_outlet_ids);
  IF v_count <> array_length(p_outlet_ids, 1) THEN
    RAISE EXCEPTION 'one or more outlets not found' USING ERRCODE = '22023';
  END IF;

  SELECT raw_app_meta_data->>'app_role' INTO v_target_role
    FROM auth.users WHERE id = p_user_id;
  IF v_target_role IS NULL THEN
    RAISE EXCEPTION 'target user not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_target_role NOT IN ('kepala_gerai', 'area_supervisor') THEN
    RAISE EXCEPTION 'target user is not an outlet manager' USING ERRCODE = '42501';
  END IF;

  v_primary := p_outlet_ids[1];

  UPDATE auth.users
     SET raw_app_meta_data = jsonb_set(
           jsonb_set(
             COALESCE(raw_app_meta_data, '{}'::jsonb),
             '{managed_outlet_id}', to_jsonb(v_primary::text), true
           ),
           '{managed_outlet_ids}',
           to_jsonb(ARRAY(SELECT x::text FROM unnest(p_outlet_ids) AS x)),
           true
         )
   WHERE id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_outlet_managers() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_reassign_outlet_manager(uuid, uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_outlet_managers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reassign_outlet_manager(uuid, uuid[]) TO authenticated;

COMMENT ON FUNCTION public.admin_list_outlet_managers() IS 'Admin-only: lists kepala gerai / area supervisor logins with current outlet scope.';
COMMENT ON FUNCTION public.admin_reassign_outlet_manager(uuid, uuid[]) IS 'Admin-only: sets a manager''s managed_outlet_id(s). Effective after their next login/token refresh.';

COMMIT;
