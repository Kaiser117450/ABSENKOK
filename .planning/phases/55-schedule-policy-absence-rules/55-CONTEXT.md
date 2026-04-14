# Phase 55: Schedule Policy & Absence Rules - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Rebuild live scheduling policy around shift bands, contract-aware required hours, WITA lateness windows, and strict no-show classification for logical workdays. This phase clarifies how schedules are represented and how lateness or absence is interpreted, while keeping existing kepala gerai scheduling workflows additive. Break-first business rules are locked here as policy input, but the capture/confirmation flow itself belongs to Phase 56. Role-per-schedule assignment, payroll red/yellow evaluation, and recap export redesign remain out of scope for this phase.

</domain>

<decisions>
## Implementation Decisions

### Schedule band representation
- Scheduled workdays should display the assigned band plus required hours, for example a `Pagi • 8j` style cell, rather than an exact clock range as the primary label.
- Required hours should default from the employee contract and remain editable per scheduled day.
- Quick band chips should remain the primary assignment interaction; the new policy model should not force a heavy form-first workflow for common edits.
- Exact clock ranges may remain visible only as a small hint or detail cue, not as the source-of-truth schedule label.

### Lateness and break-first policy
- Morning lateness uses a hard WITA cutoff of `07:00`; scans at `07:01` or later are late.
- Siang lateness uses a hard WITA cutoff of `10:00`.
- Sore lateness uses a hard WITA cutoff of `15:00`.
- Early scans remain valid; lateness only cares about whether the first relevant scan crossed the band cutoff.
- A late arrival remains factually present and is tagged as late; it does not become an absence just because it missed the cutoff.
- Lateness comparison should be evaluated at minute precision, not second precision.
- Admin review should expose a fast lateness filter, and normal late arrivals must be auditable separately from break-first late cases.
- Break-first questioning should only happen when the first scan falls inside the allowed break-first window for that shift and there is no `break` or `kembali` log yet.
- If the employee says they did **not** take break first, the case falls back to a normal late arrival.
- Break-first is allowed for any shift; the decisive difference is contract break duration:
- `PARTTIME` break-first window = band cutoff + 1 hour
- `FULLTIME` break-first window = band cutoff + 2 hours
- This implies:
- `Pagi`: break-first remains valid through `08:00` for `PARTTIME` and `09:00` for `FULLTIME`
- `Siang`: break-first remains valid through `11:00` for `PARTTIME` and `12:00` for `FULLTIME`
- `Sore`: break-first remains valid through `16:00` for `PARTTIME` and `17:00` for `FULLTIME`

### No-show and exception states
- A scheduled employee with no logs yet on the active logical workday should show as `belum_masuk`, not `tidak_hadir`.
- `Tidak_hadir` is only finalized when the logical workday has fully ended and the scheduled employee still has zero logs.
- `Sakit`, `izin`, `libur`, and `cuti` always override `tidak_hadir`; they never coexist with it.
- Partial attendance logs keep their own status (for example, `masuk` without `pulang` remains an incomplete-attendance case); `tidak_hadir` is reserved only for truly zero-log scheduled days.
- If valid attendance logs arrive later, they must automatically replace an earlier `tidak_hadir` decision.
- If admin later corrects a day to `sakit`, `izin`, or `cuti`, that approved status must automatically replace `tidak_hadir`.
- Logs on an unscheduled day should remain visible as `hadir tanpa jadwal`; they should not enter the no-show path.
- Before payroll red/yellow recap work exists, admin review should show `tidak_hadir` with a tag plus reason, not just a bare badge.

### Kepala gerai workflow continuity
- The weekly grid remains the primary scheduling surface.
- Bulk assign should stay available, but it now needs a short review step before confirmation so the operator can confirm the policy-derived defaults.
- Existing auto-generate schedule templates should stay in place, including the familiar 2-shift and 3-shift flows.
- Policy information such as band meaning, required hours, and lateness rules should appear as a compact summary in the header or detail surface rather than being repeated inside every cell.

### Claude's Discretion
- Exact field names, enum shapes, and migration choreography, as long as the user-facing policy stays band-first and additive.
- The precise review UI for bulk assign, as long as it remains a lightweight confirmation rather than a heavy full-form replacement.
- Exact wording for late, break-first, no-show, and reason tags, as long as they remain operationally clear and do not prematurely introduce the payroll red/yellow taxonomy.

</decisions>

<specifics>
## Specific Ideas

- The user explicitly wants the siang band to use `10:00` as the on-time cutoff and to treat a first scan at `11:59` or `12:00` with no break logs as a valid break-first case for `FULLTIME`.
- The user wants the same break-first logic pattern to apply across pagi, siang, and sore, with the allowed window determined by contract break duration rather than by a fixed all-shifts rule.
- The user wants kepala gerai to keep familiar scheduling speed: weekly grid first, quick chips still present, templates still present, and bulk assign still usable.
- The user wants rollout auditing to be easy for managers, which is why lateness must be filterable and normal late vs break-first late must remain distinct.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/models/shift_schedule.dart`: current schedule model already centralizes shift bands, status labels, and JSON serialization, but today it still embeds exact clock times as primary schedule data.
- `lib/screens/admin/shift_scheduler_screen.dart`: existing weekly scheduler already provides quick-tap cell assignment, bulk mode, and auto-generate templates that can be preserved instead of redesigned from scratch.
- `lib/screens/admin/widgets/schedule_table_view.dart` and `lib/screens/admin/widgets/schedule_cells.dart`: the current grid rendering is already split cleanly enough to swap cell content from exact time labels to band-plus-hours policy labels.
- `lib/screens/admin/admin_reports_screen.dart`: current admin recap tiles already distinguish incomplete attendance cases, making it a natural integration point for temporary late and no-show review tags before Phase 57.

### Established Patterns
- Scheduling is currently driven by a 7-day grid, quick chips, and lightweight modal interactions; the user wants to preserve that operational style.
- Schedule storage, portal schedule RPCs, and portal recap RPCs all currently read `shift_slot` exact time fields directly, so planning must account for those read paths when moving to band-first semantics.
- Current recap logic already treats partial attendance separately from zero-log absence, which aligns with the user's desire to reserve `tidak_hadir` only for true no-log scheduled days.
- Admin review UIs in this codebase already use compact tags and filters more naturally than dense per-cell text, which fits the desired rollout visibility.

### Integration Points
- `lib/models/shift_schedule.dart` must stop making exact clock labels the primary meaning of a schedule row and instead carry band plus required-hours policy data.
- `lib/screens/admin/shift_scheduler_screen.dart` and its grid widgets must render band-plus-hours cells, small hints, and any new review summary without breaking the familiar weekly workflow.
- `sql/phase_38_employee_schedule_read_model_20260322.sql`, `sql/phase_39_portal_read_path_hardening_20260323.sql`, and `sql/phase_42_portal_attendance_recap_20260323.sql` currently depend on exact shift time fields and will need a compatible policy-aware read model.
- `lib/screens/admin/admin_reports_screen.dart` or successor admin recap surfaces need the new temporary late and no-show audit tags before the later payroll-facing recap phases take over.

</code_context>

<deferred>
## Deferred Ideas

- Add a role to each schedule assignment such as `Housekeeping`, `Kasir`, `Assambler`, and `Kitchen`, and include that role in schedule PDF export. This is a separate capability because it changes schedule data shape and export output.
- Build the interactive break-first capture or confirmation flow in the scan path. The business rule is now defined, but the user-facing capture flow belongs to Phase 56.
- Introduce payroll red/yellow severity, overtime penalties, or recap color logic. Those belong to the later strict recap phases.

</deferred>

---

*Phase: 55-schedule-policy-absence-rules*
*Context gathered: 2026-03-26*
