---
phase: 37-portal-foundation-employee-auth
plan: 04
subsystem: portal-website
tags: [portal, employee-context, astro, supabase-rpc, auth]
dependency_graph:
  requires: [37-01, 37-03]
  provides: [resolvePortalEmployee helper, PortalLayout, portal home page]
  affects: [phase-38-schedule]
tech_stack:
  added: []
  patterns: [server-side RPC resolution before render, ResolveResult union type, PortalLayout shell]
key_files:
  created:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/employee.ts
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/layouts/PortalLayout.astro
  modified:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/index.astro
decisions:
  - "resolvePortalEmployee returns a ResolveResult union rather than throwing — callers decide redirect vs block-render per failure mode"
  - "Blocked identity (no_mapping/rpc_error) renders an inline error page rather than redirecting, so the user sees a useful message rather than a login loop"
metrics:
  duration: ~10 minutes
  completed: 2026-03-22
  tasks_completed: 2
  files_changed: 3
---

# Phase 37 Plan 04: Protected Portal Shell and Employee-Context Helper Summary

**One-liner:** Server-side employee-context resolver (resolvePortalEmployee RPC call with typed ResolveResult union) plus protected PortalLayout shell and initial home page that blocks render on identity failure.

## Tasks Completed

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | Create server-side employee-context helper | ebfb4e2 | src/lib/portal/employee.ts |
| 2 | Build protected portal shell and home page | 543d1f2 | src/layouts/PortalLayout.astro, src/pages/portal/index.astro |

## What Was Built

### `src/lib/portal/employee.ts`
Single reusable helper for all portal pages needing employee identity before render:
- `resolvePortalEmployee(Astro)` calls `resolve_portal_employee` RPC (from plan 01)
- Uses `getUser()` not `getSession()` per Supabase SSR best practice
- Returns typed `ResolveResult` union: `{ ok: true, employee: PortalEmployee }` or `{ ok: false, reason, message }`
- Three failure modes: `unauthenticated`, `no_mapping`, `rpc_error`
- `PortalEmployee` type includes: id, name, position, home_outlet_id, home_outlet_name, photo_url, active_badge_id

### `src/layouts/PortalLayout.astro`
Employee-facing shell layout:
- Sticky top nav with ABSENKOK brand, "Portal Karyawan" badge
- Employee avatar (photo or initials fallback) + name display
- Logout form posting to `/portal/auth/sign-out`
- Visually distinct from marketing homepage (gray background, compact nav)
- `max-w-3xl` centered content area

### `src/pages/portal/index.astro`
Protected employee home page:
- `export const prerender = false` — fully on-demand
- Calls `resolvePortalEmployee` before rendering any content
- Unauthenticated: redirects to `/portal/login` (belt-and-suspenders, middleware already guards)
- Resolved: renders greeting, identity card (avatar + name + position + outlet), schedule placeholder "Jadwal akan tersedia di fase 38"
- Failed mapping: renders blocked-access error card with logout button — no schedule UI shown

## Verification

- `npm run check` — 0 errors, 0 warnings
- `npm run build` — Complete, server built in 3.52s

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

### Files created/modified
- [x] src/lib/portal/employee.ts — FOUND
- [x] src/layouts/PortalLayout.astro — FOUND
- [x] src/pages/portal/index.astro — FOUND (modified)

### Commits
- [x] ebfb4e2 — FOUND
- [x] 543d1f2 — FOUND

## Self-Check: PASSED
