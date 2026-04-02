---
phase: 63-export-parity-re-lock
plan: 02
subsystem: testing
tags: [flutter, payroll, spreadsheet, pdf, parity]
requires:
  - phase: 63-01
    provides: shared merged-row report parity fixtures and recap payroll support baseline
provides:
  - Spreadsheet export contract coverage driven by the shared parity fixture bundle
  - Payroll PDF preview/file contract coverage driven by the shared parity fixture bundle
  - Plain compatibility-row no-schedule labeling fixed in shared payroll matrix semantics
affects: [reporting, payroll-exports, admin-recap]
tech-stack:
  added: []
  patterns:
    - Shared parity fixtures feed both spreadsheet and PDF export contract tests
    - Salary-facing export tests verify serialized workbook/PDF output instead of synthetic matrix literals
key-files:
  created:
    - lib/services/payroll_matrix_semantics.dart
    - test/services/payroll_spreadsheet_export_service_test.dart
    - test/services/payroll_pdf_matrix_export_service_test.dart
    - test/services/payroll_matrix_builder_test.dart
    - test/services/payroll_matrix_semantics_test.dart
  modified: []
key-decisions:
  - "Spreadsheet and PDF export tests now build datasets via AdminPolicyRecapDatasetService and buildPayrollMatrix from buildReportExportParityFixtureBundle()."
  - "Plain hadirTanpaJadwal compatibility rows now render as 'Hadir tanpa jadwal' in payroll-facing matrix outputs, while penalty-bearing compatibility rows stay time-first."
patterns-established:
  - "Export contract tests should assert against the shared merged-row parity bundle instead of inline PayrollMatrixDataset literals."
  - "Spreadsheet workbook tests should combine Excel round-trips with xl/styles.xml inspection to lock payroll color semantics."
requirements-completed: [REPORT-04, REPORT-05]
duration: 8 min
completed: 2026-04-02
---

# Phase 63 Plan 02: Export Parity Re-lock Summary

**Shared parity-fixture coverage for payroll spreadsheet and PDF exports with locked no-schedule labeling, workbook color checks, and forbidden-field boundaries**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-02T06:26:30Z
- **Completed:** 2026-04-02T06:34:30Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Rebuilt the spreadsheet export contract test from the shared merged-row parity fixture pipeline instead of an inline `PayrollMatrixDataset` literal.
- Rebuilt the payroll PDF preview/file contract test from the same shared parity fixture pipeline and locked compatibility-mode, legend, summary-order, and forbidden-field expectations.
- Fixed the exposed plain fallback-row label bug so payroll-facing matrix outputs now show `Hadir tanpa jadwal` for compatibility-only no-schedule rows.

## Task Commits

Each task was committed atomically:

1. **Task 1: Rework the spreadsheet export test onto the shared merged-row parity bundle** - `ad5f7fc` (fix)
2. **Task 2: Rework the payroll PDF export test onto the shared merged-row parity bundle** - `3723b8b` (test)

## Files Created/Modified
- `lib/services/payroll_matrix_semantics.dart` - Shared payroll matrix label/color semantics, including the compatibility-row no-schedule label fix.
- `test/services/payroll_spreadsheet_export_service_test.dart` - Workbook contract test using the shared parity fixture bundle plus `styles.xml` color assertions.
- `test/services/payroll_pdf_matrix_export_service_test.dart` - Preview-first PDF contract test using the shared parity fixture bundle and serialized forbidden-field checks.
- `test/services/payroll_matrix_builder_test.dart` - Builder expectation updated for plain fallback no-schedule rows after the semantics bug fix.
- `test/services/payroll_matrix_semantics_test.dart` - Semantics expectation updated for the locked `Hadir tanpa jadwal` payroll label.

## Decisions Made
- Reused the canonical merged recap path (`buildReportExportParityFixtureBundle()` -> `AdminPolicyRecapDatasetService.build()` -> `buildPayrollMatrix()`) for both export service tests so spreadsheet and PDF coverage now prove the same dataset parity as admin recap.
- Locked spreadsheet color assertions against serialized workbook styles instead of duplicating palettes in test code, which keeps the workbook contract tied to the real matrix cell semantics.
- Limited the production bug fix to plain `hadirTanpaJadwal` compatibility rows so the payroll-facing label becomes explicit without changing penalty-bearing fallback rows that still need time-first output.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plain fallback compatibility rows were still exported as raw scan times**
- **Found during:** Task 1 (Rework the spreadsheet export test onto the shared merged-row parity bundle)
- **Issue:** The shared parity fixture exposed that a plain no-schedule compatibility row rendered as `08:00 / 17:00`, so spreadsheet/PDF outputs never showed the locked payroll-facing label `Hadir tanpa jadwal`.
- **Fix:** Updated `PayrollMatrixSemantics` to prioritize the explicit no-schedule label for plain compatibility rows before time rendering, then updated the directly affected payroll matrix expectations.
- **Files modified:** `lib/services/payroll_matrix_semantics.dart`, `test/services/payroll_matrix_builder_test.dart`, `test/services/payroll_matrix_semantics_test.dart`, `test/services/payroll_spreadsheet_export_service_test.dart`
- **Verification:** `flutter test test/services/payroll_spreadsheet_export_service_test.dart test/services/payroll_matrix_semantics_test.dart test/services/payroll_matrix_builder_test.dart` and the full plan verification bundle
- **Committed in:** `ad5f7fc`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** The fix was required to make the real parity fixture satisfy the locked payroll export contract. Scope stayed inside the shared matrix semantics used by the planned tests.

## Issues Encountered
- `rg.exe` could not start in this Windows workspace due an access-denied error, so all search/acceptance scans fell back to PowerShell `Select-String`.
- `dart_pdf` emitted the existing Helvetica Unicode support warning during PDF generation, but the focused PDF test and full plan verification both passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 63 is complete: the shared parity fixture now locks admin recap, spreadsheet export, and payroll PDF export to one merged reporting dataset and one compatibility-mode truth.
- The remaining non-automated follow-up is the manual operator scanability check already documented in `63-VALIDATION.md` for generated spreadsheet/PDF artifacts.

## Self-Check: PASSED

- Verified summary file exists on disk.
- Verified task commits `ad5f7fc` and `3723b8b` exist in git history.

---
*Phase: 63-export-parity-re-lock*
*Completed: 2026-04-02*
