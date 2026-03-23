# Stack Research

**Domain:** Employee portal attendance recap for an existing Astro + Supabase product
**Researched:** 2026-03-23
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `astro` | `5.18.1` | Server-rendered portal routes and page composition | The employee portal already ships inside the Astro site, so extending the current SSR path is lower-risk than introducing a second frontend. |
| `@astrojs/vercel` | `9.0.5` | Deploy on-demand portal pages on the existing hosting target | Keeps portal recap on the same deployment model already used by the protected portal routes. |
| `@supabase/supabase-js` + `@supabase/ssr` | `2.99.3` + `0.9.0` | Cookie-aware server/client auth and typed RPC access | Matches the shipped portal auth pattern and keeps employee data scoped server-side. |
| Supabase Postgres RPCs | existing database surface | Read-optimized attendance recap contract | The attendance recap depends on schedule and attendance logs with business rules; an authenticated RPC keeps those rules in one place. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Intl.DateTimeFormat` in server loaders | built-in | Anchor recap dates to `Asia/Makassar` | Use for all portal reference dates so the recap matches kiosk/admin logical-day behavior. |
| Existing portal components and state unions | local app code | Reuse mobile-first shell and ready/empty/error patterns | Use instead of adding a new client framework or duplicating portal layout logic. |
| Postgres indexes on `attendance_logs` and `schedule_entries` | existing + additive | Keep recap queries fast for current + future staff counts | Add or tune only when the recap query shape shows a real lookup gap. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `astro check` | Validate website TypeScript/Astro changes | Run in the website repo after portal recap pages/helpers change. |
| Focused SQL migrations in `sql/` | Add authenticated recap RPCs and indexes | Keep migrations additive because the production database is live for 4 outlets. |
| Existing planning workflow | Maintain traceability across Flutter repo + website repo | Capture portal recap work in planning docs so cross-repo execution does not drift again. |

## Installation

```bash
# No new framework packages are required for the milestone baseline.
# Reuse the existing website stack and add SQL/read-model changes only if the implementation proves they are necessary.
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Extend the existing Astro portal | Build a separate React/Next frontend | Only if the portal grows into a much larger product surface than the current employee self-service scope. |
| Authenticated recap RPCs | Direct multi-query reads from the page layer | Only if the recap can be expressed as a trivial single-table read, which is not true once logical-day and exception rules apply. |
| Reuse current portal shell | Embed recap inside the Flutter app | Only if the user explicitly wants kiosk/admin reuse instead of employee self-service web access. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| A new frontend stack for recap only | Adds deployment, auth, and state duplication for one focused milestone | Keep recap inside the current Astro portal. |
| Service-role or admin-shaped reads from the website | Risks employee data leakage and bypasses the shipped portal trust boundary | Use authenticated RPCs and employee resolution from the current portal path. |
| Real-time streaming as v6.3 scope | Adds complexity without changing the core employee job of reviewing recent attendance | Ship a reliable pull-based recap first. |

## Stack Patterns by Variant

**If the recap stays read-only:**
- Keep everything server-rendered through existing portal loaders
- Because the current portal already works well with SSR and does not need client state complexity

**If a later milestone adds employee actions:**
- Add dedicated mutation endpoints or Astro actions behind the same portal auth boundary
- Because request submission and approvals should evolve separately from the recap read model

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| `astro@5.18.1` | `@astrojs/vercel@9.0.5` | Matches the current website repo and deployed portal model. |
| `@supabase/ssr@0.9.0` | `@supabase/supabase-js@2.99.3` | Supports the current cookie-aware portal auth flow. |

## Sources

- Local repo: `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\package.json` — current website stack and versions
- Local repo: `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\lib\portal\employee.ts` — current server-side employee resolution pattern
- Local repo: `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\sql\phase_39_portal_read_path_hardening_20260323.sql` — current authenticated portal RPC pattern
- https://docs.astro.build/en/guides/on-demand-rendering/ — on-demand SSR route model
- https://supabase.com/docs/reference/javascript/auth-getuser — server-side user verification guidance
- https://supabase.com/docs/guides/database/postgres/row-level-security — RLS and exposed-schema guidance

---
*Stack research for: employee portal attendance recap*
*Researched: 2026-03-23*
