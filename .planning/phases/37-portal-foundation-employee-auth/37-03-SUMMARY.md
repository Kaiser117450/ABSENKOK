---
phase: 37-portal-foundation-employee-auth
plan: 03
subsystem: website-portal-auth
tags: [astro, supabase-ssr, portal, auth, middleware, search]
dependency_graph:
  requires: [37-01]
  provides: [website-portal-login, portal-middleware, search-endpoint, sign-in-endpoint]
  affects: [portal-routes, marketing-static-pages]
tech_stack:
  added: ["@supabase/supabase-js@^2.99.3", "@supabase/ssr@^0.9.0"]
  patterns: [astro-on-demand-routes, supabase-ssr-cookies, debounced-search-chooser, server-rendered-form-posts]
key_files:
  created:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/supabase/server.ts
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/auth.ts
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/middleware.ts
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/login.astro
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/index.astro
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/auth/search.ts
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/auth/sign-in.ts
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/auth/sign-out.ts
  modified:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/package.json
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/astro.config.mjs
key_decisions:
  - "Kept output: static (Astro 5 removed hybrid mode — static now supports per-route prerender=false)"
  - "Used parseCookieHeader + filter for undefined values to satisfy GetAllCookies type contract"
  - "middleware calls getUser() not getSession() per Supabase SSR docs for server-side validation"
  - "search endpoint returns empty results for <2-char queries without hitting the DB"
  - "Cache-Control: private, max-age=10 on search to reduce repeated prefix refetches"
metrics:
  duration_seconds: 290
  completed_date: "2026-03-22"
  tasks_completed: 2
  tasks_total: 2
  files_created: 8
  files_modified: 2
---

# Phase 37 Plan 03: Portal Auth Website Infrastructure Summary

**One-liner:** SSR-safe Supabase client, portal middleware guard, debounced name-search login, and server-rendered sign-in/sign-out endpoints in Astro 5 using `@supabase/ssr` cookie helpers.

## What Was Built

### Task 1: Supabase SSR utilities and portal middleware

- `src/lib/supabase/server.ts` — `createSupabaseServerClient(cookieHeader, responseHeaders?)` builds an SSR-safe client using `@supabase/ssr` `createServerClient`. Cookie `getAll` parses the raw header string and filters out undefined values to satisfy the strict `GetAllCookies` type. Cookie `setAll` appends `Set-Cookie` to the provided response headers object.
- `src/lib/portal/auth.ts` — pure helpers with no framework imports: `buildPortalAuthEmail(employeeId)` derives the hidden auth email, `normalizeSearchText(raw)` lowercases and collapses whitespace, `isProtectedPortalRoute(pathname)` decides whether a path requires authentication.
- `src/middleware.ts` — intercepts `/portal/*` requests, creates an SSR Supabase client, calls `getUser()` (not `getSession()`) to refresh and validate the session, propagates updated cookies to the response, then redirects unauthenticated requests to `/portal/login` for protected routes. Marketing routes are skipped entirely.

### Task 2: Name-search login page and server-rendered auth endpoints

- `src/pages/portal/login.astro` — phone-friendly login card with a debounced (250 ms) name-search input, `AbortController`-based stale-request cancellation, in-page prefix cache, identity chooser cards (avatar/initials, name, outlet, position), hidden `employee_id` field, and a password field. Minimal vanilla JS inline script — no client framework. Form posts to `/portal/auth/sign-in`.
- `src/pages/portal/auth/search.ts` — GET endpoint; normalizes query, rejects `< 2` chars, calls `search_portal_employees` RPC, caps at 8 results, returns minimal JSON with `private, max-age=10` cache header.
- `src/pages/portal/auth/sign-in.ts` — POST endpoint; requires `employee_id`, derives hidden auth email with `buildPortalAuthEmail`, calls `signInWithPassword` server-side, redirects to `/portal` on success or `/portal/login?error=invalid` on failure without leaking whether account exists.
- `src/pages/portal/auth/sign-out.ts` — supports both POST and GET; calls `supabase.auth.signOut()` server-side, flushes cookies, redirects to `/portal/login`.
- `src/pages/portal/index.astro` — minimal protected landing page confirming middleware works; placeholder for Phase 38 schedule content.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Astro 5 removed `output: "hybrid"`**

- **Found during:** Task 1 verification (`astro check`)
- **Issue:** Plan noted keeping the site in static mode with per-route on-demand rendering, but `output: "hybrid"` was the Astro 4 mechanism. Astro 5 removed it; `output: "static"` is now the unified mode with `prerender = false` per route.
- **Fix:** Reverted to `output: 'static'`. All portal routes use `export const prerender = false`. Marketing pages remain static as before.
- **Files modified:** `astro.config.mjs`

**2. [Rule 1 - Bug] `parseCookieHeader` returns `value?: string | undefined` but `GetAllCookies` requires `value: string`**

- **Found during:** Task 1 verification (`astro check`)
- **Issue:** TypeScript error TS2769 — `{ name: string; value?: string | undefined }[]` is not assignable to `{ name: string; value: string; }[]`.
- **Fix:** Added `.filter((c): c is { name: string; value: string } => c.value !== undefined)` after `parseCookieHeader(cookieHeader)` in both `server.ts` and `middleware.ts`.
- **Files modified:** `src/lib/supabase/server.ts`, `src/middleware.ts`

## Verification

- `npm run check` passes with 0 errors, 0 warnings, 0 hints (19 files checked)
- Portal login page exists with `name="search_name"` input, hidden `employee_id`, password field
- Middleware protects `/portal` and all sub-paths except login and auth endpoints
- Search, sign-in, sign-out endpoints all have `export const prerender = false`
- Marketing pages remain static and untouched

## Self-Check: PASSED

- `src/lib/supabase/server.ts` — FOUND
- `src/lib/portal/auth.ts` — FOUND
- `src/middleware.ts` — FOUND
- `src/pages/portal/login.astro` — FOUND
- `src/pages/portal/auth/search.ts` — FOUND
- `src/pages/portal/auth/sign-in.ts` — FOUND
- `src/pages/portal/auth/sign-out.ts` — FOUND
- Task 1 commit 5bb3d3d — FOUND
- Task 2 commit c447551 — FOUND
