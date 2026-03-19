-- Phase 27: Kiosk Heartbeat Foundation
-- Additive migration: add heartbeat tracking columns to outlets table
-- All columns nullable, no DEFAULT — existing rows unaffected
-- Safe to re-run (IF NOT EXISTS guards)

ALTER TABLE outlets ADD COLUMN IF NOT EXISTS last_heartbeat_at  TIMESTAMPTZ;
ALTER TABLE outlets ADD COLUMN IF NOT EXISTS battery_level      SMALLINT;
ALTER TABLE outlets ADD COLUMN IF NOT EXISTS is_charging        BOOLEAN;
ALTER TABLE outlets ADD COLUMN IF NOT EXISTS pending_sync_count INTEGER;
ALTER TABLE outlets ADD COLUMN IF NOT EXISTS app_version        TEXT;
