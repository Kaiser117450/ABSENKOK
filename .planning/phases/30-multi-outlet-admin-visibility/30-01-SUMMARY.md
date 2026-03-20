---
phase: 30
plan: 01
subsystem: admin-dashboard
tags: [migration, kiosk-health, admin-ui, heartbeat]
dependency_graph:
  requires: [phase-27-heartbeat-foundation]
  provides: [kiosk-health-section, heartbeat-columns-production]
  affects: [admin_dashboard_screen, outlets-table]
tech_stack:
  added: []
  patterns: [status-dot-indicator, battery-level-widget, sync-badge]
key_files:
  created:
    - lib/widgets/kiosk_health_card.dart
  modified:
    - lib/screens/admin/admin_dashboard_screen.dart
decisions:
  - "Use withValues(alpha:) instead of withOpacity() for new code to match Flutter 3.x deprecation guidance"
  - "All outlets shown in health section (not just outlets with heartbeat data) so admins can spot never-connected kiosks"
metrics:
  duration_minutes: 18
  completed_date: "2026-03-20"
  tasks_completed: 3
  files_changed: 3
---

# Phase 30 Plan 01: Apply Heartbeat Migration + Kiosk Health Dashboard Section Summary

**One-liner:** Heartbeat columns applied to production Supabase outlets table + per-outlet kiosk health section (online/offline/battery/sync) added to admin dashboard.

## What Was Built

### Task 1: Heartbeat columns migration
Applied `phase_27_heartbeat_columns` migration to production Supabase (`tmapxdftdhxovthgbhww`). Added 5 nullable columns to the `outlets` table: `last_heartbeat_at`, `battery_level`, `is_charging`, `pending_sync_count`, `app_version`. All with no DEFAULT — existing rows unaffected. Verified via `information_schema.columns` query returning all 5 rows.

### Task 2: KioskHealthCard widget
Created `lib/widgets/kiosk_health_card.dart` with:
- Status dot (green/red/gray) based on heartbeat recency
- "Online" for heartbeat within 30 min
- "Offline — {age}" for heartbeat >30 min ago
- "Belum Terhubung" for never-connected outlets (lastHeartbeatAt == null)
- `_BatteryIndicator` sub-widget: red alert icon when <20%, green full icon when >=20%, charging icon when charging
- Pending sync badge: amber pill with count when pendingSyncCount > 0

### Task 3: Admin dashboard integration
Modified `lib/screens/admin/admin_dashboard_screen.dart`:
- Added import for `kiosk_health_card.dart`
- Added `_buildKioskHealthSection()` method with section header, issue count badge, and one `KioskHealthCard` per outlet
- Inserted `SliverToBoxAdapter(child: _buildKioskHealthSection())` between stat grid and dashboard button

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed withOpacity deprecation in new widget**
- **Found during:** Task 3 flutter analyze
- **Issue:** Plan code used `.withOpacity()` which is deprecated in Flutter 3.x — generates `info` warnings
- **Fix:** Replaced both instances in `kiosk_health_card.dart` with `.withValues(alpha:)` to match existing codebase pattern
- **Files modified:** lib/widgets/kiosk_health_card.dart
- **Commit:** 2fc7648

## Requirements Addressed

- HLTH-03: Offline warning for outlets with >30 min no heartbeat
- HLTH-04: Low battery warning for battery <20%
- SYNC-03: Pending sync count displayed per outlet

## Self-Check: PASSED

- `lib/widgets/kiosk_health_card.dart` — FOUND
- `lib/screens/admin/admin_dashboard_screen.dart` contains `_buildKioskHealthSection` — FOUND
- Commits: d29e2b1, 558e0a7, 2fc7648 — all present
- `flutter analyze lib/widgets/kiosk_health_card.dart` — No issues found
