# Phase 57: Strict Recap Evaluation Engine - Research

**Researched:** 2026-03-27
**Domain:** overnight-safe strict attendance evaluation across Supabase recap SQL, typed Flutter recap models, and the existing admin recap surface
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- `TWENTY_FOUR_HOUR` outlets may carry scans after midnight onto the previous logical workday until a clearly new work context begins.
- `NORMAL` outlets do not use overnight carry-forward and stay bound to same-day attendance grouping.
- Manager exemption comes from the employee's stored `position`, not auth role metadata.
- Kepala toko / kepala gerai rows remain visible but do not become red for lateness, short work, or excess break.
- `late` remains a red strict signal.
- `absence` remains a red strict signal.
- Strict recap must keep one primary status plus additional detail signals instead of collapsing everything into one generic label.
- Total break time must be derived from real `break -> kembali` pairs.
- Net work duration is `first masuk -> final pulang - paired break total`.
- Overtime is evaluated from final net work duration.
- Active logical workdays stay informational only until the logical day actually ends.
- Historical incomplete chains may become red once the logical workday has ended.
- At `NORMAL` outlets, `break` without `kembali` by day end is treated as a missing clock-out / `belum absen pulang`, not finalized excess break.
- `hadir_tanpa_jadwal` stays a dedicated signal while still using contract-based work and break thresholds.
- `PARTTIME` overtime days use the 2-hour break allowance.

### Claude's Discretion
- Exact SQL helper names and CTE structure, as long as one canonical engine owns logical-day grouping and strict signal calculation.
- Exact tie-break order when multiple signals share the same severity, as long as it is deterministic and documented.
- Exact Dart enum shapes and widget composition for primary-versus-detail signals.
- Exact operator-facing copy for exempt, incomplete, and unscheduled rows.

### Deferred Ideas (OUT OF SCOPE)
- Payroll matrix redesign, spreadsheet export, and PDF parity belong to Phases 58-59.
- Portal recap parity belongs to Phase 59.
- Payroll amount calculation or approval workflow is outside this phase.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| `CONTRACT-03` | Kepala toko / kepala gerai attendance records stay exempt from lateness, short-work, and excess-break red flags even when they still appear in recap outputs. | The strict engine must read `employees.position`, classify exempt titles in SQL, keep rows visible, and surface exemption as a first-class signal or marker instead of suppressing the row. |
| `RECAP-01` | Rekap Harian groups afternoon-to-morning sessions into one logical workday at 24-hour outlets so masuk, break, kembali, and pulang stay attached after midnight. | The current recap SQL still groups attendance by local calendar date, so Phase 57 needs ordered event-chain grouping keyed by outlet operating mode rather than plain `(scanned_at AT TIME ZONE 'Asia/Makassar')::date`. |
| `RECAP-02` | Full-time employees turn red when net work is below 10 hours or total break exceeds 2 hours by even 1 minute, and overtime above the required work duration turns yellow instead of red. | The engine must compute paired break totals, net work minutes, short-work minutes, excess-break minutes, and overtime minutes from authoritative scan history. |
| `RECAP-03` | Part-time employees turn red when net work is below 9 hours or total break exceeds the allowed contract window, and part-time overtime days can use the 2-hour break allowance when the day is classified as overtime. | The engine cannot treat part-time break allowance as fixed; it must branch on final overtime classification after net-work calculation. |
| `RECAP-04` | Recap outcomes distinguish late arrival, short work, excess break, overtime, absence, and exempt-manager cases as separate evaluation signals instead of one generic status. | SQL, Dart models, and the admin recap list all need a primary-plus-detail signal contract rather than the current `attendance_status + late_kind` pair. |
</phase_requirements>

## Summary

Phase 57 is the first place the project needs one canonical recap engine instead of loosely related schedule and scan signals. Phase 55 introduced schedule policy inputs, and Phase 56 introduced authoritative scan intent plus replay provenance, but the actual recap path still groups attendance strictly by local calendar date and still returns only `attendance_status`, `late_kind`, and a few booleans. That is not enough to model overnight chains, paired-break work math, manager exemption, or the requirement to keep multiple strict payroll signals on the same day.

The safest implementation path is additive and centralized:

1. Replace the current Phase 56 recap SQL with a stricter `CREATE OR REPLACE FUNCTION public.get_admin_schedule_policy_recap(...)` that keeps the RPC name stable but grows the payload.
2. Derive logical workdays from ordered authoritative attendance chains and outlet operating mode, not from plain WITA dates.
3. Return one primary status plus detail signals and quantitative work/break metrics from SQL so Dart and widgets do not re-implement payroll logic.
4. Extend the existing typed recap model and service to parse the richer payload while keeping staged-rollout compatibility with legacy rows.
5. Preserve the existing admin report list-card layout, but upgrade it from one badge and a few late filters to primary/detail signal rendering.

**Primary recommendation:** split Phase 57 into three execution waves: SQL engine first, typed Dart contract second, and admin presentation last.

## Existing Code Findings

### 1. Current admin recap SQL is still calendar-date based
- `sql/phase_56_server_time_scan_authority_20260327.sql` replaces `get_admin_schedule_policy_recap(...)`, but it still builds `attendance_rows` with `(al.scanned_at AT TIME ZONE 'Asia/Makassar')::date AS logical_date`.
- `schedule_rows` uses `se.date AS logical_date`, and the merge key is only `(logical_date, employee_id)`.
- That means overnight 24-hour chains still split at midnight even after Phase 56.

**Implication:** `RECAP-01` cannot be solved in Dart or widgets. The SQL recap engine itself must reassign overnight events onto a chain-owned logical day.

### 2. Phase 56 already captured the authoritative scan metadata Phase 57 needs
- `attendance_logs` now stores `capture_mode`, `queue_order`, `initial_scan_intent`, and `requires_admin_review`.
- The Phase 56 recap SQL already reads the first relevant `initial_scan_intent` to decide `break_first_confirmed`.
- The kiosk contract already distinguishes live confirmed events from queued replay.

**Implication:** Phase 57 should reuse that authoritative event history instead of inventing a second "strict recap events" table.

### 3. Schedule policy inputs are already centralized enough for strict thresholds
- `lib/services/schedule_policy_service.dart` and `sql/phase_55_schedule_policy_foundation_20260326.sql` already define contract-aware work requirements and break-first windows.
- `ShiftSlot` already carries `required_work_minutes`, `late_cutoff_hour`, and `break_first_deadline_hour`.
- `Employee.employmentContract` is typed and already available in shared model code.

**Implication:** Phase 57 should consume stored schedule policy values and contract metadata, not infer required hours from attendance history again.

### 4. Manager exemption source already exists, but only as free-text job title
- `lib/models/employee.dart` exposes `position`.
- No separate manager-role field exists in current recap models or auth metadata for payroll logic.

**Implication:** the strict engine needs a normalized `position` matcher in SQL, likely `ILIKE` or normalized text checks for `kepala toko` and `kepala gerai`.

### 5. The current Dart recap contract is too narrow
- `lib/models/attendance_policy_recap_day.dart` only exposes `attendanceStatus`, `lateKind`, `isLate`, `breakFirstEligible`, and `breakFirstConfirmed`.
- There is no place for:
  - primary strict status
  - multiple detail signals
  - manager exemption marker
  - quantitative work/break metrics
  - incomplete-chain reason

**Implication:** Phase 57 needs a new typed strict-signal layer, not just a few extra booleans on the existing model.

### 6. The admin recap UI currently assumes one badge and fixed late/no-show filters
- `lib/screens/admin/admin_reports_screen.dart` filters by `terlambat`, `breakFirst`, `belumMasuk`, `tidakHadir`, and `hadirTanpaJadwal`.
- `_PolicyRecapTile` renders exactly one `AttendancePolicyBadge`.
- `_reasonCopy()` only knows how to explain late, break-first, belum masuk, tidak hadir, hadir tanpa jadwal, or generic hadir.

**Implication:** Phase 57 can preserve the list-card surface, but it must switch filters and row copy to the new strict-signal model.

### 7. Existing tests only cover the Phase 55/56 contract
- `test/services/attendance_policy_recap_service_test.dart` checks parsing for `belum_masuk`, `tidak_hadir`, and `late_kind`.
- `test/widgets/attendance_policy_badge_test.dart` only checks `Terlambat`, `Kandidat break-first`, `Break-first`, `Tidak hadir`, and `Belum masuk`.
- There is no SQL contract test for Phase 57 and no model test for strict signal arrays or metrics.

**Implication:** Wave 0 validation gaps exist and should be handled explicitly in plans and `57-VALIDATION.md`.

## Standard Stack

### Core
| Library / System | Purpose | Why Standard |
|------------------|---------|--------------|
| Existing PostgreSQL RPC + helper-function pattern | Canonical strict recap engine | Phases 55-56 already keep schedule and recap rules inside SQL helpers and RPCs. |
| Existing `AttendancePolicyRecapService` unwrapping pattern | Typed Flutter gateway for recap RPC data | The app already centralizes RPC parsing in one service instead of in screens. |
| Existing admin report list-card UI | Minimal-scope strict recap presentation | The screen already owns filters, empty states, export controls, and recap rows. |
| `flutter_test` plus static SQL contract tests | Fast regression coverage | The repo already uses file-reading contract tests and targeted widget/service tests. |

### Supporting
| Library / System | Purpose | When to Use |
|------------------|---------|-------------|
| `attendance_logs.initial_scan_intent` | Distinguish break-first intent from plain late arrival | Use when deriving detail signals or informational notes. |
| `employees.position` | Determine manager exemption | Use only in the SQL engine and typed recap payload. |
| `outlets.operating_mode` | Drive logical-day grouping rules | Use in SQL grouping only; do not duplicate the rule in widgets. |
| `SchedulePolicyService` and Phase 55 schedule JSON keys | Reuse stored contract-aware work thresholds | Use as the source of truth for required minutes and break allowances. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SQL-owned logical-day grouping | Client-side post-processing in Dart | Easier to prototype, but guaranteed drift between admin views, exports, and future portal parity. |
| Primary status plus detail signals | One expanded generic `attendance_status` string | Simpler schema, but it fails `RECAP-04` and loses payroll audit detail. |
| Position-based exemption matcher | Auth-role-based exemption | Cleaner auth logic, but the user explicitly rejected auth role as the exemption source. |

## Architecture Patterns

### Pattern 1: One canonical logical-workday engine in SQL
**What:** Build ordered relevant attendance chains per employee/outlet, then assign each chain to a logical day based on outlet mode and whether the prior chain is closed.

**When to use:** Any strict recap grouping for `masuk`, `break`, `kembali`, and `pulang`.

**Recommended behavior:**
- `NORMAL`: `logical_date = local scan date`.
- `TWENTY_FOUR_HOUR`: post-midnight events stay attached to the chain's first `masuk` date until the prior chain is closed by `pulang` or a clearly new `masuk` starts a new chain.
- Time-off statuses (`sakit`, `izin`, `cuti`, `libur`) stay schedule-owned and do not need attendance-chain grouping.

### Pattern 2: Pair breaks from ordered events, not from the outer time envelope
**What:** Match each `break` to the next unmatched `kembali` inside the same logical chain.

**When to use:** Computing `total_break_minutes`, `net_work_minutes`, and incomplete-chain handling.

**Recommended behavior:**
- Paired `break -> kembali` intervals contribute to `total_break_minutes`.
- An unmatched `break` on a still-active logical day creates an informational incomplete state.
- An unmatched `break` on a finished `NORMAL` day becomes `belum_absen_pulang`, not `excess_break`.

### Pattern 3: Separate strict signals from primary outcome
**What:** Keep one primary status for severity ordering and a separate array of detail signals for payroll audit context.

**When to use:** SQL output, typed recap models, admin filters, and later spreadsheet export.

**Recommended signal vocabulary:**
- `late`
- `short_work`
- `excess_break`
- `overtime`
- `absence`
- `exempt_manager`
- `hadir_tanpa_jadwal`
- `belum_absen_pulang`
- `active_incomplete`
- `break_first_confirmed`

**Recommended primary-status tie-break order when severity is equal:**
1. `absence`
2. `belum_absen_pulang`
3. `short_work`
4. `excess_break`
5. `late`
6. `overtime`
7. `hadir_tanpa_jadwal`
8. `exempt_manager`
9. `hadir`

This is not user-locked, but it is deterministic and aligns with payroll-risk ordering.

### Pattern 4: Exemption is suppressive, not destructive
**What:** Keep exempt-manager rows visible and keep detail notes about late / short-work / excess-break behavior, but suppress those red signals from becoming the penal primary outcome.

**When to use:** Any strict day where `position` indicates kepala toko / kepala gerai.

**Recommended behavior:**
- If only exempted red signals are present, make `primary_status = exempt_manager`.
- Keep suppressed details in `detail_signals` and/or `detail_notes`.
- Do not suppress `absence` or `overtime`.

### Pattern 5: Keep legacy fields until the UI migration is complete
**What:** Return legacy Phase 55/56 fields (`attendance_status`, `late_kind`, `is_late`, `break_first_eligible`, `break_first_confirmed`) together with the new strict fields.

**When to use:** The first Phase 57 SQL and Dart contract rollout.

**Why:** This lets the service and widgets migrate incrementally without breaking the screen during staged rollout.

## Recommended Project Structure

```text
sql/
├── phase_57_strict_recap_evaluation_engine_20260327.sql

lib/models/
├── attendance_policy_signal.dart
└── attendance_policy_recap_day.dart

lib/services/
└── attendance_policy_recap_service.dart

lib/widgets/
├── attendance_policy_badge.dart
└── attendance_policy_signal_chip.dart

lib/screens/admin/
└── admin_reports_screen.dart

test/
├── phase57/
│  └── strict_recap_sql_contract_test.dart
├── models/
│  └── attendance_policy_recap_day_test.dart
├── services/
│  └── attendance_policy_recap_service_test.dart
├── widgets/
│  └── attendance_policy_badge_test.dart
└── screens/admin/
   └── admin_reports_policy_recap_test.dart
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Overnight chain grouping | Widget-side date heuristics | SQL-owned logical-day assignment keyed by `operating_mode` | The same grouped day must later feed admin, export, and portal surfaces. |
| Manager exemption | Auth-role lookup or screen-local string checks | One SQL matcher over `employees.position` plus typed recap fields | Keeps exemption deterministic and auditable. |
| Detail-signal rendering | Another generic string badge | Primary badge + reusable detail-signal chips | Matches `RECAP-04` without collapsing the row back to one label. |
| Break math | First-break to last-return envelope | Real paired `break -> kembali` intervals | The user explicitly rejected the envelope approximation. |

## Common Pitfalls

### Pitfall 1: Midnight still acts like a hard reset for 24-hour outlets
**What goes wrong:** one real shift becomes two recap rows, which creates false overtime or zero-work outcomes.
**How to avoid:** assign events to logical chains before deriving the recap day.

### Pitfall 2: Unmatched `break` becomes fake excess break
**What goes wrong:** a missing `kembali` or `pulang` looks like an all-day break duration.
**How to avoid:** only paired breaks count toward break minutes; unmatched breaks become incomplete-state logic.

### Pitfall 3: Exempt managers disappear instead of staying auditable
**What goes wrong:** the recap hides the row, which solves red flags but destroys payroll transparency.
**How to avoid:** keep the row and surface `exempt_manager` as a visible non-penal marker.

### Pitfall 4: Current-day incomplete chains become final red states too early
**What goes wrong:** an active shift gets labeled red even though the employee has not finished the day.
**How to avoid:** gate red incomplete outcomes on `logical_day_complete = true`.

### Pitfall 5: Widgets re-implement business rules from raw metrics
**What goes wrong:** SQL and Flutter disagree on what the same row means.
**How to avoid:** SQL decides signals and severity; widgets only map typed fields to filters and copy.

## Code Examples

### Recommended recap payload direction
```json
{
  "logical_date": "2026-03-26",
  "attendance_status": "hadir",
  "late_kind": "none",
  "primary_status": "exempt_manager",
  "primary_severity": "info",
  "detail_signals": ["late", "short_work", "exempt_manager"],
  "detail_notes": [
    "late after 07:00",
    "short work below 600 minutes",
    "position kepala gerai is exempt from red penalty"
  ],
  "is_manager_exempt": true,
  "manager_position": "Kepala Gerai",
  "logical_day_complete": true,
  "incomplete_reason": null,
  "net_work_minutes": 540,
  "total_break_minutes": 45,
  "overtime_minutes": 0,
  "short_work_minutes": 60,
  "excess_break_minutes": 0,
  "paired_break_count": 1
}
```

### Recommended SQL grouping direction
```sql
WITH ordered_events AS (
  SELECT
    al.employee_id,
    al.scan_outlet_id,
    o.operating_mode,
    al.type,
    al.initial_scan_intent,
    al.scanned_at AT TIME ZONE 'Asia/Makassar' AS scanned_local,
    ROW_NUMBER() OVER (
      PARTITION BY al.employee_id, al.scan_outlet_id
      ORDER BY al.scanned_at, al.id
    ) AS event_ordinal
  FROM public.attendance_logs al
  JOIN public.outlets o ON o.id = al.scan_outlet_id
)
-- assign a chain anchor date before aggregating to recap rows
```

## Open Questions

1. **Should the SQL patch keep the RPC name `get_admin_schedule_policy_recap` or introduce a new strict RPC name?**
   - What we know: the existing service already calls `get_admin_schedule_policy_recap`.
   - Recommendation: keep the RPC name stable and widen the return payload. That minimizes screen churn and staged rollout risk.

2. **How should equal-severity signals break ties?**
   - What we know: the user only locked "highest severity wins".
   - Recommendation: use the documented deterministic order in Pattern 3 so payroll-risk signals beat informative ones consistently.

3. **Should the admin screen render detail signals as more badges or plain text?**
   - What we know: the current UI already uses pills and small chips effectively.
   - Recommendation: keep one primary badge plus secondary chips. It fits the existing layout better than a second line of prose-only notes.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` plus static SQL contract file assertions |
| Config file | `analysis_options.yaml` |
| Quick run command | `C:\flutter\bin\flutter.bat test test/phase57/strict_recap_sql_contract_test.dart test/models/attendance_policy_recap_day_test.dart test/services/attendance_policy_recap_service_test.dart test/widgets/attendance_policy_badge_test.dart` |
| Full suite command | `C:\flutter\bin\flutter.bat test` |
| Estimated runtime | ~120 seconds |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| `RECAP-01` | 24-hour outlets keep overnight chains on one logical day | contract | `C:\flutter\bin\flutter.bat test test/phase57/strict_recap_sql_contract_test.dart` | ❌ Wave 0 |
| `CONTRACT-03` | manager exemption stays visible but non-penal | unit | `C:\flutter\bin\flutter.bat test test/models/attendance_policy_recap_day_test.dart` | ❌ Wave 0 |
| `RECAP-02`, `RECAP-03` | work/break/overtime metrics and primary/detail signal parsing stay typed | unit | `C:\flutter\bin\flutter.bat test test/services/attendance_policy_recap_service_test.dart` | ✅ |
| `RECAP-04` | primary badge plus detail-signal rendering remains stable | widget | `C:\flutter\bin\flutter.bat test test/widgets/attendance_policy_badge_test.dart` | ✅ |
| `CONTRACT-03`, `RECAP-04` | admin recap filters and copy reflect manager exemption and multi-signal rows | widget | `C:\flutter\bin\flutter.bat test test/screens/admin/admin_reports_policy_recap_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** run the task-local automated command plus the quick run command when SQL and Dart contracts changed together
- **Per wave merge:** run `C:\flutter\bin\flutter.bat test`
- **Phase gate:** run `C:\flutter\bin\flutter.bat test` before `$gsd-verify-work`

### Wave 0 Gaps
- `test/phase57/strict_recap_sql_contract_test.dart` - guard the new SQL helper names, RPC fields, and logical-day keywords
- `test/models/attendance_policy_recap_day_test.dart` - typed signal, severity, and legacy-compatibility parsing coverage
- `test/screens/admin/admin_reports_policy_recap_test.dart` - recap filter and detail-chip rendering coverage

## Sources

### Primary (HIGH confidence)
- [sql/phase_56_server_time_scan_authority_20260327.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase_56_server_time_scan_authority_20260327.sql) - current authoritative recap RPC and attendance-log authority fields
- [sql/phase_55_admin_policy_recap_20260326.sql](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase_55_admin_policy_recap_20260326.sql) - pre-Phase 56 admin recap baseline
- [lib/models/attendance_policy_recap_day.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/models/attendance_policy_recap_day.dart) - current typed recap row contract
- [lib/services/attendance_policy_recap_service.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/services/attendance_policy_recap_service.dart) - current recap RPC gateway
- [lib/screens/admin/admin_reports_screen.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/screens/admin/admin_reports_screen.dart) - current filter and recap presentation surface
- [lib/widgets/attendance_policy_badge.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/widgets/attendance_policy_badge.dart) - current single-badge recap widget
- [lib/models/employee.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/models/employee.dart) - current `position` and `employmentContract` source of truth

### Secondary (MEDIUM confidence)
- [lib/services/schedule_policy_service.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/services/schedule_policy_service.dart) - contract-aware work and break policy helpers
- [lib/models/shift_schedule.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/models/shift_schedule.dart) - stored schedule policy fields already available to recap SQL
- [test/services/attendance_policy_recap_service_test.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/test/services/attendance_policy_recap_service_test.dart) - current recap parsing coverage
- [test/widgets/attendance_policy_badge_test.dart](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/test/widgets/attendance_policy_badge_test.dart) - current badge rendering coverage

### Tertiary (LOW confidence)
- None - this research relied on direct repository evidence and locked user decisions.

## Metadata

**Confidence breakdown:**
- SQL engine direction: HIGH - the repo already centralizes recap logic in SQL, and the missing logic is clearly visible in the current patch.
- Dart contract direction: HIGH - the current model and service are small, typed seams that are ready for additive growth.
- Admin presentation direction: HIGH - the existing report screen already has the right surface area; it only needs a richer recap contract.

**Research date:** 2026-03-27
**Valid until:** 2026-04-26
