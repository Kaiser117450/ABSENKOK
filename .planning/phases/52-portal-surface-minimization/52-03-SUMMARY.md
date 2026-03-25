---
phase: 52-portal-surface-minimization
plan: 03
subsystem: auth
tags: [astro, sql, supabase, portal, security, testing]
requires:
  - phase: 37-portal-foundation-employee-auth
    provides: employee_portal_accounts schema, hidden portal email contract, and passwordless sign-in helpers
provides:
  - Fail-closed operator recovery SQL for employee portal mappings
  - Passwordless hidden-user reuse checks that require confirmed employee_portal metadata
affects: [portal-recovery, portal-sign-in, employee_portal_accounts]
tech-stack:
  added: []
  patterns: [fail-closed auth recovery, contract-backed SQL repair]
key-files:
  created:
    - sql/repair_employee_portal_accounts_20260325.sql
    - test/phase52/portal_recovery_contract_test.dart
    - .planning/phases/52-portal-surface-minimization/52-03-SUMMARY.md
  modified:
    - src/lib/portal/provision.ts
    - src/pages/portal/auth/sign-in.ts
key-decisions:
  - "Existing hidden-email auth users are only reusable when confirmed employee_portal metadata already matches the requested employee binding."
  - "Portal-account repair skips ambiguous or conflicting rows instead of overwriting auth ownership during recovery."
patterns-established:
  - "Recovery SQL must prove employee_portal identity via confirmed auth metadata before restoring portal mappings."
  - "Public sign-in paths may create missing hidden users, but they must fail closed when an existing identity is unsafe to reuse."
requirements-completed: [SECPORT-03]
duration: 27min
completed: 2026-03-25
---

# Phase 52 Plan 03: Portal Surface Minimization Summary

**Portal account recovery now restores only proven employee_portal identities, while passwordless sign-in refuses to reuse conflicting hidden auth users.**

## Performance

- **Duration:** 27 min
- **Started:** 2026-03-25T13:50:00+08:00
- **Completed:** 2026-03-25T14:17:00+08:00
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- Added a new `repair_employee_portal_accounts_20260325.sql` script that only restores confirmed `employee_portal` auth users whose explicit `employee_id` metadata matches the hidden-email identity.
- Hardened passwordless provisioning so an existing hidden-email auth user is reused only when its confirmation state and `app_metadata` already prove the same employee binding.
- Added focused contract coverage that will fail if future SQL edits drop the confirmed-user requirement, metadata requirement, or non-destructive conflict handling.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create a fail-closed portal-account recovery script** - `35837f2` (fix)
2. **Task 2: Harden hidden-auth recovery in the passwordless sign-in path** - `781cefd` (fix)
3. **Task 3: Add focused contract coverage for the Phase 52 recovery SQL** - `035b912` (test)

**Plan metadata:** pending docs commit

## Files Created/Modified
- `sql/repair_employee_portal_accounts_20260325.sql` - Recovery script that restores only proven employee portal mappings and skips conflicts for manual review.
- `src/lib/portal/provision.ts` - Reuses hidden portal users only when confirmation and metadata already match the employee identity.
- `src/pages/portal/auth/sign-in.ts` - Keeps employee-facing failures generic while logging enough operator context for recovery investigations.
- `test/phase52/portal_recovery_contract_test.dart` - Focused contract coverage for the Phase 52 recovery SQL rules.
- `.planning/phases/52-portal-surface-minimization/52-03-SUMMARY.md` - Execution summary for plan 52-03.

## Decisions Made
- Recovery correctness is stricter than convenience: ambiguous or conflicting rows are skipped rather than auto-repaired.
- Existing hidden-email users keep the passwordless flow only when they already prove `employee_portal` ownership with the same `employee_id`.
- Contract coverage stays file-based and lightweight so SQL safety regressions are detectable without a live database fixture.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- The focused `flutter test test/phase52/portal_recovery_contract_test.dart` verification timed out repeatedly in this sandbox, even with `--no-pub`, so the execution proof for this plan relies on the committed test file plus source-contract smoke checks rather than a completed local test run.
- The operator-facing recovery flow remains intentionally manual; the new SQL script is not applied automatically anywhere in the public sign-in path.

## User Setup Required

**External services require manual configuration.** See [52-USER-SETUP.md](./52-USER-SETUP.md) for:
- Supabase SQL Editor steps
- Recovery-only usage guidance
- Verification commands

## Next Phase Readiness
- Portal repair no longer depends on hidden-email inference alone.
- Passwordless sign-in now fails closed when an existing hidden identity is unsafe to reuse.
- The committed contract test should be rerun in a faster local Flutter environment before rollout if a green automated test record is required.

## Self-Check: PASSED

- FOUND: `sql/repair_employee_portal_accounts_20260325.sql`
- FOUND: `src/lib/portal/provision.ts`
- FOUND: `src/pages/portal/auth/sign-in.ts`
- FOUND: `test/phase52/portal_recovery_contract_test.dart`
- FOUND: task commit `035b912`
- FOUND: task commit `35837f2`
- FOUND: task commit `781cefd`
- VERIFIED: source-contract smoke check passed

---
*Phase: 52-portal-surface-minimization*
*Completed: 2026-03-25*
