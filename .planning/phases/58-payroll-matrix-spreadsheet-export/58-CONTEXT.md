# Phase 58: Payroll Matrix & Spreadsheet Export - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Rebuild Rekap Harian into a payroll-facing employee-by-date matrix for the admin surface and replace the old CSV recap export with a color-aware spreadsheet workbook. This phase owns the matrix presentation contract, spreadsheet structure, row/summarization rules, and how strict recap signals appear in compact salary-review cells. PDF parity, portal parity, payroll amount calculation, and interactive correction workflows remain outside this phase.

</domain>

<decisions>
## Implementation Decisions

### Spreadsheet export contract
- Phase 58 should export a single `.xlsx` workbook as the primary payroll output; CSV recap export is no longer the canonical payroll artifact.
- Export stays scoped to one outlet per workbook, matching the current strict recap policy flow that already requires one outlet per range.
- The workbook should use one main matrix sheet rather than splitting the primary payroll report into multiple summary or audit sheets.
- Each day cell in the workbook should show compact `masuk/pulang` content plus short tags when extra strict signals need to stay visible.
- Cell coloring in the workbook must follow the strict **primary** status, while secondary strict signals stay visible as compact tags in the same cell.

### Summary columns and row population
- The payroll matrix should default to showing the full active roster for the selected outlet, not only employees who had activity inside the chosen date range.
- Row ordering should group employees by contract first (`FULLTIME` / `PARTTIME`), then sort by employee name inside each group.
- Summary columns should stay payroll-core only: `late`, `short work`, `excess break`, `absence`, and `overtime`.
- Summary columns should be ordered with red/problem counts first and the yellow `overtime` count at the end.
- Employees who are currently archived should **not** appear in the Phase 58 payroll matrix, even when the selected historical range still contains their older attendance data.

### Admin matrix UI
- The admin surface should use a pinned-grid layout: employee identity stays frozen on the left while date columns extend horizontally to the right across the selected range.
- Matrix day cells should stay read-only in Phase 58; tapping a cell does not need to open a detail panel or editing flow.
- On the admin screen, summary information should stay sticky/visible even when the date range is wide, instead of only appearing after a long horizontal scroll.
- Cells without a normal `masuk/pulang` pair should still render an explicit status label such as `Libur`, `Izin`, `Sakit`, or `Tidak Hadir`; they should not rely on blank cells alone.

### the agent's Discretion
- Exact spreadsheet library/package choice, workbook style implementation, and share/export plumbing, as long as the final output is a real `.xlsx` workbook that preserves the agreed matrix contract and strict colors.
- Exact short-tag vocabulary used inside matrix cells, as long as tags remain compact and payroll-facing.
- Exact sticky-summary implementation for the admin UI, including whether it is rendered as pinned columns, a synchronized side rail, or another additive pattern that stays readable on wide ranges.
- Exact virtualization, chunking, or large-range performance strategy, as long as the UI still behaves like a pinned payroll matrix and the workbook output remains complete.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone scope and export requirements
- `.planning/ROADMAP.md` - Phase 58 goal, dependency chain, and success criteria for the payroll matrix plus spreadsheet export.
- `.planning/REQUIREMENTS.md` - `REPORT-01` and `REPORT-02` define the payroll-ready matrix, spreadsheet replacement for CSV, day-cell colors, and per-employee summary counts.
- `.planning/PROJECT.md` - v8.0 milestone framing, payroll-reporting non-goals, and the requirement to stay salary-facing without drifting into payroll amount calculation.

### Locked upstream rule decisions
- `.planning/phases/54-workforce-contract-outlet-mode-foundation/54-CONTEXT.md` - Canonical contract and outlet-mode inputs that still shape row grouping and attendance interpretation.
- `.planning/phases/55-schedule-policy-absence-rules/55-CONTEXT.md` - Band-first schedule policy, lateness windows, required-hours rules, and no-show semantics that the matrix must inherit.
- `.planning/phases/56-server-time-scan-authority/56-CONTEXT.md` - Authoritative WITA scan timing, break-first capture semantics, and offline provenance that feed recap outcomes.
- `.planning/phases/57-strict-recap-evaluation-engine/57-CONTEXT.md` - Canonical strict recap semantics for primary status, detail signals, manager exemption, incomplete chains, and overnight-safe workday logic.

### Canonical SQL and recap engine sources
- `sql/phase_55_schedule_policy_foundation_20260326.sql` - Schedule-policy helper functions for shift band, required work minutes, lateness cutoffs, and break-first deadlines.
- `sql/phase_56_server_time_scan_authority_20260327.sql` - Authoritative scan provenance fields plus break-first intent persistence that Phase 57/58 consume.
- `sql/phase_57_strict_recap_evaluation_engine_20260327.sql` - Canonical strict recap RPC contract with `primary_status`, `detail_signals`, work/break metrics, overtime, and manager-exemption semantics.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/screens/admin/admin_reports_screen.dart` already owns the admin report filters, date-range controls, recap tab shell, and export action bar; it is the primary integration point for the Phase 58 matrix and workbook export.
- `lib/services/attendance_policy_recap_service.dart` already fetches the strict recap RPC and gives Phase 58 one typed source of truth instead of ad-hoc query logic.
- `lib/models/attendance_policy_recap_day.dart` already exposes logical date, primary status, detail signals, work/break metrics, overtime, short-work, and excess-break values that the matrix and workbook can render directly.
- `lib/widgets/attendance_policy_badge.dart` and `lib/widgets/attendance_policy_signal_chip.dart` already define the current strict color and labeling semantics that Phase 58 should mirror in matrix/workbook decisions.
- `lib/screens/admin/widgets/schedule_table_view.dart` already demonstrates a pinned `TableView` with frozen header/employee columns, making it the closest in-repo interaction pattern for the payroll matrix.

### Established Patterns
- Strict attendance rules are already centralized in SQL/RPC output and mirrored into typed Dart models; Phase 58 should render/export those results without re-deriving business logic in Flutter.
- The current admin reports surface already separates per-scan data from recap data behind shared outlet/date filters, so the payroll matrix can evolve the recap side without inventing a new top-level reporting screen.
- The repo already uses `two_dimensional_scrollables` for wide operational grids, so a pinned payroll matrix can reuse an established interaction pattern instead of introducing an unrelated table system.
- The current export stack is CSV/PDF only, which means spreadsheet generation is a real net-new contract and should likely live beside the existing report export services rather than inside widget state.

### Integration Points
- `lib/screens/admin/admin_reports_screen.dart` must evolve from a recap list into a payroll matrix surface while keeping the existing date/outlet filter workflow.
- `lib/services/attendance_policy_recap_service.dart` and `lib/models/attendance_policy_recap_day.dart` should feed both the matrix rows and the workbook generator so UI/export stay aligned.
- `lib/screens/admin/widgets/schedule_table_view.dart` and the existing `TableView` pattern are the strongest starting point for the pinned-grid interaction contract.
- A new spreadsheet export service will likely need to sit alongside the existing report/PDF services so workbook generation stays testable and outside widget code.

</code_context>

<specifics>
## Specific Ideas

- The user wants the canonical payroll output to be a single-sheet `.xlsx` workbook, not a CSV bundle and not a split audit workbook.
- The user wants the admin surface to feel like a real wide matrix with employee identity pinned on the left and a sticky summary that remains readable even when many dates are shown.
- The user wants each normal day cell to show compact `masuk/pulang` data plus short tags, while non-time states still use explicit written labels rather than blanks.
- The user explicitly wants the matrix roster to follow currently active employees only; archived staff stay hidden unless restored as active employees.
- The user wants the matrix to stay read-only in this phase, so payroll review remains lightweight and does not branch into per-cell drilldown flows yet.

</specifics>

<deferred>
## Deferred Ideas

- A separate workbook audit/detail sheet was considered but intentionally not selected for Phase 58; the workbook stays one main matrix sheet for now.
- Multi-outlet workbook export was considered but deferred; Phase 58 stays one outlet per workbook.
- Interactive per-cell drilldown or tooltip-heavy matrix review was considered but deferred; Phase 58 cells remain read-only.
- Showing archived employees in historical payroll ranges was explicitly rejected for Phase 58 and can only return in a future phase if the reporting contract changes.
- PDF and portal parity remain downstream work for Phase 59, not this phase.

</deferred>

---

*Phase: 58-payroll-matrix-spreadsheet-export*
*Context gathered: 2026-03-27*
