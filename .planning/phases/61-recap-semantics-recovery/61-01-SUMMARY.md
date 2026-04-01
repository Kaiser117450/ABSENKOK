---
phase: 61-recap-semantics-recovery
plan: 01
subsystem: reporting
tags: [attendance, recap, compatibility, fallback, flutter]
requires:
  - phase: 57-strict-recap-evaluation-engine
    provides: strict `AttendancePolicyRecapDay` rows and typed recap semantics
  - phase: 58.1-schedule-ux-polish-and-legacy-payroll-fallback
    provides: honest fallback row synthesis and overnight-safe legacy source-day grouping
provides:
  - canonical merged admin recap dataset service returning strict, fallback, and merged day rows
  - focused regression coverage for strict-wins merges, compatibility mode, and overnight logical dates
affects: [61-02, 63-export-parity-re-lock, admin-recap]
tech-stack:
  added: []
  patterns:
    - strict-wins merge keyed by `(employeeId, logicalDate)`
    - compatibility derived from injected fallback rows only
key-files:
  created:
    - lib/services/admin_policy_recap_dataset_service.dart
    - test/services/admin_policy_recap_dataset_service_test.dart
  modified: []
key-decisions:
  - "AdminPolicyRecapDatasetService returns canonical `AttendancePolicyRecapDay` collections only and leaves payroll-matrix generation downstream."
  - "Plan 01 reuses `LegacyPayrollRecapFallbackService` as-is; no extra helper extraction was necessary to satisfy the merge contract."
patterns-established:
  - "Canonical admin recap data is built from strict rows plus fallback rows before any UI or export transforms."
  - "Compatibility mode is a data fact (`fallbackRows.isNotEmpty`), not a fetch-state heuristic."
requirements-completed: [RECAP-05, RECAP-06, RECAP-07]
duration: 3 min
completed: 2026-04-01
---

# Phase 61 Plan 01: Canonical Admin Recap Dataset Summary

**Canonical merged admin recap rows now come from a dedicated pure service with strict-wins fallback merging and overnight-safe legacy compatibility coverage.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-01T12:35:48+08:00
- **Completed:** 2026-04-01T12:38:53+08:00
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added `AdminPolicyRecapDatasetService` and `AdminPolicyRecapDatasetResult` as the pure row-level merge contract for admin recap semantics.
- Kept fallback synthesis honest by reusing the existing legacy fallback service and filtering attendance logs to the selected outlet before compatibility injection.
- Added direct regression coverage for strict-wins merges, compatibility mode behavior, overnight `TWENTY_FOUR_HOUR` logical dates, and null schedule-only fallback cutoffs.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extract a pure merged admin recap dataset service from the payroll-only helper** - `2f4da53` (feat)
2. **Task 2: Add direct regression coverage for strict-wins merge and overnight-safe compatibility rows** - `970e19b` (test)

_TDD order wrote the direct regression coverage first, then implemented the service against that contract._

## Files Created/Modified
- `lib/services/admin_policy_recap_dataset_service.dart` - Pure canonical recap dataset builder returning strict, fallback, and merged `AttendancePolicyRecapDay` rows.
- `test/services/admin_policy_recap_dataset_service_test.dart` - Direct service regressions for merge semantics, compatibility mode, overnight grouping, and honest fallback fields.

## Decisions Made
- `AdminPolicyRecapDatasetService` stays row-first and does not import or build payroll-matrix objects, so later plans can reuse the same merged dataset in UI and export layers.
- The existing `LegacyPayrollRecapFallbackService` already exposed the required pure source-day and missing-row APIs, so Plan 01 kept that service unchanged instead of extracting extra helpers prematurely.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `rg.exe` could not run in this Windows sandbox, so file searches fell back to PowerShell `Select-String`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 01 is complete and the reusable merged recap dataset service is ready for Plan 02 to rewire `AdminReportsScreen` to the canonical service.
- `RECAP-05`, `RECAP-06`, and `RECAP-07` remain phase-scoped and should be marked complete only after Plan 02 lands the active recap screen wiring and widget regressions.

## Self-Check: PASSED

- Verified `.planning/phases/61-recap-semantics-recovery/61-01-SUMMARY.md` exists on disk.
- Verified task commits `970e19b` and `2f4da53` exist in `git log`.

---
*Phase: 61-recap-semantics-recovery*
*Completed: 2026-04-01*
