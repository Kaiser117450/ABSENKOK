# Phase 59: PDF & Portal Parity - Research

**Researched:** 2026-03-28
**Domain:** strict portal parity and payroll-facing PDF matrix export on top of the shipped Phase 57/58/58.1 recap stack
**Confidence:** MEDIUM-HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Portal schedule cards and portal attendance recap must be band-first: `Pagi` / `Siang` / `Sore` remains the main label, while required hours and progress are the supporting context.
- Main portal schedule-facing surfaces must stop showing stale exact shift clock ranges as the primary contract.
- When work-time data exists, active days should show both already-worked time and remaining time; completed days should show worked time against the target.
- Portal outcome labels must use the canonical strict vocabulary from the admin recap and payroll exports: `Terlambat`, `Kurang jam kerja`, `Istirahat berlebih`, `Lembur`, and `Tidak hadir`.
- Portal helper copy should stay calm and employee-facing even when the underlying outcome is explicit.
- The payroll PDF recap must use the spreadsheet-style employee/date matrix as the canonical body, preceded by a compact summary page.
- PDF cells must reuse the same short-tag semantics and severity colors as the spreadsheet export.
- Payroll-facing PDF pages must exclude GPS, queue metadata, raw technical scan fields, and other low-signal audit details.
- Execution planning must respect the completed Phase 58.1 dependency because legacy no-`schedule_entries` fallback and scheduler UX polish now sit underneath this phase.

### Claude's Discretion
- Exact portal copy placement for required hours, worked time, and remaining time, as long as the hierarchy stays band-first and exact clock ranges stay off the main schedule surfaces.
- Exact PDF pagination, legend placement, and summary metric layout, as long as the summary page stays compact and the matrix remains the canonical recap body.
- Exact additive SQL shape for the employee-scoped portal parity RPCs, as long as the logic reuses the canonical strict recap contract instead of re-deriving payroll rules in Astro.

### Deferred Ideas (OUT OF SCOPE)
- Legacy per-scan audit PDF remains a separate export path.
- Payroll amount calculation, payslips, correction requests, and approval workflows remain deferred.
- Broad portal redesign outside the Phase 59 parity surface remains out of scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| `SCHED-04` | Portal and schedule-facing UI show contract-aware required hours and remaining/already-worked time without displaying stale exact shift clock ranges. | The current portal schedule and recap read-models still expose exact `start_hour` / `end_hour` fields and the Astro components still render them directly. Phase 59 needs a strict, progress-aware portal DTO plus component updates that stop depending on clock-range presentation. |
| `REPORT-03` | PDF export uses the same contract-aware and overnight-safe evaluation rules as the spreadsheet and excludes GPS or other technical scan details from payroll-facing recap pages. | The current Flutter PDF services still build legacy row-based reports. Phase 59 needs a dedicated payroll-PDF path that consumes the same `PayrollMatrixDataset` and `PayrollMatrixSemantics` already used by the spreadsheet export. |
</phase_requirements>

## Summary

Phase 59 should not invent new payroll logic. The hard business rules already live in the shipped strict recap engine and the shipped payroll matrix stack:

1. `sql/phase_57_strict_recap_evaluation_engine_20260327.sql` defines the canonical overnight-safe and contract-aware strict signals.
2. `lib/services/payroll_matrix_builder.dart` already turns recap rows plus the active roster into one employee/date matrix dataset.
3. `lib/services/payroll_matrix_semantics.dart` already owns payroll-facing primary labels, severity colors, and short tags.
4. `lib/services/payroll_spreadsheet_export_service.dart` already proves the current salary-facing export contract and explicitly excludes forbidden low-signal fields.

The remaining gap is surface parity:

- the portal still reads and renders schedule-clock-era DTOs from Phases 39/42, and
- the PDF export path still builds legacy per-scan and daily-row tables instead of the matrix contract.

The safest Phase 59 path is to keep one strict source of truth and split execution into four planning areas:

1. **portal data contract parity** — additive SQL + TypeScript loader upgrades so portal schedule and recap surfaces consume strict, progress-aware fields instead of shift-clock-era DTOs,
2. **portal UI parity** — Astro component changes that present band-first, progress-first, calm employee-facing cards,
3. **payroll PDF matrix export** — a dedicated Flutter PDF path built from `PayrollMatrixDataset` and `PayrollMatrixSemantics`,
4. **admin wiring + parity regression** — the recap export shell and validation evidence that spreadsheet, PDF, and portal agree for the same logical workday.

## Existing Code Findings

### 1. Portal schedule loading still exposes exact shift clocks as a primary contract
- `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/schedule.ts` defines `PortalScheduleEntry` around `startHour`, `startMinute`, `endHour`, `endMinute`, and `endsNextDay`.
- `sql/phase_39_portal_read_path_hardening_20260323.sql` returns `get_portal_schedule_overview(...)` rows with those exact fields as the core payload.
- `PortalScheduleSection.astro` renders those exact times directly into the card meta.

**Implication:** Phase 59 needs a new portal DTO that exposes band, required-work target, worked/remaining metrics, and strict portal outcome framing as first-class fields. Simply hiding the times in Astro would leave the SQL and TypeScript contracts stale and encourage future drift.

### 2. Portal attendance recap is still the Phase 42 status-only model
- `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap.ts` is still driven by `get_portal_attendance_recap(...)`, which returns `attendance_status`, schedule clock fields, timestamps, and aggregate minutes.
- `sql/phase_42_portal_attendance_recap_20260323.sql` derives informative states such as `hadir`, `sedang_bekerja`, `belum_pulang`, and `tidak_hadir`, but it does not emit the Phase 57 strict primary-status contract or the spreadsheet-style short-tag vocabulary.
- `PortalAttendanceHistorySection.astro` still renders exact schedule times and presentation helpers built around the older status taxonomy.

**Implication:** Phase 59 should not bolt strict meaning onto the current TS layer by ad hoc mapping. It needs a portal-safe wrapper around the strict recap contract so overnight-safe parity and contract-aware outcomes come from SQL/shared semantics, not from UI inference.

### 3. The Flutter app already has the canonical payroll matrix contract
- `lib/services/payroll_matrix_builder.dart` and `lib/models/payroll_matrix_row.dart` already define the employee/date matrix that Phase 58 introduced for admin recap and spreadsheet export.
- `lib/services/payroll_matrix_semantics.dart` already centralizes:
  - primary labels,
  - short tags (`TLT`, `KJG`, `BRK`, `ABS`, `OT`, `ME`),
  - payroll summary counts,
  - severity colors.
- `lib/screens/admin/admin_reports_screen.dart` already builds the recap dataset with Phase 58.1 compatibility fallback and wires the spreadsheet export.

**Implication:** PDF parity should consume this existing dataset and semantics helper rather than re-derive status labels or severity colors from raw recap rows.

### 4. The current PDF services are legacy-report builders, not payroll-matrix exporters
- `lib/services/pdf_service.dart` still owns:
  - schedule PDF export,
  - per-scan PDF export with `latitude` / `longitude`,
  - legacy daily recap PDF with row-based `AttendanceDailyPdfRow`.
- `lib/services/pdf_report_service.dart` still works from `DailySummary`, which predates the strict recap and payroll matrix contract.
- Both services generate useful legacy outputs, but neither is built around `PayrollMatrixDataset`.

**Implication:** Phase 59 should introduce a dedicated payroll recap PDF service instead of further stretching the legacy `DailySummary` or per-scan PDF paths. The new service can live beside them, while the admin recap tab routes payroll-facing PDF export to the matrix-driven path.

### 5. Spreadsheet export already defines the payroll-facing field boundary
- `lib/services/payroll_spreadsheet_export_service.dart` uses `PayrollMatrixDataset` and keeps a `forbiddenFields` list: `latitude`, `longitude`, `capture_mode`, `queue_order`, `requires_admin_review`, and `detail_note`.
- The service writes employee identity, contract, date cells, and summary counts only.

**Implication:** Phase 59 should treat that spreadsheet service as the field-boundary reference for the new payroll PDF. The PDF summary and matrix pages should expose the same salary-facing contract, not invent a second export vocabulary.

### 6. Admin recap currently has payroll spreadsheet export but no parity PDF path
- `AdminReportsScreen` already exposes `Ekspor Spreadsheet` on the recap tab and keeps legacy CSV/PDF paths on the per-scan tab.
- There is no recap-tab payroll PDF action or matrix-PDF generator yet.

**Implication:** the final Phase 59 admin wiring needs to add or replace the recap-tab payroll export action with a PDF path that clearly targets the same dataset as spreadsheet export, while leaving the per-scan audit exports alone.

### 7. The website repo has a type-check path but no portal behavior test harness
- `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/package.json` defines `astro check` but no `test` script or TS test runner.
- The portal repo therefore has one static automation gate (`npm run check`) but no established loader/component regression framework yet.

**Implication:** planning must either:
- add a minimal portal test harness as Wave 0, or
- explicitly accept `astro check` plus manual parity verification for the website slice.

Without acknowledging this, Phase 59 will appear verified while the portal behavior still lacks automated coverage.

## Standard Stack

### Core
| Library / System | Purpose | Why Standard |
|------------------|---------|--------------|
| `public.get_admin_schedule_policy_recap(...)` and the Phase 57 strict SQL helpers | canonical contract-aware and overnight-safe evaluation engine | Already shipped and already trusted by the admin recap and spreadsheet export. |
| `PayrollMatrixDataset` + `PayrollMatrixBuilder` | one employee/date matrix contract for recap/export | Already shipped in Phase 58 and extended in Phase 58.1 for legacy fallback. |
| `PayrollMatrixSemantics` | canonical labels, tags, palettes, and summary counts | Already shipped and already used for spreadsheet parity. |
| Flutter `pdf` package + `share_plus` | on-device PDF generation and share flow | Already used by existing report exports, so Phase 59 does not need a new export dependency. |
| Astro 5 + TypeScript + Supabase SSR loaders | portal server-rendered data and UI | Already established in the portal repo. |

### Supporting
| Library / System | Purpose | When to Use |
|------------------|---------|-------------|
| `AttendancePolicyRecapService` | strict admin recap fetch boundary | Reuse when building admin-side parity checks and matrix data for PDF export. |
| `LegacyPayrollRecapFallbackService` | no-`schedule_entries` compatibility baseline from Phase 58.1 | Preserve its merged dataset behavior so PDF parity does not regress legacy outlets. |
| `getPortalReferenceDate()` | WITA-aligned portal date anchor | Keep schedule and recap loaders anchored to the same business-local date when strict parity fields are added. |
| `npm run check` in the website repo | current automated portal gate | Use until a portal test harness exists. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Matrix-driven payroll PDF | Reuse the legacy `AttendanceDailyPdfRow` table and add a few strict columns | Faster to patch, but it guarantees drift from the spreadsheet export and keeps the wrong recap shape alive. |
| Strict SQL/shared semantics in the portal data layer | Recompute strict labels and progress heuristics directly in Astro components | Superficially simpler, but it splits parity logic across SQL and TS and will drift quickly. |
| Dedicated payroll PDF service | Extend `pdf_report_service.dart` further | Possible, but that service is built on `DailySummary` and legacy report assumptions, so it would increase technical debt rather than isolate the new contract. |
| Additive portal parity RPC | Reuse the Phase 42 RPC unchanged and map “remaining time” client-side | That keeps the old DTO stale and forces the UI layer to infer strict meaning from incomplete data. |

## Architecture Patterns

### Pattern 1: Treat strict parity as a shared data-contract problem first
**What:** introduce a portal-safe strict parity RPC or wrapper that exposes:
- shift band,
- required work minutes,
- already-worked minutes,
- remaining minutes,
- strict primary outcome,
- short tags or detail signals,
- calm supporting copy inputs,
- overnight-safe logical date.

**Why:** the portal schedule and recap surfaces should consume one canonical, typed DTO rather than stitching strict meaning together from clock-era fields in TypeScript.

### Pattern 2: Keep portal presentation band-first and progress-first
**What:** portal cards should prioritize:
- band label,
- required-hours target,
- worked/remaining progress,
- strict outcome chip,
- calm supporting copy.

Exact clock ranges can remain available only as low-signal drilldown or omitted entirely from the main cards, per the locked decision.

**Why:** this matches `SCHED-04` and the Phase 59 context directly. Reusing the current clock-range card structure would preserve the very contract this phase is supposed to retire.

### Pattern 3: Build payroll PDF from the shipped matrix contract, not from raw recap rows
**What:** use `buildPayrollRecapDatasetWithCompatibility(...)` and `PayrollMatrixDataset` as the input to a dedicated payroll PDF service.

That new PDF service should:
- build a compact summary page,
- render matrix pages using the same date columns and summary columns as the spreadsheet,
- reuse `PayrollMatrixSemantics` for labels/tags/colors,
- add a compact legend for short tags,
- exclude forbidden technical fields.

**Why:** spreadsheet parity is already defined in code. The PDF should follow it, not reinterpret it.

### Pattern 4: Keep legacy audit exports separate from payroll-facing recap export
**What:** preserve the per-scan PDF and per-scan CSV paths for audit/debug use, while the recap tab owns a distinct payroll-facing PDF path.

**Why:** payroll recap and audit exports have different audiences and different field contracts. Mixing them would reintroduce GPS and technical data into the salary-facing surface.

### Pattern 5: Plan parity verification explicitly across surfaces
**What:** for the same logical workday, the phase should verify:
- portal primary outcome,
- admin matrix cell,
- spreadsheet cell,
- PDF cell

all agree on label, short tags, and severity.

**Why:** “parity” is the actual product goal. A PDF that looks clean but disagrees with portal/admin data is not a successful Phase 59.

## Recommended Project Structure

```text
sql/
├── phase_59_portal_pdf_parity_20260328.sql
│   # additive portal parity RPC/wrapper and shared strict helper extraction

C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/
├── schedule.ts
├── attendance-recap.ts
└── strict-portal-parity.ts
   # new typed DTO normalization if split out from the existing loaders

C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/
├── PortalScheduleSection.astro
├── PortalAttendanceHistorySection.astro
└── PortalAttendanceOutcomeLegend.astro
   # optional legend/helper component if the final UI needs one

lib/services/
├── payroll_pdf_matrix_export_service.dart
├── payroll_matrix_builder.dart
├── payroll_matrix_semantics.dart
├── payroll_spreadsheet_export_service.dart
├── pdf_service.dart
└── pdf_report_service.dart

lib/screens/admin/
└── admin_reports_screen.dart

test/services/
├── payroll_pdf_matrix_export_service_test.dart
├── payroll_matrix_semantics_test.dart
└── pdf_service_color_test.dart

test/screens/admin/
└── admin_reports_payroll_matrix_test.dart
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Portal strict status meaning | Ad hoc TypeScript mapping from old `attendance_status` strings | Additive SQL/shared strict portal DTO | The strict engine is already canonical; UI should not become the second rules engine. |
| Payroll PDF body | A legacy row-per-day recap table | `PayrollMatrixDataset` | The spreadsheet export already defines the correct payroll-facing shape. |
| PDF severity/tags | A second hard-coded color or tag map | `PayrollMatrixSemantics` | This is already the shared parity source for spreadsheet output. |
| Recap-tab PDF export | Reusing the per-scan PDF path | A dedicated payroll recap PDF action | Audit exports and payroll exports intentionally have different field contracts. |
| Portal regression gating | Assuming `astro check` proves behavior parity | `astro check` plus either manual verification or a new Wave 0 test harness | Type-checking alone does not prove outcome parity or card behavior. |

## Common Pitfalls

### Pitfall 1: Hiding exact times in Astro without changing the data contract
**What goes wrong:** the TS and SQL models still center exact shift clocks, so later changes drift back toward clock-first UI.
**How to avoid:** add a portal parity DTO whose primary fields are band, required hours, worked minutes, remaining minutes, and strict outcome semantics.

### Pitfall 2: Recomputing strict outcomes in the portal layer
**What goes wrong:** portal status and admin/spreadsheet/PDF status disagree on overnight cases, manager exemptions, or fallback rows.
**How to avoid:** expose strict parity fields from SQL/shared helpers and treat Astro as a presentation consumer only.

### Pitfall 3: Building the payroll PDF from `DailySummary` or legacy daily rows
**What goes wrong:** the PDF inherits old row-based assumptions and drifts from the spreadsheet matrix immediately.
**How to avoid:** make `PayrollMatrixDataset` the only supported input for the payroll-facing PDF body.

### Pitfall 4: Forgetting the Phase 58.1 compatibility merge when generating PDF data
**What goes wrong:** legacy outlets with missing `schedule_entries` still look correct in the admin matrix/spreadsheet but go blank or partial in the PDF export.
**How to avoid:** route PDF generation through the same merged dataset builder already used by the recap tab.

### Pitfall 5: Treating `astro check` as sufficient portal verification
**What goes wrong:** portal data compiles, but required-hours/progress chips or calm-copy behavior still regress.
**How to avoid:** either add a small TS test harness or keep an explicit manual verification checklist for portal parity until one exists.

## Open Questions

1. **UI-SPEC gate:** there is no `59-UI-SPEC.md` yet even though the phase clearly has frontend indicators.
   - Recommendation: if the user wants a locked design contract before planning, generate Phase 59 UI-SPEC first.
   - If not, planning can proceed using the existing portal card language and the Phase 59 context as the visual baseline.

2. **Current-day progress semantics:** should the portal show live remaining time for in-progress days from the current chain state, or only the final worked-vs-target summary once the logical day is complete?
   - Recommendation: use live progress for current-day informative states when enough data exists, but keep the copy calm and clearly provisional.

3. **Payroll PDF action shape:** should the recap tab expose both spreadsheet and PDF together, or should PDF replace spreadsheet as the primary payroll export CTA?
   - Recommendation: keep both payroll-facing exports available if the toolbar stays clear; do not hide spreadsheet unless the user explicitly wants PDF-only.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` for the app slice plus `astro check` for the portal slice |
| Config file | `analysis_options.yaml` plus `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/tsconfig.json` |
| Quick run command | `powershell -Command "C:\flutter\bin\flutter.bat test test/services/payroll_matrix_semantics_test.dart test/services/pdf_service_color_test.dart test/services/payroll_pdf_matrix_export_service_test.dart test/screens/admin/admin_reports_payroll_matrix_test.dart; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; npm --prefix 'C:\Users\HYPE R Series\Desktop\projekan\absenkok-website' run check"` |
| Full suite command | `powershell -Command "C:\flutter\bin\flutter.bat test; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; npm --prefix 'C:\Users\HYPE R Series\Desktop\projekan\absenkok-website' run check"` |
| Estimated runtime | ~180 seconds |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| `SCHED-04` | portal loaders compile after parity DTO changes and components stop depending on stale clock-first props | static/type | `npm --prefix "C:\Users\HYPE R Series\Desktop\projekan\absenkok-website" run check` | ✅ |
| `SCHED-04` | portal cards show band, required hours, and worked/remaining context with no primary clock-range contract | manual or future TS/component tests | `npm --prefix "C:\Users\HYPE R Series\Desktop\projekan\absenkok-website" run check` | ❌ behavior W0 |
| `REPORT-03` | payroll PDF uses matrix labels/tags/colors that stay aligned with spreadsheet semantics | unit/contract | `C:\flutter\bin\flutter.bat test test/services/payroll_matrix_semantics_test.dart test/services/payroll_pdf_matrix_export_service_test.dart` | ❌ Wave 0 |
| `REPORT-03` | recap-tab wiring keeps the payroll PDF path on the same merged dataset contract as spreadsheet export | widget | `C:\flutter\bin\flutter.bat test test/screens/admin/admin_reports_payroll_matrix_test.dart` | ✅ partial |

### Sampling Rate
- **After every task commit:** run the task-local command; any change to matrix semantics or payroll PDF rendering should also run `C:\flutter\bin\flutter.bat test test/services/payroll_matrix_semantics_test.dart test/services/payroll_pdf_matrix_export_service_test.dart`
- **After every plan wave:** run the quick run command
- **Before `$gsd-verify-work`:** full suite command must be green
- **Max feedback latency:** 180 seconds

### Wave 0 Gaps
- `test/services/payroll_pdf_matrix_export_service_test.dart` - matrix-driven payroll PDF contract coverage
- Extend `test/screens/admin/admin_reports_payroll_matrix_test.dart` - recap-tab payroll PDF action and parity status feedback
- Portal behavior harness in `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website` or an explicit manual-only acceptance checklist for the updated portal schedule and recap cards
- Focused parity fixture covering one overnight employee-day and one Phase 58.1 fallback employee-day across spreadsheet, PDF, and portal outputs

## Sources

### Primary (HIGH confidence)
- [59-CONTEXT.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/phases/59-pdf-portal-parity/59-CONTEXT.md) - locked decisions and canonical references for Phase 59
- [ROADMAP.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/ROADMAP.md) - phase goal, dependency chain, and success criteria
- [REQUIREMENTS.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/REQUIREMENTS.md) - `SCHED-04` and `REPORT-03`
- [STATE.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/STATE.md) - current milestone state and reporting guardrails
- [phase_39_portal_read_path_hardening_20260323.sql](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/sql/phase_39_portal_read_path_hardening_20260323.sql) - current authenticated portal schedule RPC
- [phase_42_portal_attendance_recap_20260323.sql](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/sql/phase_42_portal_attendance_recap_20260323.sql) - current portal recap RPC
- [phase_57_strict_recap_evaluation_engine_20260327.sql](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/sql/phase_57_strict_recap_evaluation_engine_20260327.sql) - canonical strict recap engine
- [admin_reports_screen.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/screens/admin/admin_reports_screen.dart) - recap dataset orchestration and export wiring
- [payroll_matrix_semantics.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/services/payroll_matrix_semantics.dart) - canonical payroll labels/tags/palettes
- [payroll_spreadsheet_export_service.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/services/payroll_spreadsheet_export_service.dart) - current payroll export field boundary
- [pdf_service.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/services/pdf_service.dart) - current legacy schedule/per-scan/daily PDF paths
- [pdf_report_service.dart](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/services/pdf_report_service.dart) - current `DailySummary`-based PDF path
- [schedule.ts](C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/lib/portal/schedule.ts) - current portal schedule loader
- [attendance-recap.ts](C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap.ts) - current portal recap loader
- [PortalScheduleSection.astro](C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/components/portal/PortalScheduleSection.astro) - current schedule card rendering
- [PortalAttendanceHistorySection.astro](C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro) - current recap card rendering
- [package.json](C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/package.json) - portal toolchain and current `astro check` gate

### Secondary (MEDIUM confidence)
- [58-RESEARCH.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/phases/58-payroll-matrix-spreadsheet-export/58-RESEARCH.md) - payroll matrix contract baseline
- [58.1-RESEARCH.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/phases/58.1-schedule-ux-polish-and-legacy-payroll-fallback/58.1-RESEARCH.md) - legacy fallback baseline that Phase 59 must preserve

## Metadata

**Confidence breakdown:**
- portal data-contract direction: HIGH - the current SQL/TS/ASTRO chain is clearly still clock-first, and the Phase 59 context explicitly replaces that contract
- matrix-driven payroll PDF direction: HIGH - the spreadsheet export already defines the right recap shape and field boundary
- validation direction: MEDIUM - the Flutter side has good testing seams, but the portal repo still lacks a real behavior test harness beyond `astro check`

**Research date:** 2026-03-28
**Valid until:** 2026-04-27
