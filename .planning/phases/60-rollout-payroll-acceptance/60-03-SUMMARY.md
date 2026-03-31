---
phase: 60-rollout-payroll-acceptance
plan: 03
subsystem: admin-recap-ui
tags: [payroll, rollout, acceptance, admin-ui, widget-tests]
requires: ["60-01", "60-02"]
provides:
  - recap-shell rollout acceptance panel
  - readiness gating inside the admin payroll recap shell
  - widget regression coverage for rollout shell integration
affects: [admin-recap, validation-bundle-export, payroll-matrix]
tech-stack:
  added: []
  patterns:
    - rollout acceptance surface embedded in the existing recap shell
    - readiness gating derived from the rollout acceptance service
    - widget-level protection for locked rollout copy and action ordering
key-files:
  created:
    - lib/screens/admin/widgets/payroll_rollout_acceptance_panel.dart
    - test/screens/admin/admin_reports_payroll_rollout_test.dart
  modified:
    - lib/screens/admin/admin_reports_screen.dart
    - test/screens/admin/admin_reports_payroll_matrix_test.dart
key-decisions:
  - "The rollout surface stays inside PayrollRecapTab so operators review readiness in the same shell they already use for payroll recap and exports."
  - "The primary CTA remains gated by buildPayrollRolloutAcceptanceSummary and the secondary CTA reuses PayrollValidationBundleService instead of inventing local rollout state."
  - "The recap integration preserves the existing PDF and spreadsheet exports while adding rollout readiness above the matrix."
patterns-established:
  - "Admin rollout approvals layer onto existing recap flows instead of creating new reporting routes."
  - "Widget tests cover locked rollout copy, action ordering, and recap-shell coexistence with the existing export controls."
requirements-completed: [OPS-01]
duration: "~15 minutes"
completed: 2026-03-31
---

# Phase 60 Plan 03: Rollout Acceptance Shell Summary

**Admin payroll recap now includes a rollout acceptance banner, seven-scenario readiness matrix, parity evidence table, validation-bundle export action, and widget coverage that protects the integrated shell.**

## Performance

- **Duration:** ~15 minutes
- **Completed:** 2026-03-31
- **Tasks:** 2
- **Files changed:** 4

## Accomplishments

- Added `lib/screens/admin/widgets/payroll_rollout_acceptance_panel.dart` as the dedicated rollout acceptance surface with the locked copy, additive-only reminder, scenario list, parity evidence table, database-review confirmation step, and action bar.
- Integrated the rollout panel into `lib/screens/admin/admin_reports_screen.dart` so the recap shell derives readiness from `buildPayrollRolloutAcceptanceSummary` and exports evidence through `buildPayrollValidationBundle` without creating a new route or replacing the existing payroll exports.
- Added focused widget regression coverage in `test/screens/admin/admin_reports_payroll_rollout_test.dart` and `test/screens/admin/admin_reports_payroll_matrix_test.dart` for rollout copy, CTA gating, destructive-dialog timing, and recap-shell coexistence with the PDF and spreadsheet actions.

## Task Commits

- **Task 1:** `57d96fc` - `test(60-03): cover rollout acceptance shell`
- **Task 2:** `57d96fc` - `test(60-03): cover rollout acceptance shell`

## Files Created/Modified

- `lib/screens/admin/admin_reports_screen.dart` - wires the rollout acceptance service and validation bundle service into the existing payroll recap shell
- `lib/screens/admin/widgets/payroll_rollout_acceptance_panel.dart` - renders the approved rollout banner, scenario matrix, parity table, and action bar
- `test/screens/admin/admin_reports_payroll_rollout_test.dart` - verifies locked rollout copy, disabled primary CTA, evidence headers, and confirmation-dialog timing
- `test/screens/admin/admin_reports_payroll_matrix_test.dart` - verifies the rollout panel appears while the recap shell keeps the existing PDF and spreadsheet exports

## Decisions Made

- Kept the rollout experience inside the existing admin recap shell so operators review readiness where they already inspect payroll recap data.
- Reused the existing rollout acceptance and validation bundle services instead of introducing extra widget-owned state or persistence.
- Preserved the legacy export cluster below the rollout panel so acceptance review augments the recap shell rather than replacing it.

## Deviations from Plan

The owned `60-03` UI and test files were already present in commit `57d96fc` when this execution resumed, so this run verified the implementation and created the summary artifact without rewriting the working source files. No behavior-level deviation was required.

## Issues Encountered

None. The committed implementation already satisfied the plan and the targeted widget tests passed unchanged.

## User Setup Required

None. The rollout acceptance workflow stays inside the existing admin recap shell and reuses the existing validation bundle export service.

## Next Phase Readiness

- The rollout acceptance shell is ready for manual operator review using the Phase 60 docs and fixture pack from plans `60-01` and `60-02`.
- No automated blockers remain in the owned UI or widget-test files.

## Verification

- `C:\flutter\bin\flutter.bat test test/screens/admin/admin_reports_payroll_rollout_test.dart` -> PASS
- `C:\flutter\bin\flutter.bat test test/screens/admin/admin_reports_payroll_rollout_test.dart test/screens/admin/admin_reports_payroll_matrix_test.dart` -> PASS

## Self-Check: PASSED

- `lib/screens/admin/admin_reports_screen.dart` exists: FOUND
- `lib/screens/admin/widgets/payroll_rollout_acceptance_panel.dart` exists: FOUND
- `test/screens/admin/admin_reports_payroll_rollout_test.dart` exists: FOUND
- `test/screens/admin/admin_reports_payroll_matrix_test.dart` exists: FOUND
- `.planning/phases/60-rollout-payroll-acceptance/60-03-SUMMARY.md` exists: FOUND
- Commit `57d96fc` exists: FOUND
