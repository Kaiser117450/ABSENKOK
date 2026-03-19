---
phase: 27-foundation-kiosk-heartbeat
plan: "02"
subsystem: heartbeat
tags: [heartbeat, kiosk, battery, connectivity, supabase]
dependency_graph:
  requires: ["27-01"]
  provides: ["HeartbeatService", "kiosk heartbeat lifecycle"]
  affects: ["lib/services/kiosk_background_service.dart", "outlets table"]
tech_stack:
  added: []
  patterns: ["static-only service class", "Timer.periodic", "connectivity debounce", "retry loop"]
key_files:
  created:
    - lib/services/heartbeat_service.dart
  modified:
    - lib/services/kiosk_background_service.dart
decisions:
  - "HeartbeatService.stop() called as first action in KioskBackgroundService.stop() to ensure heartbeat stops before other teardown"
  - "connectivity debounce compares DateTime.now().difference(_lastSentAt).inSeconds < 30 (not a separate timer)"
metrics:
  duration_minutes: 8
  completed_date: "2026-03-20"
  tasks_completed: 2
  files_changed: 2
---

# Phase 27 Plan 02: HeartbeatService Summary

HeartbeatService with 15-minute rolling timer, battery/version/sync-count payload, retry logic, and connectivity-aware recovery wired into KioskBackgroundService.

## What Was Built

### HeartbeatService (`lib/services/heartbeat_service.dart`)
- Static-only class with `start(KioskSession)` / `stop()` API
- Fires immediately on `start()`, then every 15 minutes via `Timer.periodic`
- Payload: `last_heartbeat_at`, `battery_level`, `is_charging`, `app_version`, `pending_sync_count`
- Battery read failure returns `null` fields — heartbeat still sent
- App version cached after first read (`PackageInfo.fromPlatform()`)
- Supabase write retries 3 total attempts with 2s / 4s delays between
- Connectivity listener with 30-second debounce triggers retry on reconnect
- `supabaseReady` global guard prevents calls before Supabase is initialized

### KioskBackgroundService (`lib/services/kiosk_background_service.dart`)
- Added `import 'heartbeat_service.dart';`
- `start()`: calls `await HeartbeatService.start(session)` after `MissingClockoutService.startPeriodicCheck`
- `stop()`: calls `HeartbeatService.stop()` as first action

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] `lib/services/heartbeat_service.dart` exists
- [x] Contains `class HeartbeatService`
- [x] Contains `static Future<void> start(KioskSession session)`
- [x] Contains `static void stop()`
- [x] Contains `Timer.periodic(const Duration(minutes: 15)`
- [x] Contains `SqliteService.countPendingLogs()`
- [x] Contains `Battery().batteryLevel`
- [x] Contains `PackageInfo.fromPlatform()`
- [x] Contains `Connectivity().onConnectivityChanged`
- [x] Contains `.from('outlets').update(`
- [x] Contains `supabaseReady` guard
- [x] Contains retry loop with 3 attempts
- [x] Contains 30-second debounce check for connectivity retry
- [x] `kiosk_background_service.dart` contains `import 'heartbeat_service.dart';`
- [x] `kiosk_background_service.dart` contains `await HeartbeatService.start(session);`
- [x] `kiosk_background_service.dart` contains `HeartbeatService.stop();`
- [x] `flutter analyze --no-fatal-infos` shows no errors in heartbeat files

## Self-Check: PASSED
