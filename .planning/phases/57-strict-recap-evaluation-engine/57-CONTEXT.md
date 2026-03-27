# Phase 57: Strict Recap Evaluation Engine - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Compute one strict recap engine that turns schedule policy, contract rules, outlet mode, and server-authoritative scan history into overnight-safe payroll signals for each logical workday. This phase owns the evaluation logic for late, short work, excess break, overtime, absence, manager exemption, incomplete chains, and unscheduled attendance, while keeping spreadsheet/PDF redesign and portal/admin parity work for later phases.

</domain>

<decisions>
## Implementation Decisions

### Overnight logical-day attachment
- **D-01:** At `TWENTY_FOUR_HOUR` outlets, scans after midnight may stay attached to the previous logical workday until there is a clear new-shift context, not just until a fixed clock hour.
- **D-02:** A new logical workday starts when there is an explicit new work context, such as a fresh `masuk` chain or a clearly finished prior chain, rather than automatically at midnight.
- **D-03:** `NORMAL` outlets do not use overnight carry-forward. Their attendance stays bound to the same logical day and should not inherit the 24-hour split rules.

### Manager exemption handling
- **D-04:** Manager exemption is determined from the employee's stored job title / `position`, not from Supabase auth login role metadata.
- **D-05:** Titles such as kepala toko / kepala gerai are exempt from strict red penalties for lateness, short work, and excess break.
- **D-06:** Exempt manager rows still remain visible in recap output with an explicit exempt marker plus non-penal informational notes about late / short / break behavior when relevant.
- **D-07:** Overtime and absence still remain normal recap signals for exempt manager rows; the exemption only suppresses late / short-work / excess-break penalties.

### Signal composition and severity
- **D-08:** Strict recap output must support one primary status plus additional detail signals, rather than collapsing the day into one generic label.
- **D-09:** The primary recap status is chosen by the highest active severity, while secondary signals remain attached for payroll audit detail.
- **D-10:** `late` is a red strict signal, not a yellow or neutral informational signal.
- **D-11:** `absence` remains a red strict signal.
- **D-12:** `PARTTIME` days that qualify as overtime gain the 2-hour break allowance for that day, and overtime remains its own signal instead of replacing other triggered outcomes.

### Work and break calculation
- **D-13:** Total break time must be calculated from real `break -> kembali` pairs, not from the older first-break to last-return envelope approximation.
- **D-14:** Net work duration is calculated from first `masuk` to final `pulang`, minus total paired break time.
- **D-15:** Overtime classification is based on final net work duration after break rules have been applied.

### Incomplete and unscheduled attendance
- **D-16:** A day that is still in progress remains informational only until its logical workday has actually ended; strict final verdicts must not be locked while the day is still active.
- **D-17:** Historical days with incomplete attendance chains may resolve to a red outcome once the logical workday has ended and the chain is still incomplete.
- **D-18:** At `NORMAL` outlets, a `break` without a matching `kembali` by the time the logical workday ends is treated as a missing clock-out / `belum absen pulang` case, not as a finalized excess-break verdict.
- **D-19:** `hadir_tanpa_jadwal` remains a dedicated signal and must not be collapsed into ordinary `hadir`.
- **D-20:** Unscheduled attendance still uses the employee's contract baseline for work/break calculations, and strict signals may coexist with the dedicated unscheduled marker.

### the agent's Discretion
- Exact schema shape for storing multiple active strict signals per day, as long as the model preserves one primary outcome plus attached detail signals.
- Exact tie-break order when multiple signals share the same severity, as long as the chosen rule is deterministic and documented for downstream agents.
- Exact wording, chip labels, and admin-review copy for exempt, incomplete, and unscheduled markers.
- Exact SQL/RPC split between recap aggregation and client presentation models, as long as all strict rules above stay enforced from one canonical engine.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone scope and rule boundary
- `.planning/ROADMAP.md` - Phase 57 goal, dependency chain, and success criteria for strict recap evaluation.
- `.planning/REQUIREMENTS.md` - `CONTRACT-03`, `RECAP-01`, `RECAP-02`, `RECAP-03`, and `RECAP-04` define exemption scope, overnight grouping, red/yellow thresholds, and separate payroll signals.
- `.planning/PROJECT.md` - Milestone framing, non-goals, and the payroll-reporting boundary for v8.0.

### Locked upstream phase decisions
- `.planning/phases/54-workforce-contract-outlet-mode-foundation/54-CONTEXT.md` - Canonical `FULLTIME` / `PARTTIME` and `NORMAL` / `TWENTY_FOUR_HOUR` inputs that Phase 57 must consume.
- `.planning/phases/55-schedule-policy-absence-rules/55-CONTEXT.md` - Shift-band cutoffs, break-first windows, no-show timing, and schedule-policy read model assumptions.
- `.planning/phases/56-server-time-scan-authority/56-CONTEXT.md` - Server-authoritative WITA timing, break-first intent capture, and offline-safe scan ordering.

### Existing recap and scan engine contracts
- `sql/phase_55_schedule_policy_foundation_20260326.sql` - Helper functions for shift band resolution, required work minutes, lateness cutoffs, and break-first deadlines.
- `sql/phase_55_admin_policy_recap_20260326.sql` - Current schedule-aware admin recap RPC baseline before strict payroll expansion.
- `sql/phase_56_server_time_scan_authority_20260327.sql` - Authoritative scan capture columns, break-first intent persistence, kiosk scan context RPC, and the latest recap SQL baseline that Phase 57 will extend.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/services/attendance_policy_recap_service.dart` - Existing typed recap fetcher already pulls one recap dataset from RPC and is the natural place to absorb a richer strict-recap payload.
- `lib/models/attendance_policy_recap_day.dart` - Current recap model already carries logical date, schedule policy metadata, late-kind state, and first/last scan timestamps; it is the existing contract to extend for multi-signal strict outcomes.
- `lib/screens/admin/admin_reports_screen.dart` - Admin recap UI already has filter chips, empty/error handling, and a dedicated policy recap tab, so later phases can layer strict output on an established surface.
- `lib/widgets/attendance_policy_badge.dart` - The current single-badge renderer shows where existing one-badge recap assumptions will need to expand once strict multi-signal output arrives.
- `lib/models/employee.dart` - Employee records already expose `employment_contract` plus free-text `position`, which is the only current source suitable for manager exemption identity.

### Established Patterns
- Recap policy logic is already centralized in SQL helper functions and RPC payloads, then mirrored into typed Dart models; Phase 57 should keep one canonical engine instead of duplicating business rules across screens.
- The current recap SQL still groups attendance by WITA calendar date and does not yet apply outlet operating mode to logical-day carry-forward, so overnight-safe grouping is an open engine gap.
- Admin report presentation is filter-driven and typed, but still assumes one visible badge per row, which constrains how strict multi-signal output must be represented downstream.
- Phase 56 already persists scan provenance such as `capture_mode`, `queue_order`, `initial_scan_intent`, and `requires_admin_review`, giving Phase 57 enough source data to reason about break-first and incomplete chains without inventing a new scan history format.

### Integration Points
- `sql/phase_56_server_time_scan_authority_20260327.sql` is the current recap truth source and must absorb 24-hour logical-day grouping, manager exemption, strict multi-signal evaluation, and incomplete-chain handling.
- `lib/models/attendance_policy_recap_day.dart` and `lib/services/attendance_policy_recap_service.dart` must evolve from a one-badge recap payload to a richer strict-signal contract.
- `lib/screens/admin/admin_reports_screen.dart` and `lib/widgets/attendance_policy_badge.dart` will later need to present a primary status plus secondary detail signals without losing the current operational filter flow.
- `lib/models/employee.dart` and any employee-loading queries must preserve job-title fidelity because manager exemption now depends on `position`.

</code_context>

<specifics>
## Specific Ideas

- The user explicitly wants `late` to stay red in strict recap output rather than being softened to yellow.
- Overnight carry-forward at 24-hour outlets should stop only when a clearly new shift context begins, not because a fixed morning clock line was crossed.
- Manager exemption must follow the employee's jabatan/title and still leave an explicit exempt marker on the row instead of silently hiding the context.
- For `NORMAL` outlets, a dangling `break` without `kembali` should be understood operationally as a missing clock-out case when the day ends.
- `hadir_tanpa_jadwal` should remain visibly special, but contract-based work/break math may still surface strict signals on that row.

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within Phase 57 scope.

</deferred>

---

*Phase: 57-strict-recap-evaluation-engine*
*Context gathered: 2026-03-27*
