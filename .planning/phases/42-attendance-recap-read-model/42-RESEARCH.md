# Phase 42: Attendance Recap Read Model - Research

**Researched:** 2026-03-23
**Domain:** Employee-scoped portal attendance recap RPCs, logical-day grouping, and typed portal read-model normalization
**Confidence:** HIGH for portal auth/scoping, HIGH for reuse of existing daily recap semantics, MEDIUM for edge cases on unscheduled attendance-only days

## Summary

Phase 42 should not bolt raw `attendance_logs` onto the website. The secure portal path already exists in Phases 37-39, and the missing piece is a dedicated recap contract that merges attendance facts with schedule context into one employee-scoped day model.

The safest shape is:

1. add one additive SQL read model that resolves the authenticated portal employee internally and returns one recap row per logical day
2. preserve the current product rule for overnight handling by reattaching next-day pre-noon `pulang` activity to the prior logical workday instead of applying a blanket "hour < 12 means previous day" transform to every attendance type
3. add one portal helper in the website repo that normalizes the recap rows and derives month-to-date summary counts plus recent history from that same dataset

The current portal helper (`get_portal_schedule_overview`) is not enough for this milestone. It returns a two-week schedule-oriented overview with a small `sakit`/`izin` overlay, but it does not expose the per-day attendance timestamps, completion state, or history horizon needed for an attendance recap.

The strongest implementation anchor is the shipped admin Rekap Harian logic. The Flutter admin screen already groups raw scans into daily summaries, computes `firstMasuk`, `lastPulang`, total break duration, `sakit`/`izin`, and a `belumPulang` state, and performs the exact overnight repair that Phase 42 needs: orphan next-day `pulang` records before noon are attached back to the prior logical day if that day already has the matching work session context.

**Primary recommendation:** Build Phase 42 around one authenticated recap RPC plus one typed website helper. Keep the output row-based, not JSON-aggregated, so Phase 43 can render day-by-day history and derive summary counts from the same normalized dataset without introducing a second portal query path.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ATTN-02 | Each recap day shows the recorded attendance outcome together with the available attendance timestamps for that logical workday. | The admin Rekap Harian logic already proves the required timestamp set: `firstMasuk`, `lastPulang`, paired break duration, scan count, and notes can be normalized into one portal recap row per logical day. |
| ATTN-03 | Portal attendance recap applies the product's existing logical-day and overnight handling so cross-day attendance appears on the correct workday. | The current product rule is narrower than a generic timezone transform: overnight repair is specifically about keeping next-day pre-noon completion scans attached to the prior workday. The recap contract should reuse that rule instead of inventing a new calendar bucketing rule. |

## Current State Analysis

### 1. Portal auth and employee scoping already exist

The portal path already has the required trust boundary:

- `resolve_portal_employee()` in SQL
- `resolvePortalEmployee()` in the Astro website
- middleware that verifies the portal session server-side
- authenticated RPC ACL hardening from Phase 39

Phase 42 should build on that boundary. The recap RPC must never accept `employee_id`, query params, or any other caller-controlled identity input.

### 2. The current portal overview is schedule-first, not recap-first

Phase 39 introduced `get_portal_schedule_overview(reference_date date default null)`, which is good enough for "jadwal hari ini / minggu ini / minggu depan", but it is intentionally incomplete for a recap use case:

- it fetches only the current and next ISO week
- it overlays only `sakit` / `izin` attendance states
- it does not expose `firstMasuk`, `lastPulang`, break timing, work duration, or daily scan counts
- it does not represent scheduled past days with incomplete attendance as a dedicated outcome

That means Phase 42 should add a new recap contract instead of trying to stretch the current overview helper into a second responsibility.

### 3. The admin Rekap Harian logic already defines the closest shipped daily-attendance semantics

`lib/screens/admin/admin_reports_screen.dart` contains the most concrete recap behavior in the product today:

- groups raw scans by employee plus logical day
- reattaches orphan next-day `pulang` scans before noon back to the prior day
- captures `firstMasuk` and `lastPulang`
- pairs `breakTime` with `kembali` to calculate break duration
- computes `workDuration`
- labels `sakit`, `izin`, and `belumPulang`

Phase 42 should reuse that semantic model at the SQL/read-contract layer so the portal recap does not drift from the admin recap already used operationally.

### 4. Attendance data is rich enough for recap without new tables

The existing data sources already cover the recap job:

- `attendance_logs`
  - `type` includes `masuk`, `break`, `kembali`, `pulang`, `sakit`, `izin`
  - `scanned_at` is the raw event timestamp
  - `notes` can explain `sakit` / `izin` and other exceptional events
- `schedule_entries` + `schedules`
  - define the expected logical workday
  - expose shift name and start/end times
  - already encode overnight shifts via `end <= start`

No new storage system is required. The work is to normalize these sources into one trusted recap row per logical day.

### 5. The existing logical-day rule is not "all early-morning scans belong to yesterday"

The product's logical-day behavior is more specific than a broad timezone rule:

- streak aggregation uses a noon-rule concept for `masuk`
- admin Rekap Harian reattaches only orphan next-day `pulang` scans before noon to the prior day
- portal schedule visibility already anchors overnight shifts to the scheduled start date

For Phase 42, the safest rule is:

- keep the recap day anchored to the scheduled or session start day
- repair next-day pre-noon completion scans onto that prior logical day
- avoid re-bucketing every early-morning event onto the previous date, because that would corrupt genuine early shifts

### 6. The website repo already has the right extension point for a typed recap helper

The Astro portal already uses server-side helpers for read models:

- `src/lib/portal/employee.ts`
- `src/lib/portal/schedule.ts`
- `src/lib/portal/home.ts`

Phase 42 can add a sibling helper such as `src/lib/portal/attendance-recap.ts` that:

- reuses the business-local reference date helper
- calls the recap RPC once
- derives summary counts and recent history from one normalized row set
- stays unused by the UI until Phase 43 wires the surface

## Recommended Architecture

### Pattern 1: One recap row per logical day from merged schedule and attendance day facts

The recap read model should merge two day-scoped sources:

- scheduled days from `schedule_entries` / `schedules`
- attendance-derived day facts from `attendance_logs`

Result: one row per logical date with enough schedule context and enough attendance timestamps to explain the day outcome.

This row should preserve days that matter to later phases:

- scheduled day with complete attendance
- scheduled day with incomplete attendance
- scheduled day with no scan
- `sakit` / `izin` day
- attendance-only day when logs exist without a matching schedule row

### Pattern 2: Use one history horizon that supports both month counts and recent history

Phase 43 needs:

- month-to-date summary counts
- recent day-by-day history

The cleanest shape is to fetch one row set where:

- `effective_date` is the business-local reference date
- `month_start` is the first day of the current month
- `history_start` is the earlier of `month_start` and `effective_date - 13 days`

That gives:

- enough rows to derive current-month counts from the same dataset
- at least a two-week recent history even early in a month
- one stable query shape instead of a month query plus a history query

### Pattern 3: Return named timestamps and day facts, not one opaque JSON blob

Recommended row fields:

- `logical_date`
- `has_schedule`
- `is_day_off`
- `outlet_id`, `outlet_name`
- `shift_name`
- `start_hour`, `start_minute`, `end_hour`, `end_minute`
- `ends_next_day`
- `attendance_status`
- `first_masuk_at`
- `first_break_at`
- `last_kembali_at`
- `last_pulang_at`
- `total_break_minutes`
- `work_minutes`
- `scan_count`
- `notes`

Row-based output is easier to:

- normalize in TypeScript
- inspect in SQL smoke checks
- extend in Phase 44 without redesigning a nested payload

### Pattern 4: Keep logical-day repair explicit and local to the recap contract

The recap RPC should make the overnight rule obvious in code:

- collect raw attendance facts in local business time
- attach pre-noon next-day `pulang` activity back to the prior logical day when the prior day has the matching work context
- compute `work_minutes` and `total_break_minutes` after the logical-day repair

This mirrors shipped behavior better than hiding the rule inside ad hoc client logic.

### Pattern 5: Derive month summary counts in the website helper, not a second SQL query

The Phase 42 portal helper should return a typed model such as:

- `referenceDate`
- `monthStart`
- `summaryCounts`
- `recentDays`
- `days`

`summaryCounts` should be derived from the same normalized day rows, filtered to `logicalDate >= monthStart`.

That keeps the Phase 43 surface consistent:

- summary chips and history cards come from one fetched dataset
- no second RPC can drift in status rules or logical-day grouping

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| PostgreSQL additive migration | existing project pattern | Portal attendance recap RPC and supporting index | Matches live production safety rules: additive only, rerunnable where possible. |
| Supabase `SECURITY DEFINER` RPC | existing project pattern | Employee-scoped recap retrieval | Preserves the Phase 39 trust boundary and keeps identity resolution server-side. |
| Astro 5 SSR helper | existing website repo | Typed recap normalization for later portal UI work | Matches existing portal schedule/helper architecture. |
| TypeScript typed model | existing website repo | Normalize rows into summary + history data | Keeps the eventual recap page free of raw row casting. |

### Supporting

| Tool / Pattern | Purpose | When to Use |
|----------------|---------|-------------|
| Composite attendance index | Speed employee-scoped history reads | Add an index on attendance facts by employee and scan time for the recap window. |
| Shared portal date helper | Keep business-local reference date consistent | Reuse `getPortalReferenceDate()` so schedule and recap do not diverge. |
| PowerShell source-contract smoke checks | Fast verification for SQL/helper shape | Use after each task before the full website build. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| New recap-specific RPC | Stretch `get_portal_schedule_overview` further | Reuses an existing name, but mixes schedule-home concerns with recap history and makes future drift harder to reason about. |
| Employee-scoped `SECURITY DEFINER` RPC | Browser-side raw attendance log queries | Faster to prototype, but breaks the portal trust boundary and over-fetches sensitive attendance data. |
| Explicit orphan-`pulang` repair | Blanket "hour < 12 means previous day" bucketing | Simpler SQL, but incorrect for legitimate early shifts and broader than the current product rule. |
| Row-based daily facts | One JSON aggregate response | Smaller app code, but harder to test, type, and extend across Phase 43/44. |
| Helper-derived month counts | Separate month summary RPC | Could shrink helper logic, but introduces a second query shape that can drift from history status rules. |

## Anti-Patterns to Avoid

- **Do not accept `employee_id` from the portal page, route params, or query string.**
- **Do not read raw `attendance_logs` from the website with service-role or broad table access.**
- **Do not replace the current product rule with a new generic logical-day algorithm just because it looks simpler in SQL.**
- **Do not compute summary counts from one query and history rows from another query.**
- **Do not make Phase 42 a UI phase.** The recap surface belongs to Phase 43.
- **Do not regress the shipped `/portal` schedule path while adding recap support.**

## Do Not Hand-Roll

| Problem | Do Not Build | Use Instead | Why |
|---------|--------------|-------------|-----|
| Portal recap auth | Client-picked employee filter | Authenticated `SECURITY DEFINER` recap RPC | Keeps the recap scoped to the signed-in portal account. |
| Logical-day grouping | Ad hoc date math in Astro | SQL day-fact normalization with explicit orphan-`pulang` repair | Prevents portal and admin recap from disagreeing. |
| Month summary | Separate aggregate endpoint | Helper-derived counts from the recap rows | Summary and history stay aligned. |
| History explanation | One unreadable text field | Named timestamps and notes in each day row | Phase 43 can render each day clearly without re-parsing strings. |
| Portal state evolution | UI-only recap assumptions in planning | Typed website helper prepared before UI wiring | Keeps Phase 42 focused on the read model and Phase 43 focused on the surface. |

## Common Pitfalls

### Pitfall 1: Only reading attendance logs and losing scheduled no-scan days

**What goes wrong:** The portal recap cannot later explain missing-attendance or no-scan days because the dataset contains only logged activity.

**How to avoid:** Merge schedule-day facts and attendance-day facts into one recap row set.

### Pitfall 2: Re-bucketing all early-morning scans to the previous day

**What goes wrong:** Genuine early-day attendance gets attached to yesterday.

**How to avoid:** Keep the repair specific to the existing overnight completion rule rather than inventing a broader day-boundary rule.

### Pitfall 3: Duplicating portal date logic

**What goes wrong:** Schedule and recap disagree about what "today" means on the server.

**How to avoid:** Reuse one business-local reference date helper in the website repo.

### Pitfall 4: Building month summary and history from separate RPCs

**What goes wrong:** Counts and row history drift when status rules evolve.

**How to avoid:** Fetch one normalized row set and derive summary counts in the helper.

### Pitfall 5: Extending the current schedule overview until it becomes ambiguous

**What goes wrong:** `/portal` home schedule logic and recap logic become tightly coupled and harder to reason about.

**How to avoid:** Add a recap-specific contract with a clear name and scope.

## Code Examples

### Suggested recap horizon

```sql
effective_date := COALESCE(reference_date, current_date);
month_start := date_trunc('month', effective_date)::date;
history_start := LEAST(month_start, effective_date - 13);
```

### Suggested recap RPC signature

```sql
create or replace function get_portal_attendance_recap(reference_date date default null)
returns table (
  logical_date date,
  has_schedule boolean,
  attendance_status text,
  first_masuk_at timestamptz,
  first_break_at timestamptz,
  last_kembali_at timestamptz,
  last_pulang_at timestamptz,
  total_break_minutes integer,
  work_minutes integer,
  scan_count integer,
  notes text
)
```

### Suggested helper model

```ts
type PortalAttendanceRecapModel = {
  employee: PortalEmployee;
  referenceDate: string;
  monthStart: string;
  summaryCounts: Record<string, number>;
  days: PortalAttendanceRecapDay[];
  recentDays: PortalAttendanceRecapDay[];
};
```

## Open Questions

1. **Should attendance-only unscheduled workdays be shown in the recap history?**
   - What we know: raw attendance logs can exist without a schedule row.
   - Recommendation: include them in the recap contract with `has_schedule = false` so the UI can explain them later instead of silently dropping them.

2. **How much break detail should the Phase 42 row expose?**
   - What we know: the admin recap computes total break duration but not a full break-event timeline.
   - Recommendation: expose `first_break_at`, `last_kembali_at`, and `total_break_minutes` now; defer richer per-break timelines unless a later phase needs them.

3. **Should `belum_pulang` remain suppressed for the current logical day?**
   - What we know: the admin recap avoids flagging the current day as incomplete while the employee may still be working.
   - Recommendation: keep that current product behavior in the day-status derivation so the portal does not surface false alarms for the active day.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Astro `astro check` + `astro build`; targeted PowerShell SQL/source-contract checks |
| Config file | `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\package.json` |
| Quick run command | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` |
| Full suite command | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` |
| Estimated runtime | ~20 seconds |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ATTN-02 | Recap contract exposes day outcome plus named attendance timestamps from one employee-scoped dataset | SQL/source smoke | `powershell -Command "Select-String -Path 'sql/phase_42_portal_attendance_recap_20260323.sql','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap.ts' -Pattern 'get_portal_attendance_recap','attendance_status','first_masuk_at','last_pulang_at','summaryCounts' | Measure-Object"` | Missing in Wave 1/2 |
| ATTN-03 | Cross-day completion scans stay attached to the correct logical workday | SQL/source smoke | `powershell -Command "Select-String -Path 'sql/phase_42_portal_attendance_recap_20260323.sql' -Pattern 'history_start','logical_date','pulang','12' | Measure-Object"` | Missing in Wave 1 |

### Sampling Rate

- **Per task commit:** run the targeted SQL/source smoke or `npm run check`
- **Per wave merge:** run `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"`
- **Phase gate:** the portal recap helper can derive month-to-date counts and recent daily history from one employee-scoped recap dataset that preserves the existing logical-day rule

### Wave 0 Gaps

Existing infrastructure covers this phase. No new framework or test harness is required before execution.

### Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Overnight shift with next-day `pulang` before noon stays on the prior logical day in the recap | ATTN-03 | Needs seeded or live overnight attendance data; repo fixtures do not cover this portal scenario today | Seed one employee with `masuk` late on Day 1 and `pulang` before noon on Day 2, then confirm the recap row shows both timestamps under Day 1 |
| Month-to-date summary counts match the underlying daily recap rows for one employee | ATTN-02 | Requires realistic mixed-day data (`hadir`, `sakit`, `izin`, incomplete) | Seed a portal employee with mixed attendance outcomes in the current month, open the recap helper result, and confirm the month counts equal the day rows filtered to the current month |

## Sources

### Primary (HIGH confidence)

- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\ROADMAP.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\REQUIREMENTS.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\STATE.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\PROJECT.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\sql\phase_39_portal_read_path_hardening_20260323.sql`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\sql\phase_38_employee_schedule_read_model_20260322.sql`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\sql\phase23_rpc_functions.sql`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\lib\models\attendance_log.dart`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\lib\models\daily_summary.dart`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\lib\screens\admin\admin_reports_screen.dart`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\lib\portal\employee.ts`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\lib\portal\schedule.ts`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\lib\portal\home.ts`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\components\portal\PortalScheduleSection.astro`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\pages\portal\index.astro`

### Secondary (MEDIUM confidence)

- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\38-employee-schedule-read-model\38-RESEARCH.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\39-employee-portal-schedule-ux\39-RESEARCH.md`

## Metadata

**Confidence breakdown:**

- Employee scoping and portal auth boundary: HIGH - already shipped and hardened in Phases 37-39
- Daily recap semantics reuse: HIGH - the admin Rekap Harian logic is concrete and already used operationally
- Recap helper integration path: HIGH - matches the existing `src/lib/portal/*` helper pattern
- Unscheduled attendance-only day handling: MEDIUM - the data exists, but the portal has not rendered that scenario before

**Research date:** 2026-03-23
**Valid until:** 2026-04-22
