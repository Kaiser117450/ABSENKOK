---
phase: 32-multi-device-dashboard
plan: "01"
subsystem: data-layer
tags: [model, sql, tdd, kiosk-devices]
dependency_graph:
  requires: [phase_31_kiosk_devices_20260320.sql]
  provides: [KioskDevice model, set_device_nickname RPC, archive_device RPC]
  affects: [plan 32-02 UI]
tech_stack:
  added: []
  patterns: [fromJson model, SECURITY DEFINER RPC, TDD]
key_files:
  created:
    - lib/models/kiosk_device.dart
    - test/phase32/kiosk_device_model_test.dart
    - sql/phase_32_device_mgmt_20260322.sql
  modified: []
decisions:
  - KioskDevice.isOnline uses <= 30 minutes (inclusive at 30), matching kiosk_health_card.dart threshold
  - displayName falls back to "Kiosk {uuid[0:8]}" — 8-char prefix is unique enough for display
metrics:
  duration_minutes: 15
  completed_date: "2026-03-22"
  tasks_completed: 2
  files_changed: 3
---

# Phase 32 Plan 01: KioskDevice Data Layer Summary

KioskDevice model with TDD-verified fromJson/isOnline/copyWith/displayName, plus two SECURITY DEFINER SQL RPCs for nickname and archive operations.

## Tasks Completed

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | KioskDevice model + unit tests (TDD) | 5aa7746 | lib/models/kiosk_device.dart, test/phase32/kiosk_device_model_test.dart |
| 2 | SQL migration for nickname + archive RPCs | c33fb7c | sql/phase_32_device_mgmt_20260322.sql |

## What Was Built

**KioskDevice model** (`lib/models/kiosk_device.dart`):
- `fromJson` parses all `kiosk_devices` columns (id, device_uuid, outlet_id, last_heartbeat_at, battery_level, is_charging, pending_sync_count, app_version, nickname, is_active)
- `isOnline` getter: true when `lastHeartbeatAt` is within 30 minutes of now
- `displayName` getter: returns nickname if set, else `"Kiosk ${deviceUuid.substring(0, 8)}"`
- `copyWith` for nickname, isActive, batteryLevel, isCharging, pendingSyncCount, lastHeartbeatAt

**Unit tests** (`test/phase32/kiosk_device_model_test.dart`): 8 tests, all passing:
- fromJson full + null field variants
- isOnline: true (5 min ago), false (null), false (31 min ago)
- copyWith nickname override
- displayName with/without nickname

**SQL migration** (`sql/phase_32_device_mgmt_20260322.sql`):
- `set_device_nickname(p_device_id UUID, p_nickname TEXT)` — SECURITY DEFINER
- `archive_device(p_device_id UUID)` — SECURITY DEFINER, sets `is_active = false`
- Must be applied to Supabase before deploying Plan 02

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- lib/models/kiosk_device.dart: FOUND
- test/phase32/kiosk_device_model_test.dart: FOUND
- sql/phase_32_device_mgmt_20260322.sql: FOUND
- Commit 5aa7746: FOUND
- Commit c33fb7c: FOUND
- flutter test exits 0: CONFIRMED (8/8 tests pass)
