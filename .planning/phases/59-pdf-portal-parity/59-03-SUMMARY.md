---
phase: 59-pdf-portal-parity
plan: 03
subsystem: reporting
tags: [flutter, pdf, payroll, matrix, reporting]
requires:
  - phase: 58
    provides: payroll matrix dataset, summary ordering, shared semantics
  - phase: 59-01
    provides: shared overnight and fallback parity fixtures
provides:
  - dedicated payroll PDF matrix export service
  - dataset-level summary metric aggregation for the payroll PDF cover
  - focused regression coverage for payroll PDF summary, legend, and forbidden-field exclusion
affects: [admin-reports, payroll-export, payroll-review]
tech-stack:
  added: []
  patterns: [preview-first pdf contract testing, shared matrix semantics reuse, matrix-first payroll pdf body]
key-files:
  created:
    - lib/services/payroll_pdf_matrix_export_service.dart
    - test/services/payroll_pdf_matrix_export_service_test.dart
  modified:
    - lib/services/payroll_matrix_semantics.dart
    - lib/services/pdf_service.dart
    - test/services/payroll_matrix_semantics_test.dart
key-decisions:
  - "Built the payroll PDF around a typed preview model so tests can assert summary order, legend tags, overnight rows, fallback rows, and forbidden-field exclusion without parsing rendered PDF text."
  - "Extended `PayrollMatrixSemantics` with dataset-level summary aggregation and locked legend order instead of duplicating payroll label/color rules in the PDF service."
  - "Exposed `PdfService.loadBrandLogo()` as a thin shared branding adapter and kept the legacy per-scan/daily PDF paths untouched."
patterns-established:
  - "Payroll PDF generation now starts from `buildPreview(...)` and renders the document from that immutable matrix-first snapshot."
  - "Summary metrics follow the locked payroll ordering: Terlambat, Kurang Jam, Break Lebih, Tidak Hadir, Lembur."
requirements-completed: [REPORT-03]
duration: ~30m
completed: 2026-03-28
---

# Phase 59 Plan 03: Payroll PDF Matrix Export Summary

**A dedicated payroll PDF export service now renders a compact recap page followed by landscape matrix pages from the shipped payroll dataset and semantics contract.**

## Performance

- **Duration:** ~30m
- **Started:** 2026-03-28T16:00:00+08:00
- **Completed:** 2026-03-28T16:35:03.1657332+08:00
- **Tasks:** 1
- **Files modified:** 5

## Accomplishments

- Added `PayrollPdfMatrixExportService` with a compact summary page, locked legend order, compatibility banner support, and landscape matrix pagination.
- Extended `PayrollMatrixSemantics` with dataset-level summary aggregation and locked legend metadata that the PDF service consumes directly.
- Added contract coverage for summary labels, legend tags, overnight fixture rows, fallback fixture rows, and forbidden-field exclusion.

## Task Commits

Atomic task commits were skipped for this execution because the repository already contained extensive unrelated dirty changes. Changes were left uncommitted to avoid bundling user-owned diffs.

## Files Created/Modified

- `lib/services/payroll_pdf_matrix_export_service.dart` - dedicated matrix-driven payroll PDF builder with preview snapshot helpers for tests
- `lib/services/payroll_matrix_semantics.dart` - dataset-level summary aggregation and locked legend metadata for PDF reuse
- `lib/services/pdf_service.dart` - shared brand logo adapter plus minor style cleanup
- `test/services/payroll_pdf_matrix_export_service_test.dart` - summary, legend, overnight/fallback, and forbidden-field contract coverage
- `test/services/payroll_matrix_semantics_test.dart` - summary aggregation and locked legend ordering coverage

## Decisions Made

- Kept the matrix pages as the canonical body and limited the first page to one compact payroll-oriented summary shell.
- Reused the same colors and tag vocabulary from `PayrollMatrixSemantics` so PDF output cannot drift from the spreadsheet contract.
- Avoided any GPS or technical provenance fields entirely by constraining the PDF input to the matrix dataset and verifying the preview snapshot serialization.

## Deviations from Plan

None. The PDF path stayed matrix-driven, reused the shared semantics layer, and left legacy PDF flows untouched.

## Issues Encountered

- `dart_pdf` still prints a Helvetica Unicode support warning while generating the test document, but the targeted service tests and analyzer checks pass and the generated file contract is correct.

## User Setup Required

None.

## Next Phase Readiness

- Admin reports can now call one dedicated payroll PDF service instead of bending the legacy attendance PDF path.
- The recap tab only needs thin wiring on top of the already-tested matrix PDF contract.

---
*Phase: 59-pdf-portal-parity*
*Completed: 2026-03-28*
