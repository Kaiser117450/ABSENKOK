# Architecture Research

**Domain:** Employee-facing schedule portal for Absensi Enakko
**Researched:** 2026-03-22
**Confidence:** HIGH

## Standard Architecture

### System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                    Employee Browser / Phone                 │
├─────────────────────────────────────────────────────────────┤
│  ┌────────────────┐   ┌────────────────┐   ┌─────────────┐ │
│  │ Login Route    │   │ Portal Pages   │   │ Form Posts  │ │
│  │ /portal/login  │   │ /portal/*      │   │ Actions     │ │
│  └──────┬─────────┘   └──────┬─────────┘   └──────┬──────┘ │
│         │                    │                    │        │
├─────────┴────────────────────┴────────────────────┴────────┤
│                 Astro 5 Server Output on Vercel            │
├─────────────────────────────────────────────────────────────┤
│  ┌────────────────┐  ┌────────────────┐  ┌───────────────┐ │
│  │ middleware.ts  │  │ Supabase SSR   │  │ Portal Query  │ │
│  │ auth gate      │  │ clients        │  │ layer         │ │
│  └────────────────┘  └────────────────┘  └───────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                   Supabase Auth + PostgreSQL               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ auth.users   │  │ employees    │  │ schedules /      │  │
│  │              │  │ + mapping    │  │ schedule_entries │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Portal routes | Render login and employee-facing schedule pages | Astro pages under `src/pages/portal/` with server-rendered data loading |
| Auth middleware | Guard protected routes and refresh session cookies | `src/middleware.ts` plus Supabase SSR helpers |
| Employee identity mapping | Resolve "which employee record belongs to this auth user?" | Additive table/column plus RLS-aware query or RPC |
| Schedule query layer | Fetch only the authenticated employee's schedule data | Server-side helper or RPC returning a simplified schedule view model |

## Recommended Project Structure

```text
src/
├── actions/
│   └── portal.ts            # login and future request actions
├── components/
│   └── portal/              # employee-facing UI building blocks
├── lib/
│   ├── employee/
│   │   ├── auth.ts          # employee mapping helpers
│   │   └── schedule.ts      # schedule query helpers
│   └── supabase/
│       ├── client.ts        # browser client
│       └── server.ts        # SSR server client
├── middleware.ts            # auth gate and redirect handling
└── pages/
    ├── index.astro          # existing marketing pages remain
    └── portal/
        ├── index.astro      # employee home
        ├── login.astro      # sign-in
        └── schedule.astro   # upcoming shifts
```

### Structure Rationale

- **`pages/portal/`:** keeps employee-facing routes isolated from the public marketing site.
- **`lib/employee/`:** prevents schedule access rules from being scattered across page files.
- **`middleware.ts`:** centralizes auth gate logic instead of repeating route checks manually.

## Architectural Patterns

### Pattern 1: Mixed Static + SSR Astro

**What:** Keep public marketing pages prerendered while rendering portal routes on demand.
**When to use:** When an existing Astro marketing site gains authenticated surfaces.
**Trade-offs:** Slightly more deployment/config complexity, but far less than introducing a second web app.

**Example:**
```ts
// astro.config.mjs
export default defineConfig({
  output: 'server',
});
```

### Pattern 2: Server-Only Data Access for Employee Pages

**What:** Read employee schedule data on the server, never by exposing broad schedule tables to the browser.
**When to use:** Any page that depends on authenticated employee identity.
**Trade-offs:** Slightly more server wiring, but much safer than client-side filtering.

**Example:**
```ts
const supabase = createServerClient(Astro);
const employee = await getEmployeeForSession(supabase);
const schedule = await getScheduleForEmployee(supabase, employee.id);
```

### Pattern 3: Read-Optimized Portal View Model

**What:** Build a simplified employee schedule payload instead of reusing the admin planning grid response.
**When to use:** Mobile-first self-service views.
**Trade-offs:** Adds a translation layer, but keeps the portal focused and easier to evolve.

## Data Flow

### Request Flow

```text
[Employee opens /portal/schedule]
    ↓
[Astro middleware checks session]
    ↓
[Server helper resolves employee mapping]
    ↓
[Server query/RPC fetches schedule rows]
    ↓
[Astro renders mobile-friendly schedule page]
```

### Key Data Flows

1. **Login flow:** employee authenticates, middleware stores/refreshes session cookies, protected routes become available.
2. **Schedule flow:** authenticated employee request resolves to one employee record, then to a scoped schedule response.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0-1k users | Existing Astro monolith plus Supabase is more than enough. |
| 1k-100k users | Optimize schedule query shapes and indexes before touching the frontend architecture. |
| 100k+ users | Consider separating portal concerns only if the product grows well beyond the current restaurant-chain scale. |

### Scaling Priorities

1. **First bottleneck:** poorly scoped schedule queries or missing indexes on schedule joins.
2. **Second bottleneck:** portal UX complexity creeping toward admin-dashboard territory.

## Anti-Patterns

### Anti-Pattern 1: Client-Side Filtering of Admin Data

**What people do:** fetch a broad schedule dataset and hide rows in the browser.
**Why it's wrong:** one auth or filtering mistake leaks other employees' schedules immediately.
**Do this instead:** scope data at the query/RLS layer and render only the authenticated employee's schedule.

### Anti-Pattern 2: Reusing the Admin Scheduler UI for Employees

**What people do:** expose the same multi-employee planning grid because it already exists conceptually.
**Why it's wrong:** it is optimized for admins, not for employees checking today's shift on a phone.
**Do this instead:** build a dedicated employee read model and UI.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Supabase Auth | SSR cookie-based session handling | Employee portal routes should trust the server session, not a browser-only token cache. |
| Supabase Postgres | RLS-scoped queries or RPCs | Keep all employee schedule visibility inside the existing production database rules. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Marketing pages ↔ portal routes | Shared Astro app, separate route tree | Public and private surfaces can coexist cleanly in one site. |
| Flutter admin app ↔ employee portal | Shared Supabase backend only | Admin writes schedule data; portal reads employee-facing slices of it. |

## Sources

- Local repo: `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\package.json`
- [Astro on-demand rendering docs](https://docs.astro.build/en/guides/on-demand-rendering/)
- [Astro actions docs](https://docs.astro.build/en/guides/actions/)
- [Astro sessions docs](https://docs.astro.build/en/guides/sessions/)
- [Supabase SSR client docs](https://supabase.com/docs/guides/auth/server-side/creating-a-client)
- [Supabase RLS docs](https://supabase.com/docs/guides/database/postgres/row-level-security)

---
*Architecture research for: employee-facing schedule portal*
*Researched: 2026-03-22*
