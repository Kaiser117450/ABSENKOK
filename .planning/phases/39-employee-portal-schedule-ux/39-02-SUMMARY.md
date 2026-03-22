---
phase: 39-employee-portal-schedule-ux
plan: "02"
subsystem: employee-portal-web
tags: [portal, auth, logout, astro, mobile-ux]
dependency_graph:
  requires: [39-01]
  provides: [portal-shell-wired, portal-logout-local-scope, portal-home-state-router]
  affects: [portal-login-page, portal-layout]
tech_stack:
  added: []
  patterns: [discriminated-union-page-state, local-scope-signout, server-side-render-astro]
key_files:
  created: []
  modified:
    - src/pages/portal/auth/sign-out.ts
    - src/pages/portal/login.astro
    - src/layouts/PortalLayout.astro
    - src/pages/portal/index.astro
decisions:
  - "Portal sign-out uses scope: 'local' — auth-js default is 'global'; explicit override required for AUTH-04"
  - "not-linked and error render distinct PortalStatePanel variants inside PortalLayout — blocked states stay in shell"
  - "empty state retains employee greeting — identity preserved from loadPortalHome empty branch"
  - "Pending affordance (progress bar + button state) uses inline script — no client framework added"
metrics:
  duration: ~5 min
  completed: "2026-03-23"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 4
---

# Phase 39 Plan 02: Portal Shell Wiring and Page Integration Summary

Portal shell hardened with phone-first layout and pending affordance; logout explicitly local-scope; portal home rewritten as thin page-state router using Phase 39 components.

## What Was Built

### Task 1: Harden portal shell and logout contract (commit: be4a359)

**`src/pages/portal/auth/sign-out.ts`**
- Both POST and GET handlers now call `supabase.auth.signOut({ scope: 'local' })`
- Redirects to `/portal/login?signed_out=1` — portal-scoped target
- AUTH-04 is now explicit in code rather than relying on auth-js default

**`src/pages/portal/login.astro`**
- Detects `signed_out=1` query param
- Renders a green confirmation banner: "Anda telah keluar dari Portal Karyawan. Masuk kembali untuk melihat jadwal."
- Existing invalid-login red error banner behavior unchanged

**`src/layouts/PortalLayout.astro`**
- Phone-first sticky header: `h-12` on mobile, `sm:h-14` on desktop; `px-3` / `sm:px-6` gutters
- Avatar shrinks slightly on mobile (`w-7 h-7`); name text still hidden on small screens
- Added `<div id="portal-progress">` — a thin pink progress bar under the header
- Inline script animates the bar and disables/re-labels the Keluar button on form submit
- `aria-busy` attribute toggled on `<main>` during the pending state

### Task 2: Rewrite portal home as page-state router (commit: 43df657)

**`src/pages/portal/index.astro`**
- `loadPortalSchedule` replaced with `loadPortalHome(Astro)` — single call, state-union result
- Branches on `state.kind`:
  - `unauthenticated` → `Astro.redirect('/portal/login')` (belt-and-suspenders)
  - `ready` → `<PortalLayout>` + greeting + `<PortalScheduleSection schedule={state.schedule} />`
  - `empty` → `<PortalLayout>` + greeting + `<PortalStatePanel variant="empty" />`
  - `not-linked` → `<PortalLayout>` + `<PortalStatePanel variant="not-linked">` with logout button
  - `error` → `<PortalLayout>` + `<PortalStatePanel variant="error">` with reload link
- Schedule rows never rendered in blocked states (PORT-02 satisfied)
- not-linked and error are visually and semantically distinct

## Deviations from Plan

None — plan executed exactly as written.

## Verification

- `scope: 'local'` confirmed in sign-out.ts (both POST and GET handlers)
- `signed_out=1` confirmed in redirect target and login.astro detection
- `Keluar` confirmed in PortalLayout.astro logout button label
- `loadPortalHome` confirmed in portal/index.astro
- `npm run build` passed with no errors

## Self-Check: PASSED

All key files confirmed present. Both task commits confirmed in git log (be4a359, 43df657).
