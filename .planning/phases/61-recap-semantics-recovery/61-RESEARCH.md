# Phase 61: Recap Semantics Recovery - Research

**Researched:** 2026-04-01
**Domain:** admin recap continuity for legacy no-schedule attendance data on top of the shipped strict recap, fallback, and payroll export stack
**Confidence:** HIGH

## Summary

Phase 61 should not reopen the strict attendance rules. Phases 57-59 already shipped the strict recap RPC, the legacy fallback synthesizer, the payroll matrix, the spreadsheet export, the payroll PDF export, and the current compatibility banner pattern. The remaining gap is that the admin-facing "Rekap Harian" semantics are still split across two incompatible paths:

1. the newer strict-plus-fallback payroll dataset path inside `buildPayrollRecapDatasetWithCompatibility(...)`, and
2. the older raw-log `DailySummary` path in `admin_reports_screen.dart` that still bypasses the strict recap contract entirely.

That split explains the roadmap wording for Phase 61. Legacy no-schedule rows are already recoverable for salary-facing outputs, but the admin day-level recap experience is not yet anchored to the same merged semantics. The repo still contains the row-level `AttendancePolicyRecapDay` helpers, filters, reason-copy builder, and widget tests, but the active `Rekap Harian` tab currently renders the payroll matrix shell rather than the day-row recap contract the requirements describe.

**Primary recommendation:** plan Phase 61 as two execution plans across two waves:

1. extract one reusable admin recap dataset service that merges strict rows with compatibility rows at the `AttendancePolicyRecapDay` level, and
2. restore the admin-facing Rekap Harian surface, filters, and pending semantics on top of that merged dataset while explicitly retiring the raw-log recap summary path as the source of truth.

No database migration is required by the strongest local reading. The strict SQL engine already knows how to preserve late, break-first, excess-break, manager exemption, and overnight-safe logical days. The current gap is the client-side recap orchestration and UI contract, not the payroll rules themselves.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| `RECAP-05` | Admin Rekap Harian and pending views continue to show usable day rows for existing attendance data even when some dates still have no `schedule_entries`. | The codebase already has `AttendancePolicyRecapDay`, `PolicyRecapTile`, row filters, and a compatibility row synthesizer, but the active recap surface does not yet use them as the canonical merged admin dataset. |
| `RECAP-06` | Compatibility rows for no-schedule days preserve logical-day grouping, contract-based required hours, and honest incomplete states without fabricating late or absence signals. | `LegacyPayrollRecapFallbackService` already encodes the honest fallback contract and `TWENTY_FOUR_HOUR` logical-day grouping; Phase 61 should reuse it at the admin recap layer instead of rebuilding from raw logs. |
| `RECAP-07` | Break-first, excess-break, and other strict contract-aware recap rules remain visible for days where strict evaluation data exists; compatibility handling must not downgrade those days into generic no-schedule rows. | The current `putIfAbsent` merge pattern in `buildPayrollRecapDatasetWithCompatibility(...)` already expresses the needed strict-wins behavior and should be extracted into a reusable service for the recap layer. |

## Existing Code Findings

### 1. Compatibility merging exists, but only inside the payroll matrix path

- `lib/screens/admin/admin_reports_screen.dart` already contains `buildPayrollRecapDatasetWithCompatibility(...)`.
- That helper merges strict `AttendancePolicyRecapDay` rows with fallback rows from `LegacyPayrollRecapFallbackService`.
- The helper is screen-local and returns a `PayrollMatrixDataset`, which is correct for salary-facing exports but too specialized to be the long-term admin recap source of truth.

**Implication:** Phase 61 should extract a reusable service that returns merged recap rows first, not matrix cells first. Phase 63 can then reuse that same corrected merged recap dataset when it re-locks spreadsheet and PDF parity.

### 2. The active `Rekap Harian` tab is currently payroll-first, not day-row-first

- `_buildRekapHarian()` in `lib/screens/admin/admin_reports_screen.dart` returns `PayrollRecapTab`.
- `PayrollRecapTab` renders the rollout panel, compatibility banner, and `PayrollMatrixTable`.
- The same file still contains `PolicyRecapFilter`, `filterPolicyRecapRows(...)`, `buildPolicyRecapReasonCopy(...)`, and `PolicyRecapTile`, plus targeted tests in `test/screens/admin/admin_reports_policy_recap_test.dart`.

**Implication:** the repo already contains the right row-level recap primitives, but they are no longer the active admin recap surface. Phase 61 should promote those semantics back into the real tab instead of inventing a third recap presentation model.

### 3. The old raw-log `DailySummary` path still exists and bypasses strict semantics

- `_computeDailySummaries(...)` in `lib/screens/admin/admin_reports_screen.dart` groups raw `_ReportRow` logs by date and employee.
- That logic predates the strict recap engine and only knows `DailySummaryStatus.normal`, `sakit`, `izin`, and `belumPulang`.
- The same method still powers the hidden tab-1 branch of `_exportCsv()` and `_exportPdf()` when `isRekap` is true.
- `test/screens/admin/rekap_harian_test.dart` is still a placeholder specification file rather than real behavior coverage.

**Implication:** this is the largest semantic drift in the current code. Even if the payroll matrix stays correct, any admin recap path that continues to depend on `_computeDailySummaries()` cannot satisfy `RECAP-06` or `RECAP-07`.

### 4. The strict recap engine already has the data Phase 61 needs

- `sql/phase_57_strict_recap_evaluation_engine_20260327.sql` already returns:
  - `primary_status`
  - `detail_signals`
  - `is_manager_exempt`
  - `logical_day_complete`
  - `net_work_minutes`
  - `total_break_minutes`
  - `short_work_minutes`
  - `overtime_minutes`
  - `excess_break_minutes`
  - `paired_break_count`
- `AttendancePolicyRecapDay.fromJson(...)` already parses those fields and still preserves legacy compatibility with earlier payloads.

**Implication:** Phase 61 does not need a new admin recap DTO. `AttendancePolicyRecapDay` is already the canonical row contract for both strict and fallback data.

### 5. `LegacyPayrollRecapFallbackService` already encodes the honest fallback contract

- `lib/services/legacy_payroll_recap_fallback_service.dart` already:
  - groups raw logs into overnight-safe source days,
  - derives contract-aware `requiredWorkMinutes`,
  - computes `shortWork`, `overtime`, and `excessBreak`,
  - preserves `belumAbsenPulang` and `activeIncomplete`,
  - forbids fabricated `late` and `absence` outputs, and
  - uses `putIfAbsent` merge semantics so strict rows win.

**Implication:** Phase 61 should reuse this service rather than copy its logic into another screen-private helper.

### 6. Schedule-gap notifications belong to Phase 62, not this phase

- `admin_dashboard_screen.dart` still uses `_loadOpenShifts()` to detect "Belum Absen Pulang" operationally from raw logs.
- The roadmap already assigns schedule-gap follow-up notices to Phase 62 (`SCHED-05`).

**Implication:** Phase 61 should not try to solve outlet-scoped missing-schedule notifications or dashboard staffing alerts. It should focus on truthful recap semantics and pending row continuity inside the admin reporting experience.

## Standard Stack

### Core
| Library / System | Purpose | Why Standard |
|------------------|---------|--------------|
| `AttendancePolicyRecapDay` | canonical merged day-row contract | Already used by the strict recap service, row-level widgets, and compatibility logic. |
| `AttendancePolicyRecapService` | strict recap fetch boundary | Already calls the canonical `get_admin_schedule_policy_recap` RPC and parses the strict payload. |
| `LegacyPayrollRecapFallbackService` | compatibility row synthesis for missing strict keys | Already implements the honest no-schedule fallback contract and `TWENTY_FOUR_HOUR` grouping rules. |
| Flutter `flutter_test` | service and widget regression coverage | Already used throughout the admin recap and payroll flows. |

### Supporting
| Library / System | Purpose | When to Use |
|------------------|---------|-------------|
| `PayrollMatrixSemantics` and `PayrollMatrixDataset` | salary-facing export parity baseline | Keep as downstream consumers; do not let them remain the only merged recap path. |
| `PolicyRecapTile`, `buildPolicyRecapReasonCopy(...)`, `filterPolicyRecapRows(...)` | existing admin day-row recap primitives | Reuse when rebuilding the active recap tab. |
| `OutletOperatingMode` | overnight-safe logical-day behavior | Pass through the merged recap service so `TWENTY_FOUR_HOUR` outlets keep the same keying across strict and fallback rows. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extracting a shared merged recap service | Leave `buildPayrollRecapDatasetWithCompatibility(...)` screen-local and build the row list ad hoc in the widget layer | Faster short-term, but it would keep the canonical dataset trapped in UI code and make Phase 63 harder. |
| Reusing `AttendancePolicyRecapDay` | Introduce a new "admin recap row" DTO | Unnecessary duplication; the current model already covers strict and fallback fields. |
| Retiring the raw `DailySummary` recap path | Keep both recap models alive and decide per surface | This would preserve the semantic drift Phase 61 exists to remove. |

## Architecture Patterns

### Pattern 1: Canonical merged recap rows first, specialized outputs second

**What:** create a pure service that returns merged `AttendancePolicyRecapDay` rows and compatibility metadata before any widget or export builder transforms them.

**Why:** the roadmap now treats the corrected merged admin recap dataset as the canonical source that later exports must follow.

### Pattern 2: Strict rows always win over fallback rows

**What:** merge by `(employeeId, logicalDate)` using `putIfAbsent` semantics so days with valid strict evaluation keep their original break-first, excess-break, late, exemption, and contract-aware signals.

**Why:** `RECAP-07` is explicitly about retaining strict semantics where legitimate.

### Pattern 3: Keep pending semantics inside the recap contract, not dashboard heuristics

**What:** use `AttendancePolicySignal.belumAbsenPulang` and `AttendancePolicySignal.activeIncomplete` from merged recap rows to drive the admin recap's "pending" filters and counts.

**Why:** this is more precise than raw open-shift heuristics and keeps pending row visibility tied to the same canonical semantics as the recap itself.

### Pattern 4: Salary-facing exports stay downstream and secondary in this phase

**What:** keep spreadsheet/PDF actions available as supporting outputs, but do not let them define the primary admin recap experience.

**Why:** Phase 63 already exists to relock those exports to the corrected merged recap dataset once Phase 61 establishes that dataset.

### Pattern 5: Fence off `DailySummary` as legacy-only or remove it from recap paths

**What:** any active Rekap Harian path must stop depending on `_computeDailySummaries()` or `DailySummaryStatus` as its truth source.

**Why:** that path cannot represent manager exemption, break-first retention, excess break, honest no-schedule compatibility, or mixed strict-plus-fallback overnight rows.

## Recommended Project Structure

```text
lib/services/
├── attendance_policy_recap_service.dart
├── legacy_payroll_recap_fallback_service.dart
└── admin_policy_recap_dataset_service.dart
   # new pure merged-recap service returning canonical AttendancePolicyRecapDay rows

lib/screens/admin/
└── admin_reports_screen.dart

test/services/
├── attendance_policy_recap_service_test.dart
├── legacy_payroll_recap_fallback_service_test.dart
└── admin_policy_recap_dataset_service_test.dart

test/screens/admin/
├── admin_reports_policy_recap_test.dart
└── rekap_harian_test.dart
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Legacy no-schedule day rows | A second fallback algorithm inside the widget tree | `LegacyPayrollRecapFallbackService` | The honest fallback rules are already encoded there. |
| Admin recap row contract | A new map/DTO unrelated to `AttendancePolicyRecapDay` | `AttendancePolicyRecapDay` | It already carries strict and compatibility semantics. |
| Pending recap filters | Raw scan heuristics from dashboard-style queries | `AttendancePolicySignal.belumAbsenPulang` and `activeIncomplete` | Those reflect the canonical recap interpretation, not just unmatched `masuk` scans. |
| Rekap semantics | `_computeDailySummaries()` | merged strict-plus-fallback `AttendancePolicyRecapDay` rows | `DailySummary` cannot represent the required strict and compatibility signals. |

## Common Pitfalls

### Pitfall 1: Letting matrix-first code remain the only merged dataset path
**What goes wrong:** the admin row recap and future exports diverge again because the canonical merge logic still lives inside a payroll-specific builder.
**How to avoid:** extract one reusable merged recap service in Wave 1.

### Pitfall 2: Replacing strict rows with fallback rows when both exist
**What goes wrong:** valid strict late/excess-break/exemption rows degrade into generic `hadir_tanpa_jadwal` rows.
**How to avoid:** strict rows must always win by `(employeeId, logicalDate)`.

### Pitfall 3: Keeping `DailySummary` as a hidden recap source of truth
**What goes wrong:** CSV/PDF or future recap refactors keep inheriting pre-strict behavior and silently reintroduce false semantics.
**How to avoid:** any recap-specific path must be rewritten around merged `AttendancePolicyRecapDay` rows or explicitly marked legacy-only and unreachable.

### Pitfall 4: Pulling schedule-gap notices into this phase
**What goes wrong:** Phase 61 expands into operational missing-schedule notification work that belongs to Phase 62.
**How to avoid:** keep the scope on recap continuity and pending row honesty only.

## Open Questions

1. **Should the active `Rekap Harian` tab become a day-row list again while payroll export CTAs remain visible as secondary actions?**
   - What we know: the requirement language emphasizes usable day rows and pending views.
   - Recommendation: yes. The active recap tab should be row-first, with salary export actions preserved but secondary.

2. **Should `activeIncomplete` and `belumAbsenPulang` share one pending bucket or remain separately filterable?**
   - What we know: both represent operational follow-up, but they are not the same state.
   - Recommendation: show one combined pending count, but keep separate chips or filter states so operators can isolate unfinished-current-day versus historical-missing-clock-out rows.

3. **Should tab-1 CSV/PDF export be rehabilitated in this phase or deferred until the new row recap surface lands?**
   - What we know: the current export branches still depend on `_computeDailySummaries()`.
   - Recommendation: if recap export remains user-facing after the row surface is restored, convert it in this phase; otherwise explicitly fence it off so it cannot masquerade as the canonical recap path.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` |
| Config file | `analysis_options.yaml` |
| Quick run command | `C:\flutter\bin\flutter.bat test test/services/admin_policy_recap_dataset_service_test.dart test/screens/admin/admin_reports_policy_recap_test.dart test/screens/admin/rekap_harian_test.dart test/services/attendance_policy_recap_service_test.dart test/services/legacy_payroll_recap_fallback_service_test.dart` |
| Full suite command | `C:\flutter\bin\flutter.bat test` |
| Estimated runtime | ~150 seconds |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| `RECAP-05` | merged admin recap rows stay visible when strict rows are empty or partial but attendance-backed fallback rows exist | unit + widget | `C:\flutter\bin\flutter.bat test test/services/admin_policy_recap_dataset_service_test.dart test/screens/admin/rekap_harian_test.dart` | ❌ Wave 0 / ❌ placeholder |
| `RECAP-06` | no-schedule compatibility rows preserve honest incomplete states and never fabricate late or absence signals | unit | `C:\flutter\bin\flutter.bat test test/services/admin_policy_recap_dataset_service_test.dart test/services/legacy_payroll_recap_fallback_service_test.dart` | ❌ Wave 0 / ✅ |
| `RECAP-07` | strict rows keep their richer signals in mixed strict-plus-fallback overnight datasets | unit + widget | `C:\flutter\bin\flutter.bat test test/services/admin_policy_recap_dataset_service_test.dart test/screens/admin/admin_reports_policy_recap_test.dart` | ❌ Wave 0 / ✅ partial |

### Sampling Rate
- **After every task commit:** run the task-local command plus the quick run command if the merged recap service or screen wiring changed.
- **After every plan wave:** run `C:\flutter\bin\flutter.bat test`.
- **Before `$gsd-verify-work`:** full suite must be green.
- **Max feedback latency:** 150 seconds.

### Wave 0 Gaps
- `test/services/admin_policy_recap_dataset_service_test.dart` - new merged strict-plus-fallback recap dataset coverage
- Replace placeholder `test/screens/admin/rekap_harian_test.dart` with real widget-level recap continuity coverage
- Extend `test/screens/admin/admin_reports_policy_recap_test.dart` with mixed strict-plus-fallback pending/filter behavior on the active recap surface

## Sources

### Primary (HIGH confidence)
- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/STATE.md`
- `.planning/phases/58.1-schedule-ux-polish-and-legacy-payroll-fallback/58.1-02-PLAN.md`
- `.planning/phases/58.1-schedule-ux-polish-and-legacy-payroll-fallback/58.1-03-PLAN.md`
- `.planning/phases/58.1-schedule-ux-polish-and-legacy-payroll-fallback/58.1-03-SUMMARY.md`
- `lib/screens/admin/admin_reports_screen.dart`
- `lib/services/attendance_policy_recap_service.dart`
- `lib/services/legacy_payroll_recap_fallback_service.dart`
- `lib/models/attendance_policy_recap_day.dart`
- `sql/phase_57_strict_recap_evaluation_engine_20260327.sql`
- `test/screens/admin/admin_reports_policy_recap_test.dart`
- `test/screens/admin/admin_reports_payroll_matrix_test.dart`
- `test/screens/admin/rekap_harian_test.dart`

### Secondary (MEDIUM confidence)
- `.planning/phases/59-pdf-portal-parity/59-RESEARCH.md`
- `.planning/phases/60-rollout-payroll-acceptance/60-RESEARCH.md`
- `.planning/codebase/INTEGRATIONS.md`
- `.planning/codebase/STRUCTURE.md`

## Metadata

**Confidence breakdown:**
- merged recap service direction: HIGH - the code already contains the strict rows, fallback service, and a screen-local merge helper that proves the shape
- admin recap UI direction: HIGH - row-level recap helpers and tests already exist in the repo, but they are not the active surface
- export cleanup timing: MEDIUM - the stale tab-1 recap export path is real, but the UI currently hides those actions on the recap tab

**Research date:** 2026-04-01
**Valid until:** 2026-05-01
