---
phase: 31
plan: 01
title: "Device Identity Service & UUID Persistence"
subsystem: device-identity
tags: [uuid, shared-preferences, identity, persistence]
completed: "2026-03-20T09:08:33Z"
duration_minutes: 15

dependency_graph:
  requires: []
  provides: [DeviceIdentityService, installationDeviceUuidKey]
  affects: [app_provider, setup_screen]

tech_stack:
  added: []
  patterns: [static-service, shared-preferences-persistence, uuid-v4]

key_files:
  created:
    - lib/services/device_identity_service.dart
    - test/device_identity_service_test.dart
  modified:
    - lib/core/constants.dart
    - lib/providers/app_provider.dart
    - lib/screens/setup/setup_screen.dart

decisions:
  - uuid package was already present at ^4.5.1 — no new dependency needed
  - DeviceIdentityService is a pure static class (no instance state needed)

metrics:
  tasks_completed: 6
  files_created: 2
  files_modified: 3
  tests_added: 8
  tests_passing: 8
---

# Phase 31 Plan 01: Device Identity Service & UUID Persistence Summary

**One-liner:** Persistent installation-level UUIDv4 that survives kiosk logout/re-setup, replacing the per-setup random 12-char device ID.

## What Was Built

A `DeviceIdentityService` static class that generates a UUIDv4 on first boot and persists it in SharedPreferences under `installation_device_uuid_v1`. The service auto-upgrades old 12-char device IDs to UUIDv4 on the first boot after upgrade. The UUID is created early in the app boot sequence via `AppNotifier.loadSession()` and reused in setup so the same identity persists across kiosk logout → re-setup cycles.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 31-01-01 | Confirm uuid ^4.5.1 dependency (already present) | — |
| 31-01-02 | Add installationDeviceUuidKey constant | 6cda407 |
| 31-01-03 | Create DeviceIdentityService | 6e5d826 |
| 31-01-04 | Wire into AppNotifier.loadSession() | ca9bd5f |
| 31-01-05 | Replace _generateDeviceId in setup_screen.dart | 27b7114 |
| 31-01-06 | Unit tests for isValidUuidV4 (8 cases) | ae000a2 |

## Verification Results

- `flutter pub get` — success
- `flutter test test/device_identity_service_test.dart` — 8/8 passed
- `installationDeviceUuidKey` count in constants.dart — 1
- `_generateDeviceId` count in setup_screen.dart — 0 (removed)
- `DeviceIdentityService` count in setup_screen.dart — 1
- `DeviceIdentityService` count in app_provider.dart — 1

## Deviations from Plan

None — plan executed exactly as written. The `uuid` package was already present at ^4.5.1 (Task 31-01-01 was a no-op confirm step).

## Self-Check: PASSED

- lib/services/device_identity_service.dart — EXISTS
- test/device_identity_service_test.dart — EXISTS
- lib/core/constants.dart — contains installationDeviceUuidKey
- setup_screen.dart — no _generateDeviceId, uses DeviceIdentityService
- app_provider.dart — calls DeviceIdentityService.getOrCreateDeviceUuid()
- Commits 6cda407, 6e5d826, ca9bd5f, 27b7114, ae000a2 — all present
