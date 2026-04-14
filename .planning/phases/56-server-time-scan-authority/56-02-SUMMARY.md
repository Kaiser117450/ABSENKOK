---
phase: 56-server-time-scan-authority
plan: 02
subsystem: offline-queue
tags: [flutter, sqlite, sync, kiosk, queue]
requires:
  - phase: 56-server-time-scan-authority
    provides: typed authority DTOs and RPC gateway for live/queued scan replay
provides:
  - monotonic queue ordering for pending attendance logs
  - explicit pending-log capture metadata for Phase 56 replay
  - sequential authority-based sync instead of direct inserts
affects: [kiosk_scan_screen, kiosk_idle_screen, sakit_izin_dialog]
tech-stack:
  added: []
  patterns: [monotonic-queue-order, sequential-authority-replay, shared-offline-defaults]
key-files:
  created:
    - test/services/sync_service_order_test.dart
  modified:
    - lib/core/constants.dart
    - lib/models/pending_log.dart
    - lib/services/sqlite_service.dart
    - lib/services/sync_service.dart
    - lib/screens/admin/sakit_izin_dialog.dart
key-decisions:
  - Queue-order generation stays inside SQLite via `MAX(queue_order) + 1` so replay order is device-local and monotonic even when network state changes.
  - Sync now replays pending rows through `KioskScanAuthorityService.recordScan(...)` one row at a time instead of direct table inserts or `Future.wait(...)`.
  - Shared offline producers default to `captureMode = queued` and `initialScanIntent = none` unless the caller explicitly sets richer metadata.
patterns-established:
  - Pending-log writes must carry the same authority metadata that the replay RPC expects.
  - Queue replay success is defined by the authority RPC result or duplicate local-id acknowledgement, not by transport reachability alone.
requirements-completed: [SCAN-01]
duration: 9 min
completed: 2026-03-27
---

# Phase 56 Plan 02 Summary

**The local attendance queue now preserves a deterministic replay order and syncs through the Phase 56 authority RPC instead of bypassing the server-owned scan contract.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-03-27T14:04:30+08:00
- **Completed:** 2026-03-27T14:13:21.5354346+08:00
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Bumped the SQLite queue schema to v6 with `device_captured_at`, `capture_mode`, `queue_order`, and `initial_scan_intent`, plus migration logic that keeps unsynced rows and backfills deterministic order.
- Extended `PendingLog` and `SqliteService.insertPendingLog(...)` so queued producers can persist Phase 56 replay metadata while keeping safe defaults for admin fallback paths.
- Replaced direct parallel inserts in `SyncService` with sequential `KioskScanAuthorityService.recordScan(...)` replay and added focused regression coverage for order, failure handling, duplicate local-id acknowledgement, and `break_first` intent retention.

## Task Commits

Atomic task commits were intentionally skipped in this session.

- The worktree still contains unrelated tracked edits, so plan-scoped commits would have mixed existing user changes with Phase 56 queue work.
- Verification remained intact through targeted analyze/test commands instead of forcing unsafe git history.

## Files Created/Modified

- `lib/core/constants.dart` - SQLite schema version now advances to Phase 56 queue metadata.
- `lib/models/pending_log.dart` - Pending log model now round-trips device capture time, capture mode, queue order, and initial scan intent.
- `lib/services/sqlite_service.dart` - Queue schema, migration, write helper, and read ordering now enforce monotonic replay.
- `lib/services/sync_service.dart` - Pending sync now replays sequentially through `KioskScanAuthorityService.recordScan(...)`.
- `lib/screens/admin/sakit_izin_dialog.dart` - Shared offline fallback now supplies explicit queued defaults when it enqueues admin-created records.
- `test/services/sync_service_order_test.dart` - Regression coverage for ordered replay, duplicate acknowledgement, and `break_first` intent propagation.

## Decisions Made

- Kept `insertPendingLog(...)` backward-compatible by adding new optional metadata parameters with safe defaults instead of forcing every caller to change at once.
- Chose a lazy-initialized Supabase client inside `KioskScanAuthorityService` so replay tests can subclass the service without booting the real Supabase singleton.
- Preserved sequential processing even after a row fails; later rows still replay only after the failed row attempt completes, so ordering remains deterministic without turning one bad row into a global stop-the-world failure.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Authority-service tests needed a lazy client to avoid booting the real Supabase singleton**
- **Found during:** Task 2 replay-test execution
- **Issue:** The sync replay test double inherited the authority service and hit `Supabase.instance` before the test could inject behavior.
- **Fix:** Made `KioskScanAuthorityService` resolve its client lazily at method-call time instead of constructor time.
- **Files modified:** `lib/services/kiosk_scan_authority_service.dart`
- **Verification:** `C:\flutter\bin\flutter.bat test test/services/sync_service_order_test.dart`
- **Committed in:** not committed

**2. [Rule 3 - Blocking] Verification again required the short-drive workaround**
- **Found during:** Task 1/2 verification
- **Issue:** Direct formatter/test commands from the workspace path remain unreliable because of the known path-space tooling issue.
- **Fix:** Re-ran format, analyze, and the sync replay test through the short-drive (`subst`) workspace.
- **Files modified:** none
- **Verification:** `C:\flutter\bin\flutter.bat analyze ...`; `C:\flutter\bin\flutter.bat test test/services/sync_service_order_test.dart`
- **Committed in:** not committed

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Delivered scope is intact. The queue contract and replay path are verified; only atomic git history remains intentionally skipped because the worktree is not isolated.

## Issues Encountered

- `flutter analyze` reported three pre-existing `withOpacity` deprecation infos in `lib/screens/admin/sakit_izin_dialog.dart`. They are informational only and not introduced by this plan.

## User Setup Required

None - no extra dashboard or environment setup was introduced beyond the already-pending Phase 56 SQL approval gate.

## Next Phase Readiness

- `56-03-PLAN.md` can now trust local pending rows to carry `captureMode`, `queueOrder`, and `initialScanIntent` when it merges authoritative and queued state in the kiosk UI.
- Connectivity-driven background sync can now reconcile queued rows through the same authority contract as live scans.
- The kiosk UI wave can safely distinguish live-confirmed vs queued-pending flows without inventing another offline replay path.

---
*Phase: 56-server-time-scan-authority*
*Completed: 2026-03-27*
