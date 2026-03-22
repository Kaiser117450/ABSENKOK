-- Phase 32: Multi-Device Dashboard — Nickname + Archive RPCs
-- Additive migration. Safe to re-run (CREATE OR REPLACE).

-- 1. set_device_nickname: admin sets a human-readable name for a kiosk
CREATE OR REPLACE FUNCTION set_device_nickname(
  p_device_id UUID,
  p_nickname  TEXT
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE kiosk_devices
  SET nickname = p_nickname, updated_at = NOW()
  WHERE id = p_device_id;
END;
$$;

-- 2. archive_device: soft-delete a retired kiosk
CREATE OR REPLACE FUNCTION archive_device(
  p_device_id UUID
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE kiosk_devices
  SET is_active = false, updated_at = NOW()
  WHERE id = p_device_id;
END;
$$;
