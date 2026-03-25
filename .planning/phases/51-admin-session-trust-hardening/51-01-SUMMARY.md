---
phase: 51-admin-session-trust-hardening
plan: 01
subsystem: database
tags: [supabase, postgres, security, rpc, flutter_test]
requires:
  - phase: 23-dashboard-aggregation
    provides: Dashboard analytics RPC signatures and caller contracts
  - phase: 24-analytics-alerting
    provides: Overtime, missing clock-out, and arrival pattern RPC contracts
  - phase: 33-central-dashboard
    provides: Null-safe admin-only SQL guard pattern for comparison
provides:
  - Additive SQL hardening migration for seven privileged analytics RPCs
  - Repository-local contract test that locks the protected function list and grant statements
affects: [analytics-service, pattern-detection-service, supabase-rollout]
tech-stack:
  added: []
  patterns: [fail-closed app_metadata role guards, repository SQL contract testing]
key-files:
  created:
    - sql/phase_51_admin_session_trust_20260325.sql
    - test/phase51/sql_role_guard_contract_test.dart
    - .planning/phases/51-admin-session-trust-hardening/51-01-SUMMARY.md
  modified: []
key-decisions:
  - "Kept every affected RPC name, signature, REVOKE, and GRANT contract unchanged while tightening only the authorization guards."
  - "Qualified project-table references with public. inside the redefined SECURITY DEFINER functions to keep the trust boundary explicit."
  - "Captured the rollout contract in a repo-local Flutter test instead of a live database test so the migration can be reviewed before manual Supabase application."
patterns-established:
  - "Privileged SECURITY DEFINER RPCs must reject non-authenticated callers and null or empty app_metadata.app_role claims explicitly."
  - "SQL hardening migrations should ship with a lightweight text contract test that protects function names, grants, and forbidden metadata sources."
requirements-completed: [SECACC-01]
duration: 3min
completed: 2026-03-25
---

# Phase 51 Plan 01: Admin Session Trust Hardening Summary

**Additive Supabase hardening for seven privileged analytics RPCs, backed by a repository contract test that locks their null-safe guards and execute grants.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-25T04:26:59Z
- **Completed:** 2026-03-25T04:29:02Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added `sql/phase_51_admin_session_trust_20260325.sql` to redefine the vulnerable dashboard and analytics RPCs with authenticated-only, fail-closed `app_metadata` role checks.
- Preserved the existing Flutter-facing RPC names, argument lists, `REVOKE ALL`, `GRANT EXECUTE`, and kepala gerai outlet scoping while auditing Phase 33's already-safe admin-only pattern.
- Added `test/phase51/sql_role_guard_contract_test.dart` to guard the protected function list, null-safe role patterns, grant statements, and the absence of `user_metadata`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create the additive SQL hardening migration for vulnerable dashboard and analytics role guards** - `9b875db` (fix)
2. **Task 2: Add an automated contract test for the Phase 51 SQL migration** - `7bd66ed` (test)

**Plan metadata:** pending docs commit

## Files Created/Modified
- `sql/phase_51_admin_session_trust_20260325.sql` - Additive migration that hardens the seven privileged analytics RPCs without changing their signatures.
- `test/phase51/sql_role_guard_contract_test.dart` - Lightweight repository contract test for the migration text and protected function surface.
- `.planning/phases/51-admin-session-trust-hardening/51-01-SUMMARY.md` - Execution summary for plan 51-01.

## Decisions Made
- Kept the migration focused on the actually vulnerable Phase 23 and Phase 24 RPCs; Phase 33 central-dashboard functions were audited but not rewritten because their admin-only pattern already fails closed.
- Used explicit `v_role IS NULL` rejection for mixed admin / `kepala_gerai` RPCs and `IS DISTINCT FROM 'admin'` for the admin-only outlet comparison guard to match the safer Phase 33 style.
- Treated missing, empty, or malformed `managed_outlet_id` claims as invalid scope for `kepala_gerai` reads by requiring a parsed UUID match before access is granted.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `rg.exe` was not runnable in this environment because the packaged executable path returned an access-denied error, so PowerShell `Select-String` was used for source verification instead.
- The expected `$HOME/.claude/get-shit-done/bin/gsd-tools.cjs` path was not present here, and the execution request limited writes to the SQL file, the contract test, and this summary. As a result, `STATE.md` and `ROADMAP.md` were intentionally left untouched.

## User Setup Required

Manual Supabase review and application is still required. After explicit approval, run `sql/phase_51_admin_session_trust_20260325.sql` in Supabase SQL Editor as described in the plan frontmatter.

## Next Phase Readiness
- The server-side hardening artifact and its regression test are in place and verified locally with `C:\flutter\bin\flutter.bat test test/phase51/sql_role_guard_contract_test.dart`.
- Flutter-side claim hardening work can proceed independently; this plan preserved the existing analytics RPC contract for current callers.
- Planning state files were not updated in this run because they were outside the allowed write targets for this execution.

## Self-Check: PASSED

- FOUND: `sql/phase_51_admin_session_trust_20260325.sql`
- FOUND: `test/phase51/sql_role_guard_contract_test.dart`
- FOUND: `.planning/phases/51-admin-session-trust-hardening/51-01-SUMMARY.md`
- FOUND: task commit `9b875db`
- FOUND: task commit `7bd66ed`

---
*Phase: 51-admin-session-trust-hardening*
*Completed: 2026-03-25*
