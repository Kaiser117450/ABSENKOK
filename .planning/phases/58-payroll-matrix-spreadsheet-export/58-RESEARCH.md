# Phase 58: Payroll Matrix & Spreadsheet Export - Research

**Researched:** 2026-03-27
**Domain:** payroll-ready attendance matrix UI and real `.xlsx` workbook export on top of the Phase 57 strict recap engine
**Confidence:** MEDIUM-HIGH

<user_constraints>
## User Constraints (from CONTEXT.md and UI-SPEC.md)

### Locked Decisions
- Rekap Harian must become a payroll-facing employee-by-date matrix, not remain a flat list of recap cards.
- The workbook output must be one real `.xlsx` file, one outlet per export, with one main matrix sheet named `Rekap Payroll`.
- Matrix rows must default to the full active outlet roster, grouped by contract (`FULLTIME`, `PARTTIME`) and then sorted by employee name.
- Archived employees must stay out of the Phase 58 matrix and workbook even if the selected range contains older attendance data.
- Each day cell must show compact `masuk/pulang` content when available, otherwise an explicit label such as `Libur`, `Izin`, `Sakit`, `Cuti`, `Tidak Hadir`, or `Hadir Tanpa Jadwal`.
- Cell fill must follow the strict primary status from Phase 57, while secondary strict signals stay visible as compact inline tags.
- Summary columns are fixed to `Terlambat`, `Kurang Jam`, `Break Lebih`, `Tidak Hadir`, and `Lembur`, in that order.
- The admin matrix is read-only in this phase.
- The admin surface must keep employee identity pinned on the left and summary totals visibly sticky on wide date ranges.
- Exports must stay salary-facing and must not include GPS, latitude/longitude, queue provenance, or other low-signal technical scan data.

### Claude's Discretion
- Exact payroll matrix DTO shape, as long as one shared contract drives both UI and workbook export.
- Exact sticky-summary implementation, as long as the right-side summary stays readable on wide ranges.
- Exact `.xlsx` package choice, provided it can produce a real workbook with the locked formatting behavior.
- Exact short-tag implementation, as long as tags remain compact and payroll-facing.

### Deferred Ideas (OUT OF SCOPE)
- PDF parity and portal parity remain Phase 59 work.
- Multi-outlet workbook export is deferred.
- Interactive drilldown or per-cell correction flows are deferred.
- Payroll amount calculation and approval workflows remain out of scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| `REPORT-01` | Rekap Harian admin view can render a payroll-ready matrix with employees on the left, selected dates across the page, and each day cell showing compact masuk/pulang information plus the correct evaluation color for that day. | The current recap stack already exposes one strict row per employee/logical day. Phase 58 needs a roster-first matrix builder, a pinned-grid UI, and one shared cell-semantics helper instead of re-deriving payroll meaning in widgets. |
| `REPORT-02` | Spreadsheet export replaces payroll recap CSV export and preserves color-coded day cells plus per-employee summary counts for late arrival, short work, excess break, overtime, and absence across the selected range. | The repo has CSV/PDF export patterns but no workbook writer. Phase 58 needs a dedicated `.xlsx` service, one source of truth for colors/tags/summary counts, and regression tests that read the generated workbook contract. |
</phase_requirements>

## Summary

Phase 58 should not extend the existing recap card list incrementally. The current Phase 57 stack already solved the hard business logic by returning strict payroll signals per employee and logical date; the missing work is now presentation and export shape. The safest path is to introduce one shared payroll-matrix contract that:

1. starts from the active employee roster for the selected outlet,
2. indexes Phase 57 strict recap rows by employee plus logical date,
3. computes row summaries from those strict rows,
4. feeds both the new admin matrix UI and the workbook generator, and
5. centralizes color, label, and short-tag decisions so UI and export cannot drift.

The phase naturally breaks into four plan areas:

1. shared matrix models, roster merge, and payroll cell semantics,
2. pinned-grid admin matrix UI,
3. dedicated spreadsheet export service, and
4. final admin-screen wiring plus regression coverage.

## Existing Code Findings

### 1. `AdminReportsScreen` still owns all report orchestration and export state
- `lib/screens/admin/admin_reports_screen.dart` loads outlets, handles the `Per Scan` and `Rekap Harian` tabs, owns the export toolbar, and currently exposes only `CSV` and `PDF`.
- `_buildRekapHarian()` still renders a filtered `ListView` of `PolicyRecapTile`, not a matrix.
- `_exportCsv()` writes recap CSV or per-scan CSV directly from widget state, and `_exportPdf()` also runs from the same screen.

**Implication:** Phase 58 should keep `AdminReportsScreen` as the integration shell, but it should stop owning workbook creation logic directly. The screen should orchestrate filters, loading, and share states, while new matrix/export services stay outside widget state.

### 2. The strict recap service already exposes the right day-level payroll inputs
- `lib/services/attendance_policy_recap_service.dart` returns typed `AttendancePolicyRecapDay` rows from the canonical `get_admin_schedule_policy_recap` RPC.
- `lib/models/attendance_policy_recap_day.dart` already includes:
  - employee identity
  - outlet identity
  - logical date
  - primary status and severity
  - detail signals and notes
  - net work, break, overtime, short-work, and excess-break minutes
  - explicit non-time statuses such as `sakit`, `izin`, `cuti`, `libur`, and `hadir_tanpa_jadwal`

**Implication:** Phase 58 should not add payroll logic in Flutter. It should only transform these strict rows into matrix cells and row summaries.

### 3. The current recap fetch is activity-driven, but the matrix requirement is roster-driven
- `_loadDailySummaryData()` fetches strict recap rows only for the selected outlet/date range.
- Those rows represent returned recap activity, not the full active employee roster.
- The employee model already exposes `isActive`, `archivedAt`, and `employmentContract`, and multiple admin surfaces already filter active employees with `.eq('is_active', true)`.

**Implication:** Phase 58 needs a separate active-roster query for the selected outlet. Building the matrix only from recap rows would violate the locked requirement to show all active employees and to hide archived staff.

### 4. The repo already has a strong pinned-grid pattern, but it only solves the left rail
- `lib/screens/admin/widgets/schedule_table_view.dart` uses `TableView.builder` from `two_dimensional_scrollables` with `pinnedRowCount: 1` and `pinnedColumnCount: 1`.
- That pattern is already accepted in this repo for wide schedule grids and matches the user’s “employee column fixed, dates scroll right” requirement.
- The current pattern does not provide a ready-made sticky trailing summary rail.

**Implication:** Phase 58 should reuse `TableView`, but the summary rail will need an explicit layout strategy:
- either a three-pane composition (`employee rail` + `date grid` + `summary rail`),
- or a coordinated shell where only the middle date section scrolls horizontally.

Trying to fake sticky summary columns inside the current list-card recap surface will not scale.

### 5. Export ownership is already fragmented and should not get a third ad-hoc path
- The repo contains both `lib/services/pdf_service.dart` and `lib/services/pdf_report_service.dart`.
- `AdminReportsScreen` currently exports CSV directly and calls into PDF generation patterns separately.
- `PROJECT.md` already lists “Dual PDF service files” as tech debt.

**Implication:** spreadsheet export should be introduced as one dedicated service with a clear contract, not as more inline logic in `AdminReportsScreen` and not as a third general-purpose report service that overlaps the PDF debt.

### 6. No workbook dependency exists yet, and package choice is a real planning gate
- `pubspec.yaml` currently includes CSV, PDF, `share_plus`, and `two_dimensional_scrollables`, but no `.xlsx` writer.
- As of **2026-03-27**, pub.dev shows:
  - [`excel` 4.0.6](https://pub.dev/packages/excel) as a Dart/Flutter XLSX create/update package with cell styling and merge support.
  - [`syncfusion_flutter_xlsio` 33.1.45](https://pub.dev/packages/syncfusion_flutter_xlsio) as a richer XLSX package with documented formatting, row/column manipulation, and worksheet APIs.
  - [`Range.freezePanes()` in Syncfusion XlsIO docs](https://pub.dev/documentation/syncfusion_flutter_xlsio/latest/xlsio/Range-class.html), which directly matters because the Phase 58 workbook contract requires frozen top row and frozen employee-identification columns.
  - [`Syncfusion license terms`](https://pub.dev/packages/syncfusion_flutter_xlsio/license), which require either a community or commercial license.

**Implication:** the researched package that clearly matches the workbook contract is `syncfusion_flutter_xlsio`, but it introduces a license checkpoint. The lighter `excel` package may still be viable for basic workbook generation, but from the sources reviewed there is no documented freeze-pane API, so it is a weaker fit for the locked workbook behavior.

### 7. Phase 58 needs an explicit performance boundary for wide date ranges
- The current recap list simply renders `filteredRows` with `ListView.builder`.
- A payroll matrix multiplies `employee count x day count`, and the current screen also fetches all daily rows for export in one go.
- The repo already chose `TableView` previously specifically to handle dense, scrollable data surfaces.

**Implication:** Phase 58 should pre-index rows by `employeeId + logicalDate` and render cheap cell DTOs. It should not repeatedly scan the recap list inside cell builders.

### 8. Existing tests stop at strict recap parsing and list-card rendering
- `test/services/attendance_policy_recap_service_test.dart` covers strict recap parsing.
- `test/screens/admin/admin_reports_policy_recap_test.dart` covers strict filter behavior on the list-card recap.
- `test/services/pdf_report_service_test.dart` covers PDF summary math, not workbook export.
- No tests currently protect:
  - roster-first payroll matrix building
  - sticky matrix UI rendering
  - workbook output structure
  - color and tag parity between UI and workbook

**Implication:** Phase 58 needs new Wave 0 tests before implementation drifts.

## Standard Stack

### Core
| Library / System | Purpose | Why Standard |
|------------------|---------|--------------|
| `AttendancePolicyRecapService` + `AttendancePolicyRecapDay` | strict day-level payroll source of truth | Phase 57 already made SQL and typed Dart the canonical recap contract. |
| Active employee query pattern on `employees.is_active` | roster-first matrix population | The repo already uses active-only employee loading across admin surfaces, and the Phase 58 context explicitly excludes archived staff. |
| `two_dimensional_scrollables` `TableView` | wide matrix rendering with pinned left rail | This repo already uses it for schedule management, so it is the least risky matrix foundation. |
| `share_plus` | file handoff to Android share sheet | Existing report exports already rely on it. |

### Supporting
| Library / System | Purpose | When to Use |
|------------------|---------|-------------|
| `AttendancePolicyBadge` and `AttendancePolicySignalChip` semantics | existing red/yellow/info vocabulary | Use as the starting color/tag vocabulary, but move the actual matrix/export mapping into a shared payroll semantics helper. |
| `AppCard`, `AppEmptyState`, `AppToast` | admin shell continuity | Reuse in the matrix toolbar, loading, empty, and export-feedback states. |
| `path_provider` + `dart:io` | temporary workbook creation before share | Reuse the same file-output pattern already used by CSV/PDF export. |

### Workbook Package Recommendation
| Option | Pros | Risks | Recommendation |
|--------|------|-------|----------------|
| `syncfusion_flutter_xlsio` | Documented XLSX focus, formatting APIs, and freeze-pane support; good fit for a payroll workbook with frozen panes and styled summary columns. | Requires community or commercial Syncfusion licensing. | **Primary recommendation** if the project can satisfy the license terms. |
| `excel` | Smaller OSS dependency and already proven for basic XLSX create/update workflows. | The sources reviewed did not show documented freeze-pane support, which is a locked workbook requirement. | Use only as a fallback if licensing blocks Syncfusion and the freeze-pane requirement is consciously re-scoped or solved another way. |

## Architecture Patterns

### Pattern 1: Build one shared payroll matrix contract before touching UI or workbook code
**What:** Introduce pure Dart models and builder logic that transform:
- active employees,
- selected date range,
- strict recap rows

into one matrix contract with:
- employee identity block,
- one cell per logical date,
- right-side summary counts,
- precomputed labels/tags/colors.

**Why:** UI and workbook should consume the same matrix object. If they each reshape rows independently, parity will drift immediately.

### Pattern 2: Keep payroll cell semantics in one reusable helper
**What:** Centralize:
- primary fill color
- foreground color
- explicit fallback labels
- short tags (`TLT`, `KJG`, `BRK`, `ABS`, `OT`, `ME`)
- summary-count increment rules

in one helper or small service.

**Why:** The current badge/chip widgets prove the vocabulary, but matrix cells and workbook cells need a simpler shared representation than reusing widget classes.

### Pattern 3: Treat the matrix as three coordinated surfaces, not one giant improvised widget
**What:** Split the UI into:
- pinned employee rail,
- scrollable date grid,
- sticky summary rail.

**Why:** `TableView` already solves the employee/date part well, but the right-side sticky summary requirement is separate. Designing it explicitly keeps layout complexity contained.

### Pattern 4: Keep workbook generation outside `AdminReportsScreen`
**What:** Create a dedicated spreadsheet export service that accepts the shared payroll matrix contract and returns a file path or bytes for sharing.

**Why:** `AdminReportsScreen` is already large and already carries both CSV and PDF behavior. More export formatting logic inside the widget will make Phase 58 brittle and harder to test.

### Pattern 5: Make roster population active-only and outlet-scoped before date indexing
**What:** Fetch active employees for the chosen outlet first, then map date cells against that roster.

**Why:** The context explicitly rejects both “activity-only rows” and “include archived staff historically.” The roster query itself is part of the product contract.

## Recommended Project Structure

```text
lib/models/
├── payroll_matrix_day_cell.dart
├── payroll_matrix_row.dart
└── payroll_matrix_summary.dart

lib/services/
├── payroll_matrix_builder.dart
├── payroll_matrix_semantics.dart
└── payroll_spreadsheet_export_service.dart

lib/screens/admin/widgets/
├── payroll_matrix_table.dart
├── payroll_matrix_employee_cell.dart
├── payroll_matrix_day_cell_widget.dart
└── payroll_matrix_summary_rail.dart

test/models/
├── payroll_matrix_day_cell_test.dart
└── payroll_matrix_row_test.dart

test/services/
├── payroll_matrix_builder_test.dart
├── payroll_matrix_semantics_test.dart
└── payroll_spreadsheet_export_service_test.dart

test/widgets/
└── payroll_matrix_table_test.dart

test/screens/admin/
└── admin_reports_payroll_matrix_test.dart
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Payroll business rules | New Dart recalculation logic | The existing Phase 57 SQL output | The strict recap engine is already canonical. |
| Activity-based matrix population | “Only rows returned by recap RPC” | Active employee roster + recap index | The user explicitly wants all active employees. |
| Sticky summary with ad-hoc overlay math in one huge widget | One monolithic custom painter or nested `SingleChildScrollView` hack | Explicit employee rail + date grid + summary rail composition | Easier to test and reason about on tablet-sized layouts. |
| Workbook export from screen-local state | Inline `AdminReportsScreen` file building | Dedicated spreadsheet export service | Keeps the export path testable and prevents more report-service sprawl. |
| Fake spreadsheet by renaming CSV | `.csv` bytes with `.xlsx` extension | Real XLSX writer package | `REPORT-02` explicitly replaces CSV with spreadsheet export. |

## Common Pitfalls

### Pitfall 1: Deriving the matrix only from recap rows
**What goes wrong:** active employees with no activity vanish from the matrix and workbook.
**How to avoid:** make roster fetch a first-class input to the matrix builder.

### Pitfall 2: Recomputing summary counts in both UI and export
**What goes wrong:** the on-screen summary rail and workbook right-side columns disagree for the same employee/date range.
**How to avoid:** compute summaries once in the shared matrix builder.

### Pitfall 3: Letting matrix colors drift from workbook colors
**What goes wrong:** payroll reviewers see different severity semantics depending on surface.
**How to avoid:** use one payroll-semantics helper for both UI and workbook styling.

### Pitfall 4: Forcing the current list-card recap widget tree into a matrix role
**What goes wrong:** the screen becomes an unreadable set of nested lists or horizontally scrolling cards.
**How to avoid:** introduce purpose-built matrix widgets and keep the old list-card recap logic as an upstream reference, not the rendering foundation.

### Pitfall 5: Choosing an XLSX package before acknowledging the license constraint
**What goes wrong:** execution starts, the workbook path is implemented, and only later the package license blocks shipping.
**How to avoid:** make the package choice explicit in planning and execution prerequisites.

### Pitfall 6: Querying or rendering cell data with repeated list scans
**What goes wrong:** wide date ranges become sluggish because every cell rebuild walks all recap rows.
**How to avoid:** build a keyed map such as `employeeId -> date -> cell` before rendering.

## Open Questions

1. **Can the project accept the Syncfusion license path?**
   - What we know: Syncfusion is the only researched option with documented freeze-pane support, which the Phase 58 workbook contract requires.
   - Recommendation: treat this as an execution checkpoint in the first plan. If license acceptance is blocked, the fallback package decision must be revisited before coding starts.

2. **Should the sticky summary rail live inside the same `TableView` or beside it?**
   - What we know: `TableView` already fits the employee/date grid, but the repo precedent only covers pinned start columns.
   - Recommendation: keep the summary rail as a coordinated sibling surface rather than forcing unsupported trailing-pin behavior into the same builder.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` plus workbook contract assertions |
| Config file | `analysis_options.yaml` |
| Quick run command | `C:\flutter\bin\flutter.bat test test/models/payroll_matrix_day_cell_test.dart test/models/payroll_matrix_row_test.dart test/services/payroll_matrix_builder_test.dart test/services/payroll_matrix_semantics_test.dart test/services/payroll_spreadsheet_export_service_test.dart test/widgets/payroll_matrix_table_test.dart test/screens/admin/admin_reports_payroll_matrix_test.dart` |
| Full suite command | `C:\flutter\bin\flutter.bat test` |
| Estimated runtime | ~150 seconds |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| `REPORT-01` | active roster merges into one employee-by-date matrix with explicit non-time labels and summary counts | unit | `C:\flutter\bin\flutter.bat test test/services/payroll_matrix_builder_test.dart` | ❌ Wave 0 |
| `REPORT-01` | matrix shell keeps the employee rail and summary rail visible while day cells stay read-only | widget | `C:\flutter\bin\flutter.bat test test/widgets/payroll_matrix_table_test.dart test/screens/admin/admin_reports_payroll_matrix_test.dart` | ❌ Wave 0 |
| `REPORT-02` | workbook export produces one real `.xlsx` payroll matrix with date cells, summary columns, and no GPS fields | unit/contract | `C:\flutter\bin\flutter.bat test test/services/payroll_spreadsheet_export_service_test.dart` | ❌ Wave 0 |
| `REPORT-01`, `REPORT-02` | UI and workbook use the same fill/tag semantics | unit | `C:\flutter\bin\flutter.bat test test/services/payroll_matrix_semantics_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** run the task-local automated command; if shared matrix semantics change, also run `C:\flutter\bin\flutter.bat test test/services/payroll_matrix_builder_test.dart test/services/payroll_matrix_semantics_test.dart`
- **Per wave merge:** run the full quick run command
- **Phase gate:** run `C:\flutter\bin\flutter.bat test` before `$gsd-verify-work`

### Wave 0 Gaps
- `test/models/payroll_matrix_day_cell_test.dart` - explicit label, primary color, and short-tag mapping coverage
- `test/models/payroll_matrix_row_test.dart` - summary-count ordering and contract-group sorting coverage
- `test/services/payroll_matrix_builder_test.dart` - roster-first matrix building and archived-employee exclusion
- `test/services/payroll_matrix_semantics_test.dart` - UI/workbook parity for fill and tags
- `test/services/payroll_spreadsheet_export_service_test.dart` - real workbook generation contract
- `test/widgets/payroll_matrix_table_test.dart` - pinned employee rail plus read-only cell rendering
- `test/screens/admin/admin_reports_payroll_matrix_test.dart` - toolbar state, empty state, and export feedback integration

## Sources

### Primary (HIGH confidence)
- [admin_reports_screen.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/screens/admin/admin_reports_screen.dart) - current report shell, recap list, and CSV/PDF export ownership
- [attendance_policy_recap_service.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/services/attendance_policy_recap_service.dart) - canonical strict recap fetch path
- [attendance_policy_recap_day.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/models/attendance_policy_recap_day.dart) - typed strict day payload already available to matrix/export code
- [schedule_table_view.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/screens/admin/widgets/schedule_table_view.dart) - existing pinned-grid implementation pattern
- [employee.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/models/employee.dart) - active/archive and contract fields needed for roster-first matrix building
- [pdf_service.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/services/pdf_service.dart) - existing table-export ownership pattern and report-service fragmentation risk
- [pdf_report_service.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/services/pdf_report_service.dart) - existing report-summary service seam
- [58-CONTEXT.md](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/.planning/phases/58-payroll-matrix-spreadsheet-export/58-CONTEXT.md) - locked product decisions
- [58-UI-SPEC.md](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/.planning/phases/58-payroll-matrix-spreadsheet-export/58-UI-SPEC.md) - locked visual and workbook contract

### Secondary (MEDIUM confidence)
- [attendance_policy_badge.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/widgets/attendance_policy_badge.dart) - current strict-status colors and labels
- [attendance_policy_signal_chip.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/widgets/attendance_policy_signal_chip.dart) - current detail-signal vocabulary
- [attendance_policy_recap_service_test.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/test/services/attendance_policy_recap_service_test.dart) - existing strict recap parsing coverage
- [admin_reports_policy_recap_test.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/test/screens/admin/admin_reports_policy_recap_test.dart) - current admin recap widget coverage
- [pdf_report_service_test.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/test/services/pdf_report_service_test.dart) - current report-summary testing seam

### External package references (current as of 2026-03-27)
- [excel package on pub.dev](https://pub.dev/packages/excel) - current OSS XLSX create/update package
- [syncfusion_flutter_xlsio package on pub.dev](https://pub.dev/packages/syncfusion_flutter_xlsio) - current richer XLSX package
- [syncfusion_flutter_xlsio license terms](https://pub.dev/packages/syncfusion_flutter_xlsio/license) - licensing checkpoint for the recommended workbook path
- [Range.freezePanes() API docs](https://pub.dev/documentation/syncfusion_flutter_xlsio/latest/xlsio/Range-class.html) - documented freeze-pane support

## Metadata

**Confidence breakdown:**
- Matrix UI direction: HIGH - the repo already uses `TableView` for dense operational grids and the UI contract is explicit.
- Shared matrix builder direction: HIGH - the strict recap model already contains the needed business semantics.
- Workbook package recommendation: MEDIUM - Syncfusion clearly fits the contract technically, but the license checkpoint is real.
- Test strategy: HIGH - the repo already uses focused model/service/widget tests and can extend that pattern cleanly.

**Research date:** 2026-03-27
**Valid until:** 2026-04-26
