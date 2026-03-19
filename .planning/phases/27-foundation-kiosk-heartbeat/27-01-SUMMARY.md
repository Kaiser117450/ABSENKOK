---
phase: 27-foundation-kiosk-heartbeat
plan: "01"
subsystem: heartbeat
tags: [heartbeat, outlet-model, database-migration, dependencies]
dependency_graph:
  requires: []
  provides: [heartbeat-db-columns, outlet-heartbeat-model, battery-plus-dep, package-info-plus-dep]
  affects: [lib/models/outlet.dart, pubspec.yaml]
tech_stack:
  added: [battery_plus ^6.2.3, package_info_plus ^8.1.0]
  patterns: [nullable additive migration, optional constructor params]
key_files:
  created:
    - sql/phase_27_heartbeat_columns_20260320.sql
  modified:
    - lib/models/outlet.dart
    - pubspec.yaml
    - pubspec.lock
key_decisions:
  - "battery_plus ^6.2.3 (not ^7.x) — v7 requires Kotlin 2.2.0 which breaks nfc_manager"
  - "All 5 heartbeat columns nullable with no DEFAULT — existing production rows unaffected"
metrics:
  duration_minutes: 8
  tasks_completed: 1
  tasks_total: 1
  files_changed: 4
  completed_date: "2026-03-20"
---

# Phase 27 Plan 01: Heartbeat Foundation Summary

**One-liner:** 5 nullable heartbeat columns via additive SQL migration, Outlet model expanded with fromJson/toJson, battery_plus + package_info_plus added to pubspec.

## What Was Built

### SQL Migration
`sql/phase_27_heartbeat_columns_20260320.sql` — 5 additive ALTER TABLE statements:
- `last_heartbeat_at TIMESTAMPTZ`
- `battery_level SMALLINT`
- `is_charging BOOLEAN`
- `pending_sync_count INTEGER`
- `app_version TEXT`

All nullable, all guarded by `IF NOT EXISTS`. Safe to re-run against production.

### Outlet Model
`lib/models/outlet.dart` expanded with 5 new optional fields:
- `final DateTime? lastHeartbeatAt`
- `final int? batteryLevel`
- `final bool? isCharging`
- `final int? pendingSyncCount`
- `final String? appVersion`

`fromJson` handles null-safe DateTime parsing. `toJson` includes all 5 fields. Constructor parameters are optional — no breaking changes to existing callers.

### pubspec.yaml
Added under dependencies:
```yaml
battery_plus: ^6.2.3
package_info_plus: ^8.1.0
```
`flutter pub get` resolved successfully (5 new packages: battery_plus, package_info_plus, upower, etc.).

## Commits

| Hash | Message |
|------|---------|
| 5d3a4c6 | feat(27-01): heartbeat foundation — SQL migration, Outlet model, dependencies |

## Verification

- `flutter pub get` — succeeded, 5 packages changed
- `flutter analyze --no-fatal-infos` — no errors in modified files (outlet.dart clean); pre-existing test errors in unrelated test files are out of scope

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- sql/phase_27_heartbeat_columns_20260320.sql: FOUND (contains 5 ALTER TABLE statements)
- lib/models/outlet.dart: FOUND (contains lastHeartbeatAt, batteryLevel, isCharging, pendingSyncCount, appVersion)
- pubspec.yaml: FOUND (contains battery_plus: ^6.2.3 and package_info_plus: ^8.1.0)
- Commit 5d3a4c6: FOUND
