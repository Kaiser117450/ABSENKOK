---
phase: 59-pdf-portal-parity
plan: 04
subsystem: ui
tags: [flutter, admin-reports, payroll, pdf, recap]
requires:
  - phase: 58.1-03
    provides: merged strict-plus-fallback payroll recap dataset and compatibility disclosure pattern
  - phase: 59-03
    provides: dedicated payroll PDF export service
provides:
  - recap-tab payroll PDF primary action
  - spreadsheet secondary action with preserved recap dataset parity
  - screen-level regression coverage for recap export shell copy and compatibility note
affects: [admin-reports, payroll-export, operator-workflow]
tech-stack:
  added: []
  patterns: [separate recap export states, inline recap export feedback, pdf-primary recap action]
key-files:
  created: []
  modified:
    - lib/screens/admin/admin_reports_screen.dart
    - test/screens/admin/admin_reports_payroll_matrix_test.dart
key-decisions:
  - "Kept PDF and spreadsheet export state separate so the recap PDF button can disable during generation while the spreadsheet action remains visible as the secondary path."
  - "Reused the existing merged payroll matrix dataset from the recap tab instead of building another PDF-only data pipeline."
  - "Moved the recap status copy below the action row to keep the shell readable when export feedback changes."
patterns-established:
  - "PayrollRecapTab now receives explicit `isExportingPdf`, `canExportPdf`, and `onExportPdf` inputs rather than inferring CTA behavior from the spreadsheet path."
  - "The recap tab uses one shared inline status copy surface for both payroll export actions."
requirements-completed: [SCHED-04, REPORT-03]
duration: ~20m
completed: 2026-03-28
---

# Phase 59 Plan 04: Admin Recap Export Wiring Summary

**The admin recap tab now exposes `Ekspor PDF Payroll` as the primary payroll export action, keeps spreadsheet export beside it, and reports progress inline without leaving the recap surface.**

## Performance

- **Duration:** ~20m
- **Started:** 2026-03-28T16:10:00+08:00
- **Completed:** 2026-03-28T16:35:03.1657332+08:00
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments

- Wired the recap tab to `PayrollPdfMatrixExportService` with exact loading, success, and failure copy from the Phase 59 UI contract.
- Preserved `Ekspor Spreadsheet` as the outlined secondary action beside the new PDF CTA.
- Extended the recap shell regression tests to cover the PDF CTA, inline progress copy, success copy, compatibility note, and absence of the legacy per-scan export cluster.

## Task Commits

Atomic task commits were skipped for this execution because the repository already contained extensive unrelated dirty changes. Changes were left uncommitted to avoid bundling user-owned diffs.

## Files Created/Modified

- `lib/screens/admin/admin_reports_screen.dart` - recap-tab payroll PDF export state, callback wiring, CTA ordering, and inline export feedback
- `test/screens/admin/admin_reports_payroll_matrix_test.dart` - regression coverage for the payroll PDF primary action, spreadsheet secondary action, compatibility note, and recap shell copy

## Decisions Made

- Left the legacy per-scan CSV/PDF actions untouched and scoped the new PDF action only to the payroll recap tab.
- Reused `_payrollExportStatusMessage` for the recap shell so success/error messaging stays consistent across export actions.
- Kept spreadsheet export available beside the PDF CTA rather than hiding or relocating it.

## Deviations from Plan

None. The recap-tab wiring stayed inside the approved copy, CTA order, and non-blocking inline feedback scope.

## Issues Encountered

None.

## User Setup Required

None.

## Next Phase Readiness

- Phase 59 now has its operator-facing recap export shell in place on top of the tested payroll PDF service.
- Remaining closeout work is phase-level verification/tracking, not more feature wiring.

---
*Phase: 59-pdf-portal-parity*
*Completed: 2026-03-28*
