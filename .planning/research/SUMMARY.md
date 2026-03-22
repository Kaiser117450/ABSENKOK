# Project Research Summary

**Project:** Absensi Enakko
**Domain:** Employee-facing schedule portal
**Researched:** 2026-03-22
**Confidence:** HIGH

## Executive Summary

`v6.1` should not introduce a second web stack. The lowest-risk path is to extend the existing Astro 5 website into a mixed static + SSR application: keep the marketing pages public and prerendered, then add protected `/portal/*` routes rendered on demand for employees. Supabase already owns the source-of-truth schedule data, so it should also own employee auth/session scope and row-level access rules.

The main product risk is not frontend rendering; it is identity and data scope. The portal only works if an authenticated user can be mapped cleanly to a single employee record and if schedule reads are enforced at the server/RLS layer. The safest milestone shape is therefore narrow: portal foundation, employee identity mapping, and a mobile-first read-only schedule experience.

## Key Findings

### Recommended Stack

The existing website repo already uses `astro@5.18.1` with `@astrojs/vercel@9.0.5`, so adding server output is cheaper than introducing Next.js or another app shell. Supabase's SSR guidance supports separate browser/server clients with cookie-aware auth handling, which fits a protected employee portal well.

**Core technologies:**
- `astro@5.18.1`: server-rendered employee portal routes inside the existing website
- `@astrojs/vercel@9.0.5`: deploy SSR routes on the current hosting target
- `@supabase/supabase-js@2.99.3` + `@supabase/ssr@0.9.0`: authenticated browser/server clients for portal access
- Supabase Auth + Postgres RLS: enforce employee-specific data visibility safely

### Expected Features

The user chose a focused milestone with "view schedule" as the first employee job, so the portal should launch with secure access and a read-only personal schedule rather than broader workforce workflows.

**Must have (table stakes):**
- Employee login to a private portal
- Employee can view only their own upcoming shifts
- Mobile-friendly "today / this week" schedule view
- Clear "not linked" and "no shifts" states

**Should have (competitive):**
- Attendance recap beside schedule
- Better filters and personal account context

**Defer (v2+):**
- Time-off requests
- Shift swaps
- Notifications/reminders

### Architecture Approach

Use the Astro website as the portal shell, add auth middleware plus Supabase SSR helpers, and build a read-optimized schedule query layer instead of exposing the admin planning model directly.

**Major components:**
1. Portal routes under `/portal/*` - employee-facing pages only
2. Auth middleware + Supabase SSR clients - protected routing and session refresh
3. Employee identity mapping + schedule query layer - safe bridge from auth user to employee schedule

### Critical Pitfalls

1. **No employee identity mapping** - solve the auth-user to employee-record bridge before building the UI
2. **Static-site assumptions** - protected routes need server output and SSR sessions, not browser-only auth hacks
3. **Data leakage from admin-shaped queries** - scope all reads server-side with RLS or dedicated RPCs
4. **Date logic drift** - carry the existing timezone and cross-day schedule rules into the portal
5. **Over-scoping v6.1** - keep the release centered on schedule visibility, not approvals or swaps

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 37: Portal Foundation and Employee Auth
**Rationale:** Protected employee routes and session handling must exist before any self-service feature can ship.
**Delivers:** Astro server output setup, portal route tree, auth/session middleware, and employee identity mapping foundation.
**Addresses:** employee login and access separation.
**Avoids:** static-site auth hacks and weak identity mapping.

### Phase 38: Employee Schedule Read Model
**Rationale:** The portal needs a safe, employee-scoped data path before the UI can be trusted.
**Delivers:** additive schema/mapping support if needed, RLS-safe schedule queries or RPCs, and cross-day-aware schedule formatting inputs.
**Uses:** Supabase Auth, Postgres RLS, existing schedule tables.
**Implements:** server-side employee schedule query layer.

### Phase 39: Portal Schedule UI
**Rationale:** Once access and data scope are correct, build the mobile-first employee-facing pages.
**Delivers:** login page, employee home, schedule page, and empty/error states optimized for phone usage.
**Uses:** Astro pages/components with optional minimal client interactivity.
**Implements:** the focused "view schedule" v6.1 milestone outcome.

### Phase Ordering Rationale

- Auth and identity mapping come first because every employee feature depends on them.
- The read model comes before UI so data scope, RLS, and date rules are solved once in the backend layer.
- The final UI phase stays focused because v6.1 is intentionally narrow and should not absorb approval workflows.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 37:** employee auth and identity-linking details, because the current system is kiosk/admin oriented
- **Phase 38:** exact RLS/query strategy, because employee access must be safer than admin-only internal reads

Phases with standard patterns (skip research-phase):
- **Phase 39:** schedule UI composition, because the product is already clear and the main unknowns are data and auth

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified against the current website repo and official Astro/Supabase docs |
| Features | HIGH | Driven directly by the user's chosen milestone scope |
| Architecture | HIGH | Mixed static + SSR Astro is a straightforward fit for the current deployment model |
| Pitfalls | HIGH | The main risks are standard for auth-scoped employee portals and clear in this domain |

**Overall confidence:** HIGH

### Gaps to Address

- Employee auth UX is not chosen yet (magic link, password, or admin-invited credentials) and should be finalized during requirements
- The exact employee-to-auth mapping path needs confirmation from the current Supabase schema before Phase 37 planning

## Sources

### Primary (HIGH confidence)
- Local repo: `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\package.json` - current website stack
- [Astro on-demand rendering docs](https://docs.astro.build/en/guides/on-demand-rendering/) - server output model
- [Astro actions docs](https://docs.astro.build/en/guides/actions/) - backend mutations/forms pattern
- [Astro sessions docs](https://docs.astro.build/en/guides/sessions/) - session support in Astro server apps
- [Supabase SSR client docs](https://supabase.com/docs/guides/auth/server-side/creating-a-client) - browser/server client split
- [Supabase RLS docs](https://supabase.com/docs/guides/database/postgres/row-level-security) - exposed-schema policy requirements

### Secondary (MEDIUM confidence)
- Existing product context in `.planning/PROJECT.md` and `.planning/STATE.md` - current platform constraints and deferred roadmap items

---
*Research completed: 2026-03-22*
*Ready for roadmap: yes*
