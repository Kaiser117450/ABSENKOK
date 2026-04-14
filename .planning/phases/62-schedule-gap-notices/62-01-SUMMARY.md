---
phase: 62-schedule-gap-notices
plan: 01
subsystem: reporting
tags: [schedule, notice, compatibility, dashboard, flutter]
requires:
  - phase: 61-recap-semantics-recovery
    provides: canonical merged recap dataset with explicit fallback rows
provides:
  - typed schedule-gap notice entries and result contract for dashboard follow-up
  - pure notice service sourced only from canonical compatibility rows
  - focused unit coverage for outlet scope, ordering, deduplication, and locked copy
affects: [62-02, admin-dashboard, scheduler-follow-up]
tech-stack:
  added: []
  patterns:
    - schedule-gap notices are derived from fallback recap rows only
    - notice results stay pure, typed, and single-outlet scoped
key-files:
  created:
    - lib/models/schedule_gap_notice.dart
    - lib/services/schedule_gap_notice_service.dart
    - test/services/schedule_gap_notice_service_test.dart
  modified: []
key-decisions:
  - "Schedule-gap notices are emitted exclusively from `AdminPolicyRecapDatasetService.fallbackRows`; strict recap rows never become notice rows."
  - "The notice contract stays non-punitive and dashboard-ready, with locked follow-up copy and no recap/export mutations."
patterns-established:
  - "Operational follow-up for missing schedules lives in a separate typed read model instead of inside recap heuristics."
  - "Notice ordering is newest logical date first, then employee name, with duplicate `(employeeId, logicalDate)` rows collapsed."
requirements-completed: [SCHED-05]
duration: 8 min
completed: 2026-04-01
---

# Phase 62 Plan 01: Canonical Schedule-Gap Notice Summary

**Canonical schedule-gap notice rows now come from a dedicated pure service that reuses recap compatibility rows and exposes one typed, non-punitive dashboard contract.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-01T15:01:00+08:00
- **Completed:** 2026-04-01T15:09:00+08:00
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `ScheduleGapNoticeEntry` and `ScheduleGapNoticeResult` so dashboard UI can consume typed notice rows without re-deriving recap semantics.
- Added `ScheduleGapNoticeService` that rebuilds the canonical recap dataset, reads `fallbackRows` only, deduplicates by `(employeeId, logicalDate)`, and sorts newest notice dates first.
- Added direct unit coverage for empty results, locked non-punitive copy, strict-row exclusion, outlet scoping, and duplicate ordering behavior.

## Task Commits

Workspace commits were intentionally skipped for this plan because tracked files in the current worktree already had unrelated local modifications before execution. Creating a normal commit would have bundled user work outside Phase 62.

1. **Task 1: Create a pure schedule-gap notice domain from canonical compatibility rows** - not committed (dirty tracked workspace)
2. **Task 2: Add direct regression coverage for notice grouping, outlet scope, and non-punitive copy** - not committed (dirty tracked workspace)

## Files Created/Modified

- `lib/models/schedule_gap_notice.dart` - Typed notice row/result contract for outlet-scoped follow-up state.
- `lib/services/schedule_gap_notice_service.dart` - Pure notice builder sourced from `AdminPolicyRecapDatasetService`.
- `test/services/schedule_gap_notice_service_test.dart` - Focused coverage for copy, scoping, strict exclusion, deduplication, and ordering.

## Decisions Made

- `fallbackRows` remain the single trusted signal for schedule-gap notices, so Phase 62 does not reintroduce a raw-log-only detection path.
- Notice copy is intentionally informational: `Hadir tanpa jadwal` plus the locked helper text, with no penalty wording or recap-state bleed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Flutter validation had to use the full SDK path**
- **Found during:** Task 2 (verification)
- **Issue:** Plain `flutter test` in this workspace resolved through a broken local path with spaces and failed native-asset startup.
- **Fix:** Re-ran verification using `C:\flutter\bin\flutter.bat test ...` so the focused suite used the correct SDK location.
- **Files modified:** none
- **Verification:** `test/services/schedule_gap_notice_service_test.dart` passed with the full SDK path
- **Committed in:** not committed

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope creep. The deviation only changed how verification was executed in this environment.

## Issues Encountered

- The workspace already contained unrelated tracked modifications, so task-level commits were not safe to create without bundling user work.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The typed notice domain is ready for dashboard wiring in Plan 02.
- Phase 62 UI work can now reuse one canonical notice service instead of re-deriving recap compatibility state inside widget code.

## Self-Check: PASSED

- Verified `test/services/schedule_gap_notice_service_test.dart` passes with `C:\flutter\bin\flutter.bat test`.
- Verified the service reads `fallbackRows` only and returns typed notice entries with locked copy.

---
*Phase: 62-schedule-gap-notices*
*Completed: 2026-04-01*
