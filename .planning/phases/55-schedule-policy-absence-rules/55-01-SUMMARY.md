---
phase: 55-schedule-policy-absence-rules
plan: 01
subsystem: schedule-policy
tags: [flutter, supabase, schedule, policy, jsonb]
requires:
  - phase: 54-workforce-contract-outlet-mode-foundation
    provides: employment_contract defaults for active employees
provides:
  - typed ShiftBand parsing for band-first schedules
  - reusable schedule policy math for WITA lateness and break-first windows
  - additive shift_slot JSON backfill for active schedules
affects: [shift_scheduler_screen, admin_reports_screen, schedule_entries]
tech-stack:
  added: []
  patterns: [band-first-shift-payload, additive-jsonb-backfill, contract-aware-policy-service]
key-files:
  created:
    - lib/models/shift_band.dart
    - lib/services/schedule_policy_service.dart
    - sql/phase_55_schedule_policy_foundation_20260326.sql
    - test/models/shift_schedule_policy_test.dart
  modified:
    - lib/models/shift_schedule.dart
key-decisions:
  - ShiftSlot stays backward-compatible by preserving legacy start/end hints while serializing the new Phase 55 policy keys beside them.
  - Legacy schedule JSON without policy keys falls back to full-time defaults so existing rows remain readable until the additive SQL backfill is approved and applied.
  - The SQL backfill updates only active schedules and derives required minutes from employees.employment_contract, defaulting to FULLTIME semantics when a row has no employee binding.
patterns-established:
  - Band-first schedule payloads should treat exact clock ranges as compatibility hints, not the primary policy meaning.
  - Schedule policy math now belongs in SchedulePolicyService instead of being re-derived ad hoc in UI code.
requirements-completed: [SCHED-01, SCHED-02]
duration: 16 min
completed: 2026-03-27
---

# Phase 55 Plan 01: Schedule Policy Foundation Summary

**Band-first schedule payloads now carry typed shift bands, contract-aware required hours, and additive WITA cutoff metadata across Dart serialization and the Phase 55 SQL backfill path.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-03-27T03:21:20.841Z
- **Completed:** 2026-03-27T03:37:20.791Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added `ShiftBand` plus `SchedulePolicyService` so the repo has one typed source of truth for 07:00 / 10:00 / 15:00 cutoffs, FULLTIME/PARTTIME required hours, and break-first deadlines.
- Upgraded `ShiftSlot` to serialize and parse `band`, `required_work_minutes`, `late_cutoff_*`, and `break_first_deadline_*` while still round-tripping legacy `start_*`, `end_*`, and `color` keys.
- Added `sql/phase_55_schedule_policy_foundation_20260326.sql` to backfill active `schedule_entries.shift_slot` rows additively from the stored employee contract without touching production.

## Task Commits

Each task was committed atomically:

1. **Task 1: add red-phase schedule policy coverage** - `5ce9c12` (test)
2. **Task 1: implement the typed shift policy foundation** - `b98cc88` (feat)
3. **Task 2: add additive schedule policy SQL backfill** - `4259e3f` (feat)

## Files Created/Modified

- `lib/models/shift_band.dart` - Canonical shift-band enum with storage values, labels, and lateness cutoff metadata.
- `lib/services/schedule_policy_service.dart` - Shared policy math for required hours, break-first windows, and minute-precision lateness.
- `lib/models/shift_schedule.dart` - Backward-compatible `ShiftSlot` serialization that emits both legacy hints and Phase 55 policy keys.
- `test/models/shift_schedule_policy_test.dart` - Regression coverage for legacy/new payload parsing and locked WITA policy helpers.
- `sql/phase_55_schedule_policy_foundation_20260326.sql` - Additive helper functions and `jsonb_set` backfill for active schedule rows.

## Decisions Made

- `ShiftSlot` keeps legacy clock fields as compatibility hints so existing scheduler, portal, and cache paths do not break while the repo shifts to band-first meaning.
- Full-time defaults are used when policy keys are absent because legacy stored rows do not yet encode contract-aware required minutes or break-first windows.
- The SQL patch avoids destructive rewrites by enriching existing JSON in place and by limiting the backfill to active schedules only.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Continued inline after the executor stalled before task completion**
- **Found during:** Task 1 execution setup
- **Issue:** The spawned `gsd-executor` agent loaded context and created the red test file but never returned a completion signal or filesystem artifacts for the plan.
- **Fix:** Closed the stalled agent, preserved the generated red test file, and completed the remaining plan inline while keeping the atomic task commit structure.
- **Files modified:** `test/models/shift_schedule_policy_test.dart`, `lib/models/shift_band.dart`, `lib/services/schedule_policy_service.dart`, `lib/models/shift_schedule.dart`, `sql/phase_55_schedule_policy_foundation_20260326.sql`
- **Verification:** `C:\flutter\bin\flutter.bat test test/models/shift_schedule_policy_test.dart`; `C:\flutter\bin\flutter.bat test test/models/shift_schedule_test.dart`
- **Committed in:** `5ce9c12`, `b98cc88`, `4259e3f`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Execution style changed from delegated to inline, but delivered scope and verification stayed aligned with the plan.

## Issues Encountered

None - product implementation completed cleanly once execution moved inline.

## User Setup Required

**External setup is still required.** See `55-USER-SETUP.md` for the manual Supabase SQL apply step that must wait for explicit approval.

## Next Phase Readiness

- `55-02-PLAN.md` can now consume `ShiftBand`, `ShiftSlot.requiredWorkMinutes`, and `SchedulePolicyService` for the band-first scheduler UI.
- The additive SQL file is ready for review, but it must not be applied to production until the user explicitly approves the database change.
- `55-03-PLAN.md` can reuse the same policy keys and contract defaults when building the admin recap RPC.
