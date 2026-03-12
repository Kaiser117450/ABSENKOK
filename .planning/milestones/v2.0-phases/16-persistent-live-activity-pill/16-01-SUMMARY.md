---
phase: 16-persistent-live-activity-pill
plan: 01
subsystem: services
tags: [overlay, supabase, attendance, break-detection, fun-facts, dart]

# Dependency graph
requires:
  - phase: v1.1
    provides: "Overlay infrastructure (overlay_task.dart, KioskBackgroundService, OverlayPillState)"
provides:
  - "OverlayPillState.displayLabel field for arbitrary overlay text"
  - "LiveContentProvider service with break detection and fun facts rotation"
  - "Injectable callback pattern for pure Dart service testability"
affects: [16-02-integration, kiosk-background-service, overlay-task]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Injectable callbacks (FetchLogsCallback/FetchActiveCountCallback) for Supabase testability"
    - "Chronological log iteration for break state machine"
    - "Interleaved content pool (stats + motivational messages)"

key-files:
  created:
    - lib/services/live_content_provider.dart
    - test/services/live_content_provider_test.dart
  modified:
    - lib/models/overlay_pill_state.dart
    - test/models/overlay_pill_state_test.dart

key-decisions:
  - "Injectable callbacks over Supabase mocking — cleaner testability, no static method issues"
  - "displayLabel defaults to empty string — backward compat with existing payloads"
  - "Replace content lists completely on each poll — prevent memory growth over 24h"
  - "Reset rotation index on each poll — ensures fresh content appears immediately"

patterns-established:
  - "Injectable callback pattern: service constructor accepts optional typed callbacks, defaults to real Supabase"
  - "Break state machine: chronological iteration with 'break'→onBreak, 'kembali'→offBreak"
  - "Content interleaving: alternate live stats with motivational messages in a flat list"

requirements-completed: [LIVE-02, LIVE-03]

# Metrics
duration: 11min
completed: 2026-03-11
---

# Phase 16 Plan 01: LiveContentProvider + OverlayPillState displayLabel Summary

**Break detection service with injectable callbacks, fun-facts content pool builder, and backward-compatible displayLabel field on OverlayPillState**

## Performance

- **Duration:** 11 min
- **Started:** 2026-03-11T18:09:49Z
- **Completed:** 2026-03-11T18:20:36Z
- **Tasks:** 2 (both TDD: RED → GREEN)
- **Files modified:** 4

## Accomplishments
- OverlayPillState gains displayLabel field with full backward compatibility (empty string default)
- LiveContentProvider detects break status from chronological attendance logs
- Fun facts pool interleaves live stats (hadir count, %, earliest arrival) with 5 motivational messages
- Injectable callback pattern enables pure Dart testing without Supabase mocking
- Error handling preserves cached data on poll failure

## Task Commits

Each task was committed atomically (TDD: RED → GREEN):

1. **Task 1: Extend OverlayPillState with displayLabel** - `27d81a4` (test: RED) → `13b5039` (feat: GREEN)
2. **Task 2: Create LiveContentProvider service** - `41ef582` (test: RED) → `beab835` (feat: GREEN)

_TDD tasks have two commits each (test → feat)_

## Files Created/Modified
- `lib/models/overlay_pill_state.dart` — Added displayLabel field, constructor param, fromMap/toMap/defaults/legacy
- `lib/services/live_content_provider.dart` — New: break detection, fun facts, content rotation, injectable callbacks
- `test/models/overlay_pill_state_test.dart` — 6 new displayLabel tests (14 total)
- `test/services/live_content_provider_test.dart` — New: 12 tests covering break detection, rotation, stats, errors

## Decisions Made
- Used injectable callbacks (FetchLogsCallback, FetchActiveCountCallback) instead of Supabase mocking for testability
- displayLabel defaults to empty string for backward compatibility with existing payloads
- Content lists are replaced completely on each poll (not appended) to prevent memory growth
- Rotation indices reset on each poll for immediate fresh content display
- Break detection uses 'break' DB value (not 'istirahat') matching AttendanceType.breakTime.value

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- **Path spaces in Dart build hooks:** Windows path `C:\Users\HYPE R Series\...` caused objective_c native asset compilation failures. Resolved by creating junction links (`C:\proj`, `C:\flutter-sdk`, `C:\PubCache`) to provide space-free paths for the Dart toolchain. This is a pre-existing environment issue, not caused by plan changes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- OverlayPillState.displayLabel ready for Plan 02 to wire into overlay_task.dart rendering
- LiveContentProvider ready for Plan 02 to integrate into KioskBackgroundService._pollTimer
- All exports in place: `LiveContentProvider` class, `FetchLogsCallback`/`FetchActiveCountCallback` typedefs

---
*Phase: 16-persistent-live-activity-pill*
*Completed: 2026-03-11*

## Self-Check: PASSED

- All 5 expected files exist
- All 4 task commits verified (27d81a4, 13b5039, 41ef582, beab835)
- displayLabel field: 7 occurrences in model (field, constructor, fromMap, toMap, defaults, legacy)
- LiveContentProvider class exists with attendance_logs query and employees join
- All 26 tests passing (14 overlay_pill_state + 12 live_content_provider)
