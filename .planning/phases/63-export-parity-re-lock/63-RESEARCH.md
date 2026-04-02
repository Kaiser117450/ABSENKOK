# Phase 63: Export Parity Re-lock - Research

**Researched:** 2026-04-02
**Domain:** Flutter admin reporting export parity on the canonical merged recap dataset
**Confidence:** HIGH

## User Constraints

No phase-local `63-CONTEXT.md` exists in `.planning/phases/63-export-parity-re-lock/`.

Locked from the phase brief, milestone requirements, and shipped milestone guardrails:

- Spreadsheet export must use the corrected merged recap dataset already trusted by admin recap.
- Spreadsheet output must stay compact and payroll-facing while preserving summary counts.
- Payroll PDF must use the same corrected merged recap dataset and preserve the same reporting meaning as admin recap and spreadsheet export.
- Forbidden technical scan fields must remain absent from spreadsheet and PDF outputs.
- Mixed strict and fallback fixtures must prove parity across admin recap, spreadsheet, and payroll PDF.
- Phase 63 must not reopen Phase 61 recap recovery semantics or Phase 62 schedule-gap notice behavior.

## Project Constraints (from CLAUDE.md)

- No repo `CLAUDE.md` exists.
- No repo `AGENTS.md` exists.
- Local `.codex/skills/` and `.agents/skills/` contain generic GSD workflow skills plus Sentry helpers only; they do not add repo-specific implementation rules for this phase.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REPORT-04 | Spreadsheet export uses the same corrected merged recap dataset as admin Rekap Harian while preserving compact payroll-facing fields, current color semantics, and per-employee summary counts. | Current production wiring already builds `_payrollMatrixDataset` from `AdminPolicyRecapDatasetService.build(...).mergedRows`, but the parity tests do not verify that chain end-to-end. Phase 63 should relock it with shared mixed-fixture contract tests, not redesign the export service. |
| REPORT-05 | Payroll PDF uses the same corrected merged recap dataset as admin Rekap Harian and spreadsheet export without reintroducing technical scan fields or a second reporting interpretation. | `PayrollPdfMatrixExportService` already consumes `PayrollMatrixDataset` plus `isCompatibilityMode`, but its tests still use synthetic matrix rows instead of admin recap-derived fixtures. Phase 63 should add cross-surface fixtures and repair the broken report-screen test seam. |

## Summary

Production code is already much closer to the Phase 63 goal than the roadmap title suggests. `AdminReportsScreen._loadDailySummaryData()` now builds the canonical merged row set through `AdminPolicyRecapDatasetService`, then projects that merged row set into `_payrollMatrixDataset` with `buildPayrollMatrix(...)`, and both recap-tab export actions already consume that matrix dataset. In other words, the active runtime path is already `mergedRows -> payroll matrix -> spreadsheet/PDF`.

The real gap is not missing business logic. The gap is that the parity guardrails are stale. The old top-level `buildPayrollRecapDatasetWithCompatibility(...)` helper still exists in `admin_reports_screen.dart`, but it is no longer used by the screen. The only remaining consumer is `test/screens/admin/admin_reports_payroll_matrix_test.dart`, and that file currently fails to compile because it still references removed `PayrollRecapTab`. The export service tests also build hand-authored `PayrollMatrixDataset` objects directly, so they prove file formatting and forbidden-field exclusion, but they do not prove parity with the admin recap dataset source.

Phase 63 should therefore be planned as a test-first re-lock plus light seam cleanup:

1. keep the current production export pipeline,
2. replace the broken test seam with the actual Phase 61/62 recap pipeline,
3. introduce shared mixed strict/fallback fixtures that flow through admin recap rows and both export services, and
4. preserve the shipped compact payroll contract, summary-column order, color semantics, and forbidden-field boundary.

**Primary recommendation:** plan Phase 63 as a parity-hardening phase, not a recap-rules phase. Reuse `AdminPolicyRecapDatasetService -> buildPayrollMatrix -> PayrollMatrixSemantics -> export services`, repair the broken validation seam, and add shared mixed-fixture contract tests that start from merged recap rows instead of synthetic matrix cells.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `AdminPolicyRecapDatasetService` | repo current | Canonical merged strict-plus-fallback `AttendancePolicyRecapDay` rows | This is the Phase 61 source of truth for corrected admin recap semantics. |
| `buildPayrollMatrix` + `PayrollMatrixDataset` | repo current | Compact payroll-facing matrix projection from merged recap rows | This is the current runtime seam used by recap-tab spreadsheet/PDF actions. |
| `PayrollMatrixSemantics` | repo current | Shared short tags, severity colors, primary labels, and summary counts | Both salary-facing exports already depend on this contract; Phase 63 should not fork it. |
| `syncfusion_flutter_xlsio` | repo pinned `29.2.11`; latest docs observed `33.1.45`/package `33.1.46` on 2026-04-02 | Real `.xlsx` workbook generation with freeze panes and cell styling | Already shipped in repo; supports the locked workbook shape without phase-scoped dependency churn. |
| `pdf` + `printing` | repo pinned `3.11.3` + `5.14.2`; latest package pages observed `3.12.0` + `5.14.3` on 2026-04-02 | Payroll PDF document generation and share flow | Already shipped in repo; Phase 63 should keep the current PDF stack and avoid upgrade risk. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `excel` | repo dev dependency `4.0.6` | Read generated workbook bytes in tests | Use only for workbook contract assertions, not production export. |
| `flutter_test` | Flutter 3.41.1 / Dart 3.11.0 | Service and widget regression coverage | Existing test framework for recap, export, and admin screen logic. |
| `59-PARITY-FIXTURES.md` | planning artifact | Canonical overnight strict + legacy fallback parity scenarios | Use as the seed for shared code-level fixtures. |
| `60-ACCEPTANCE-FIXTURES.md` | planning artifact | Expected payroll meaning for normal, overtime, overnight, break-first, and no-show scenarios | Use to extend fixture coverage without inventing new payroll semantics. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Current runtime chain `mergedRows -> buildPayrollMatrix -> export service` | Feed export services directly from raw `AttendancePolicyRecapDay` rows | Unnecessary new projection logic and a new drift surface. |
| Shared mixed-fixture builders derived from recap rows | Keep hand-authored `PayrollMatrixDataset` objects in export tests | Faster to write, but it does not prove REPORT-04/REPORT-05 parity. |
| Keep pinned package versions | Upgrade `syncfusion_flutter_xlsio`, `pdf`, or `printing` inside this phase | Off-scope version churn with no parity benefit. |
| Repair or replace the broken screen test seam | Leave `admin_reports_payroll_matrix_test.dart` broken and rely on service tests only | Loses coverage for the recap-tab export affordance and lets drift hide in screen composition. |

**Installation:**
```bash
flutter pub get
```

**Version verification:** verified locally from `pubspec.lock` and current official package pages on 2026-04-02. The repo is intentionally behind the latest published package versions; do not couple Phase 63 to package upgrades.

## Architecture Patterns

### Recommended Project Structure

```text
lib/services/
├── admin_policy_recap_dataset_service.dart
├── payroll_matrix_builder.dart
├── payroll_matrix_semantics.dart
├── payroll_spreadsheet_export_service.dart
└── payroll_pdf_matrix_export_service.dart

lib/screens/admin/
└── admin_reports_screen.dart

test/fixtures/
└── report_export_parity_fixture.dart
   # new shared strict/fallback scenario builders for admin recap + exports

test/services/
├── admin_policy_recap_dataset_service_test.dart
├── payroll_spreadsheet_export_service_test.dart
├── payroll_pdf_matrix_export_service_test.dart
└── report_export_parity_test.dart
   # new end-to-end parity contract test

test/screens/admin/
├── rekap_harian_test.dart
└── admin_reports_payroll_matrix_test.dart
   # repair or replace current broken seam
```

### Pattern 1: Use one canonical source chain and nothing else

**What:** all salary-facing export paths should continue to derive from:

1. `AdminPolicyRecapDatasetService.build(...)`
2. `buildPayrollMatrix(..., recapRows: recapDataset.mergedRows)`
3. `PayrollMatrixSemantics`
4. spreadsheet/PDF export services

**Why:** that is the actual Phase 61+62 production seam. Phase 63 should harden it, not invent a new reporting chain.

### Pattern 2: Treat admin recap and export parity as "same meaning, different projection"

**What:** admin recap is row-first and verbose; spreadsheet/PDF are compact payroll projections.

**Compare for parity:**
- logical date
- primary status meaning
- severity family / color family
- short tags
- summary counts
- compatibility-mode truth

**Do not compare for parity:**
- identical literal widget text
- identical layout
- identical time/status formatting density

**Why:** the product intentionally uses different surfaces for operations versus payroll evidence.

### Pattern 3: Put mixed strict/fallback fixtures in code, not only in markdown

**What:** create one shared fixture builder that starts from:
- employees,
- attendance logs,
- strict recap rows,
- outlet operating mode,
- expected admin recap meaning,
- expected matrix cell tags/colors/counts.

Then reuse that builder in:
- `rekap_harian_test.dart`
- spreadsheet export contract tests
- payroll PDF preview/file tests
- any repaired recap-tab support test

**Why:** current export tests verify formatting, but they do not verify that the formatted outputs came from the corrected merged recap source.

### Pattern 4: Fix the validation seam before adding more assertions

**What:** `test/screens/admin/admin_reports_payroll_matrix_test.dart` currently targets removed `PayrollRecapTab` and fails to compile. Either:
- rewrite it around the real `PolicyRecapTab` plus the actual payroll support section composition, or
- extract a small public payroll-support widget and target that instead.

**Why:** broken tests are not guardrails. Phase 63 needs a real screen-level parity check again before it can claim re-lock.

### Pattern 5: Preserve the shipped payroll output contract exactly

**Locked output behavior to preserve:**
- spreadsheet sheet name `Rekap Payroll`
- summary column order: `Terlambat`, `Kurang Jam`, `Break Lebih`, `Tidak Hadir`, `Lembur`
- compact day-cell text with optional newline + tags
- forbidden fields absent from workbook XML and PDF preview payloads
- compatibility mode passed into the payroll PDF when fallback rows were injected

**Why:** REPORT-04 and REPORT-05 are parity requirements, not redesign requirements.

### Code Example: The current production export seam

```dart
// Source: lib/screens/admin/admin_reports_screen.dart
final recapDataset = _adminPolicyRecapDatasetService.build(
  employees: employees,
  strictRows: recapResult.rows,
  attendanceLogs: allRows.map((row) => row.log),
  outletId: outletId,
  outletName: payrollOutletContext.outletName,
  outletOperatingMode: payrollOutletContext.operatingMode,
  now: DateTime.now(),
);

final payrollDataset = buildPayrollMatrix(
  startDate: _startDate,
  endDate: _endDate,
  employees: employees,
  recapRows: recapDataset.mergedRows,
);

await _payrollSpreadsheetExportService.exportPayrollSpreadsheet(
  outletName: outletName,
  startDate: _startDate,
  endDate: _endDate,
  dataset: payrollDataset,
);

await _payrollPdfMatrixExportService.buildPayrollPdf(
  dataset: payrollDataset,
  outletName: outletName,
  startDate: _startDate,
  endDate: _endDate,
  isCompatibilityMode: recapDataset.isCompatibilityMode,
);
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Corrected merged recap source | A second merge helper in tests or widgets | `AdminPolicyRecapDatasetService` | Phase 61 already established the canonical merge contract. |
| Export parity fixtures | Hand-written `PayrollMatrixDataset` rows only | Shared fixture builder that flows through merged recap rows | Manual matrix cells do not prove admin/export parity. |
| Tag/color/count logic | Another label or palette map in PDF/spreadsheet tests | `PayrollMatrixSemantics` | This is the current contract for short tags, colors, and summary counts. |
| Legacy export semantics | `DailySummary` or per-scan PDF/CSV branches | Recap-tab payroll export services only | Legacy audit paths are out of scope and can reintroduce a second reporting interpretation. |
| Package churn | Mid-phase dependency upgrades | Existing pinned repo versions | This phase is about parity lock, not tooling refresh. |

**Key insight:** the production export code already follows the right data source. Phase 63 should lock that fact in tests and remove stale seams that make the codebase look less aligned than it is.

## Common Pitfalls

### Pitfall 1: Trusting a broken test file as parity evidence

**What goes wrong:** the planner assumes report-screen parity coverage already exists because `admin_reports_payroll_matrix_test.dart` is present.
**Why it happens:** the file still references removed `PayrollRecapTab`.
**How to avoid:** treat this as a Wave 0 repair item, not as usable baseline coverage.
**Warning signs:** `flutter test test/screens/admin/admin_reports_payroll_matrix_test.dart` fails with `Method not found: 'PayrollRecapTab'`.

### Pitfall 2: Proving only file formatting, not dataset parity

**What goes wrong:** spreadsheet/PDF tests pass even if the recap-to-matrix projection drifts away from admin recap semantics.
**Why it happens:** current export service tests use hard-coded `PayrollMatrixDataset` objects.
**How to avoid:** build export inputs from shared strict/fallback recap fixtures through `AdminPolicyRecapDatasetService` and `buildPayrollMatrix`.
**Warning signs:** export tests never mention `AttendancePolicyRecapDay`, `AttendanceLog`, or `AdminPolicyRecapDatasetService`.

### Pitfall 3: Comparing exact UI copy instead of reporting meaning

**What goes wrong:** planners or tests over-constrain admin recap row text to match compact export cells exactly.
**Why it happens:** parity is misread as identical presentation rather than identical meaning.
**How to avoid:** compare logical day, primary outcome/severity, short tags, compatibility truth, and summary counts.
**Warning signs:** tests fail because admin recap says `Terlambat` while spreadsheet/PDF shows `07:12 / 17:05` plus `TLT`.

### Pitfall 4: Reopening stale legacy paths

**What goes wrong:** Phase 63 starts editing `_computeDailySummaries()`, legacy recap CSV/PDF branches, or per-scan audit exports.
**Why it happens:** those older paths still live in `admin_reports_screen.dart`.
**How to avoid:** keep scope on recap-tab spreadsheet and payroll PDF only.
**Warning signs:** plan tasks mention `DailySummary`, legacy daily PDF rows, or GPS/per-scan audit columns.

### Pitfall 5: Ignoring the Windows Flutter test crash

**What goes wrong:** repeated `flutter test` invocations fail with a `NativeAssetsManifest.json` copy crash and the phase looks flaky even when code is correct.
**Why it happens:** this workspace can leave `build/unit_test_assets` and `build/native_assets` in a state that breaks subsequent runs.
**How to avoid:** clean those generated directories before focused test batches and prefer one combined test command per validation cycle.
**Warning signs:** `PathExistsException` mentioning `build\unit_test_assets\NativeAssetsManifest.json`.

### Pitfall 6: Coupling parity work to package upgrades

**What goes wrong:** the phase expands into `syncfusion_flutter_xlsio` or `pdf` upgrades because official package pages show newer releases.
**Why it happens:** version drift looks tempting during research.
**How to avoid:** keep the current pinned packages for Phase 63 and treat upgrades as a separate spike.
**Warning signs:** plan tasks add `flutter pub upgrade` without a parity-specific bug forcing it.

## Code Examples

Verified patterns from the current repo and official docs:

### Current workbook freeze-pane pattern

```dart
// Source: lib/services/payroll_spreadsheet_export_service.dart
sheet.getRangeByName('C2').freezePanes();
```

This matches the official XlsIO `Range.freezePanes()` API, which keeps selected rows and columns visible while scrolling.

### Shared compact export text contract

```dart
// Source: lib/models/payroll_matrix_day_cell.dart
String get exportText {
  if (secondaryTags.isEmpty) {
    return primaryLabel;
  }
  return '$primaryLabel\n${secondaryTags.join(' ')}';
}
```

### Summary-count order is already locked in one model

```dart
// Source: lib/models/payroll_matrix_row.dart
static const List<String> summaryLabels = <String>[
  'Terlambat',
  'Kurang Jam',
  'Break Lebih',
  'Tidak Hadir',
  'Lembur',
];
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Screen-local merge helper plus matrix-first recap assumptions in tests | `AdminPolicyRecapDatasetService` feeds a row-first admin recap surface, and the export path projects from `mergedRows` into `_payrollMatrixDataset` | Phase 61 on 2026-04-01 | Phase 63 should align tests and parity fixtures with the real service seam. |
| Export contract tests built only from synthetic matrix rows | Recommended Phase 63 approach: build fixtures from strict + fallback recap inputs before exporting | Planning target for Phase 63 | This is the missing guardrail for REPORT-04 and REPORT-05. |

**Deprecated/outdated:**

- `PayrollRecapTab` references in `test/screens/admin/admin_reports_payroll_matrix_test.dart` are outdated and currently break compilation.
- Top-level `PayrollRecapDatasetResult` and `buildPayrollRecapDatasetWithCompatibility(...)` in `admin_reports_screen.dart` are outdated relative to `AdminPolicyRecapDatasetService`; they should not remain the main parity evidence seam.

## Open Questions

1. **Should Phase 63 delete the stale top-level recap-dataset helper, or just stop testing it?**
   - What we know: it is no longer used by the active screen path.
   - What's unclear: whether another unscanned future phase still expects that symbol for ad hoc tooling.
   - Recommendation: prefer removal if no production caller remains; otherwise mark it as legacy and stop treating it as parity evidence.

2. **Should the repaired screen-level parity test target `PolicyRecapTab` composition directly, or should the payroll support card be extracted into a dedicated widget first?**
   - What we know: the current broken file fails because it targets a removed widget.
   - What's unclear: whether extraction reduces test scaffolding enough to justify a tiny refactor.
   - Recommendation: extract only if it makes the test seam materially cleaner; otherwise rewrite the test around the current screen composition and keep production behavior unchanged.

3. **Where should shared mixed-fixture builders live?**
   - What we know: Phase 59 and 60 already define the right scenarios in markdown, but the repo lacks a shared code fixture source.
   - What's unclear: whether this repo prefers `test/fixtures/` or `test/support/`.
   - Recommendation: use one shared builder file under `test/fixtures/` and have both service and widget tests import it.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All implementation and validation work | ✓ | 3.41.1 | — |
| Dart SDK | Pure service logic and tests | ✓ | 3.11.0 | — |
| `syncfusion_flutter_xlsio` | Spreadsheet export implementation | ✓ | repo pinned 29.2.11 | — |
| `pdf` | Payroll PDF generation | ✓ | repo pinned 3.11.3 | — |
| `printing` | PDF share/printing integration | ✓ | repo pinned 5.14.2 | — |
| `excel` | Workbook contract assertions in tests | ✓ | repo dev 4.0.6 | — |
| Android cmdline-tools | Android device builds only | ✗ | — | Not needed for this phase's Flutter tests |
| Visual Studio C++ workload | Windows desktop builds only | ✗ | — | Not needed for this phase's Flutter tests |

**Missing dependencies with no fallback:**
- None for Phase 63 implementation and focused validation.

**Missing dependencies with fallback:**
- Repeated `flutter test` runs can crash on Windows due to stale native-assets build output; clean `build/unit_test_assets` and `build/native_assets` first, then run tests in one batch.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` on Flutter 3.41.1 / Dart 3.11.0 |
| Config file | `analysis_options.yaml` |
| Quick run command | `powershell -Command "Remove-Item -LiteralPath build\\unit_test_assets -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath build\\native_assets -Recurse -Force -ErrorAction SilentlyContinue; C:\\flutter\\bin\\flutter.bat test test/services/admin_policy_recap_dataset_service_test.dart test/services/payroll_spreadsheet_export_service_test.dart test/services/payroll_pdf_matrix_export_service_test.dart test/screens/admin/rekap_harian_test.dart"` |
| Full suite command | `powershell -Command "Remove-Item -LiteralPath build\\unit_test_assets -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath build\\native_assets -Recurse -Force -ErrorAction SilentlyContinue; C:\\flutter\\bin\\flutter.bat test"` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REPORT-04 | Spreadsheet export is derived from the same merged recap rows as admin recap, including mixed strict/fallback cases and summary counts | unit/contract | `C:\flutter\bin\flutter.bat test test/services/report_export_parity_test.dart test/services/payroll_spreadsheet_export_service_test.dart` | ❌ Wave 0 / ✅ partial |
| REPORT-05 | Payroll PDF is derived from the same merged recap rows as admin recap and preserves forbidden-field exclusions | unit/contract | `C:\flutter\bin\flutter.bat test test/services/report_export_parity_test.dart test/services/payroll_pdf_matrix_export_service_test.dart` | ❌ Wave 0 / ✅ partial |
| REPORT-04, REPORT-05 | Admin recap meaning, spreadsheet export, and payroll PDF stay aligned for shared overnight and no-schedule fallback fixtures | widget + unit | `C:\flutter\bin\flutter.bat test test/screens/admin/rekap_harian_test.dart test/services/report_export_parity_test.dart` | ✅ / ❌ Wave 0 |
| REPORT-04, REPORT-05 | Recap-tab payroll export affordance remains available on the current screen composition | widget | `C:\flutter\bin\flutter.bat test test/screens/admin/admin_reports_payroll_matrix_test.dart` | ✅ but broken baseline |

### Sampling Rate

- **Per task commit:** run the task-local command plus the cleanup pre-step.
- **Per wave merge:** run the quick run command.
- **Phase gate:** full `flutter test` batch after cleanup before `/gsd:verify-work`.

### Wave 0 Gaps

- Repair or replace `test/screens/admin/admin_reports_payroll_matrix_test.dart`; it currently fails to compile because `PayrollRecapTab` no longer exists.
- Add `test/fixtures/report_export_parity_fixture.dart` so admin recap, spreadsheet, and PDF tests consume the same mixed strict/fallback inputs.
- Add `test/services/report_export_parity_test.dart` (or equivalent) that derives export inputs from `AdminPolicyRecapDatasetService` and `buildPayrollMatrix`, then asserts parity outcomes across admin recap expectations, spreadsheet XML, and payroll PDF preview data.
- Decide whether to remove or fully deprecate the unused top-level `buildPayrollRecapDatasetWithCompatibility(...)` helper in `admin_reports_screen.dart`.
- Normalize validation commands to pre-clean `build/unit_test_assets` and `build/native_assets` before focused Flutter test runs on this machine.

## Sources

### Primary (HIGH confidence)

- [admin_reports_screen.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/screens/admin/admin_reports_screen.dart) - current recap load path, recap-tab export buttons, stale top-level helper, and current `PolicyRecapTab` composition
- [admin_policy_recap_dataset_service.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/services/admin_policy_recap_dataset_service.dart) - canonical merged recap-row service
- [payroll_matrix_builder.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/services/payroll_matrix_builder.dart) - current merged-row to payroll-matrix projection
- [payroll_matrix_semantics.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/services/payroll_matrix_semantics.dart) - tag/color/summary-count contract
- [payroll_spreadsheet_export_service.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/services/payroll_spreadsheet_export_service.dart) - current workbook contract and forbidden-field list
- [payroll_pdf_matrix_export_service.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/services/payroll_pdf_matrix_export_service.dart) - current payroll PDF contract and forbidden-field list
- [payroll_matrix_day_cell.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/models/payroll_matrix_day_cell.dart) - compact export text contract
- [payroll_matrix_row.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/models/payroll_matrix_row.dart) - locked summary label order
- [admin_policy_recap_dataset_service_test.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/test/services/admin_policy_recap_dataset_service_test.dart) - strict/fallback merge and overnight baseline coverage
- [payroll_spreadsheet_export_service_test.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/test/services/payroll_spreadsheet_export_service_test.dart) - current workbook contract coverage
- [payroll_pdf_matrix_export_service_test.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/test/services/payroll_pdf_matrix_export_service_test.dart) - current PDF preview/file contract coverage
- [rekap_harian_test.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/test/screens/admin/rekap_harian_test.dart) - current row-first admin recap widget coverage
- [61-02-SUMMARY.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/phases/61-recap-semantics-recovery/61-02-SUMMARY.md) - locked row-first recap direction after Phase 61
- [62-02-SUMMARY.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/phases/62-schedule-gap-notices/62-02-SUMMARY.md) - confirms Phase 63 should focus only on export parity

### Secondary (MEDIUM confidence)

- [58-RESEARCH.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/phases/58-payroll-matrix-spreadsheet-export/58-RESEARCH.md) - original payroll matrix + spreadsheet contract
- [58.1-RESEARCH.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/phases/58.1-schedule-ux-polish-and-legacy-payroll-fallback/58.1-RESEARCH.md) - legacy fallback baseline
- [59-RESEARCH.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/phases/59-pdf-portal-parity/59-RESEARCH.md) - payroll PDF parity contract
- [59-PARITY-FIXTURES.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/phases/59-pdf-portal-parity/59-PARITY-FIXTURES.md) - overnight strict and legacy fallback parity scenarios
- [60-ACCEPTANCE-FIXTURES.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/phases/60-rollout-payroll-acceptance/60-ACCEPTANCE-FIXTURES.md) - accepted parity scenario expectations across artifacts

### External (official docs)

- [syncfusion_flutter_xlsio package](https://pub.dev/packages/syncfusion_flutter_xlsio) - current package metadata and latest published version observed during research
- [syncfusion_flutter_xlsio license](https://pub.dev/packages/syncfusion_flutter_xlsio/license) - official licensing terms and current package metadata
- [Range class docs](https://pub.dev/documentation/syncfusion_flutter_xlsio/latest/xlsio/Range-class.html) - official `freezePanes()` API documentation
- [pdf package](https://pub.dev/packages/pdf) - current package metadata and widget-based PDF generation docs
- [printing package](https://pub.dev/packages/printing) - current package metadata and print/share integration docs
- [Flutter unit testing docs](https://docs.flutter.dev/cookbook/testing/unit/introduction) - official `flutter_test` guidance and test-folder conventions

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - current repo code, lockfile, and official package docs all agree on the shipped implementation path.
- Architecture: HIGH - the production seam is explicit in `AdminReportsScreen`, and the stale helper/test drift is directly observable.
- Pitfalls: HIGH - the broken screen test and Windows native-assets crash were reproduced locally, not inferred.

**Research date:** 2026-04-02
**Valid until:** 2026-05-02
