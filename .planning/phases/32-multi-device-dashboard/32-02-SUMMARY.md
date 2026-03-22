---
phase: 32-multi-device-dashboard
plan: "02"
subsystem: ui-layer
tags: [widget, dashboard, realtime, kiosk-devices, heartbeat]
dependency_graph:
  requires: [lib/models/kiosk_device.dart, sql/phase_32_device_mgmt_20260322.sql]
  provides: [KioskDeviceCard widget, per-device dashboard UI, nickname dialog, archive dialog]
  affects: [admin dashboard Status Kiosk section]
tech_stack:
  added: []
  patterns: [PopupMenuButton, optimistic update, realtime subscription, SECURITY DEFINER RPC call]
key_files:
  created:
    - lib/widgets/kiosk_device_card.dart
  modified:
    - lib/screens/admin/admin_dashboard_screen.dart
    - lib/services/heartbeat_service.dart
decisions:
  - KioskDeviceCard uses 8x8 dot (not 10x10 like KioskHealthCard) per UI-SPEC
  - Nickname copyWith on optimistic update reverts to oldNickname on RPC error
  - Archive failure is silent (device reappears on next load) per UI-SPEC
  - _subscribeKioskDevicesRealtime() called inside _loadOutlets() after other subscriptions
metrics:
  duration_minutes: 20
  completed_date: "2026-03-22"
  tasks_completed: 2
  files_changed: 3
---

# Phase 32 Plan 02: Dashboard UI and HeartbeatService Bridge Removal Summary

Per-device KioskDeviceCard widget replacing the outlet-based KioskHealthCard in the admin dashboard Status Kiosk section, with nickname/archive dialogs, realtime subscription, and HeartbeatService bridge write removed.

## Tasks Completed

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | KioskDeviceCard widget + dashboard migration | 6866cba | lib/widgets/kiosk_device_card.dart, lib/screens/admin/admin_dashboard_screen.dart |
| 2 | Remove HeartbeatService bridge write | 1b1eda8 | lib/services/heartbeat_service.dart |

## What Was Built

**KioskDeviceCard widget** (`lib/widgets/kiosk_device_card.dart`):
- Status dot (8x8, green/red/gray with glow box shadow)
- Display name (nickname or "Kiosk {uuid[0:8]}"), status label (Online / Offline — N jam lalu / Belum Terhubung)
- Battery indicator: icon + percentage, color-coded danger < 20%
- Pending sync badge: warningLight container with sync_problem_outlined icon
- PopupMenuButton with "Opsi perangkat" tooltip — Beri Nama (edit_outlined) and Arsipkan (archive_outlined, danger color)

**Admin Dashboard migration** (`lib/screens/admin/admin_dashboard_screen.dart`):
- Added `List<KioskDevice> _kioskDevices` and `RealtimeChannel? _kioskDevicesChannel` state
- `_loadKioskDevices()` queries `kiosk_devices` table filtered by `is_active = true`
- `_subscribeKioskDevicesRealtime()` subscribes to `kiosk_devices_changes` channel (PostgresChangeEvent.all)
- `_showNicknameDialog()` with optimistic update + revert on RPC error (calls `set_device_nickname` RPC)
- `_showArchiveDialog()` with optimistic remove (calls `archive_device` RPC)
- `_buildKioskHealthSection()` replaced: reads from `_kioskDevices`, shows one `KioskDeviceCard` per device, empty state with `Icons.devices_outlined` and "Tidak ada kiosk aktif" message
- `_kioskDevicesChannel?.unsubscribe()` added to `dispose()`

**HeartbeatService bridge removed** (`lib/services/heartbeat_service.dart`):
- Deleted entire bridge write block (27 lines) — no more `from('outlets').update(...)`
- Updated class doc comment: "Admin dashboard now reads directly from kiosk_devices (Phase 32)"
- `_sendWithRetry()` now only does the RPC primary write to `kiosk_devices`

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- lib/widgets/kiosk_device_card.dart: FOUND
- lib/screens/admin/admin_dashboard_screen.dart: FOUND (contains KioskDeviceCard, _loadKioskDevices, kiosk_devices_changes, _showNicknameDialog, _showArchiveDialog, set_device_nickname, archive_device, Tidak ada kiosk aktif, from('kiosk_devices'), .eq('is_active', true))
- lib/services/heartbeat_service.dart: FOUND (no from('outlets'), no 'bridge', contains 'Admin dashboard now reads directly from kiosk_devices')
- Commit 6866cba: FOUND
- Commit 1b1eda8: FOUND
- flutter analyze: No errors on all 3 files
- flutter test test/phase32/: 8/8 PASSED
