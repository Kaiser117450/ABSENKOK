# Pitfalls Research

**Domain:** Employee-facing schedule portal for Absensi Enakko
**Researched:** 2026-03-22
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: No Reliable Employee Identity Mapping

**What goes wrong:**
Employees can log in, but the portal cannot safely determine which `employees` row belongs to the authenticated user.

**Why it happens:**
Teams add auth first and postpone the database linkage, then patch access rules later with brittle email matching.

**How to avoid:**
Create an explicit employee-to-auth-user mapping and write portal queries/RLS around that mapping from day one.

**Warning signs:**
Code starts filtering schedules by email string or outlet membership instead of a stable employee identifier.

**Phase to address:**
Portal foundation and auth phase.

---

### Pitfall 2: Treating the Current Astro Site as Static Forever

**What goes wrong:**
The team tries to bolt protected portal behavior onto a static build with client-side auth workarounds.

**Why it happens:**
The current website is static marketing-only, so it is easy to assume the portal must work the same way.

**How to avoid:**
Switch the site to server output for portal routes and use SSR sessions/cookies for protected pages.

**Warning signs:**
Login state is stored only in `localStorage`, or protected pages flash public HTML before redirecting.

**Phase to address:**
Portal foundation and routing phase.

---

### Pitfall 3: Leaking Other Employees' Schedule Data

**What goes wrong:**
A portal bug exposes another employee's shifts, outlet, or attendance data.

**Why it happens:**
Developers reuse admin queries or rely on client-side filtering instead of enforcing server-side scope.

**How to avoid:**
Enforce RLS and use server-side helpers or RPCs that return only the authenticated employee's schedule slice.

**Warning signs:**
Frontend pages request generic schedule tables and then filter rows in JavaScript.

**Phase to address:**
Employee data model / query phase.

---

### Pitfall 4: Date Logic Drift Between Portal and Core Attendance Rules

**What goes wrong:**
Employees see schedules or recaps that do not align with the app's established timezone and cross-day shift logic.

**Why it happens:**
The web portal is built quickly and re-implements time/date formatting without respecting the existing noon-rule and outlet-local assumptions.

**How to avoid:**
Carry the existing date rules into the portal data layer and verify with concrete cross-day examples before launch.

**Warning signs:**
A night shift appears on the wrong day in the portal or differs from admin/kiosk views.

**Phase to address:**
Schedule read-model phase and portal UI phase.

---

### Pitfall 5: Over-Scoping v6.1

**What goes wrong:**
The release expands from "employees can view schedules" into approvals, swaps, notifications, and attendance history before the foundation is stable.

**Why it happens:**
Self-service portals invite obvious adjacent ideas, and each seems small in isolation.

**How to avoid:**
Hold v6.1 to schedule visibility plus access/control foundations. Defer request workflows until the first portal surface is trusted.

**Warning signs:**
Requirements start mixing read-only schedule access with manager approval logic in the same milestone.

**Phase to address:**
Requirements definition before roadmap generation.

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Matching employees to auth users by email text only | Fast to prototype | Brittle when emails change or duplicates appear | Only as a temporary migration path with a clear replacement plan |
| Reusing admin schedule query payloads | Fewer backend changes now | Security and UX debt immediately | Never for the employee portal surface |
| Building v6.1 as a new web stack | Isolation from current site | Extra auth, deployment, and UI duplication | Only if Astro becomes a proven blocker, which research does not show |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Astro + Supabase SSR | Using a browser client everywhere | Split server and browser clients and refresh auth via cookies/middleware |
| Supabase RLS | Creating tables in `public` but forgetting policies | Enable RLS and write explicit authenticated-user policies before exposing reads |
| Existing website repo | Treating the portal as just another public page | Separate `/portal/*` routes and auth middleware from the marketing surface |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Rendering the full admin grid for employees | Slow mobile pages and noisy UI | Build a compact read model for "today / upcoming" | Immediately on phones |
| Client-side schedule joins | Large payloads and leaked data risk | Join/filter on the server or in SQL/RPC | Even at the current 4-outlet scale |
| Adding interactive UI libraries too early | Larger bundles and more moving parts | Start with SSR pages, add islands only where justified | Before the first portal ship |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Using service-role credentials in the portal | Full database compromise | Keep service-role on server-only infrastructure, never in the website repo runtime |
| Trusting `employeeId` from query params | Horizontal data leakage | Resolve employee identity from the session on the server |
| Sharing admin-facing routes/components with employee auth | Permission confusion and accidental exposure | Keep employee route tree and guards separate |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Desktop-like planning grid on mobile | Employees cannot quickly answer "when do I work?" | Use simple cards or list sections for today and upcoming shifts |
| No "not linked yet" state | Employees think the portal is broken | Explain that their account is not linked and who to contact |
| Portal shows raw shift codes only | Employees do not understand schedule data | Show human-readable labels, times, and outlet context |

## "Looks Done But Isn't" Checklist

- [ ] **Login:** User can sign in, but protected portal routes still redirect correctly after refresh
- [ ] **Schedule view:** Data is scoped to one employee at the SQL/RLS layer, not just in the browser
- [ ] **Cross-day shifts:** Overnight examples match the existing attendance system's logical-day rules
- [ ] **Empty states:** "No shift", "not linked", and "loading error" are clearly distinct

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Missing employee mapping | MEDIUM | Add explicit mapping, backfill links, then tighten RLS before reopening access |
| Static-only auth workaround | MEDIUM | Convert portal routes to server output and replace client-only auth handling |
| Data leak via broad queries | HIGH | Revoke access immediately, patch RLS/query scope, and verify with targeted tests before relaunch |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| No reliable employee identity mapping | Phase 37 foundation/auth | Authenticated user resolves to exactly one employee record |
| Static-site assumptions | Phase 37 foundation/auth | Protected routes work server-side and survive refresh |
| Schedule data leakage | Phase 38 schedule read model | Portal queries cannot return another employee's rows |
| Date logic drift | Phase 38 schedule read model / Phase 39 UI | Cross-day schedule examples match admin expectations |
| Over-scoping v6.1 | Requirements and roadmap gate | Milestone scope stays focused on schedule visibility |

## Sources

- Existing project constraints in `.planning/PROJECT.md` and `.planning/STATE.md`
- [Astro sessions docs](https://docs.astro.build/en/guides/sessions/)
- [Astro actions docs](https://docs.astro.build/en/guides/actions/)
- [Supabase SSR client docs](https://supabase.com/docs/guides/auth/server-side/creating-a-client)
- [Supabase RLS docs](https://supabase.com/docs/guides/database/postgres/row-level-security)

---
*Pitfalls research for: employee-facing schedule portal*
*Researched: 2026-03-22*
