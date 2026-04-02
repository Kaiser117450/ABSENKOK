---
phase: 63-export-parity-re-lock
verified: 2026-04-02T06:42:38Z
status: human_needed
score: 4/4 must-haves verified
human_verification:
  - test: "Generate spreadsheet and payroll PDF for a mixed strict/fallback date range from the recap tab"
    expected: "The spreadsheet and PDF stay compact, payroll-facing, readable, and keep the compatibility explanation understandable for operators"
    why_human: "Automated checks prove dataset parity, summary ordering, colors, and forbidden-field exclusion, but they do not judge human scanability of the generated files"
  - test: "Generate a payroll PDF with realistic production employee and outlet names, including any non-ASCII characters in live data"
    expected: "Names and labels render cleanly in the PDF with no missing glyphs or garbled text"
    why_human: "The focused PDF test passed but emitted existing Helvetica Unicode warnings and does not visually inspect rendered output"
---

# Phase 63: Export Parity Re-lock Verification Report

**Phase Goal:** Keep spreadsheet export and payroll PDF on the same corrected merged recap dataset used by admin recap.
**Verified:** 2026-04-02T06:42:38Z
**Status:** human_needed
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Spreadsheet export uses the corrected merged recap dataset and preserves compact payroll-facing output plus summary counts. | ✓ VERIFIED | `AdminReportsScreen._loadDailySummaryData()` builds `recapDataset` through `AdminPolicyRecapDatasetService`, projects `recapDataset.mergedRows` through `buildPayrollMatrix`, and stores `_payrollMatrixDataset`; `_exportPayrollSpreadsheet()` exports that dataset. Focused spreadsheet tests rebuild the same fixture pipeline and verify headers, `exportText`, summary order, colors, and forbidden-field exclusion. |
| 2 | Payroll PDF uses the same corrected merged recap dataset and preserves the same reporting meaning as admin recap and spreadsheet export. | ✓ VERIFIED | `AdminReportsScreen._exportPayrollPdf()` uses `_payrollMatrixDataset` plus `_isPayrollCompatibilityMode`; the PDF service preview derives summary metrics from `PayrollMatrixSemantics` and exposes the compatibility banner only when fallback rows exist. Focused PDF tests rebuild the same merged-row fixture pipeline and verify legend tags, summary order, compatibility copy, and output parity. |
| 3 | Forbidden technical fields remain absent from spreadsheet and PDF outputs. | ✓ VERIFIED | Both export services define `forbiddenFields`, and the focused spreadsheet/PDF tests scan workbook XML, preview JSON, and generated PDF bytes to assert those fields never appear. |
| 4 | Mixed strict/fallback regression fixtures prove parity across admin recap, spreadsheet, and payroll PDF. | ✓ VERIFIED | The shared fixture bundle encodes eight scenario IDs, including overnight, overtime, no-show, break-first, and legacy no-schedule fallback. It is reused by the merged-row parity test, spreadsheet export test, PDF export test, and recap widget test. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/fixtures/report_export_parity_fixture.dart` | Shared strict/fallback parity fixture bundle | ✓ VERIFIED | Exists, is substantive (412 lines), defines the eight locked scenario IDs, and keys expectations by `employeeId|yyyy-MM-dd`. |
| `test/services/report_export_parity_test.dart` | Canonical merged-row parity contract test | ✓ VERIFIED | Exists, is substantive, and drives `AdminPolicyRecapDatasetService.build(...)` into `buildPayrollMatrix(...)` instead of instantiating synthetic matrix datasets. |
| `lib/screens/admin/admin_reports_screen.dart` | Runtime recap/export seam on the canonical merged dataset | ✓ VERIFIED | `_policyRecapRows = recapDataset.mergedRows`, `_payrollMatrixDataset = buildPayrollMatrix(... recapDataset.mergedRows)`, and both payroll export actions consume `_payrollMatrixDataset`. |
| `lib/screens/admin/widgets/policy_recap_payroll_support_section.dart` | Reusable production payroll support card | ✓ VERIFIED | Exists, is substantive, and contains the live recap-surface CTA labels for payroll PDF and spreadsheet export. |
| `test/screens/admin/admin_reports_payroll_matrix_test.dart` | Current recap-tab widget guardrail | ✓ VERIFIED | Exists, is substantive, and uses `PolicyRecapTab`, `PolicyRecapPayrollSupportSection`, and the shared parity fixture bundle rather than the removed `PayrollRecapTab` seam. |
| `lib/services/payroll_matrix_semantics.dart` | Shared payroll label/color semantics | ✓ VERIFIED | Exists, is substantive, and centralizes summary metrics, legend tags, palette mapping, and the explicit `Hadir tanpa jadwal` compatibility label. |
| `test/services/payroll_spreadsheet_export_service_test.dart` | Spreadsheet contract coverage from the shared fixture bundle | ✓ VERIFIED | Exists, is substantive, and inspects workbook XML and `xl/styles.xml` after building the dataset from merged recap rows. |
| `test/services/payroll_pdf_matrix_export_service_test.dart` | PDF contract coverage from the shared fixture bundle | ✓ VERIFIED | Exists, is substantive, and verifies preview/file behavior, compatibility copy, legend tags, summary order, and forbidden-field exclusion from the same merged recap fixture pipeline. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/screens/admin/admin_reports_screen.dart` | `lib/services/admin_policy_recap_dataset_service.dart` | `_loadDailySummaryData()` | ✓ WIRED | The screen builds `recapDataset` from employees, strict recap rows, attendance logs, outlet ID, outlet name, and outlet mode. |
| `lib/screens/admin/admin_reports_screen.dart` | `lib/services/payroll_matrix_builder.dart` | `_loadDailySummaryData()` | ✓ WIRED | The screen calls `buildPayrollMatrix(... recapRows: recapDataset.mergedRows)` before storing `_payrollMatrixDataset`. |
| `lib/screens/admin/admin_reports_screen.dart` | `lib/services/payroll_spreadsheet_export_service.dart` | `_exportPayrollSpreadsheet()` | ✓ WIRED | The spreadsheet export action uses `_payrollMatrixDataset` built from the merged recap rows. |
| `lib/screens/admin/admin_reports_screen.dart` | `lib/services/payroll_pdf_matrix_export_service.dart` | `_exportPayrollPdf()` | ✓ WIRED | The PDF export action uses `_payrollMatrixDataset` and passes `_isPayrollCompatibilityMode` through to the real export service. |
| `lib/screens/admin/admin_reports_screen.dart` | `lib/screens/admin/widgets/policy_recap_payroll_support_section.dart` | `_buildPayrollSupportSection()` | ✓ WIRED | The live recap surface renders the extracted production payroll-support widget with the real CTA callbacks and preview section. |
| `test/services/report_export_parity_test.dart` | `lib/services/payroll_matrix_builder.dart` | direct parity contract | ✓ WIRED | The canonical parity test projects merged recap rows through `buildPayrollMatrix(...)`. |
| `test/services/payroll_spreadsheet_export_service_test.dart` | `test/fixtures/report_export_parity_fixture.dart` | `_buildParitySpreadsheetContext()` | ✓ WIRED | The workbook contract test rebuilds its dataset from the shared parity fixture bundle via `AdminPolicyRecapDatasetService` and `buildPayrollMatrix`. |
| `test/services/payroll_pdf_matrix_export_service_test.dart` | `test/fixtures/report_export_parity_fixture.dart` | `_buildParityPdfContext()` | ✓ WIRED | The PDF contract test rebuilds its dataset from the shared parity fixture bundle via `AdminPolicyRecapDatasetService` and `buildPayrollMatrix`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `lib/screens/admin/admin_reports_screen.dart` | `_policyRecapRows` | `_attendancePolicyRecapService.fetchAdminSchedulePolicyRecap(...)` -> `_adminPolicyRecapDatasetService.build(...)` | Yes - strict rows and synthesized fallback rows are merged, sorted, and stored in state for the recap UI. | ✓ FLOWING |
| `lib/screens/admin/admin_reports_screen.dart` | `_payrollMatrixDataset` | `buildPayrollMatrix(... recapRows: recapDataset.mergedRows)` | Yes - the payroll matrix is built directly from the same merged rows stored in `_policyRecapRows`. | ✓ FLOWING |
| `test/services/report_export_parity_test.dart` | `payrollDataset` | `buildReportExportParityFixtureBundle()` -> `AdminPolicyRecapDatasetService.build(...)` -> `buildPayrollMatrix(...)` | Yes - the parity contract test uses the real mixed strict/fallback fixture bundle rather than static matrix literals. | ✓ FLOWING |
| `test/services/payroll_spreadsheet_export_service_test.dart` | `context.dataset` | `buildReportExportParityFixtureBundle()` -> `AdminPolicyRecapDatasetService.build(...)` -> `buildPayrollMatrix(...)` | Yes - the spreadsheet test reaches real workbook bytes from the shared merged recap fixture pipeline. | ✓ FLOWING |
| `test/services/payroll_pdf_matrix_export_service_test.dart` | `context.dataset` | `buildReportExportParityFixtureBundle()` -> `AdminPolicyRecapDatasetService.build(...)` -> `buildPayrollMatrix(...)` | Yes - the PDF preview/file test reaches real preview data and PDF bytes from the shared merged recap fixture pipeline. | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Shared recap/export parity suite | `Remove-Item build\unit_test_assets ...; Remove-Item build\native_assets ...; C:\flutter\bin\flutter.bat test test/services/report_export_parity_test.dart test/services/payroll_spreadsheet_export_service_test.dart test/services/payroll_pdf_matrix_export_service_test.dart test/screens/admin/admin_reports_payroll_matrix_test.dart test/screens/admin/rekap_harian_test.dart` | `9 tests passed`; merged-row parity, spreadsheet export, PDF export, recap widget guardrails, compatibility messaging, and forbidden-field checks all passed. | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `REPORT-04` | `63-01-PLAN.md`, `63-02-PLAN.md` | Spreadsheet export uses the same corrected merged recap dataset as admin recap while preserving compact payroll-facing fields, current color semantics, and per-employee summary counts. | ✓ SATISFIED | Runtime recap/export wiring shares `recapDataset.mergedRows` -> `buildPayrollMatrix(...)`; spreadsheet contract tests rebuild that same pipeline, verify `Rekap Payroll`, compact cell text, `styles.xml` color semantics, and ordered summary headers. |
| `REPORT-05` | `63-01-PLAN.md`, `63-02-PLAN.md` | Payroll PDF uses the same corrected merged recap dataset as admin recap and spreadsheet export without reintroducing technical scan fields or a second reporting interpretation. | ✓ SATISFIED | Runtime PDF export uses `_payrollMatrixDataset` and `_isPayrollCompatibilityMode`; the PDF contract tests rebuild the same fixture pipeline and verify compatibility banner, legend tags, summary order, and forbidden-field exclusion in both preview and generated file. |
| Phase 63 orphaned requirements | `REQUIREMENTS.md` | Requirements mapped to Phase 63 but not claimed by any plan | ✓ NONE | `REQUIREMENTS.md` maps only `REPORT-04` and `REPORT-05` to Phase 63, and both IDs appear in both plan frontmatters. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| None | - | Targeted stub/placeholder scan found no blocker anti-patterns in Phase 63 files. | - | Only legitimate null initializers and test placeholders matched the generic grep patterns; no stale `PayrollRecapTab`, no old recap helper seam, and no TODO/FIXME placeholders remained. |

### Human Verification Required

### 1. Payroll Artifact Scanability

**Test:** Generate the spreadsheet and payroll PDF from the recap tab for a date range that includes strict, overtime, no-show, overnight, and no-schedule fallback rows.
**Expected:** Both artifacts stay compact, payroll-facing, and easy for operators to scan; summary columns remain readable; the compatibility banner is understandable.
**Why human:** Automated tests prove parity, summary ordering, colors, and forbidden-field exclusion, but they do not judge the human readability of the generated files.

### 2. PDF Text Rendering On Live Names

**Test:** Generate a payroll PDF with realistic production employee and outlet names, especially any names containing non-ASCII characters.
**Expected:** The PDF renders names and labels cleanly with no missing glyphs or corrupted text.
**Why human:** The focused PDF test passed, but `dart_pdf` emitted existing Helvetica Unicode warnings and the tests do not visually inspect rendered typography.

### Gaps Summary

No automated implementation gaps were found. The Phase 63 runtime seam is wired to one merged recap dataset, the shared parity fixtures lock spreadsheet/PDF/admin recap meaning onto that same dataset, and the focused Flutter verification bundle passes cleanly. Status remains `human_needed` because final operator-facing spreadsheet/PDF scanability and PDF text rendering still require human review.

---

_Verified: 2026-04-02T06:42:38Z_
_Verifier: Codex (gsd-verifier)_
