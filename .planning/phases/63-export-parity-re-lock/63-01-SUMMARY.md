---
phase: 63-export-parity-re-lock
plan: 01
subsystem: testing
tags: [flutter, reporting, payroll, recap, widget-test]
requires:
  - phase: 61-recap-semantics-recovery
    provides: row-first merged strict-plus-fallback recap semantics
  - phase: 62-schedule-gap-notices
    provides: the current PolicyRecapTab shell and compatibility messaging
provides:
  - shared export parity fixture bundle derived from strict and fallback recap inputs
  - canonical merged-row contract coverage through AdminPolicyRecapDatasetService and buildPayrollMatrix
  - repaired PolicyRecapTab payroll-support coverage using a production widget instead of mirrored test markup
affects: [63-02, export-parity, admin-rekap]
tech-stack:
  added: []
  patterns:
    - fixture-backed parity tests flow recap inputs through AdminPolicyRecapDatasetService and buildPayrollMatrix
    - PolicyRecapTab widget tests reuse production payroll-support composition instead of local duplicate copy
key-files:
  created:
    - test/fixtures/report_export_parity_fixture.dart
    - test/services/report_export_parity_test.dart
    - lib/screens/admin/widgets/policy_recap_payroll_support_section.dart
  modified:
    - lib/screens/admin/admin_reports_screen.dart
    - test/screens/admin/admin_reports_payroll_matrix_test.dart
key-decisions:
  - Kept the shipped AdminPolicyRecapDatasetService -> buildPayrollMatrix export seam and removed the dead screen-local recap helper.
  - Extracted the payroll output card into PolicyRecapPayrollSupportSection while leaving rollout acceptance wiring in AdminReportsScreen.
patterns-established:
  - Canonical export parity tests must start from recap employees, strict rows, and attendance logs instead of hand-authored PayrollMatrixDataset literals.
  - PolicyRecapTab coverage should inject the production payroll-support widget and scroll to it when the recap list pushes it below the initial viewport.
requirements-completed: [REPORT-04, REPORT-05]
duration: 8 min
completed: 2026-04-02
---

# Phase 63 Plan 01: Export Parity Re-lock Summary

**Shared recap-derived parity fixtures, a merged-row payroll matrix contract test, and a repaired PolicyRecapTab payroll-support seam for the current export path**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-02T06:09:26Z
- **Completed:** 2026-04-02T06:17:49Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added one reusable fixture bundle under `test/fixtures/` that encodes the locked strict, overnight, overtime, no-show, and legacy fallback payroll scenarios for later export parity work.
- Added a focused contract test that drives `AdminPolicyRecapDatasetService.build(...)` into `buildPayrollMatrix(...)` and locks the compatibility flag, tags, and ordered summary totals on the runtime chain.
- Removed the stale report-screen helper seam, extracted the payroll output card into a production widget, and rewrote the recap widget test around `PolicyRecapTab` plus the real payroll-support surface.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create the shared export parity fixture bundle and canonical merged-row contract test** - `a3b6379` (`test`)
2. **Task 2: Remove the stale payroll recap helper seam and rewrite the broken widget test for PolicyRecapTab** - `8b74dab` (`fix`)

## Files Created/Modified

- `test/fixtures/report_export_parity_fixture.dart` - shared strict/fallback fixture bundle keyed by `employeeId|yyyy-MM-dd` with locked scenario expectations.
- `test/services/report_export_parity_test.dart` - canonical merged-row to payroll-matrix contract coverage for the active export path.
- `lib/screens/admin/widgets/policy_recap_payroll_support_section.dart` - reusable production payroll-support card for recap output actions.
- `lib/screens/admin/admin_reports_screen.dart` - removed the dead recap helper seam and switched recap support rendering to the reusable widget.
- `test/screens/admin/admin_reports_payroll_matrix_test.dart` - rebuilt the screen-level guardrail around `PolicyRecapTab` and the production support widget.

## Decisions Made

- Kept the shipped runtime export path intact. The plan now proves parity by feeding fixtures through `AdminPolicyRecapDatasetService` and `buildPayrollMatrix` instead of reintroducing a screen-local compatibility helper.
- Extracted only the payroll output card as the reusable widget. The rollout acceptance panel remains wired directly in `AdminReportsScreen`, which preserves its existing summary-based download callback contract.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The rewritten widget test initially could not see the payroll-support section because `PolicyRecapTab` renders it below a scrollable recap list. The harness now scrolls to the production widget before asserting its labels and CTAs.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for `63-02-PLAN.md` to re-lock spreadsheet and payroll PDF service tests onto the shared fixture bundle delivered here.
- No blockers remain for the next plan; the current recap screen now exercises the production payroll-support composition and the canonical recap-to-matrix contract is in place.

## Self-Check: PASSED

- FOUND: `.planning/phases/63-export-parity-re-lock/63-01-SUMMARY.md`
- FOUND: `a3b6379`
- FOUND: `8b74dab`
