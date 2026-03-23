---
phase: 43-portal-attendance-recap-surface
plan: 02
subsystem: ui
tags: [astro, portal, attendance, navigation, mobile]

# Dependency graph
requires:
  - phase: 42-attendance-recap-read-model
    provides: loadPortalAttendanceRecap helper and typed recap model
  - phase: 39-employee-portal-schedule-ux
    provides: PortalLayout shell, home page structure
provides:
  - activeSection prop on PortalLayout for 'home' | 'attendance' tab state
  - compact bottom shell nav linking /portal and /portal/attendance
  - attendance recap CTA card on the portal home page
affects:
  - 43-portal-attendance-recap-surface plan 03 (recap page itself)
  - 44-portal-attendance-recap-hardening

# Tech tracking
tech-stack:
  added: []
  patterns:
    - activeSection prop pattern for shell-level nav state (server-render-friendly, no client JS)
    - inline SVG icons pattern for zero-dependency icons inside Astro components

key-files:
  created: []
  modified:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/layouts/PortalLayout.astro
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/index.astro

key-decisions:
  - "activeSection defaults to 'home' so existing PortalLayout callers need no update"
  - "Shell nav placed inside <header> below employee identity row, above progress bar — keeps sticky header compact"
  - "Home CTA card uses inline SVG icons to avoid adding any package dependency"

patterns-established:
  - "Pattern 1: Shell nav via activeSection prop — all portal pages pass activeSection to PortalLayout; no client-side router state needed"
  - "Pattern 2: Recap CTA below greeting, above primary content — recap entry is visible but does not displace the schedule home role"

requirements-completed: [ATTN-01, PORT-03]

# Metrics
duration: 7min
completed: 2026-03-23
---

# Phase 43 Plan 02: Portal Shell Nav and Home CTA Summary

**Shell-level two-tab navigation (Beranda/Kehadiran) via activeSection prop in PortalLayout, plus compact attendance recap CTA card on the home page**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-23T07:26:36Z
- **Completed:** 2026-03-23T07:33:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Extended PortalLayout with `activeSection: 'home' | 'attendance'` prop (defaults to `'home'` — backward compatible)
- Added compact phone-safe shell nav with pink active-tab indicator inside the sticky header
- Added attendance recap CTA card to the portal home below the greeting, with inline SVG calendar icon and chevron

## Task Commits

Each task was committed atomically:

1. **Task 1: Add attendance navigation state to portal shell** - `909c406` (feat)
2. **Task 2: Add recap entry point to portal home** - `7d5541a` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `src/layouts/PortalLayout.astro` - Added `ActiveSection` type, `activeSection` prop, and shell nav with active tab styling
- `src/pages/portal/index.astro` - Passes `activeSection="home"`, adds attendance recap CTA card

## Decisions Made
- `activeSection` defaults to `'home'` so the existing `not-linked` and `error` PortalLayout usages in `index.astro` require no change (only the `ready` and `empty` branches were updated for completeness)
- Shell nav placed inside the `<header>` below the identity row rather than as a separate `<nav>` element outside the header — keeps the entire chrome in one sticky zone
- Inline SVG icons chosen over any icon package to keep the component zero-dependency

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `npm run check` reported 16 errors in `supabase/functions/` (Deno imports not resolved by the Node tsconfig) and 1 warning in `PortalAttendanceHistorySection.astro` — all pre-existing, unrelated to this plan's changes, and out-of-scope per deviation rules.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Shell nav and home CTA are in place; plan 03 can create `/portal/attendance` and use `activeSection="attendance"` immediately
- The `activeSection` prop is discoverable from the PortalLayout interface; no further shell changes are expected for Phase 43

---
*Phase: 43-portal-attendance-recap-surface*
*Completed: 2026-03-23*
