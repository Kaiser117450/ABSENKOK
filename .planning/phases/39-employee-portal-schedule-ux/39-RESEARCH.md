# Phase 39: Employee Portal Schedule UX - Research

**Researched:** 2026-03-22
**Domain:** Mobile-first Astro portal UX, explicit portal schedule state modeling, and portal-only logout handling
**Confidence:** HIGH for page-state architecture, HIGH for logout hardening, MEDIUM for final loading-state presentation

## Summary

Phase 38 proved the secure data path. The employee portal can already resolve the authenticated employee and render current-week schedule rows, but the current `/portal` page still behaves like a bridge screen instead of a finished employee surface:

1. `no_mapping` and `rpc_error` are collapsed into one blocked page
2. state resolution, schedule formatting, and UI markup all live in `src/pages/portal/index.astro`
3. the current logout route calls `supabase.auth.signOut()` with the installed default scope of `global`
4. the schedule list is safe on mobile, but not intentionally designed as the employee's primary phone view

Phase 39 should convert the portal home into an explicit page-state model with reusable employee-facing components. The clean split is:

1. introduce a `PortalHomeState` union that maps the current backend results into `ready`, `empty`, `not-linked`, and `error`
2. render those states through shared Astro components designed for stacked phone layouts rather than inline page-specific markup
3. harden logout to `scope: 'local'`, then make the shell and login page explicitly communicate that the employee signed out of the portal only

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUTH-04 | Employee can sign out of the portal without affecting kiosk or admin sessions. | The installed `@supabase/auth-js` build defaults `signOut()` to `{ scope: 'global' }`, so the logout route should pass `{ scope: 'local' }` explicitly and keep the redirect scoped to `/portal/login`. |
| LINK-02 | If no linked employee record exists, the portal shows a clear "account not linked" state instead of exposing schedule data. | The current helper already reports `no_mapping`; the missing work is a dedicated page-state mapping and a distinct UI panel instead of the generic blocked screen. |
| PORT-01 | Portal schedule pages are usable on a phone-sized browser without relying on the admin schedule grid. | The current page already avoids the admin grid, but the weekly list still needs a deliberate mobile card/timeline treatment and less duplicated identity chrome. |
| PORT-02 | Portal distinguishes loading, empty schedule, not-linked, and error states clearly. | Current code only cleanly exposes `ready` and a combined blocked state. Phase 39 should introduce a state union and shared state panel component to cover all required surfaces. |

## Current State Analysis

### 1. The data path is already solved

The website repo already has:

- `resolvePortalEmployee()` in `src/lib/portal/employee.ts`
- `loadPortalSchedule()` in `src/lib/portal/schedule.ts`
- a protected `/portal` page in `src/pages/portal/index.astro`
- a dedicated portal shell in `src/layouts/PortalLayout.astro`

That means Phase 39 is a UI/state phase, not a new backend phase.

### 2. The current page collapses different blocked states together

`src/pages/portal/index.astro` currently treats every non-auth blocked outcome as one "Akun tidak terhubung" screen. That is enough for Phase 37/38 safety, but it misses:

- LINK-02 because "not linked" is not distinct from backend failure
- PORT-02 because `error` has no dedicated presentation

### 3. The current logout route is not explicit enough for AUTH-04

The installed local package shows:

```js
async signOut(options = { scope: 'global' }) {
```

So the current route:

```ts
await supabase.auth.signOut();
```

inherits `global` scope unless the route overrides it. Phase 39 should set:

```ts
await supabase.auth.signOut({ scope: 'local' });
```

### 4. The current page is mobile-safe, but not yet mobile-first

The existing `/portal` layout already uses stacked cards and avoids the admin grid. The remaining issues are:

- the page duplicates identity info in both the sticky header and the main card
- blocked states render outside the portal shell
- the week list is a plain divider list rather than a deliberately compact employee schedule surface

### 5. Loading needs to be modeled at the shell/form level

Astro resolves the page on the server before HTML reaches the browser, so there is no useful SPA-style loading spinner on first render. The meaningful loading experience here is:

- submit-pending feedback for logout and future form-driven actions
- optional transition/pending overlay in the portal shell
- shared loading card/skeleton visuals so loading belongs to the same state family as empty/error/not-linked

## Recommended Architecture

1. Create `src/lib/portal/home.ts` with a discriminated union such as:
   - `ready`
   - `empty`
   - `not-linked`
   - `error`
   - `unauthenticated`
2. Keep all authenticated states inside `PortalLayout.astro`; only `unauthenticated` should redirect to `/portal/login`.
3. Add shared components such as:
   - `src/components/portal/PortalStatePanel.astro`
   - `src/components/portal/PortalScheduleSection.astro`
4. Update the sign-out route to:
   - call `signOut({ scope: 'local' })`
   - redirect to `/portal/login?signed_out=1`
   - keep portal copy explicitly scoped to the employee portal
5. Implement loading as a shared visual state for pending submits/navigation, not as a client-framework hydration flow.

## Anti-Patterns

- Do not keep `no_mapping` and `rpc_error` on the same card with the same message.
- Do not call `supabase.auth.signOut()` without an explicit scope.
- Do not move portal states back to raw inline conditionals in `index.astro`.
- Do not introduce the admin schedule grid or a table-based layout into the employee portal.
- Do not add a client framework just to render state cards or a pending indicator.

## Validation Architecture

| Property | Value |
|----------|-------|
| Framework | Astro `astro check` + `astro build`; targeted PowerShell source-contract checks |
| Quick run | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` |
| Full suite | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` |

### Requirement Test Map

| Req ID | Automated Command |
|--------|-------------------|
| AUTH-04 | `Select-String` for `scope: 'local'` and `signed_out=1` in `sign-out.ts` and `login.astro` |
| LINK-02 | `npm run check` after the typed portal-home helper and page wiring land |
| PORT-01 | `npm run build` after the mobile-first portal page is wired |
| PORT-02 | `Select-String` for `loading`, `empty`, `not-linked`, and `error` in the new helper/components plus `npm run build` |

## Manual Verifications

- Open `/portal` at phone width and confirm the page remains one-column with no horizontal scroll.
- Sign in with a portal account that has no active employee mapping and confirm the portal renders the dedicated not-linked state with no schedule rows.
- Trigger logout from `/portal`, confirm redirect to `/portal/login?signed_out=1`, and confirm the portal session is gone while unrelated kiosk/admin sessions remain unaffected.

## Sources

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/STATE.md`
- `.planning/phases/38-employee-schedule-read-model/38-RESEARCH.md`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\src\\layouts\\PortalLayout.astro`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\src\\lib\\portal\\employee.ts`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\src\\lib\\portal\\schedule.ts`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\src\\pages\\portal\\index.astro`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\src\\pages\\portal\\login.astro`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\src\\pages\\portal\\auth\\sign-out.ts`
- `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\node_modules\\@supabase\\auth-js\\dist\\main\\GoTrueClient.js`
