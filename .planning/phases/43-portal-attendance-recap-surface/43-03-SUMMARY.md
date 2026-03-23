---
phase: 43-portal-attendance-recap-surface
plan: 03
subsystem: ui
tags: [astro, portal, attendance, recap, ssr]

requires:
  - phase: 42-attendance-recap-read-model
    provides: loadPortalAttendanceRecap helper and PortalAttendanceRecapModel type
  - phase: 43-01
    provides: PortalAttendanceSummary and PortalAttendanceHistorySection shared components
  - phase: 43-02
    provides: PortalLayout activeSection nav + portal home CTA card linking to /portal/attendance

provides:
  - /portal/attendance SSR route wired to the Phase 42 recap helper
  - Month-to-date summary counts and 14-day recent history rendered inside the portal shell
  - Guarded fallback states (no_mapping, rpc_error) using PortalStatePanel without exposing recap data

affects: [phase-44-portal-attendance-hardening]

tech-stack:
  added: []
  patterns:
    - "loadPortalAttendanceRecap called once per page render — all derived datasets from one RPC result"
    - "Blocked states (no_mapping, rpc_error) use PortalStatePanel inside the shell; unauthenticated redirects out"
    - "Fallback employee stub matches index.astro pattern for non-ready states"

key-files:
  created:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/attendance.astro
  modified: []

key-decisions:
  - "Fallback employee stub (employee_id='' employee_name='Karyawan') matches existing index.astro pattern — no new convention needed"
  - "no_mapping fallback includes logout action so employee can exit blocked state, matching portal home pattern"
  - "rpc_error fallback offers a reload link pointing back to /portal/attendance"

patterns-established:
  - "Portal page: call loader once, redirect unauthenticated, branch on result.ok in template — no client state"

requirements-completed: [ATTN-01, ATTN-04, PORT-03]

duration: 12min
completed: 2026-03-23
---

# Phase 43 Plan 03: Portal Attendance Recap Route Summary

**Server-rendered `/portal/attendance` page wired to `loadPortalAttendanceRecap` — renders PortalAttendanceSummary month counts and PortalAttendanceHistorySection 14-day history inside the existing portal shell with guarded no_mapping/rpc_error fallbacks.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-03-23T07:35:00Z
- **Completed:** 2026-03-23T07:47:00Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Created `/portal/attendance` SSR route calling `loadPortalAttendanceRecap` exactly once
- Renders month-to-date summary chips and 14-day history cards inside PortalLayout with `activeSection="attendance"`
- Blocked states (no_mapping, rpc_error) use PortalStatePanel and never expose ready-state recap data
- Build passes with no errors

## Task Commits

Each task was committed atomically:

1. **Task 1 + Task 2: Create attendance recap page route with guarded fallback states** - `593b32a` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `src/pages/portal/attendance.astro` — Portal attendance recap route; loads recap once, renders summary + history or state panel fallbacks

## Decisions Made

- Fallback employee stub `{ employee_id: '', employee_name: 'Karyawan', ... }` matches the existing `index.astro` pattern — no new convention introduced
- `no_mapping` fallback includes a logout button so an employee stuck in this state can exit, consistent with portal home
- `rpc_error` fallback reload link points to `/portal/attendance` (self-reload) rather than `/portal` so the employee stays in context

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 44 can now harden the recap-specific loading skeleton, empty state, and exception taxonomy without undoing any custom system
- The guarded fallbacks are intentionally minimal — PortalStatePanel handles everything; Phase 44 can replace with recap-specific variants if needed

---
*Phase: 43-portal-attendance-recap-surface*
*Completed: 2026-03-23*
