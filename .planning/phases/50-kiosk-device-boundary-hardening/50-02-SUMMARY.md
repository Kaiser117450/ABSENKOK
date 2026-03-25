---
phase: 50-kiosk-device-boundary-hardening
plan: 02
subsystem: ui
tags: [flutter, dashboard, testing, kiosk, uuid, safety]
requires:
  - phase: 32-multi-device-dashboard
    provides: kiosk device model, dashboard surface, and admin device card rendering
provides:
  - safe kiosk-device UUID and timestamp parsing that no longer crashes on malformed data
  - row-by-row dashboard kiosk device loading with malformed-row isolation
  - focused regression tests for malformed UUID fallback behavior
affects: [phase-51, admin-dashboard, kiosk-device-card]
tech-stack:
  added: []
  patterns:
    - trim nickname first, then fall back to a bounds-safe kiosk label when UUID data is malformed
    - skip malformed Supabase rows in admin lists instead of letting one row break the whole section
key-files:
  created:
    - test/phase50/kiosk_device_model_test.dart
    - .planning/phases/50-kiosk-device-boundary-hardening/50-02-SUMMARY.md
  modified:
    - lib/models/kiosk_device.dart
    - lib/screens/admin/admin_dashboard_screen.dart
key-decisions:
  - "Short, empty, or null kiosk UUID values degrade to the plain `Kiosk` label instead of attempting a partial substring."
  - "Malformed heartbeat timestamps degrade to `null` so `isOnline` remains safe without special-case callers."
  - "The dashboard loader now drops malformed kiosk rows with `debugPrint` rather than failing the entire section."
patterns-established:
  - "TDD safety flow: add regression tests for malformed Supabase payloads before hardening the model fallback behavior."
  - "Row isolation in admin loaders: parse each Supabase row independently and keep the section alive when one row is bad."
requirements-completed: [SECSAFE-01]
duration: 8 min
completed: 2026-03-25
---

# Phase 50 Plan 02: Kiosk Device Safety Summary

**Kiosk device parsing is now crash-safe for malformed UUID and heartbeat data, and the admin dashboard isolates bad rows instead of failing the whole kiosk section**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-25T11:25:09+08:00
- **Completed:** 2026-03-25T11:33:44+08:00
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added focused regression coverage for null, empty, and short `device_uuid` values plus malformed `last_heartbeat_at` payloads.
- Hardened `KioskDevice.fromJson` and `displayName` so malformed rows degrade safely instead of throwing on `DateTime.parse` or `substring`.
- Reworked `_loadKioskDevices()` to parse one row at a time, log malformed rows, and keep the dashboard section rendering with the valid devices that remain.
- Cleared analyzer debt in the touched dashboard file so the plan-specific verification command now passes cleanly.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add regression coverage and safe parsing for malformed kiosk UUID data** - `32d1c0d` (test), `822cd7d` (fix)
2. **Task 2: Harden dashboard kiosk-device loading so one bad row cannot break the whole section** - `4f2d6b7` (fix)

_Note: Task 1 followed the TDD RED -> GREEN flow, so it spans multiple commits._

## Files Created/Modified

- `test/phase50/kiosk_device_model_test.dart` - regression coverage for malformed UUID, nickname trimming, and malformed heartbeat timestamps.
- `lib/models/kiosk_device.dart` - defensive parsing helpers and bounds-safe display fallback logic.
- `lib/screens/admin/admin_dashboard_screen.dart` - row-by-row kiosk device parsing plus malformed-row logging and analyzer cleanup.

## Decisions Made

- Preserve recognizable labels for valid UUIDs by keeping the `Kiosk {uuidPrefix}` pattern when at least eight characters are available.
- Keep nickname as the first-choice display label, but trim whitespace before deciding whether it is usable.
- Favor row isolation in the dashboard over hard failure because malformed Supabase data should not block healthy devices from rendering.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Existing analyzer warnings in `admin_dashboard_screen.dart` blocked the plan verification command**
- **Found during:** Task 2 verification
- **Issue:** The targeted `flutter analyze` command reported pre-existing unused helpers, missing braces, and deprecated style patterns in the same dashboard file that Phase 50 had to touch.
- **Fix:** Removed dead private helpers and unused state, added the missing braces, and left the kiosk dashboard logic behaviorally unchanged outside the defensive row parsing path.
- **Files modified:** `lib/screens/admin/admin_dashboard_screen.dart`
- **Verification:** `flutter analyze lib/models/kiosk_device.dart lib/screens/admin/admin_dashboard_screen.dart lib/screens/setup/setup_screen.dart`
- **Committed in:** `4f2d6b7` (fix)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** The cleanup was required only to make the planned verification pass. The kiosk-device UI contract stayed the same.

## Issues Encountered

- The parallel executor wrote directly into the main worktree and never produced the expected structured completion payload, so summary and doc closeout were finished manually after the code commits were verified.

## User Setup Required

None - no external service configuration required for the client-side kiosk safety hardening plan.

## Next Phase Readiness

- Phase 51 can rely on the kiosk dashboard surviving malformed device payloads while admin session hardening work proceeds.
- The remaining Phase 50 rollout dependency is only the manual Supabase SQL application documented in `50-USER-SETUP.md`.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/50-kiosk-device-boundary-hardening/50-02-SUMMARY.md`.
- `flutter test test/phase50/kiosk_device_model_test.dart` passes.
- `flutter analyze lib/models/kiosk_device.dart lib/screens/admin/admin_dashboard_screen.dart lib/screens/setup/setup_screen.dart` reports `No issues found!`.
- `git log --oneline --all --grep="50-02"` returns the task commits.

---
*Phase: 50-kiosk-device-boundary-hardening*
*Completed: 2026-03-25*
