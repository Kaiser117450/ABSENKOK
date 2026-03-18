---
phase: 23-bug-fix-database-foundation
plan: 02
subsystem: database
tags: [supabase, sql, rpc, rls, indexes, streaks]

requires: []
provides:
  - Production Supabase RPC functions for dashboard attendance rates, weekly trend, outlet comparison, and streak updates
  - employee_streaks cache table with outlet-scoped read policy
  - Performance indexes for dashboard and streak queries
affects: [phase-24, phase-25, dashboard-analytics, gamification]

tech-stack:
  added: [supabase-postgres migrations]
  patterns:
    - dashboard aggregation via RPC instead of fetch-all-in-Dart
    - additive SQL scripts committed locally before production deployment

key-files:
  created:
    - sql/phase23_rpc_functions.sql
    - sql/phase23_employee_streaks.sql
    - sql/phase23_indexes.sql
  modified:
    - sql/phase23_employee_streaks.sql

key-decisions:
  - "Used employees.home_outlet_id instead of the stale outlet_id placeholder from the phase draft because that is the real production schema"
  - "Deployed the SQL through Supabase MCP only after the scripts were committed locally so production state matches the repository"

patterns-established:
  - "Supabase dashboard functions should use SECURITY DEFINER with explicit search_path and internal role checks"
  - "Phase SQL should be kept as reusable scripts in sql/ even when deployed via MCP migrations"

requirements-completed: [DASH-05, GAME-01]

duration: 1h24m
completed: 2026-03-18
---

# Phase 23 Plan 02: Database Foundation Summary

**Phase 23 database foundation is live in production with four Supabase RPC functions, the employee streak cache table, and the indexes needed for downstream analytics and dashboard work**

## Performance

- **Duration:** 1h 24m
- **Started:** 2026-03-18T11:11:29Z
- **Completed:** 2026-03-18T12:35:12Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created reusable SQL scripts for the dashboard RPC layer, streak cache table, and supporting indexes
- Applied the additive database changes to production Supabase via MCP migrations
- Verified all four RPCs return JSON successfully and confirmed the new streak row plus all required indexes exist

## Task Commits

Each task was committed atomically where repository changes existed:

1. **Task 1: Create SQL scripts for RPC functions, streaks table, and indexes** - `714c732` (feat)
2. **Task 1 follow-up: Tune employee_streaks RLS policy after advisor feedback** - `d2be333` (perf)
3. **Task 2: Deploy SQL scripts to Supabase production** - Applied via Supabase MCP migrations `phase_23_dashboard_foundation_20260318` and `phase_23_employee_streaks_rls_perf_20260318`

## Files Created/Modified
- `sql/phase23_rpc_functions.sql` - Defines `get_attendance_rates`, `get_weekly_trend`, `get_outlet_comparison`, and `update_employee_streak`
- `sql/phase23_employee_streaks.sql` - Creates the streak cache table and outlet-scoped RLS policy
- `sql/phase23_indexes.sql` - Adds the attendance and streak indexes used by downstream analytics work

## Decisions Made
- Switched the employee outlet reference to `home_outlet_id` before deployment because production employees do not have an `outlet_id` column
- Kept the dashboard RPCs additive and idempotent so they are safe to reapply on a live multi-outlet production database

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the employee outlet column before production deploy**
- **Found during:** Task 1 (SQL authoring)
- **Issue:** The phase draft referenced `employees.outlet_id`, but the real schema uses `employees.home_outlet_id`
- **Fix:** Rewrote the streak table policy and RPC employee counts to use `home_outlet_id`
- **Files modified:** `sql/phase23_rpc_functions.sql`, `sql/phase23_employee_streaks.sql`
- **Verification:** Production migration applied successfully and all RPC verification queries returned valid JSON
- **Committed in:** `714c732`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary schema correction before production deployment. No scope creep.

## Issues Encountered
- Supabase performance advisors flagged the new `employee_streaks` read policy for auth init-plan evaluation; a follow-up policy rewrite was applied and synced locally, but the advisor still reports the warning alongside multiple pre-existing RLS/performance advisories already present in the project

## User Setup Required

None - production deployment and verification were completed via Supabase MCP during execution.

## Next Phase Readiness
- Phase 24 can now build the chart, streak, and analytics services against live RPC endpoints instead of raw client-side aggregation
- Phase 25 can rely on the deployed streak cache and comparison RPCs for dashboard UI work
- No blockers remain for phase 23

---
*Phase: 23-bug-fix-database-foundation*
*Completed: 2026-03-18*
