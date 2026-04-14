---
phase: 58-payroll-matrix-spreadsheet-export
plan: 01
subsystem: reporting
tags: [flutter, payroll, matrix, xlsx, syncfusion]
requires: []
provides:
  - shared payroll matrix dataset models
  - roster-first payroll matrix builder
  - shared semantics for labels, tags, colors, and summary counts
affects: [admin-reports, spreadsheet-export, payroll-review]
tech-stack:
  added: [syncfusion_flutter_xlsio, excel]
  patterns: [shared payroll matrix contract, roster-first matrix building, UI/workbook semantic parity]
key-files:
  created:
    - lib/models/payroll_matrix_day_cell.dart
    - lib/models/payroll_matrix_row.dart
    - lib/services/payroll_matrix_semantics.dart
    - lib/services/payroll_matrix_builder.dart
    - test/models/payroll_matrix_day_cell_test.dart
    - test/models/payroll_matrix_row_test.dart
    - test/services/payroll_matrix_builder_test.dart
    - test/services/payroll_matrix_semantics_test.dart
  modified:
    - pubspec.yaml
key-decisions:
  - "Kept one shared dataset contract for UI and workbook paths so payroll rendering never re-derives recap semantics."
  - "Sorted active employees by contract then name and excluded archived staff from the matrix."
  - "Downgraded syncfusion_flutter_xlsio to ^29.2.11 because ^33.1.45 conflicts with excel ^4.0.6 through incompatible archive versions."
patterns-established:
  - "PayrollMatrixDayCell.exportText is the canonical compact workbook/UI cell body."
  - "PayrollMatrixRow.summaryValuesInOrder locks payroll summary ordering to late, short work, excess break, absence, overtime."
requirements-completed: [REPORT-01, REPORT-02]
duration: resumed
completed: 2026-03-27
---

# Phase 58 Plan 01: Payroll Matrix Foundation Summary

**Shared payroll matrix models, builder, and semantics now define one roster-first contract for both the recap UI and spreadsheet export.**

## Performance

- **Duration:** resumed execution
- **Started:** 2026-03-27 (resumed from existing in-progress work)
- **Completed:** 2026-03-27T20:39:16.4618794+08:00
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Added canonical matrix models for day cells, per-employee rows, and date-scoped datasets.
- Built the shared payroll semantics layer for explicit labels, compact tags, primary color palettes, and payroll-only summary counts.
- Added unit coverage for placeholders, tag formatting, summary ordering, semantic mapping, and archived-employee exclusion.

## Task Commits

Atomic task commits were skipped for this execution because the repository already contained extensive unrelated dirty changes. Changes were left uncommitted to avoid bundling user-owned diffs.

## Files Created/Modified

- `pubspec.yaml` - added `syncfusion_flutter_xlsio` and `excel` for the Phase 58 workbook path and contract tests
- `lib/models/payroll_matrix_day_cell.dart` - canonical compact payroll cell contract with `exportText`
- `lib/models/payroll_matrix_row.dart` - per-employee payroll row plus fixed summary ordering
- `lib/services/payroll_matrix_semantics.dart` - maps strict recap results into payroll-facing labels, colors, tags, and counts
- `lib/services/payroll_matrix_builder.dart` - builds the roster-first dataset from active employees and strict recap rows
- `test/models/payroll_matrix_day_cell_test.dart` - placeholder and compact-tag coverage
- `test/models/payroll_matrix_row_test.dart` - summary ordering and dataset emptiness coverage
- `test/services/payroll_matrix_builder_test.dart` - roster-first and archived-employee exclusion coverage
- `test/services/payroll_matrix_semantics_test.dart` - shared semantic parity coverage

## Decisions Made

- Used one shared matrix contract instead of separate UI/export DTOs.
- Locked the employee rail/workbook summary order to the payroll counts approved in Phase 58 context.
- Resolved the `archive` version conflict by using `syncfusion_flutter_xlsio: ^29.2.11` rather than the originally researched `^33.1.45`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Resolved incompatible XLSX package graph**
- **Found during:** Task 1
- **Issue:** `syncfusion_flutter_xlsio ^33.1.45` and `excel ^4.0.6` could not coexist because they require incompatible `archive` major versions.
- **Fix:** Pinned `syncfusion_flutter_xlsio` to `^29.2.11`, which still supports the workbook features Phase 58 needs and keeps the contract test dependency working.
- **Files modified:** `pubspec.yaml`
- **Verification:** `C:\flutter\bin\flutter.bat pub get`

---

**Total deviations:** 1 auto-fixed blocking issue
**Impact on plan:** No scope change. The dependency adjustment was required to keep the workbook path and XLSX contract tests buildable.

## Issues Encountered

- Syncfusion licensing remains a rollout checkpoint. The implementation proceeded under the assumption that the project has or will secure the required approval.

## User Setup Required

- Confirm the project qualifies for the Syncfusion Community License or has commercial approval before shipping the workbook path to production.

## Next Phase Readiness

- The shared payroll matrix contract is stable and ready for the matrix UI shell and workbook generator.
- Downstream work should keep using `PayrollMatrixDataset` rather than rebuilding recap semantics from raw rows.

---
*Phase: 58-payroll-matrix-spreadsheet-export*
*Completed: 2026-03-27*
