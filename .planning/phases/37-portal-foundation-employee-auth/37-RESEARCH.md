# Phase 37: Portal Foundation & Employee Auth - Research

**Researched:** 2026-03-22
**Domain:** Astro employee portal authentication, Supabase SSR session handling, and indexed employee-name search on Postgres
**Confidence:** HIGH for Astro/Supabase routing and session strategy, HIGH for indexed search architecture, MEDIUM for exact project-specific SQL shape

## Summary

Phase 37 should still keep the website mostly static. The current Astro repo is a static marketing site, and Astro's routing model supports mixing static pages with on-demand routes in the same project. The safest shape is to keep all marketing pages static, then mark only portal pages, auth endpoints, and middleware-backed protected routes as on-demand with `prerender = false`.

The authentication layer should use Supabase Auth on the server, not a hand-rolled password table in Astro. Supabase's SSR guidance is built around `@supabase/ssr`, cookie updates in server middleware, and server-side claim validation rather than trusting `getSession()`.

The user-facing login should not depend on `employee_code`. A simpler and safer first-release UX is:

1. Employee types their name.
2. Portal shows a few matching identity cards with name, outlet, position, and photo or initials.
3. Employee selects the right card.
4. Employee enters password.
5. Server signs in using a hidden auth identity derived from the stable `employee_id`, not from name or employee code.

For performance, the database contract should support fast prefix search first and only use fuzzier matching when needed. The best shape is a normalized search column plus:

- a B-tree prefix index using `text_pattern_ops` for fast `LIKE 'query%'` matching
- a trigram GIN index using `pg_trgm` for 3-plus-character fallback matching
- a capped server-side RPC such as `search_portal_employees(...)`
- an Astro search endpoint with debounce, stale-request cancellation, and tiny payloads

The debounce/cancel/cache part is an implementation inference from the indexed-search docs, not a direct product requirement from Astro or Supabase docs. It is the right way to stop the browser from hammering Supabase while keeping the login feeling instant.

**Primary recommendation:** Build the foundation around four contracts: an additive portal-account mapping in Supabase, a server-side provisioning path that creates portal users with stable hidden auth identifiers, an indexed employee-search RPC for login discovery, and an Astro portal shell that uses server-rendered forms plus middleware-protected routes.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUTH-01 | Admin can provision initial employee portal access for an existing employee by enabling portal login and setting an initial password. | Reuse the existing Edge Function pattern from Phase 26 so provisioning stays server-side and can create a hidden Supabase Auth user plus portal mapping atomically. |
| AUTH-02 | Employee can find and choose their own portal profile through name search, then sign in using password. | Use a server-rendered Astro login page plus a lightweight search endpoint that calls a capped indexed RPC. |
| AUTH-03 | Employee session persists across refresh while protected portal routes reject unauthenticated access. | Use Astro on-demand routes, middleware, and Supabase SSR cookie handling for protected `/portal/*` pages. |
| LINK-01 | An authenticated portal session resolves to exactly one employee record before schedule data is shown. | Add a one-to-one portal-account mapping plus a single server-side identity resolver that joins auth identity to one active employee row. |

## Current State Analysis

### 1. The website repo is still a static marketing site

`C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\` currently contains only:

- `src/pages/index.astro`
- marketing components like `Hero.astro`, `Features.astro`, `Header.astro`
- `astro.config.mjs` with `output: 'static'`
- no auth utilities, middleware, server endpoints, or protected routes

That means Phase 37 must add the first server-side website surface rather than extending an existing auth stack.

### 2. The backend already uses Supabase Auth and server-side privileged creation patterns

The main app already has:

- admin email/password auth through Supabase Auth
- JWT role metadata such as `app_role`
- a working privileged account-creation pattern in `supabase/functions/create-admin-user/index.ts`

That is a strong signal to reuse Supabase Auth plus Edge Functions for employee portal provisioning instead of introducing a second password system.

### 3. Employee identity already has the right chooser fields

The current `Employee` model already includes:

- `name`
- `photoUrl`
- `position`
- `homeOutletId`
- `activeBadgeId`
- optional `employeeCode`

That means the product already has enough identity context to support duplicate-safe chooser cards without forcing employee-code setup first.

### 4. Name search is simpler than employee-code onboarding, but it needs a real index

Searching employee names is fine for discovery, but not if the browser sends unbounded `ILIKE '%term%'` queries directly to Supabase on every keypress. The search must be indexed, capped, and routed through a thin server endpoint so the browser never becomes a chatty database client.

### 5. The website repo has build validation but no dedicated JS test harness

Current website automation is:

- `npm run check`
- `npm run build`

There is no Vitest or Playwright setup today. Phase 37 planning should therefore rely on build-time and route-level validation commands, not assume a pre-existing frontend test suite.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Astro | existing `^5.18.1` | Portal pages, form posts, middleware-protected routes | Already installed in the website repo and supports mixed static/on-demand routing. |
| `@astrojs/vercel` | existing `^9.0.5` | Vercel deployment adapter | Already present; required for on-demand routes in production. |
| `@supabase/supabase-js` | latest compatible | Auth and RPC client | Official Supabase JavaScript client for auth, claims, and database access. |
| `@supabase/ssr` | latest compatible | SSR-safe cookie/session helpers | Official Supabase SSR package for middleware-driven cookie refresh and server clients. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Supabase Edge Functions | existing platform pattern | Server-side provisioning with service-role access | Use for creating portal auth users and writing mapping records atomically. |
| PostgreSQL additive migration | project pattern | Portal account table, indexed name-search contract, identity resolver RPC | Use for deterministic search and auth-to-employee resolution before later schedule work. |
| `pg_trgm` extension | PostgreSQL built-in extension | Indexed fuzzy name search fallback | Use only after the prefix-search path, mainly for 3-plus-character typo tolerance. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Supabase Auth + hidden identifier | Custom password table + Astro sessions | Simpler mental model, but much more security and session-handling risk. |
| Indexed name search + chooser cards | Mandatory employee-code onboarding | More deterministic input, but adds admin setup friction and fails the user's preferred simple flow. |
| Mixed static + on-demand routes | Full `output: 'server'` website | Easier mental model, but needlessly makes marketing pages dynamic. |
| Server-rendered form posts and search endpoint | Client-only browser auth flow against Supabase | Faster to prototype, but weaker route protection and more direct database traffic from the browser. |

**Installation (website repo):**

```bash
npm install @supabase/supabase-js @supabase/ssr
```

## Architecture Patterns

### Pattern 1: Keep marketing static, opt portal routes into on-demand rendering

**What:** Leave the website in static mode, and add `export const prerender = false` only to portal pages and auth endpoints.

**When to use:** For protected pages that need cookies, form posts, or server-side identity checks.

**Why:** Astro documents that static projects can opt specific routes out of prerendering, so the portal can be dynamic without regressing the public site.

### Pattern 2: Use server-rendered auth/search flows, not browser-only auth

**What:** Build a login page that uses a tiny client script for the name chooser, posts sign-in to a server endpoint, then redirects to protected `/portal/*` routes after successful sign-in.

**When to use:** For name-search-plus-password login and logout flows that must set and clear cookies safely.

**Why:** This keeps the portal mostly HTML-first and consistent with the current zero-framework marketing repo, while still supporting protected routes.

### Pattern 3: Refresh and validate auth in middleware

**What:** Create a middleware helper that updates Supabase cookies and checks claims for protected portal routes.

**When to use:** On every `/portal/*` request that needs to reject unauthenticated users and preserve session continuity across refresh.

**Why:** Supabase's SSR guidance explicitly routes session maintenance through server middleware and warns not to trust `getSession()` in server code.

### Pattern 4: Separate portal account mapping from the employee table

**What:** Add a dedicated table, for example `employee_portal_accounts`, keyed one-to-one to `employees` and `auth.users`.

**Recommended columns:**

- `employee_id uuid primary key references employees(id)`
- `auth_user_id uuid unique not null`
- `auth_email text unique not null`
- `enabled_at timestamptz not null default now()`
- `provisioned_by uuid null`
- `last_password_reset_at timestamptz null`

**Why:** This makes LINK-01 explicit and gives later phases a stable identity join instead of inferring from mutable employee fields.

### Pattern 5: Derive hidden auth identity from stable employee id, not name or code

**What:** Provision a synthetic auth email from the employee UUID, for example `employee+<uuid>@portal.absenkok.internal`.

**When to use:** For any server-side sign-in path that needs to convert the chosen employee card into a Supabase Auth identifier.

**Why:** `employee_id` is stable and unique. Display name, outlet, and employee code can all be edited or duplicated in ways that are bad auth keys.

### Pattern 6: Use indexed name search for login discovery

**What:** Add a normalized search field and two index paths:

- prefix path: B-tree plus `text_pattern_ops`
- fallback path: GIN plus `gin_trgm_ops`

**Recommended RPC:** `search_portal_employees(search_text text, limit_count integer default 8)`

**Recommended result shape:**

- `employee_id`
- `employee_name`
- `home_outlet_id`
- `home_outlet_name`
- `position`
- `photo_url`
- `active_badge_id`

**Why:** PostgreSQL documents that `xxx_pattern_ops` supports indexed `LIKE` prefix matching, while `pg_trgm` supports indexed `LIKE`, `ILIKE`, and similarity searches. Prefix search is the cheapest path for typeahead. Trigram is useful, but only after the query is long enough to be selective.

### Pattern 7: Provision portal users through an Edge Function

**What:** Reuse the Phase 26 pattern to create the Supabase Auth user and the mapping row in one server-side operation.

**Recommended metadata on the auth user:**

- `app_role: 'employee_portal'`
- `employee_id: <uuid>`

**Why:** The Flutter app and browser must never hold service-role credentials, and the provisioning path already has a proven pattern in the repo.

### Pattern 8: Resolve employee identity server-side before any schedule query

**What:** Add one resolver, preferably a `SECURITY DEFINER` RPC, that takes the authenticated auth user and returns exactly one active employee row or an explicit blocked result.

**Why:** Phase 38 schedule logic should not duplicate identity resolution in multiple queries. Phase 37 should establish the single trusted resolver now.

## Fast Search Contract

### Recommended query flow

1. The login page keeps a plain text name input.
2. The page waits until the user enters at least 2 characters.
3. A small inline script debounces requests around 200-300ms and cancels stale requests with `AbortController`.
4. The browser calls `/portal/auth/search?q=<normalized prefix>`, not Supabase directly.
5. The Astro endpoint normalizes the query, rejects too-short terms, caps results, and calls `search_portal_employees(...)`.
6. The SQL function prefers left-anchored prefix matches and only uses trigram fallback when the query length is at least 3.
7. The user clicks one result card, which fills a hidden `employee_id` field for the actual password submission.

### Why this is fast

From the primary sources:

- PostgreSQL says `text_pattern_ops` is useful for pattern matching with `LIKE` and regular expressions when the default operator class would not be appropriate.
- PostgreSQL says trigram indexes support `LIKE`, `ILIKE`, `=`, and similarity operators.
- PostgreSQL also warns that a pattern with no extractable trigrams degenerates into a full-index scan.

That leads to the correct database strategy:

- prefix index for normal typeahead
- trigram only after 3 characters
- no `%term%` wildcard scanning as the default path

### How to keep browser load low

This is the implementation inference based on the indexing guidance:

- do not query Supabase directly from the browser
- debounce requests
- cancel stale requests
- cache recent prefixes in page memory
- cap results to a tiny payload
- return only the fields needed for chooser cards

That gives the portal the "blazingly fast" feel the user asked for without turning the login page into a constant stream of Supabase traffic.

## Anti-Patterns to Avoid

- **Do not switch the entire Astro site to server output** just to add one protected portal section.
- **Do not store or hash employee passwords in the website repo** when Supabase Auth can own password verification.
- **Do not put service-role secrets in Flutter or browser-exposed code.**
- **Do not query Supabase tables directly from the browser on every keypress.**
- **Do not use `%term%` search as the default login-query path** without an index strategy.
- **Do not use trigram search for 1-2 character inputs** because PostgreSQL warns short patterns can degrade badly.
- **Do not allow name-only login without password.**
- **Do not derive hidden auth identity from mutable display name or employee code.**
- **Do not trust `supabase.auth.getSession()` in middleware or other server guards** for access decisions.

## Recommended Provisioning Contract

### Employee-facing credentials

- Discovery step: search by employee name
- Selection step: choose one identity card
- Password: admin-provided at initial provisioning
- Hidden auth identifier: synthetic email derived from employee id, such as `employee+<uuid>@portal.absenkok.internal`

### Why the hidden email approach is still the right compromise

Supabase Auth's password sign-in is email/phone based, while the product requirement is search-plus-password. A hidden synthetic email lets the system keep a standard, supported auth backend while preserving the simpler employee-facing credential shape.

### Required supporting rules

1. Portal search must only return active, non-archived employees that already have portal access provisioned.
2. The chosen employee card is only a discovery step; `employee_id` becomes the source-of-truth login input.
3. Duplicate display names are handled by showing outlet, position, and photo or initials on the chooser cards.
4. The portal should never display or ask for the synthetic email.
5. The auth metadata and portal-account table must both point back to the same employee.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Portal password verification | Custom password hash table in app schema | Supabase Auth | Avoids owning password hashing, reset logic, and auth hardening. |
| Portal session persistence | Custom signed cookie/session store | Supabase SSR cookie helpers | Fits the documented SSR flow and integrates with auth refresh. |
| Protected-route auth | Client-side local state checks | Astro middleware plus server claims check | Protected routes must reject requests before rendering. |
| Privileged provisioning | Flutter/browser direct admin API calls with secrets | Supabase Edge Function | Keeps service-role usage server-side only. |
| Login discovery | Browser-side full employee directory dump | Indexed RPC plus Astro search endpoint | Keeps payloads tiny and avoids exposing the full employee list up front. |
| Identity lookup per page | Ad hoc joins across multiple pages | One resolver RPC/helper | Prevents inconsistent employee resolution in later phases. |

**Key insight:** The only custom logic worth building here is the mapping between a chosen employee card and the hidden auth identity, plus the indexed search contract that finds that card quickly. Password verification and session handling should stay on the platform.

## Common Pitfalls

### Pitfall 1: Leaving portal routes prerendered

**What goes wrong:** Login pages render, but cookies and protected-route logic do not run per request.

**How to avoid:** Add `prerender = false` to every portal page and auth endpoint.

### Pitfall 2: Trusting `getSession()` server-side

**What goes wrong:** Middleware or route guards accept stale or spoofed session state.

**How to avoid:** Use claim validation in server code and let middleware refresh cookies.

### Pitfall 3: Hitting the database on every keystroke without gating

**What goes wrong:** The login page becomes noisy and slow under real typing.

**How to avoid:** Enforce minimum query length, debounce, cancel stale requests, and cap results.

### Pitfall 4: Leaning on trigram search too early

**What goes wrong:** Very short patterns perform poorly because trigram selectivity is weak.

**How to avoid:** Keep prefix search as the primary path and reserve trigram fallback for longer inputs.

### Pitfall 5: Deriving auth identity from mutable display fields

**What goes wrong:** Changing employee name or employee code can silently desync visible identity from the auth identifier.

**How to avoid:** Use stable employee UUID as the hidden auth identity seed.

### Pitfall 6: Mixing login discovery and schedule lookup in the same phase

**What goes wrong:** Identity bugs get hidden inside schedule queries and are harder to isolate.

**How to avoid:** Phase 37 should end with a protected portal shell and deterministic employee resolution, not schedule fetching.

## Code Examples

### Astro route-level on-demand rendering

```ts
export const prerender = false;
```

Use this on portal pages and auth endpoints, not on the marketing homepage.

### Prefix-search index for login discovery

```sql
CREATE INDEX IF NOT EXISTS employees_portal_search_prefix_idx
ON employees (portal_search_name text_pattern_ops)
WHERE is_active = true AND archived_at IS NULL;
```

### Trigram fallback index

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS employees_portal_search_trgm_idx
ON employees USING gin (portal_search_name gin_trgm_ops)
WHERE is_active = true AND archived_at IS NULL;
```

### Supabase admin user creation

```ts
const { data, error } = await supabase.auth.admin.createUser({
  email: syntheticEmail,
  password,
  email_confirm: true,
  app_metadata: {
    app_role: 'employee_portal',
    employee_id: employeeId,
  },
});
```

### Server-side auth guard rule

```ts
// Guard decisions should validate claims in server code.
// Do not trust getSession() for protected route access checks.
```

## Open Questions

1. **Should login search be global or softly outlet-biased?**
   - What we know: duplicate names are expected and the chooser card can disambiguate with outlet plus position.
   - What's unclear: whether the product wants same-outlet results ranked above others when the browser already knows outlet context.
   - Recommendation: keep Phase 37 global and deterministic; add smarter ranking later only if real usage demands it.

2. **Should photo or badge appear on chooser cards in Phase 37?**
   - What we know: the employee model already exposes `photoUrl` and `activeBadgeId`.
   - What's unclear: whether badge metadata is cheap enough to resolve for the website in this phase.
   - Recommendation: use photo if already available, otherwise fall back to initials. Treat badge visuals as optional polish, not a blocker.

3. **Should admin reset and reprovision share one flow?**
   - What we know: first-release ops will likely need a simple recovery path.
   - What's unclear: whether reset must preserve the same auth user or replace it.
   - Recommendation: Phase 37 should at least support repeatable password reset/reprovision through the same backend contract, even if the exact UX stays minimal.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Flutter `flutter_test` plus targeted `flutter analyze`; Astro `astro check`; build smoke via `astro build` |
| Config file | none beyond existing project defaults |
| Quick run command | Website: `npm run check` |
| Full suite command | Website: `npm run build` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUTH-01 | Provisioning creates a portal auth account and mapping for one employee without requiring employee_code setup | smoke/static validation | `powershell -Command "Select-String -Path 'supabase/functions/*/index.ts','sql/phase_37_*.sql' -Pattern 'createUser','employee_portal_accounts','employee_id' | Measure-Object"` | ❌ Wave 1 |
| AUTH-02 | Login form can search employee names, select one employee id, and submit password through the Astro auth path | build/check smoke | `npm run check` | ❌ Wave 2 |
| AUTH-03 | Protected portal routes are on-demand and remain authenticated across refresh | build/check smoke | `npm run build` | ❌ Wave 2 |
| LINK-01 | Authenticated portal user resolves to exactly one active employee before schedule access | SQL/helper smoke | `powershell -Command "Select-String -Path 'sql/phase_37_*.sql' -Pattern 'resolve_portal_employee','search_portal_employees','employee_portal_accounts' | Measure-Object"` | ❌ Wave 1 |

### Sampling Rate

- **Per task commit:** targeted command for the touched subsystem (`flutter analyze`, `npm run check`, or SQL grep smoke)
- **Per wave merge:** `npm run build` in the website repo and targeted Flutter validation in the app repo
- **Phase gate:** portal routes build successfully, provisioning artifacts exist, indexed search contract exists, and identity resolver contract is present before moving to Phase 38

### Wave 0 Gaps

- None mandatory. Existing validation for this phase can rely on build-time and static contract checks without introducing a new frontend test harness.

## Sources

### Primary (HIGH confidence)

- Astro routing reference: [https://docs.astro.build/en/reference/routing-reference/#prerender](https://docs.astro.build/en/reference/routing-reference/#prerender)
- Astro authentication guide: [https://docs.astro.build/en/guides/authentication/](https://docs.astro.build/en/guides/authentication/)
- Supabase SSR client guide: [https://supabase.com/docs/guides/auth/server-side/creating-a-client](https://supabase.com/docs/guides/auth/server-side/creating-a-client)
- Supabase admin createUser reference: [https://supabase.com/docs/reference/javascript/auth-admin-createuser](https://supabase.com/docs/reference/javascript/auth-admin-createuser)
- Supabase full text search guide: [https://supabase.com/docs/guides/database/full-text-search](https://supabase.com/docs/guides/database/full-text-search)
- PostgreSQL operator classes docs: [https://www.postgresql.org/docs/current/indexes-opclass.html](https://www.postgresql.org/docs/current/indexes-opclass.html)
- PostgreSQL `pg_trgm` docs: [https://www.postgresql.org/docs/current/pgtrgm.html](https://www.postgresql.org/docs/current/pgtrgm.html)
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\astro.config.mjs`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\package.json`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\pages\index.astro`
- `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\layouts\BaseLayout.astro`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\supabase\functions\create-admin-user\index.ts`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\lib\services\admin_onboarding_service.dart`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\lib\models\employee.dart`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\ROADMAP.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\REQUIREMENTS.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\STATE.md`

### Secondary (MEDIUM confidence)

- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\phases\26-admin-onboarding\26-RESEARCH.md`
- `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\.planning\PROJECT.md`

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - official Astro and Supabase docs plus current repo state align
- Architecture: HIGH - the website repo shape and platform docs clearly support mixed static/on-demand protected routes
- Search strategy: HIGH - official PostgreSQL docs directly support prefix operator classes and trigram behavior
- Provisioning contract: MEDIUM - stable employee-id hidden auth identifiers are project-specific, but they fit the platform and current constraints

**Research date:** 2026-03-22
**Valid until:** 2026-04-21
