# Phase 38: Employee Schedule Read Model - Research

**Researched:** 2026-03-22
**Domain:** Employee-scoped schedule RPCs, Astro server helpers, and logical-day handling for portal schedule visibility
**Confidence:** HIGH for portal/server contract, HIGH for existing schedule schema reuse, MEDIUM for live overnight coverage because current production templates are mostly same-day

## Summary

Phase 38 should not invent a second schedule system. The source of truth is still `schedules` plus `schedule_entries`, and the portal already has a trusted authenticated employee resolver from Phase 37. The safest shape is:

1. add one additive SQL read model that resolves the authenticated employee internally and returns only that employee's current-week assignments
2. add one server-side website helper that turns the RPC rows into a typed portal schedule model
3. replace the `/portal` placeholder with a minimal schedule surface that proves retrieval works without doing the Phase 39 UX/state redesign early

The week calculation should reuse the same Monday-start rule already used by the Flutter scheduler. The existing scheduler computes start-of-week by normalizing the date and subtracting `weekday - 1`, so the portal should not introduce Sunday-start or rolling-7-day behavior.

Overnight representation should match the system's existing logical-day rule. The reports code and the original requirements both treat pre-noon next-day `pulang` scans as belonging to the prior work day. For schedule visibility, that means the portal should keep the assignment anchored to `schedule_entries.date`, compute `ends_next_day = true` when the stored shift end is earlier than or equal to the start time, and never move the assignment onto the following day as if it were a separate shift.

The key implementation choice is to make the schedule RPC accept an optional `reference_date` rather than depend only on the database server's `current_date`. That keeps the behavior deterministic and lets the website pass one business-local date explicitly, which is safer while the portal is server-rendered on Vercel and the schedule tables themselves remain pure local-date records.

**Primary recommendation:** Build Phase 38 around one `SECURITY DEFINER` current-week RPC plus one portal helper/page update. Keep the UI intentionally basic so Phase 39 can own mobile polish, explicit empty/error/not-linked states, and logout refinement.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCHED-01 | Employee can view today's assigned shift with outlet, shift label, and start/end times. | A server-side week RPC can return a typed row for the authenticated employee, and the website helper can derive `todayAssignment` from that same dataset. |
| SCHED-02 | Employee can view upcoming assigned shifts for at least the current week. | Reuse the admin scheduler's Monday-start week boundaries and return ordered current-week rows, not ad hoc per-day queries. |
| SCHED-03 | Overnight or cross-day shifts appear consistently with the system's existing logical-day rules. | Keep `schedule_entries.date` as the logical day, compute next-day end markers from `shift_slot`, and avoid re-anchoring overnight assignments to the next calendar date. |

## Current State Analysis

### 1. Portal auth and employee identity resolution already exist

Phase 37 delivered:

- `resolve_portal_employee()` in SQL
- `resolvePortalEmployee()` in the website repo
- protected `/portal/*` routes in Astro
- a placeholder `/portal` page inside `PortalLayout.astro`

That means Phase 38 does not need to solve authentication again. It only needs to extend the portal after the employee identity is already resolved.

### 2. Schedule source of truth is still weekly `schedules` plus `schedule_entries`

The admin scheduler loads one active weekly schedule row from `schedules`, then loads its `schedule_entries` by `schedule_id`. Entries already contain:

- `date`
- `employee_id`
- `display_name`
- `shift_slot` JSON with start/end hour/minute and label
- `is_day_off`
- `notes`

This is enough to power the employee portal without introducing a new portal-specific schedule table.

### 3. The scheduler's week boundary is Monday-start, not rolling 7 days

`ShiftSchedulerScreen._getStartOfWeek()` normalizes the date and subtracts `weekday - 1`. Portal schedule visibility should match that rule exactly so the same employee sees the same "current week" in admin and portal contexts.

### 4. The existing logical-day rule is the noon rule

The original v1.1 requirements and the reports implementation both anchor cross-day work to the start day when the next-day `pulang` occurs before noon. Phase 38 should reuse that principle for schedules:

- logical day stays on the scheduled start date
- overnight is represented as a next-day end, not a second assignment
- "today" means the logical scheduled day, not whichever calendar day contains the end time

### 5. The website repo already has the right extension points

The Astro repo now contains:

- `src/lib/portal/employee.ts` for identity resolution
- `src/layouts/PortalLayout.astro` for the protected shell
- `src/pages/portal/index.astro` as the first authenticated page

Phase 38 can add one sibling helper such as `src/lib/portal/schedule.ts` and keep the portal page server-rendered.

### 6. Existing validation is route/build focused, not DB-integration heavy

The website repo currently validates through `npm run check` and `npm run build`. There is no dedicated database integration harness today, so the plan should use:

- targeted SQL contract smoke checks during implementation
- `astro check` after helper/page changes
- `astro build` at the end of the phase wave

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| PostgreSQL additive migration | existing project pattern | Portal schedule read model, indexes, and RPC | Matches the live Supabase production rules: additive only, rerunnable where possible. |
| Supabase `SECURITY DEFINER` RPC | existing project pattern | Employee-scoped current-week schedule retrieval | Keeps schedule access server-side and prevents client-supplied employee IDs. |
| Astro 5 on-demand route | existing repo | Server-rendered `/portal` schedule retrieval | Portal routes already use `prerender = false`, so Phase 38 can extend the existing protected surface. |
| `@supabase/ssr` + `@supabase/supabase-js` | already installed in website repo | Server-side RPC invocation from Astro | Already adopted in Phase 37; no new dependency is needed. |

### Supporting

| Tool / Pattern | Purpose | When to Use |
|----------------|---------|-------------|
| Partial indexes | Speed filtered schedule lookups | Index active weekly schedule headers and employee-date entry lookups that match the portal query shape. |
| Typed portal helper | Normalize RPC rows for the page | Keep portal pages free of raw row casting and week-derivation logic. |
| Shared local-date helper | Explicit business-local reference date | Avoid accidental UTC drift from the server environment when selecting "today". |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| One current-week RPC | Separate today RPC + upcoming RPC | Duplicates filtering logic and makes SCHED-01/SCHED-02 drift apart. |
| Employee-scoped `SECURITY DEFINER` RPC | Browser-side direct table queries | Simpler to prototype, but unsafe and easy to over-fetch. |
| Explicit `reference_date` | Database `current_date` everywhere | Easier SQL, but riskier for server-rendered portal requests running outside the business timezone. |
| Row-based read model | One large JSON aggregate in SQL | Fewer app transforms, but harder to type, debug, and extend in Astro. |
| Derive outlet from the schedule row | Assume employee `home_outlet_id` always equals assignment outlet | Works today, but ties the portal to a mutable employee profile field instead of the actual assigned schedule header. |

### Installation

No new package installation is required for Phase 38 if Phase 37 dependencies are already present in the website repo.

## Architecture Patterns

### Pattern 1: Reuse the authenticated employee resolver, never accept employee IDs from the page

**What:** The schedule RPC resolves the portal employee internally through `resolve_portal_employee()` or an equivalent internal lookup.

**Why:** The page should never decide which employee row to load. Portal identity already exists; Phase 38 must build on that trust boundary.

### Pattern 2: Use the same Monday-start week boundary as the scheduler

**What:** Compute:

- `week_start = reference_date - (isodow(reference_date) - 1 days)`
- `week_end = week_start + 6 days`

**Why:** Admin scheduling and employee viewing should agree on what "minggu ini" means.

### Pattern 3: Keep overnight rows anchored to the logical start day

**What:** The read model should expose:

- `logical_date` = stored `schedule_entries.date`
- `start_hour`, `start_minute`, `end_hour`, `end_minute`
- `ends_next_day` boolean when `end_time <= start_time` and the row is not day-off

**Why:** This is the schedule equivalent of the noon rule already used for cross-day attendance reporting.

### Pattern 4: Match indexes to the actual portal query shape

The portal query always filters by:

- authenticated employee
- current-week date range
- active schedule headers

Following the Supabase Postgres guidance, the migration should add indexes on the filtered/join columns and keep them partial where the query already excludes inactive rows. The likely minimum set is:

- `schedule_entries (employee_id, date)` where `employee_id is not null`
- `schedules (outlet_id, start_date, end_date)` where `is_active = true`

### Pattern 5: Keep the portal helper typed and derived from one dataset

**What:** `src/lib/portal/schedule.ts` should return one typed result containing:

- `employee`
- `referenceDate`
- `todayAssignment`
- `weekAssignments`
- `upcomingAssignments`

**Why:** SCHED-01 and SCHED-02 should come from one canonical fetch, not from page-level duplicated filters.

### Pattern 6: Replace the placeholder on `/portal` without doing Phase 39 early

**What:** Render basic schedule data on `/portal`:

- today's shift card
- current-week list
- simple empty placeholder when there are no assignments

**Why:** Phase 38 is a read-model phase. Phase 39 still owns the full mobile UX, state matrix, and portal-only logout refinement.

## Anti-Patterns to Avoid

- **Do not query `schedule_entries` directly from the browser.**
- **Do not accept `employee_id` from URL params, form fields, or client-side state for schedule retrieval.**
- **Do not key portal schedule visibility off `employees.home_outlet_id` alone when the real assignment outlet comes from the schedule header.**
- **Do not anchor overnight assignments to the next calendar day just because the shift ends after midnight.**
- **Do not let the portal server's default timezone silently choose "today" without one explicit business-local date rule.**
- **Do not turn Phase 38 into a full mobile UI redesign.**

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Portal schedule auth | Client-provided employee filtering | `SECURITY DEFINER` RPC that resolves the employee internally | Keeps data scoped to the signed-in portal user. |
| Week visibility | Ad hoc date math in multiple files | One SQL week window plus one website helper | Prevents "today" and "minggu ini" from diverging. |
| Overnight labeling | Free-form string parsing in the page | Structured `ends_next_day` plus start/end fields from the RPC | Easier to render and verify consistently. |
| Performance tuning | Generic full-table indexes | Partial/composite indexes that match employee + week filters | Smaller indexes and faster filtered reads. |
| Portal page state | Raw row casting inline in `index.astro` | `src/lib/portal/schedule.ts` typed transformer | Keeps the page readable and Phase 39-friendly. |

## Common Pitfalls

### Pitfall 1: Using the schedule header's outlet but forgetting the employee filter

**What goes wrong:** The portal can accidentally show all entries in an outlet's weekly schedule.

**How to avoid:** Filter by resolved employee ID first, then join the schedule header only to decorate the row with outlet/week metadata.

### Pitfall 2: Recomputing "today" from UTC server time

**What goes wrong:** Portal users near midnight can see the wrong day's shift.

**How to avoid:** Pass one explicit business-local `reference_date` into the RPC and derive both `todayAssignment` and week bounds from that date.

### Pitfall 3: Treating overnight shifts as two separate days

**What goes wrong:** A Monday 22:00 -> Tuesday 06:00 shift appears under Tuesday instead of Monday.

**How to avoid:** Keep `logical_date = schedule_entries.date` and expose `ends_next_day` instead of moving the row.

### Pitfall 4: Overbuilding empty and error states in Phase 38

**What goes wrong:** The phase starts absorbing Phase 39's work and loses focus.

**How to avoid:** Keep the page minimal: basic schedule cards, basic empty placeholder, existing blocked-account behavior. Save UX polish and explicit state treatment for Phase 39.

### Pitfall 5: Adding unscoped full indexes on large tables

**What goes wrong:** Extra write cost and larger indexes without helping the real query path.

**How to avoid:** Match indexes to the actual filter predicates, especially active schedule rows and non-null employee-linked entries.

## Code Examples

### Suggested current-week RPC shape

```sql
create or replace function get_portal_schedule_week(reference_date date default null)
returns table (
  logical_date date,
  outlet_id uuid,
  outlet_name text,
  shift_name text,
  start_hour integer,
  start_minute integer,
  end_hour integer,
  end_minute integer,
  is_day_off boolean,
  ends_next_day boolean,
  notes text
)
```

### Suggested overnight flag rule

```sql
case
  when is_day_off then false
  when make_time(end_hour, end_minute, 0) <= make_time(start_hour, start_minute, 0) then true
  else false
end as ends_next_day
```

### Suggested week-boundary rule

```sql
week_start := reference_date - ((extract(isodow from reference_date)::int) - 1);
week_end := week_start + 6;
```

### Suggested website helper result

```ts
type PortalScheduleModel = {
  referenceDate: string;
  todayAssignment: PortalScheduleEntry | null;
  weekAssignments: PortalScheduleEntry[];
  upcomingAssignments: PortalScheduleEntry[];
};
```

## Open Questions

1. **What is the long-term business timezone for the portal?**
   - What we know: the kiosk/admin app is effectively local-date driven, and this session runs in `Asia/Makassar`.
   - What's unclear: whether the chain will ever need outlet-level timezone configuration.
   - Recommendation: centralize one explicit portal-local date helper now and document the assumption so a later timezone field can replace it cleanly.

2. **Should day-off rows appear in the basic Phase 38 list?**
   - What we know: the schedule system stores `Libur` as a first-class entry and the employee may expect to see it.
   - What's unclear: whether Phase 38 should show those rows now or reserve that presentation decision for Phase 39.
   - Recommendation: return `is_day_off` in the read model either way, then let the minimal page decide whether to display or filter them while keeping Phase 39 free to refine the final treatment.

3. **Could one employee ever have more than one active weekly schedule row in the same week?**
   - What we know: current admin behavior creates one active weekly schedule per outlet/week and soft-deletes the prior schedule header.
   - What's unclear: whether future cross-outlet assignment workflows will intentionally allow multiple active schedule headers for one employee in the same week.
   - Recommendation: Phase 38 should support multiple rows across the week as long as each row is still filtered by `employee_id`; do not hardcode a one-outlet-only assumption into the page helper.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Astro `astro check` + `astro build`; targeted SQL contract smoke via PowerShell `Select-String` |
| Config file | `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\package.json` |
| Quick run command | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` |
| Full suite command | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCHED-01 | Authenticated employee can fetch today's assignment with outlet plus shift time data | SQL/TS smoke | `powershell -Command "Select-String -Path 'sql/phase_38_employee_schedule_read_model_20260322.sql','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/schedule.ts' -Pattern 'get_portal_schedule_week','todayAssignment','outlet_name','shift_name' | Measure-Object"` | ❌ Wave 1 |
| SCHED-02 | Portal can fetch current-week assignments from one helper and one page | build/check smoke | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` | ❌ Wave 2 |
| SCHED-03 | Overnight shifts stay on the logical start day and carry a next-day end marker | SQL/build smoke | `powershell -Command "Select-String -Path 'sql/phase_38_employee_schedule_read_model_20260322.sql','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/index.astro' -Pattern 'logical_date','ends_next_day','besok' | Measure-Object"` | ❌ Wave 2 |

### Sampling Rate

- **Per task commit:** run the targeted SQL smoke or `npm run check`
- **Per wave merge:** `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"`
- **Phase gate:** portal page renders schedule data from the authenticated employee-scoped RPC and preserves logical-day handling for overnight rows

### Wave 0 Gaps

Existing infrastructure covers this phase. No new framework or test harness is required before execution.

### Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real overnight shift appears on the logical start day with a next-day end marker | SCHED-03 | Needs live or seeded overnight data; repo fixtures do not include that portal scenario today | Provision one employee with a 22:00 -> 06:00 shift, sign in to the portal, and confirm the row stays on the scheduled start day while showing the next-day end context |
| Portal "today" matches the business-local day near midnight | SCHED-01 | Server-rendered environment timezone needs live confirmation | Check one portal session before and after local midnight against the same employee's weekly schedule and confirm the highlighted "today" row changes on the correct local date |

## Sources

### Primary (HIGH confidence)

- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\ROADMAP.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\REQUIREMENTS.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\STATE.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\PROJECT.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\37-portal-foundation-employee-auth\37-RESEARCH.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\sql\phase_37_employee_portal_foundation_20260322.sql`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\lib\screens\admin\shift_scheduler_screen.dart`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\lib\models\shift_schedule.dart`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\lib\screens\admin\admin_reports_screen.dart`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\lib\portal\employee.ts`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\lib\portal\auth.ts`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\layouts\PortalLayout.astro`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\pages\portal\index.astro`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\pages\portal\auth\search.ts`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\lib\supabase\server.ts`

### Secondary (MEDIUM confidence)

- `C:\Users\HYPE R Series\.agents\skills\supabase-postgres-best-practices\references\query-missing-indexes.md`
- `C:\Users\HYPE R Series\.agents\skills\supabase-postgres-best-practices\references\query-partial-indexes.md`
- `C:\Users\HYPE R Series\.agents\skills\supabase-postgres-best-practices\references\security-rls-performance.md`
- `C:\Users\HYPE R Series\.agents\skills\supabase-postgres-best-practices\references\security-privileges.md`

## Metadata

**Confidence breakdown:**

- Schedule source reuse: HIGH - admin scheduler already proves the schema and row shape
- Portal integration path: HIGH - Phase 37 created the exact helper/layout/page extension points needed
- Index/security strategy: HIGH - matches the Supabase Postgres guidance for filtered lookups and scoped privileges
- Overnight schedule representation: MEDIUM - the rule is clear, but live overnight portal coverage still needs manual confirmation because current templates are mostly same-day

**Research date:** 2026-03-22
**Valid until:** 2026-04-21
