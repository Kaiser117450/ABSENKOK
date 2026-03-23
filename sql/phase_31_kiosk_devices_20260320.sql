-- Phase 31: Device Identity Foundation
-- Creates kiosk_devices table + upsert_kiosk_heartbeat RPC
-- Additive migration: does NOT modify existing outlets table
-- Safe to re-run (IF NOT EXISTS guards)

-- ── 1. Create kiosk_devices table ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS kiosk_devices (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_uuid        TEXT NOT NULL UNIQUE,
  outlet_id          UUID REFERENCES outlets(id),
  last_heartbeat_at  TIMESTAMPTZ,
  battery_level      SMALLINT,
  is_charging        BOOLEAN,
  pending_sync_count INTEGER,
  app_version        TEXT,
  nickname           TEXT,
  is_active          BOOLEAN DEFAULT TRUE,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);

-- Index for outlet-based lookups (admin dashboard Phase 32)
CREATE INDEX IF NOT EXISTS idx_kiosk_devices_outlet ON kiosk_devices(outlet_id);

-- ── 2. Enable RLS ──────────────────────────────────────────────────────────

ALTER TABLE kiosk_devices ENABLE ROW LEVEL SECURITY;

-- Admin can read all devices
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polname = 'admin_read_kiosk_devices') THEN
    CREATE POLICY admin_read_kiosk_devices ON kiosk_devices
      FOR SELECT USING (get_app_role() = 'admin');
  END IF;
END $$;

-- Authenticated users can read all devices (matches outlets pattern)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polname = 'auth_read_kiosk_devices') THEN
    CREATE POLICY auth_read_kiosk_devices ON kiosk_devices
      FOR SELECT USING (true);
  END IF;
END $$;

-- ── 3. Upsert RPC (SECURITY DEFINER) ──────────────────────────────────────
-- Kiosk uses anon key, so direct INSERT/UPDATE would be blocked by RLS.
-- SECURITY DEFINER runs as the function owner (postgres) bypassing RLS.
-- This matches the existing verify_kiosk_password pattern.

CREATE OR REPLACE FUNCTION upsert_kiosk_heartbeat(
  p_device_uuid      TEXT,
  p_outlet_id        UUID,
  p_battery_level    SMALLINT  DEFAULT NULL,
  p_is_charging      BOOLEAN   DEFAULT NULL,
  p_pending_sync_count INTEGER DEFAULT NULL,
  p_app_version      TEXT      DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.role() <> 'authenticated' THEN
    RAISE EXCEPTION 'upsert_kiosk_heartbeat requires authenticated role';
  END IF;

  INSERT INTO kiosk_devices (
    device_uuid, outlet_id, last_heartbeat_at,
    battery_level, is_charging, pending_sync_count, app_version,
    updated_at
  ) VALUES (
    p_device_uuid, p_outlet_id, NOW(),
    p_battery_level, p_is_charging, p_pending_sync_count, p_app_version,
    NOW()
  )
  ON CONFLICT (device_uuid) DO UPDATE SET
    outlet_id          = EXCLUDED.outlet_id,
    last_heartbeat_at  = NOW(),
    battery_level      = EXCLUDED.battery_level,
    is_charging        = EXCLUDED.is_charging,
    pending_sync_count = EXCLUDED.pending_sync_count,
    app_version        = EXCLUDED.app_version,
    updated_at         = NOW();
END;
$$;


-- Restrict RPC execution surface (never PUBLIC for SECURITY DEFINER)
REVOKE ALL ON FUNCTION upsert_kiosk_heartbeat(TEXT, UUID, SMALLINT, BOOLEAN, INTEGER, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION upsert_kiosk_heartbeat(TEXT, UUID, SMALLINT, BOOLEAN, INTEGER, TEXT) TO authenticated;
