---
phase: 31
plan: 02
title: "Database Migration & HeartbeatService Refactor"
subsystem: device-identity
tags: [heartbeat, kiosk-devices, supabase, dual-write]
dependency_graph:
  requires: [31-01]
  provides: [kiosk_devices-table, upsert_kiosk_heartbeat-rpc, heartbeat-dual-write]
  affects: [lib/services/heartbeat_service.dart, admin-dashboard-compat]
tech_stack:
  added: []
  patterns: [dual-write-bridge, security-definer-rpc, exponential-backoff-retry]
key_files:
  created:
    - sql/phase_31_kiosk_devices_20260320.sql
  modified:
    - lib/services/heartbeat_service.dart
key_decisions:
  - "Dual-write pattern: RPC primary + outlets bridge for backward compat"
  - "SECURITY DEFINER RPC bypasses RLS for anon-key kiosk writes"
  - "_deviceUuid cached at start() and cleared at stop() — not re-fetched each heartbeat"
metrics:
  duration: "~10 min"
  completed_date: "2026-03-20"
  tasks_completed: 3
  files_changed: 2
---

# Phase 31 Plan 02: Database Migration & HeartbeatService Refactor Summary

## One-Liner

kiosk_devices table + SECURITY DEFINER upsert RPC + HeartbeatService dual-write to both kiosk_devices and outlets tables for backward-compatible transition.

## What Was Built

### SQL Migration (sql/phase_31_kiosk_devices_20260320.sql)

- `kiosk_devices` table with 12 columns: id, device_uuid (UNIQUE TEXT), outlet_id (FK to outlets), last_heartbeat_at, battery_level, is_charging, pending_sync_count, app_version, nickname, is_active, created_at, updated_at
- `idx_kiosk_devices_outlet` index on outlet_id for dashboard queries
- RLS enabled with two SELECT policies: `admin_read_kiosk_devices` and `auth_read_kiosk_devices`
- `upsert_kiosk_heartbeat` SECURITY DEFINER function: INSERT ON CONFLICT (device_uuid) DO UPDATE — allows anon-key kiosk to write device records without RLS bypass exposure

### HeartbeatService Refactor (lib/services/heartbeat_service.dart)

- Added `import 'device_identity_service.dart'`
- Added `static String? _deviceUuid` field
- `start()` now calls `DeviceIdentityService.getOrCreateDeviceUuid()` before first heartbeat
- `stop()` clears `_deviceUuid = null`
- `_sendWithRetry()` now executes two independent write paths:
  1. **Primary:** `Supabase.instance.client.rpc('upsert_kiosk_heartbeat', params: {...})` with p_device_uuid, p_outlet_id, p_battery_level, p_is_charging, p_pending_sync_count, p_app_version
  2. **Bridge:** `Supabase.instance.client.from('outlets').update(payload).eq('id', outletId)` (original behavior preserved)
- Both paths have independent 3-attempt retry with exponential backoff (2s, 4s)
- Sentry captures final failures with distinct operation names: `heartbeat_rpc` and `heartbeat_bridge`

## Commits

| Task | Description | Commit |
|------|-------------|--------|
| 31-02-01 | SQL migration file created | 9519fb9 |
| 31-02-03 | HeartbeatService dual-write refactor | c641d3f |

## Deviations from Plan

### Migration Application (Task 31-02-02)

Task 31-02-02 requires applying the migration to Supabase via MCP `apply_migration` tool. The direct supabase CLI connection timed out (IPv6 connectivity issue to db.tmapxdftdhxovthgbhww.supabase.co:5432). The migration file is committed and ready.

**Action required:** Apply `sql/phase_31_kiosk_devices_20260320.sql` to Supabase via the Supabase Dashboard SQL Editor or MCP tool before deploying the updated APK.

## Verification Results

- `flutter build apk --debug` — PASSED (117.4s, no errors)
- `grep -c 'upsert_kiosk_heartbeat' lib/services/heartbeat_service.dart` — 2 matches (function name in RPC call + comment)
- `grep -c 'DeviceIdentityService' lib/services/heartbeat_service.dart` — 2 matches (import + usage)
- No changes to admin_dashboard_screen.dart or kiosk_health_card.dart — backward compat preserved

## Self-Check: PASSED

- sql/phase_31_kiosk_devices_20260320.sql — FOUND
- lib/services/heartbeat_service.dart — FOUND (modified)
- Commit 9519fb9 — SQL migration
- Commit c641d3f — HeartbeatService refactor
