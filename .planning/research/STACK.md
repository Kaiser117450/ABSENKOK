# Stack Research

**Domain:** Employee-facing schedule portal for Absensi Enakko
**Researched:** 2026-03-22
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `astro` | `5.18.1` | Portal shell with protected routes and server-rendered pages | The existing website already runs on Astro, and Astro supports on-demand rendering so the same app can keep marketing pages static while rendering employee portal routes on the server. |
| `@astrojs/vercel` | `9.0.5` | Deployment adapter for server output on Vercel | The website already ships on Vercel, so this is the lowest-friction way to add authenticated SSR routes without introducing a second hosting model. |
| `@supabase/supabase-js` | `2.99.3` | Browser and server database/auth client | Supabase already backs the attendance system, so reusing it keeps employee auth, schedules, and future attendance data in one security model. |
| `@supabase/ssr` | `0.9.0` | Cookie-aware SSR auth helpers | Supabase documents SSR clients for browser and server contexts so auth tokens can be refreshed and read correctly in server-rendered apps. |
| Supabase Auth + Postgres RLS | existing backend | Employee authentication and row-level data isolation | Employee self-service is only safe if schedule reads are scoped per authenticated employee, which is exactly what RLS is for. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `zod` | `4.3.6` | Shared validation for login and future request forms | Use when Astro Actions alone are not enough and the same schema needs to validate server actions and client-side UI. |
| `@astrojs/react` | `5.0.1` | Interactive islands for richer schedule filters or request flows | Add only if the employee portal grows past simple SSR pages and small form interactions. |
| `@astrojs/check` | existing | Type and route validation in the website repo | Keep using it as the first guardrail when the static marketing site becomes a mixed static+server application. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `astro check` | Validate routes, props, and integration mistakes early | Run it on every portal phase because server output adds more routing and typing surface than the current static site. |
| Supabase SQL migrations | Keep employee auth mapping and RLS policy changes explicit | The production database is live, so every portal-facing schema change must stay additive and reviewable. |

## Installation

```bash
# Core
npm install @supabase/supabase-js @supabase/ssr

# Supporting
npm install zod

# Optional interactive UI
npm install @astrojs/react react react-dom
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Extend the existing Astro site into mixed static + SSR | Create a brand new Next.js app | Use a new app only if the employee portal quickly grows into a highly interactive dashboard with deep client-side state. |
| Supabase Auth + SSR cookies | Custom auth layer on top of existing tables | Use custom auth only if business rules become incompatible with Supabase Auth; that is not justified for v6.1. |
| Mostly SSR Astro pages with optional islands | Full SPA from day one | Use a SPA only if offline behavior or live collaborative interactions become a first-order requirement. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| A brand new web stack for v6.1 | It adds another deployment surface, auth model, and component system for a focused release. | Reuse the existing Astro/Vercel site and add server-rendered portal routes. |
| Static-only auth hacks with `localStorage` tokens | They fight the current static site architecture and make protected route handling brittle. | Use Astro server output with Supabase SSR cookies and middleware. |
| Exposing schedule reads through unrestricted public tables | Employee-facing data leaks are the fastest way to invalidate the portal. | Add employee mapping plus RLS-scoped queries or RPCs. |

## Stack Patterns by Variant

**If v6.1 stays read-mostly:**
- Use Astro SSR pages with minimal JavaScript.
- Because schedule viewing and account access can be delivered quickly without building a heavy client app.

**If v6.2 adds richer employee workflows:**
- Keep Astro as the shell and add isolated React islands only where interaction density demands it.
- Because the product can evolve incrementally without rewriting the portal foundation.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| `astro@5.18.1` | `@astrojs/vercel@9.0.5` | Matches the current website repo and supports server output on Vercel. |
| `@supabase/supabase-js@2.99.3` | `@supabase/ssr@0.9.0` | Pin exact versions in the website repo because `@supabase/ssr` is still pre-1.0. |
| `@astrojs/react@5.0.1` | `react` / `react-dom` current stable | Optional only; do not add unless a phase explicitly needs interactive islands. |

## Sources

- Local repo: `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\package.json` - verified current Astro/Vercel stack
- [Astro on-demand rendering docs](https://docs.astro.build/en/guides/on-demand-rendering/) - verified server output support for protected routes
- [Astro actions docs](https://docs.astro.build/en/guides/actions/) - verified backend actions pattern for forms and protected mutations
- [Astro sessions docs](https://docs.astro.build/en/guides/sessions/) - verified built-in session support for server-rendered apps
- [Supabase SSR client docs](https://supabase.com/docs/guides/auth/server-side/creating-a-client) - verified browser/server client split and cookie-aware SSR setup
- [Supabase RLS docs](https://supabase.com/docs/guides/database/postgres/row-level-security) - verified policy requirements for exposed schemas
- `npm view` on 2026-03-22 - verified current package versions for `@supabase/supabase-js`, `@supabase/ssr`, `zod`, and `@astrojs/react`

---
*Stack research for: employee-facing schedule portal*
*Researched: 2026-03-22*
