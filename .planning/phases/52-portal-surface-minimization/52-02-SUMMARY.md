---
phase: 52-portal-surface-minimization
plan: 02
subsystem: auth
tags: [astro, sql, supabase, portal, security]
requires:
  - phase: 37-portal-foundation-employee-auth
    provides: Passwordless chooser entry flow and the original public search RPC contract
  - phase: 39-employee-portal-schedule-ux
    provides: Portal login UI and hidden employee-id auto-submit behavior
provides:
  - Chooser-safe public search SQL contract with tighter public caps
  - Astro endpoint enforcement for minimum, maximum, and no-store search behavior
affects: [portal-login-chooser, public-search-rpc, passwordless-entry]
tech-stack:
  added: []
  patterns: [chooser-safe DTO contract, server-enforced public search caps]
key-files:
  created:
    - .planning/phases/52-portal-surface-minimization/52-02-SUMMARY.md
  modified:
    - sql/phase_52_portal_search_minimization_20260325.sql
    - src/lib/portal/auth.ts
    - src/pages/portal/auth/search.ts
    - src/pages/portal/login.astro
key-decisions:
  - "Public chooser search now requires 3 normalized characters, caps results at 5, and rejects queries longer than 64 characters."
  - "The Astro endpoint trims the public DTO to the fields the chooser renders even if SQL drifts in the future."
patterns-established:
  - "Public portal endpoints should return only the rendered chooser fields and use no-store caching."
  - "Client-side chooser copy and guards should mirror the same bounds enforced by SQL and the Astro endpoint."
requirements-completed: [SECPORT-02]
duration: 22min
completed: 2026-03-25
---

# Phase 52 Plan 02: Portal Surface Minimization Summary

**Public portal search now exposes only chooser-safe employee data, enforces tighter server-side bounds, and keeps the passwordless card-selection flow intact.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-03-25T13:54:00+08:00
- **Completed:** 2026-03-25T14:16:30+08:00
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Added an additive SQL patch that redefines `search_portal_employees(...)` to return only `employee_id`, `employee_name`, `home_outlet_name`, `position`, and `photo_url` while capping public queries at 5 results.
- Tightened the Astro `/portal/auth/search` endpoint so it rejects short or overly long queries, prunes any extra fields from SQL responses, and serves the public chooser with `Cache-Control: no-store`.
- Updated the portal login screen to communicate the 3-character threshold and enforce the same client-side bounds without changing the accepted auto-submit passwordless flow.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create an additive SQL hardening patch for the public chooser RPC** - `31d1655` (fix)
2. **Task 2: Align the website search boundary and chooser UI with the tightened public contract** - `e5ff785` (fix)

**Plan metadata:** pending docs commit

## Files Created/Modified
- `sql/phase_52_portal_search_minimization_20260325.sql` - Narrows the public RPC DTO and enforces 3-char minimum, 64-char maximum, 4-char trigram fallback, and 5-result cap.
- `src/lib/portal/auth.ts` - Centralizes the tightened chooser constants for shared portal use.
- `src/pages/portal/auth/search.ts` - Fail-closes out-of-bounds queries, returns only the minimal DTO, and disables persistent caching.
- `src/pages/portal/login.astro` - Updates chooser guidance, max-length handling, and client-side threshold messaging to match the server contract.
- `.planning/phases/52-portal-surface-minimization/52-02-SUMMARY.md` - Execution summary for plan 52-02.

## Decisions Made
- Kept the chooser public for passwordless entry, but reduced the surface by shrinking the DTO instead of adding a new auth model.
- Enforced the tightened search contract in both SQL and Astro so browser behavior is not the only control on a public endpoint.
- Kept the hidden `employee_id` submission path unchanged so existing card selection and auto-submit behavior remains intact.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `npm run check` is currently red because of pre-existing Supabase Edge Function typing issues in `supabase/functions/create-admin-user/index.ts` and `supabase/functions/provision-employee-portal-user/index.ts`. Those errors are outside the Phase 52 files.
- `npm run build` passed after the chooser changes, so the shipped Astro surface relevant to this plan is green despite the unrelated `astro check` debt.

## User Setup Required

**External services require manual configuration.** See [52-USER-SETUP.md](./52-USER-SETUP.md) for:
- Supabase SQL Editor steps
- Production-safe rollout sequencing
- Verification commands

## Next Phase Readiness
- Public chooser leakage is reduced without breaking passwordless entry.
- The remaining portal hardening work can now focus on recovery correctness rather than search-surface exposure.
- The additive search SQL still requires explicit human review and application in Supabase before production rollout.

## Self-Check: PASSED

- FOUND: `sql/phase_52_portal_search_minimization_20260325.sql`
- FOUND: `src/lib/portal/auth.ts`
- FOUND: `src/pages/portal/auth/search.ts`
- FOUND: `src/pages/portal/login.astro`
- FOUND: task commit `31d1655`
- FOUND: task commit `e5ff785`
- VERIFIED: `npm run build` passed

---
*Phase: 52-portal-surface-minimization*
*Completed: 2026-03-25*
