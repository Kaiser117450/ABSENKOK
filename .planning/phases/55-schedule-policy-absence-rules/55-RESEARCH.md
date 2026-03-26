# Phase 55: Schedule Policy & Absence Rules - Research

**Researched:** 2026-03-26
**Domain:** additive schedule policy refactor across Flutter schedule surfaces, Supabase schedule JSON, and portal/admin attendance recap logic
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Schedule cells must become band-first (`Pagi`, `Siang`, `Sore`) with required hours as the visible meaning, not stale exact clock labels.
- Required hours default from the employee contract introduced in Phase 54, but remain editable per scheduled day.
- Lateness uses WITA minute-precision cutoffs: `07:00` for pagi, `10:00` for siang, `15:00` for sore.
- Break-first applies to all bands, but the allowed window depends on the employee contract: `PARTTIME = cutoff + 1 hour`, `FULLTIME = cutoff + 2 hours`.
- Late employees remain present; lateness does not turn into absence.
- A scheduled employee with zero logs on the active logical workday is `belum_masuk`; `tidak_hadir` only applies after the logical workday ends with zero logs.
- `Sakit`, `izin`, `libur`, and `cuti` must override `tidak_hadir` and remain distinct outcomes.
- The weekly grid, quick chips, auto-generate templates, and kepala gerai scheduling speed must stay intact.

### Immediate Planning Gate
- The user selected `Generate UI-SPEC first` for this phase. Planning should stop after research and route to `$gsd-ui-phase 55`.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| `SCHED-01` | Work schedules stay mandatory for scheduled workdays, but the schedule stores shift bands and required hours instead of misleading fixed clock labels in admin and portal surfaces. | The current model stores only exact `start_hour` / `end_hour` values inside `shift_slot`; Phase 55 needs an additive band-first payload plus compatibility fields while downstream readers migrate. |
| `SCHED-02` | Lateness is evaluated from scheduled shift rules in WITA, including the morning hard cutoff at `07:00` plus contract-aware siang and sore windows. | Current scheduler and SQL read models treat shift start times as the only time semantics; Phase 55 needs one canonical policy evaluator shared across Dart and SQL. |
| `SCHED-03` | A scheduled employee with no attendance logs for the logical workday is marked `tidak_hadir`, while scheduled sakit, izin, libur, and cuti states remain distinct from absence. | The portal recap RPC already derives `belum_masuk` / `tidak_hadir`, but admin recap models do not expose those states yet and approved time off still collapses to generic `Libur`. |
</phase_requirements>

## Summary

Phase 55 is a cross-cutting policy refactor, not a simple UI relabel. The repo already has a working weekly schedule grid, extracted `TableView` widgets, portal schedule RPCs, and a portal recap engine that understands logical-day status derivation. The problem is that all of those layers still treat exact clock values from `shift_slot` as the primary schedule meaning, while the new business rules define schedule intent by band, contract-aware required hours, and WITA lateness windows.

The safest implementation path is additive:

1. Keep the existing weekly grid and quick assignment interactions.
2. Extend the schedule payload so band and required-hours become first-class fields.
3. Derive lateness and break-first decisions from one canonical policy table instead of from legacy `start_hour` values.
4. Reuse the existing logical-day recap pipeline for `belum_masuk` and `tidak_hadir`, but extend it to preserve `cuti` / approved time-off distinctions and to surface manager-facing audit tags.
5. Leave old exact-time fields available as compatibility hints until all SQL and UI consumers are migrated.

**Primary recommendation:** plan this as one foundation pass for the shared policy contract plus two dependent integration passes: schedule UI/write-path migration and recap/read-model migration. Do not let each surface invent its own lateness math.

## Existing Code Findings

### 1. Scheduler data model still encodes exact times as the schedule contract
- `lib/models/shift_schedule.dart` defines `ShiftSlot` with only `name`, `startTime`, `endTime`, and `color`.
- Factory defaults are currently `Pagi 09:00-17:00`, `Siang 12:00-20:00`, `Sore 14:00-22:00`, and `Libur 00:00-00:00`.
- `ShiftSlot.toJson()` persists only `name`, `start_hour`, `start_minute`, `end_hour`, `end_minute`, and `color`.
- `ScheduleEntry` already has `ScheduleStatus.cuti`, but no current scheduler flow writes or displays that state as distinct from generic leave.

**Implication:** `start_hour` cannot remain the lateness baseline because the new pagi lateness cutoff is `07:00`, not `09:00`. Phase 55 needs new policy fields instead of reinterpreting the old exact-time payload.

### 2. Admin scheduler UX is already modular enough to stay additive
- `lib/screens/admin/shift_scheduler_screen.dart` still loads and saves `schedule_entries.shift_slot` JSON directly from Supabase.
- The weekly grid is already extracted into `lib/screens/admin/widgets/schedule_table_view.dart` and `lib/screens/admin/widgets/schedule_cells.dart`.
- Current empty and assigned grid cells only render band names (`Pagi`, `Siang`, `Sore`, `Libur`), which is a good seam for moving to `Band + Hours` chips without redesigning the grid.
- Bulk assign and auto-generate flows already exist, but they currently hardcode exact-time labels in dialogs and keep "Libur" as the only generic leave exception.
- The header still shows `Buka: 09:00 - 22:00`, which reinforces the stale clock-range story the phase is trying to retire.

**Implication:** the UI rewrite should be narrow. Preserve the grid and chips, but swap the cell label/data source and add a lightweight review step for policy-derived defaults.

### 3. SQLite and Supabase write paths will preserve whatever shape the model emits
- `lib/services/schedule_sqlite_service.dart` stores the entire schedule template and entry list as JSON blobs.
- `ShiftSchedulerScreen._saveSchedule()` writes `entry.shift.toJson()` directly into the `schedule_entries.shift_slot` column.
- `ShiftSchedulerScreen._loadScheduleFromSupabase()` reconstructs entries by feeding the stored JSON back into `ShiftSlot.fromJson(...)`.

**Implication:** once `ShiftSlot` grows band-first policy fields, both the local SQLite cache and Supabase write path will start carrying them automatically. The execution risk is not storage plumbing; it is coordinating all of the readers that still expect the legacy shape.

### 4. Portal schedule and recap SQL still project exact time fields from `shift_slot`
- `sql/phase_38_employee_schedule_read_model_20260322.sql` and `sql/phase_39_portal_read_path_hardening_20260323.sql` both extract `shift_name`, `start_hour`, `start_minute`, `end_hour`, and `end_minute` from `schedule_entries.shift_slot`.
- Those RPCs also derive `ends_next_day` by comparing `end_time <= start_time`, which means they still treat the old exact-time payload as canonical schedule meaning.
- `sql/phase_42_portal_attendance_recap_20260323.sql` already contains the logical-day state machine for:
  - `belum_pulang`
  - `sedang_bekerja`
  - `tidak_hadir`
  - `belum_masuk`
  - `libur`
  - unscheduled-day `hadir`

**Implication:** Phase 55 should reuse the existing recap status framework for no-show logic, but it must stop deriving policy from legacy `start_hour` values alone. The SQL layer needs additive fields or CASE mappings for band and required-hours semantics.

### 5. Admin recap models are behind the SQL status taxonomy
- `lib/models/daily_summary.dart` only supports `DailySummaryStatus.normal`, `sakit`, `izin`, and `belumPulang`.
- `lib/screens/admin/admin_reports_screen.dart` therefore cannot yet surface `tidak_hadir`, `belum_masuk`, `hadir tanpa jadwal`, or late/no-show audit tags as first-class states.
- The portal recap SQL already distinguishes prior-day gaps from current-day informational states. Admin recap should reuse that taxonomy instead of inventing a second one.

**Implication:** the phase needs a recap-facing model/status expansion, not just scheduler UI work.

### 6. Approved time off currently collapses into generic `Libur`
- `lib/models/time_off_request.dart` is explicitly a request model for "libur/cuti".
- `ShiftSchedulerScreen._loadTimeOffRequests()` loads approved `time_off_requests`, but downstream display treats them as generic `Libur`.
- `lib/screens/admin/widgets/schedule_cells.dart` renders approved time off as a `Libur` chip.
- PDF merge/export in `ShiftSchedulerScreen._exportToPdf()` also maps approved time off to `ShiftSlot.libur()` and `ScheduleStatus.libur`.

**Implication:** this is the clearest conflict with `SCHED-03`. Phase 55 must decide how approved `cuti` is represented distinctly from `libur`, or else `tidak_hadir` precedence will stay semantically wrong.

### 7. Phase 54 is a real prerequisite, not background context
- Phase 54 introduces canonical `FULLTIME` / `PARTTIME` employee contracts.
- The break-first windows in Phase 55 explicitly depend on that contract metadata.

**Implication:** planning should assume the Phase 54 model and SQL outputs are the contract source of truth. Do not re-infer hours from scan history or ad-hoc outlet heuristics.

## Standard Stack

### Core
| Library / System | Purpose | Why Standard |
|------------------|---------|--------------|
| Existing Flutter schedule stack (`Material`, `flutter_riverpod`, `two_dimensional_scrollables`) | Preserve the current weekly scheduler interaction model | The grid and callbacks already exist and do not need replacement. |
| Existing Supabase `schedule_entries.shift_slot` JSON write path | Additive carrier for new band-first fields | The app already round-trips this JSON through Dart and SQLite without extra serialization layers. |
| Existing portal recap SQL pattern | Logical-day status derivation | `phase_42` already models prior-day gaps vs current-day informational states. |
| `flutter_test` | Unit, widget, and SQL contract coverage | The repo already uses file-reading SQL contract tests and model/widget tests. |

### Supporting
| Library / System | Purpose | When to Use |
|------------------|---------|-------------|
| Shared Dart policy helpers | One canonical source for band cutoffs and break-first windows | Use anywhere Flutter surfaces need the same lateness/break-first math. |
| SQL CASE / additive RPC columns | Mirror Dart policy into portal/admin read models | Use for recap and schedule RPC compatibility during rollout. |
| Existing `ScheduleStatus` / `DailySummaryStatus` models | Surface exception states consistently | Extend instead of inventing screen-local string tags. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Additive band-first payload plus legacy compatibility fields | Rewrite `shift_slot` to band-only in one step | Cleaner long-term, but too risky while portal/admin readers still parse exact-hour fields. |
| One shared policy table/helper | Screen-local lateness checks and SQL-local CASE blocks | Faster short-term, but guarantees drift between scheduler, recap, and portal output. |
| Distinct `cuti` handling | Continue mapping approved time off to `Libur` | Simpler, but directly violates `SCHED-03` and makes absence precedence ambiguous. |

## Architecture Patterns

### Pattern 1: Band-first schedule payload with compatibility hints
**What:** Make band and required-hours the primary schedule meaning, while keeping old exact-time fields only as compatibility data for readers that have not migrated yet.
**When to use:** Every schedule row written after Phase 55.

**Recommended payload direction:**
```json
{
  "name": "Pagi",
  "band": "pagi",
  "required_hours": 8,
  "required_minutes": 480,
  "start_hour": 9,
  "start_minute": 0,
  "end_hour": 17,
  "end_minute": 0,
  "color": 4282099454
}
```

**Why:** old readers keep working, but new policy code stops treating `start_hour` as the lateness contract.

### Pattern 2: One canonical policy evaluator for lateness and break-first
**What:** Represent the business rules as one shared mapping keyed by band plus employee contract.
**When to use:** Scheduler review UIs, admin recap, portal recap, and future scan-path decisions.

**Recommended canonical inputs:**
- `shiftBand`
- `employmentContract`
- `requiredMinutes`
- `firstRelevantScanAtWita`
- whether a `break` / `kembali` pair already exists
- logical workday status (`current day` vs `completed day`)

**Recommended derived outputs:**
- `lateCutoff`
- `breakFirstDeadline`
- `isLate`
- `isBreakFirstEligible`
- `attendanceStatus`
- manager-facing audit tag(s)

### Pattern 3: Preserve status precedence as a matrix, not scattered if-statements
**What:** Encode the exception order once.
**When to use:** Recap derivation and admin audit surfaces.

**Recommended precedence:**
1. `sakit`
2. `izin`
3. `cuti`
4. `libur`
5. attendance-present states (`hadir`, `terlambat`, `belum_pulang`, break-first variants)
6. scheduled zero-log states (`belum_masuk` on active logical day, `tidak_hadir` only after day completion)
7. unscheduled attendance (`hadir tanpa jadwal`)

**Why:** this keeps `tidak_hadir` as a fallback, not a competing exception.

### Pattern 4: Keep the scheduler operational style unchanged
**What:** Reuse the weekly grid, quick chips, auto-generate templates, and bulk assign.
**When to use:** Admin UI work for this phase.

**Required UX shifts:**
- Cells display `Band + required hours` instead of exact ranges.
- Shift picker and bulk-assign surfaces show policy summaries rather than exact-time labels.
- Bulk assign gets a short review/confirmation step before writing contract-derived defaults.
- Policy summary sits in a header/detail surface, not repeated as dense text in each cell.

### Pattern 5: Extend read models additively
**What:** Update SQL RPCs to emit the new policy semantics without removing the old fields immediately.
**When to use:** `get_portal_schedule_week`, `get_portal_schedule_overview`, and `get_portal_attendance_recap`.

**Recommended additive outputs:**
- `shift_band`
- `required_hours` or `required_minutes`
- manager/audit tags for late vs break-first vs no-show
- any no-show override reason already resolved from `sakit` / `izin` / `cuti` / `libur`

**Why:** existing portal/admin consumers can migrate gradually instead of through one risky breaking change.

## Recommended Project Structure

```text
sql/
├── phase_55_schedule_policy_absence_rules_20260326.sql
├── phase_38_employee_schedule_read_model_20260322.sql
├── phase_39_portal_read_path_hardening_20260323.sql
└── phase_42_portal_attendance_recap_20260323.sql

lib/models/
├── shift_schedule.dart
├── daily_summary.dart
└── time_off_request.dart

lib/services/
├── schedule_sqlite_service.dart
└── [new] schedule_policy_service.dart

lib/screens/admin/
├── shift_scheduler_screen.dart
├── admin_reports_screen.dart
└── widgets/
   ├── schedule_cells.dart
   ├── schedule_table_view.dart
   └── [new] schedule_policy_summary.dart

test/
├── models/
│  ├── shift_schedule_test.dart
│  └── [new] schedule_policy_service_test.dart
├── screens/admin/
│  ├── rekap_harian_test.dart
│  └── [new] schedule_policy_grid_test.dart
└── phase55/
   └── [new] schedule_policy_sql_contract_test.dart
```

## Common Pitfalls

### Pitfall 1: Reusing `start_hour` as the lateness source of truth
**What goes wrong:** pagi remains effectively "late after 09:00" even though the phase locked a `07:00` cutoff.
**How to avoid:** create dedicated band policy cutoffs and treat old exact hours as compatibility-only data.

### Pitfall 2: Letting Dart and SQL drift
**What goes wrong:** the scheduler says a scan is valid break-first while the recap SQL marks the same day late or absent.
**How to avoid:** derive both sides from the same band/contract mapping and verify it with SQL contract tests.

### Pitfall 3: Marking the active day as `tidak_hadir`
**What goes wrong:** a currently scheduled employee shows as absent before the logical workday ends.
**How to avoid:** keep the existing `belum_masuk` vs `tidak_hadir` split from `phase_42` and extend it, do not rewrite it from scratch.

### Pitfall 4: Treating approved time off as plain `Libur`
**What goes wrong:** `cuti` disappears, so `tidak_hadir` overrides become semantically wrong and audit review loses the real reason.
**How to avoid:** represent approved time off distinctly and only collapse to `libur` when the business rule explicitly says so.

### Pitfall 5: Replacing the scheduler workflow with a form-heavy UI
**What goes wrong:** kepala gerai lose the quick weekly assignment flow the user explicitly wants to preserve.
**How to avoid:** keep the grid/chip workflow and move complexity into summary/review surfaces, not cell editing.

## Validation Architecture

Phase 55 should start with Wave 0 verification assets before the behavior change lands. This phase touches both Flutter UI and SQL contract logic, so the test strategy has to cover model serialization, recap status precedence, and SQL file-level contract guarantees in the same wave.

### Recommended automated coverage
- `test/models/schedule_policy_service_test.dart`
  - band cutoff mapping for pagi / siang / sore
  - contract-aware break-first windows
  - minute-precision late evaluation
- `test/models/shift_schedule_test.dart`
  - additive schedule payload round-trips with new policy fields
  - `cuti` / `libur` distinction survives serialization
- `test/screens/admin/schedule_policy_grid_test.dart`
  - scheduler cells render `Band + Hours`
  - bulk assign review summary shows policy-derived defaults
- `test/screens/admin/rekap_harian_test.dart`
  - `belum_masuk` stays informational on the active day
  - `tidak_hadir` only appears for prior scheduled zero-log days
  - exception precedence preserves `sakit`, `izin`, `cuti`, `libur`
- `test/phase55/schedule_policy_sql_contract_test.dart`
  - verifies the phase SQL adds band/required-hours outputs
  - verifies recap/read-model SQL preserves `belum_masuk` / `tidak_hadir` distinctions
  - verifies no contract test silently removes the legacy `start_hour` / `end_hour` compatibility fields in the same pass

### Recommended manual checks
- Weekly grid still supports quick chip assignment and template generation.
- Bulk assign shows the short review step before confirmation.
- Admin audit surface can filter late arrivals separately from break-first exceptions.
- A scheduled active-day employee with no scans shows `belum_masuk`, not `tidak_hadir`.
- An approved `cuti` day never coexists with `tidak_hadir`.

### Recommended execution ordering
1. Add shared policy helpers and tests first.
2. Migrate scheduler model/write path second.
3. Migrate admin recap model/status surfaces third.
4. Migrate SQL read models last, with contract tests guarding backward compatibility.

## Planning Notes

- The user explicitly requested a UI design contract before planning continues.
- `55-UI-SPEC.md` should be generated before any `55-PLAN.md` files are created.
- Once `55-UI-SPEC.md` exists, the next `gsd-plan-phase 55` run can reuse this research artifact and skip the research prompt.

---

*Phase: 55-schedule-policy-absence-rules*
*Research fallback: local orchestrator analysis after subagent shutdown on Windows*
