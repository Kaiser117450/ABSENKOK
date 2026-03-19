---
phase: 29
plan: 01
subsystem: kiosk-ui
tags: [diagnostics, sync, kiosk, offline-queue]
dependency_graph:
  requires: [lib/services/sync_service.dart, lib/services/sqlite_service.dart, lib/providers/app_provider.dart]
  provides: [lib/screens/kiosk/kiosk_diagnostics_screen.dart]
  affects: [lib/screens/kiosk/kiosk_idle_screen.dart, lib/app.dart]
tech_stack:
  added: []
  patterns: [ConsumerStatefulWidget, Timer.periodic, SlideTransition, GoRouter sub-route]
key_files:
  created:
    - lib/screens/kiosk/kiosk_diagnostics_screen.dart
  modified:
    - lib/screens/kiosk/kiosk_idle_screen.dart
    - lib/app.dart
decisions:
  - "SlideTransition from top for sync strip (not AnimatedSwitcher) — matches UI spec exactly"
  - "Long-press only on brand logo column (not full header) — intentionally hidden from employees"
metrics:
  duration_seconds: 316
  completed_date: "2026-03-20"
  tasks_completed: 3
  files_modified: 3
---

# Phase 29 Plan 01: Kiosk Diagnostics and Sync Indicator Summary

**One-liner:** Sync indicator amber strip on kiosk idle screen + hidden long-press diagnostics screen with battery/connectivity display and Force Sync button backed by SyncService.

## What Was Built

### KioskDiagnosticsScreen (`lib/screens/kiosk/kiosk_diagnostics_screen.dart`)
New `ConsumerStatefulWidget` accessible at `/kiosk/diagnostics` via hidden long-press gesture.

- **PERANGKAT section:** outlet name, app version (from PackageInfo), battery level with color-coded dot (green/amber/red by threshold), real-time connectivity status (Online/Offline), heartbeat status
- **SINKRONISASI section:** pending count and failed count from SQLite, Force Sync button
- **Force Sync flow:** connectivity guard → zero-pending guard → `SyncService.syncPendingLogs()` → toast feedback (success/partial/failure/no-pending)
- **30s periodic refresh** via `Timer.periodic` for pending/failed counts
- **Real-time connectivity** via `Connectivity().onConnectivityChanged` stream
- All toasts: dark `#111827` background, white text, 50px borderRadius, `Alignment.topCenter`

### Kiosk Idle Screen modifications (`lib/screens/kiosk/kiosk_idle_screen.dart`)
- **Sync indicator strip:** Amber `#FEF3C7` strip (36px, `cloud_upload_outlined` icon) appears below header divider when `pendingCount > 0`. Uses `SlideTransition` (250ms, `Curves.easeOut`) from Offset(0,-1) to Offset.zero. Auto-hides when count reaches 0.
- **30s pending refresh timer:** `_pendingRefreshTimer` calls `_refreshPendingCount()` which updates `AppState.pendingCount` via notifier.
- **Long-press logo:** `GestureDetector.onLongPress` on brand Column triggers `HapticFeedback.mediumImpact()` then `context.push('/kiosk/diagnostics')`.

### GoRouter registration (`lib/app.dart`)
Added `'diagnostics'` sub-route under `/kiosk` route, alongside existing `'scan'`. Import added for `kiosk_diagnostics_screen.dart`. Existing redirect guard (`!loc.startsWith('/kiosk') => '/kiosk'`) already covers `/kiosk/diagnostics`.

## Requirements Covered

| Req | Description | Status |
|-----|-------------|--------|
| SYNC-04 | Sync indicator strip on kiosk idle screen | DONE |
| RECV-01 | Diagnostics screen via long-press logo | DONE |
| RECV-02 | Force Sync button calls SyncService.syncPendingLogs() | DONE |
| RECV-03 | Toast feedback for all sync result cases | DONE |

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

**Files created/modified:**
- [x] `lib/screens/kiosk/kiosk_diagnostics_screen.dart` — FOUND (504 lines)
- [x] `lib/screens/kiosk/kiosk_idle_screen.dart` — modified
- [x] `lib/app.dart` — modified

**Commits:**
- [x] c158722 — feat(29-01): create KioskDiagnosticsScreen
- [x] 21a24d3 — feat(29-01): add sync indicator strip and long-press entry
- [x] 5e4b905 — feat(29-01): register /kiosk/diagnostics route

**flutter analyze:** No errors in modified files (only pre-existing deprecation infos).

## Self-Check: PASSED
