---
phase: 57-strict-recap-evaluation-engine
plan: 02
subsystem: api
tags: [flutter, model, parser, recap, compatibility]
requires:
  - phase: 57-01
    provides: widened get_admin_schedule_policy_recap payload with strict fields
provides:
  - typed strict recap enums
  - expanded recap row model with compatibility fallbacks
  - recap service parsing for strict and legacy rows
affects: [57-03, phase-58-reporting]
tech-stack:
  added: [typed strict recap enums, model/service tests]
  patterns: [strict-plus-legacy parsing, typed signal arrays]
key-files:
  created: [lib/models/attendance_policy_signal.dart, test/models/attendance_policy_recap_day_test.dart]
  modified: [lib/models/attendance_policy_recap_day.dart, lib/services/attendance_policy_recap_service.dart, test/services/attendance_policy_recap_service_test.dart]
key-decisions:
  - "Derived safe legacy attendanceStatus and lateKind values from strict-only rows so rollout can tolerate mixed payloads."
  - "Kept the service's nested data unwrapping and added single-row map support for defensive parsing."
patterns-established:
  - "Primary status and detail signals are exposed as typed enums, never raw strings in widgets."
  - "Legacy recap rows degrade into a strict model without throwing."
requirements-completed: [CONTRACT-03, RECAP-01, RECAP-02, RECAP-03, RECAP-04]
duration: 14min
completed: 2026-03-27
---

# Phase 57: Strict Recap Evaluation Engine Summary

**Typed Flutter recap models now carry strict primary status, detail signals, metrics, and legacy compatibility from one parsing layer**

## Performance

- **Duration:** 14 min
- **Started:** 2026-03-27T15:31:00+08:00
- **Completed:** 2026-03-27T15:45:00+08:00
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Added strict recap enums for severity, primary status, and detail signals.
- Expanded `AttendancePolicyRecapDay` to parse strict metrics plus compatibility defaults for old rows.
- Kept `AttendancePolicyRecapService` resilient across nested strict payloads, single-row maps, and legacy Phase 56 responses.

## Task Commits

1. **Task 1: Create the typed strict recap signal layer and expand the recap row model** - `02bb6a0` (`feat(57-02): add strict recap typed models`)
2. **Task 2: Update the recap service and tests to consume the widened strict recap RPC** - `59ff028` (`test(57-02): support strict recap service parsing`)

## Files Created/Modified
- `lib/models/attendance_policy_signal.dart` - canonical strict recap enums and storage/label helpers.
- `lib/models/attendance_policy_recap_day.dart` - widened recap row model with compatibility derivation.
- `lib/services/attendance_policy_recap_service.dart` - defensive strict/legacy row extraction.
- `test/models/attendance_policy_recap_day_test.dart` - strict parsing and legacy compatibility coverage.
- `test/services/attendance_policy_recap_service_test.dart` - strict nested payload and legacy service parsing coverage.

## Decisions Made
- Preferred compatibility derivation inside the recap model so screens do not need rollout-specific conditionals.
- Treated strict arrays as the source of truth, with legacy fields acting as fallbacks only.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

None.

## User Setup Required

None - no extra operator setup beyond the SQL rollout already captured in Plan 01.

## Next Phase Readiness

- The admin recap surface can now consume strict status/severity fields directly.
- Phase 57-03 only needs presentation and filtering work; no additional parsing layer is required.

---
*Phase: 57-strict-recap-evaluation-engine*
*Completed: 2026-03-27*
