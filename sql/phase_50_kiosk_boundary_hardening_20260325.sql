-- Phase 50: Kiosk Device Boundary Hardening
-- Additive migration. Safe to re-run with CREATE OR REPLACE FUNCTION.
-- Does not drop tables, columns, or existing data.

-- ── 1. Activation binds one persistent device UUID to one outlet ───────────

CREATE OR REPLACE FUNCTION public.activate_kiosk_device(
  p_outlet_name text,
  p_password text,
  p_device_uuid text
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_verify_result jsonb;
  v_verified_outlet_id uuid;
  v_verified_outlet_name text;
  v_outlet_name text := NULLIF(btrim(p_outlet_name), '');
  v_device_uuid text := NULLIF(btrim(p_device_uuid), '');
  v_existing_outlet_id uuid;
BEGIN
  IF v_outlet_name IS NULL THEN
    RAISE EXCEPTION 'Outlet name is required for kiosk activation';
  END IF;

  IF p_password IS NULL OR p_password = '' THEN
    RAISE EXCEPTION 'Password is required for kiosk activation';
  END IF;

  IF v_device_uuid IS NULL THEN
    RAISE EXCEPTION 'Device UUID is required for kiosk activation';
  END IF;

  v_verify_result :=
    public.verify_kiosk_password(
      v_outlet_name,
      p_password
    )::jsonb;

  IF v_verify_result IS NULL THEN
    RAISE EXCEPTION 'Kiosk activation failed: outlet verification returned no result';
  END IF;

  IF v_verify_result ? 'error' THEN
    RAISE EXCEPTION '%', v_verify_result ->> 'error';
  END IF;

  v_verified_outlet_id := NULLIF(v_verify_result ->> 'outlet_id', '')::uuid;
  v_verified_outlet_name := NULLIF(v_verify_result ->> 'outlet_name', '');

  IF v_verified_outlet_id IS NULL OR v_verified_outlet_name IS NULL THEN
    RAISE EXCEPTION 'Kiosk activation failed: outlet verification returned an incomplete response';
  END IF;

  SELECT kd.outlet_id
  INTO v_existing_outlet_id
  FROM public.kiosk_devices kd
  WHERE kd.device_uuid = v_device_uuid;

  IF FOUND THEN
    IF v_existing_outlet_id IS NOT NULL
       AND v_existing_outlet_id IS DISTINCT FROM v_verified_outlet_id THEN
      RAISE EXCEPTION 'Device UUID % is already activated for a different outlet', v_device_uuid;
    END IF;

    UPDATE public.kiosk_devices kd
    SET outlet_id = v_verified_outlet_id,
        is_active = TRUE,
        updated_at = now()
    WHERE kd.device_uuid = v_device_uuid;
  ELSE
    INSERT INTO public.kiosk_devices (
      device_uuid,
      outlet_id,
      is_active,
      created_at,
      updated_at
    ) VALUES (
      v_device_uuid,
      v_verified_outlet_id,
      TRUE,
      now(),
      now()
    );
  END IF;

  RETURN json_build_object(
    'outlet_id', v_verified_outlet_id,
    'outlet_name', v_verified_outlet_name,
    'device_uuid', v_device_uuid
  );
END;
$$;

REVOKE ALL ON FUNCTION public.activate_kiosk_device(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.activate_kiosk_device(text, text, text) TO anon;

-- ── 2. Heartbeats only refresh telemetry for an activated device binding ───

CREATE OR REPLACE FUNCTION public.upsert_kiosk_heartbeat(
  p_device_uuid text,
  p_outlet_id uuid,
  p_battery_level smallint DEFAULT NULL,
  p_is_charging boolean DEFAULT NULL,
  p_pending_sync_count integer DEFAULT NULL,
  p_app_version text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_device_uuid text := NULLIF(btrim(p_device_uuid), '');
  v_existing_outlet_id uuid;
  v_is_active boolean;
BEGIN
  IF v_device_uuid IS NULL THEN
    RAISE EXCEPTION 'Device UUID is required for kiosk heartbeat';
  END IF;

  IF p_outlet_id IS NULL THEN
    RAISE EXCEPTION 'Outlet ID is required for kiosk heartbeat';
  END IF;

  UPDATE public.kiosk_devices kd
  SET last_heartbeat_at = now(),
      battery_level = p_battery_level,
      is_charging = p_is_charging,
      pending_sync_count = p_pending_sync_count,
      app_version = p_app_version,
      updated_at = now()
  WHERE kd.device_uuid = v_device_uuid
    AND kd.outlet_id = p_outlet_id
    AND kd.is_active = TRUE;

  IF FOUND THEN
    RETURN;
  END IF;

  SELECT kd.outlet_id, kd.is_active
  INTO v_existing_outlet_id, v_is_active
  FROM public.kiosk_devices kd
  WHERE kd.device_uuid = v_device_uuid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kiosk device % is not activated for outlet %', v_device_uuid, p_outlet_id;
  END IF;

  IF v_existing_outlet_id IS NULL THEN
    RAISE EXCEPTION 'Kiosk device % is not activated for outlet %', v_device_uuid, p_outlet_id;
  END IF;

  IF v_existing_outlet_id IS DISTINCT FROM p_outlet_id THEN
    RAISE EXCEPTION
      'Kiosk device % is already activated for outlet % and cannot send heartbeat for outlet %',
      v_device_uuid,
      v_existing_outlet_id,
      p_outlet_id;
  END IF;

  IF COALESCE(v_is_active, FALSE) = FALSE THEN
    RAISE EXCEPTION
      'Kiosk device % is archived and must be activated again before heartbeat updates are accepted',
      v_device_uuid;
  END IF;

  RAISE EXCEPTION 'Kiosk device % is not activated for outlet %', v_device_uuid, p_outlet_id;
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_kiosk_heartbeat(text, uuid, smallint, boolean, integer, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upsert_kiosk_heartbeat(text, uuid, smallint, boolean, integer, text) TO anon;

-- ── 3. Nickname changes require authenticated admin or scoped kepala gerai ─

CREATE OR REPLACE FUNCTION public.set_device_nickname(
  p_device_id uuid,
  p_nickname text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text := auth.jwt() -> 'app_metadata' ->> 'app_role';
  v_managed_outlet_id uuid := NULLIF(auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id', '')::uuid;
  v_target_outlet_id uuid;
BEGIN
  IF auth.role() IS DISTINCT FROM 'authenticated' THEN
    RAISE EXCEPTION 'Authenticated session required to manage kiosk devices';
  END IF;

  SELECT kd.outlet_id
  INTO v_target_outlet_id
  FROM public.kiosk_devices kd
  WHERE kd.id = p_device_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kiosk device % not found', p_device_id;
  END IF;

  IF v_role = 'admin' THEN
    NULL;
  ELSIF v_role = 'kepala_gerai'
        AND v_managed_outlet_id IS NOT NULL
        AND v_managed_outlet_id = v_target_outlet_id THEN
    NULL;
  ELSE
    RAISE EXCEPTION 'Not authorized to rename this kiosk device';
  END IF;

  UPDATE public.kiosk_devices kd
  SET nickname = NULLIF(btrim(p_nickname), ''),
      updated_at = now()
  WHERE kd.id = p_device_id;
END;
$$;

REVOKE ALL ON FUNCTION public.set_device_nickname(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_device_nickname(uuid, text) TO authenticated;

-- ── 4. Archive requires the same authenticated outlet-aware authorization ──

CREATE OR REPLACE FUNCTION public.archive_device(
  p_device_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text := auth.jwt() -> 'app_metadata' ->> 'app_role';
  v_managed_outlet_id uuid := NULLIF(auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id', '')::uuid;
  v_target_outlet_id uuid;
BEGIN
  IF auth.role() IS DISTINCT FROM 'authenticated' THEN
    RAISE EXCEPTION 'Authenticated session required to manage kiosk devices';
  END IF;

  SELECT kd.outlet_id
  INTO v_target_outlet_id
  FROM public.kiosk_devices kd
  WHERE kd.id = p_device_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kiosk device % not found', p_device_id;
  END IF;

  IF v_role = 'admin' THEN
    NULL;
  ELSIF v_role = 'kepala_gerai'
        AND v_managed_outlet_id IS NOT NULL
        AND v_managed_outlet_id = v_target_outlet_id THEN
    NULL;
  ELSE
    RAISE EXCEPTION 'Not authorized to archive this kiosk device';
  END IF;

  UPDATE public.kiosk_devices kd
  SET is_active = FALSE,
      updated_at = now()
  WHERE kd.id = p_device_id;
END;
$$;

REVOKE ALL ON FUNCTION public.archive_device(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.archive_device(uuid) TO authenticated;
