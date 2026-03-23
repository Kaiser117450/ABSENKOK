# Architecture Research

**Domain:** Authenticated employee portal attendance recap
**Researched:** 2026-03-23
**Confidence:** HIGH

## Standard Architecture

### System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                     Astro Portal Routes                     │
├─────────────────────────────────────────────────────────────┤
│  /portal index  │  recap loader  │  mobile components      │
├─────────────────────────────────────────────────────────────┤
│                Server-side Portal Helpers                  │
├─────────────────────────────────────────────────────────────┤
│  resolvePortalEmployee  │  loadPortalRecap  │  state model │
├─────────────────────────────────────────────────────────────┤
│                 Supabase Authenticated RPCs                │
├─────────────────────────────────────────────────────────────┤
│  recap overview RPC  │  schedule context RPC  │  RLS       │
├─────────────────────────────────────────────────────────────┤
│                   Postgres Source Tables                   │
│  attendance_logs  │  schedule_entries  │  schedules        │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Portal page/loaders | Request the recap once and branch on typed page state | Astro page calling a server helper from `src/lib/portal/*` |
| Employee resolver | Guarantee one authenticated employee identity before recap reads | Reuse `resolvePortalEmployee()` and fail closed on missing mapping |
| Recap RPC | Merge attendance logs, schedule context, and logical-day rules | Authenticated `SECURITY DEFINER` function with additive indexes |
| Portal components | Render summary + daily history for phone-sized screens | Reuse existing card/list patterns from the shipped portal |

## Recommended Project Structure

```text
absenkok-website/
├── src/pages/portal/           # portal routes
│   └── index.astro             # entry point or recap surface
├── src/lib/portal/             # server-side portal loaders/helpers
│   ├── employee.ts             # employee identity resolution
│   ├── schedule.ts             # existing schedule model
│   └── recap.ts                # new attendance recap loader
├── src/components/portal/      # mobile portal components
│   ├── PortalScheduleSection.astro
│   └── PortalAttendanceRecapSection.astro
└── src/layouts/                # shared portal shell

absensi_enakko_flutter/
└── sql/                        # additive recap RPC + index migrations
```

### Structure Rationale

- **`src/lib/portal/`:** keeps employee-scoped business logic on the server side and prevents page files from owning auth or RPC details.
- **`src/components/portal/`:** keeps recap rendering consistent with the current mobile-first schedule UI.
- **`sql/`:** keeps the database contract versioned beside the main app planning and rollout history.

## Architectural Patterns

### Pattern 1: Authenticated server-side portal loaders

**What:** Route loaders resolve the portal employee and fetch recap data on the server before rendering.
**When to use:** For every employee-facing page that needs protected data.
**Trade-offs:** Slightly more backend ceremony, but it avoids exposing internal query shape to the browser.

### Pattern 2: Read-optimized recap RPC

**What:** One RPC returns summary-ready recap rows with exception semantics already resolved.
**When to use:** When the UI needs attendance meaning, not raw `attendance_logs` events.
**Trade-offs:** More SQL design upfront, but much lower cross-repo drift and better consistency with kiosk/admin rules.

### Pattern 3: Discriminated page state model

**What:** Map low-level RPC outcomes into page-level states such as `ready`, `empty`, `error`, or `not-linked`.
**When to use:** For portal pages where mobile UX clarity matters more than raw backend errors.
**Trade-offs:** Requires a small translation layer, but keeps page templates simple and testable.

## Data Flow

### Request Flow

```text
Employee opens /portal
    ↓
Astro page loader
    ↓
resolvePortalEmployee()
    ↓
attendance recap RPC
    ↓
typed recap model + state mapping
    ↓
summary cards + daily history UI
```

### State Management

```text
Server loader result
    ↓
Portal page state union
    ↓
Portal components render by state
```

### Key Data Flows

1. **Identity flow:** Auth session -> server-side employee resolution -> scoped recap query.
2. **Recap flow:** Attendance logs + schedule context -> logical-day normalization -> summary counts + day history.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0-200 employees | Current RPC + indexed tables are sufficient; keep the portal monolithic. |
| 200-2,000 employees | Add more targeted recap indexes and tighten query plans before changing architecture. |
| 2,000+ employees | Consider materialized summary support only if recap query latency becomes a proven problem. |

### Scaling Priorities

1. **First bottleneck:** recap SQL shape on `attendance_logs` date windows; fix with query-specific indexes and bounded history windows.
2. **Second bottleneck:** duplicated logic across website loaders and SQL; fix by keeping recap semantics centralized in one RPC.

## Anti-Patterns

### Anti-Pattern 1: Rebuilding employee scope inside every page

**What people do:** Each page hand-rolls auth checks and employee joins.
**Why it's wrong:** Scope drift and edge cases appear quickly across portal routes.
**Do this instead:** Keep `resolvePortalEmployee()` as the one identity gate and build recap loaders on top of it.

### Anti-Pattern 2: Treating recap as a raw event log dump

**What people do:** Expose raw punches and let the UI infer workday meaning.
**Why it's wrong:** Cross-day rules and exception semantics will diverge from kiosk/admin behavior.
**Do this instead:** Normalize recap semantics in SQL or a single server helper before UI rendering.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Supabase Auth | Cookie-aware server client | Verify employee sessions server-side before recap reads. |
| Supabase Postgres | Authenticated RPCs | Keep recap and exception logic close to the data. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Website repo ↔ SQL migrations | Versioned files + planning docs | Cross-repo portal work needs explicit planning to avoid drift. |
| Portal loaders ↔ components | Typed models | Components should not know raw RPC schema details. |

## Sources

- Local repo: `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\lib\portal\employee.ts`
- Local repo: `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\lib\portal\schedule.ts`
- Local repo: `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\sql\phase_38_employee_schedule_read_model_20260322.sql`
- Local repo: `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\sql\phase_39_portal_read_path_hardening_20260323.sql`
- https://docs.astro.build/en/guides/on-demand-rendering/
- https://supabase.com/docs/reference/javascript/auth-getuser

---
*Architecture research for: employee portal attendance recap*
*Researched: 2026-03-23*
