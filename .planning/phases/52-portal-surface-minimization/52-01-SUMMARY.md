---
phase: 52-portal-surface-minimization
plan: 01
subsystem: auth
tags: [astro, middleware, supabase, portal, security]
requires:
  - phase: 37-portal-foundation-employee-auth
    provides: Passwordless portal auth model, hidden portal identities, and protected route classification helpers
  - phase: 39-employee-portal-schedule-ux
    provides: Portal shell pages and request-local portal employee resolution
provides:
  - Middleware-first redirect for unauthenticated protected portal requests
  - Request-local portal employee resolution that trusts only Astro.locals.portalUser
affects: [portal-home-loader, portal-attendance-loader, portal-auth-boundary]
tech-stack:
  added: []
  patterns: [middleware-first portal auth gating, middleware-cached portal user contract]
key-files:
  created:
    - .planning/phases/52-portal-surface-minimization/52-01-SUMMARY.md
  modified:
    - src/middleware.ts
    - src/lib/portal/employee.ts
key-decisions:
  - "Protected portal redirects now happen before next() while reusing the same getUser()-verified SSR session flow."
  - "resolvePortalEmployee() now treats Astro.locals.portalUser as the single verified protected-route boundary and no longer performs its own auth fetch fallback."
patterns-established:
  - "Protected /portal loaders should consume the middleware-cached portal user instead of re-querying Supabase Auth."
  - "Redirect responses created in middleware must still receive refreshed Set-Cookie headers from the Supabase SSR client."
requirements-completed: [SECPORT-01]
duration: 6min
completed: 2026-03-25
---

# Phase 52 Plan 01: Portal Surface Minimization Summary

**Protected portal requests now redirect before downstream page handlers run, while portal employee resolution trusts the middleware-cached verified user boundary instead of re-fetching auth state.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-25T13:51:10+08:00
- **Completed:** 2026-03-25T13:53:57+08:00
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Moved protected `/portal` enforcement in `src/middleware.ts` ahead of `await next()` without changing the existing route-classification or `getUser()` verification flow.
- Preserved Supabase SSR cookie refresh behavior on both pass-through responses and the new unauthenticated redirect path by attaching queued `Set-Cookie` headers before returning either response.
- Simplified `resolvePortalEmployee()` so protected page loaders trust `Astro.locals.portalUser` and return `unauthenticated` immediately when the middleware-established session boundary is absent.

## Task Commits

Each task was committed atomically:

1. **Task 1: Move protected-route enforcement ahead of `next()` in middleware** - `13b8715` (fix)
2. **Task 2: Make `resolvePortalEmployee()` trust only the middleware-established request boundary** - `816f5b2` (fix)

**Plan metadata:** pending docs commit

## Files Created/Modified
- `src/middleware.ts` - Enforces protected portal redirects before route handlers run and applies refreshed Supabase cookies to redirect responses.
- `src/lib/portal/employee.ts` - Treats `Astro.locals.portalUser` as the only verified portal session source before calling `resolve_portal_employee`.
- `.planning/phases/52-portal-surface-minimization/52-01-SUMMARY.md` - Execution summary for plan 52-01.

## Decisions Made
- Kept the existing `/portal` route scope, public portal routes, and `isProtectedPortalRoute()` helper unchanged so the hardening remains sequencing-only as required by the plan.
- Used a local `appendRefreshedCookies()` helper in middleware instead of duplicating `Set-Cookie` attachment logic between redirect and pass-through responses.
- Treated an absent `portalUser` local the same as `null` so protected loaders fail closed if the middleware request contract is missing for any reason.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- The required `npm run build` verification was initially blocked because `node_modules` was missing in this forked workspace, so `npm install` was run before rerunning the build gate successfully.
- Shared planning state files were intentionally left untouched because this execution was explicitly scoped to `src/middleware.ts`, `src/lib/portal/employee.ts`, and this summary file.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Protected portal pages can now rely on middleware to resolve the auth boundary before any loader logic runs.
- The request-local `portalUser` contract is explicit and reusable for the remaining Phase 52 work on public chooser minimization and recovery hardening.
- Shared `.planning/STATE.md`, `.planning/ROADMAP.md`, and `.planning/REQUIREMENTS.md` updates remain for the orchestrator wave-integration step.

## Self-Check: PASSED

- FOUND: `src/middleware.ts`
- FOUND: `src/lib/portal/employee.ts`
- FOUND: `.planning/phases/52-portal-surface-minimization/52-01-SUMMARY.md`
- FOUND: task commit `13b8715`
- FOUND: task commit `816f5b2`

---
*Phase: 52-portal-surface-minimization*
*Completed: 2026-03-25*
