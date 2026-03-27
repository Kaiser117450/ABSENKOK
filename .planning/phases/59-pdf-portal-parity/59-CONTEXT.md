# Phase 59: PDF & Portal Parity - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Align the salary-facing PDF recap and employee portal schedule/attendance surfaces with the v8 strict payroll contract. This phase removes stale exact shift clock ranges from portal schedule-facing UI, moves portal recap and payroll recap PDF onto the canonical strict evaluation engine, and preserves parity with the admin matrix and spreadsheet export for the same logical workday. Legacy per-scan audit PDF output, payroll amount calculation, and correction workflows remain out of scope.

</domain>

<decisions>
## Implementation Decisions

### Portal schedule framing
- **D-01:** Portal schedule cards and attendance recap schedule context should use **shift band + required hours** as the primary framing, not exact start/end shift clocks.
- **D-02:** Stale exact shift clock ranges should be removed from the main portal schedule and recap surfaces rather than kept as small hints.
- **D-03:** The visual hierarchy stays band-first. `Pagi` / `Siang` / `Sore` remains the main label, while required hours and progress sit underneath as supporting context.
- **D-04:** When work-time data exists, active days should show **both** already-worked time and remaining time; completed days should show worked time against the required-hours target so the employee can see deficit or surplus clearly.

### Portal strict outcome presentation
- **D-05:** The employee portal should use the same canonical strict outcome names as the admin recap and payroll exports, including labels such as `Terlambat`, `Kurang jam kerja`, `Istirahat berlebih`, `Lembur`, and `Tidak hadir`.
- **D-06:** Portal helper copy should stay calm and employee-facing even when the outcome labels are explicit; the portal should explain the state without payroll-admin harshness.
- **D-07:** Portal schedule-facing and recap-facing surfaces must consume the strict payroll contract instead of the older Phase 42 status-only recap model so overnight-safe results, manager exemption, and strict signals stay aligned cross-surface.

### Payroll PDF recap contract
- **D-08:** The payroll PDF should use the spreadsheet-style **employee/date matrix** as the core recap structure instead of the legacy row-per-day daily-summary table.
- **D-09:** The PDF should include a compact summary page ahead of the matrix pages, but the matrix remains the canonical recap body.
- **D-10:** PDF matrix cells should use the same compact primary label plus short secondary signal tags as the spreadsheet export, with a legend so payroll operators can decode the tags quickly.
- **D-11:** PDF recap colors and outcomes must follow the strict primary-status contract so the same logical workday reads the same in admin, spreadsheet, PDF, and portal.
- **D-12:** Payroll-facing PDF recap must exclude GPS coordinates, queue/sync metadata, raw technical scan fields, and other low-signal audit data from the recap surface.
- **D-13:** The salary-facing recap PDF is in scope; the legacy per-scan audit PDF can remain a separate export path unless later planning explicitly expands the parity goal.

### Dependency guard
- **D-14:** Phase 59 planning can proceed against the strict recap and spreadsheet baseline, but execution must respect the newly inserted **Phase 58.1** dependency because it now owns urgent schedule UX polish and the legacy no-`schedule_entries` payroll fallback.

### the agent's Discretion
- Exact placement and styling of required-hours and progress copy on portal cards, as long as the hierarchy stays band-first and exact shift clocks stay off the main portal surfaces.
- Exact PDF pagination, summary metric selection, and legend placement, as long as the output remains compact and the matrix stays the canonical recap body.
- Exact implementation path for upgrading portal RPC/read-model fields, as long as strict logic is reused from canonical backend/model contracts rather than re-derived in Astro components.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase boundary and milestone requirements
- `.planning/ROADMAP.md` - Phase 59 goal, dependency chain, and success criteria for PDF and portal parity.
- `.planning/REQUIREMENTS.md` - `SCHED-04` and `REPORT-03` define the portal hour/progress contract and the payroll-facing PDF parity requirement.
- `.planning/PROJECT.md` - v8.0 milestone framing, payroll-reporting non-goals, and the explicit note that PDF/portal parity is the remaining reporting gap after Phase 58.

### Locked upstream phase decisions
- `.planning/phases/54-workforce-contract-outlet-mode-foundation/54-CONTEXT.md` - Canonical `FULLTIME` / `PARTTIME` and outlet-mode metadata that still drive portal and recap behavior.
- `.planning/phases/55-schedule-policy-absence-rules/55-CONTEXT.md` - Band-first schedule semantics, required-hours defaults, lateness cutoffs, and the earlier decision that schedule UI should stop depending on exact clock labels.
- `.planning/phases/56-server-time-scan-authority/56-CONTEXT.md` - Authoritative WITA scan timing and break-first intent capture that portal/PDF recap must reflect accurately.
- `.planning/phases/57-strict-recap-evaluation-engine/57-CONTEXT.md` - Canonical strict primary status, detail signals, overnight-safe workday logic, and manager-exemption semantics.
- `.planning/phases/58-payroll-matrix-spreadsheet-export/58-CONTEXT.md` - Locked payroll matrix and spreadsheet export contract that the PDF recap now needs to mirror.

### Portal read-model and schedule-policy baselines
- `sql/phase_39_portal_read_path_hardening_20260323.sql` - Current authenticated `get_portal_schedule_overview` contract that still exposes exact shift clocks as primary schedule data.
- `sql/phase_42_portal_attendance_recap_20260323.sql` - Current portal attendance recap RPC and follow-up taxonomy before strict parity.
- `sql/phase_55_schedule_policy_foundation_20260326.sql` - Canonical shift-band, required-hours, lateness-cutoff, and break-first helper functions.

### Strict recap and spreadsheet parity sources
- `sql/phase_57_strict_recap_evaluation_engine_20260327.sql` - Canonical strict recap evaluation engine and output contract.
- `lib/services/payroll_matrix_semantics.dart` - Existing spreadsheet tag order, primary labels, and color palette that the PDF matrix must stay aligned with.
- `lib/services/payroll_spreadsheet_export_service.dart` - Existing spreadsheet workbook layout and salary-facing field exclusions that define the current parity target.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/services/attendance_policy_recap_service.dart` and `lib/models/attendance_policy_recap_day.dart` already expose the strict recap payload used by the admin recap and spreadsheet export.
- `lib/services/payroll_matrix_builder.dart`, `lib/services/payroll_matrix_semantics.dart`, and `lib/services/payroll_spreadsheet_export_service.dart` already define the matrix row contract, short-tag semantics, and payroll-facing export baseline that the PDF should mirror.
- `lib/screens/admin/admin_reports_screen.dart` already owns the outlet/date filter shell and export actions that Phase 59 must rewire from legacy PDF flows to the strict matrix contract.
- `lib/services/pdf_service.dart` and `lib/services/pdf_report_service.dart` are the current PDF entry points, but both still operate on legacy daily-summary or per-scan row shapes.
- `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/schedule.ts`, `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap.ts`, `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalScheduleSection.astro`, and `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro` are the current portal read-model and UI touchpoints.

### Established Patterns
- Portal surfaces are server-rendered Astro pages backed by typed loader helpers and one authenticated RPC per surface, so the correct parity path is upgrading the read model instead of recreating strict logic in the UI layer.
- Strict payroll semantics are already centralized in SQL plus typed Flutter models and then mirrored into spreadsheet cell tags/colors; Phase 59 should reuse that contract rather than invent a parallel PDF or portal taxonomy.
- Portal UI is already card-based and phone-first, so the new band/target/progress framing should stay within that existing card language rather than switching to a dense grid.
- Current PDF export is still built from legacy daily-summary/per-scan data, which is exactly the stale contract this phase must replace for payroll recap parity.

### Integration Points
- `sql/phase_39_portal_read_path_hardening_20260323.sql` and `src/lib/portal/schedule.ts` need new band/required-hours/progress-friendly fields instead of exact `start_hour` / `end_hour` display assumptions.
- `sql/phase_42_portal_attendance_recap_20260323.sql`, `src/lib/portal/attendance-recap.ts`, and the portal recap components need strict-engine outputs plus work-progress metrics.
- `lib/screens/admin/admin_reports_screen.dart` and `lib/services/pdf_service.dart` need the payroll recap PDF to read from strict recap / payroll matrix data instead of legacy `DailySummary` rows.
- Spreadsheet semantics helpers should stay the shared source for PDF cell labels, tags, and colors so export parity remains enforceable.

</code_context>

<specifics>
## Specific Ideas

- The user chose a **band-first** portal contract: the band stays the main label, required hours are prominent, and progress lives as supporting copy.
- The user wants active portal days to show both **already-worked** and **remaining** time, while completed days show worked time against the target.
- The user wants the portal to expose the real strict outcomes explicitly, but with calmer employee-facing supporting text.
- The user wants the payroll PDF to use a **compact summary page + matrix pages** instead of the older daily row table.
- The user wants PDF secondary signals to reuse the spreadsheet's short tags, with a legend rather than full labels in every cell.
- The roadmap changed during this session: Phase `58.1` now sits in front of Phase `59`, so downstream planning should treat the new fallback/UX work as an explicit blocker for implementation order.

</specifics>

<deferred>
## Deferred Ideas

- Legacy per-scan audit PDF can remain separate from the payroll recap parity contract unless a later phase intentionally merges audit and payroll reporting.
- Payroll amount calculation, payslips, correction requests, and approval workflows remain outside this phase.

</deferred>

---

*Phase: 59-pdf-portal-parity*
*Context gathered: 2026-03-27*
