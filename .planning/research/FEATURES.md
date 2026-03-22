# Feature Research

**Domain:** Employee-facing schedule portal for Absensi Enakko
**Researched:** 2026-03-22
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Employee login to a private portal | A self-service portal is useless if employees cannot securely reach their own account. | MEDIUM | Needs employee-to-auth-user mapping and protected routes. |
| View own upcoming shifts | This is the primary job the user picked for v6.1. | MEDIUM | Must be mobile-friendly and clearly show date, time, outlet, and shift type. |
| "Today / this week" schedule clarity | Employees need fast answers, not an admin-style planning grid. | LOW | A focused list or cards is better than exposing the full scheduler UI. |
| Empty/error states that explain what to do next | Employees will not debug missing schedule data themselves. | LOW | Must clearly distinguish "no shift", "not linked yet", and "portal unavailable". |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Attendance recap next to schedule | Reinforces trust by tying planned work to actual attendance history. | MEDIUM | Good v6.2 candidate once portal auth and schedule reads are stable. |
| Time-off request flow | Gives employees a direct operational win beyond passive viewing. | HIGH | Requires request submission, approval workflow, and manager/admin surfaces. |
| Shift reminders or notifications | Keeps the portal useful between visits. | MEDIUM | Valuable only after core account access and schedule reliability are proven. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Full admin schedule editor for employees | Feels like "just reuse the current schedule screen" | It leaks admin complexity and permissions into a focused employee release. | Start with read-only personal schedule views. |
| Shift-swap marketplace in v6.1 | Sounds exciting and employee-friendly | It multiplies approval logic, state transitions, and conflict rules immediately. | Defer until the portal foundation is trusted. |
| Rebuilding the portal as a heavy SPA up front | Teams assume dashboards always need a SPA | It adds cost before the first employee workflow is validated. | Use Astro SSR first, then add islands where needed. |

## Feature Dependencies

```text
[Employee Login]
    └──requires──> [Employee Identity Mapping]
                       └──requires──> [RLS-Safe Schedule Query]
                                              └──requires──> [Portal UI]

[Attendance Recap] ──enhances──> [Portal UI]

[Time-Off Requests] ──requires──> [Employee Login]
                               └──requires──> [Approval Workflow]
```

### Dependency Notes

- **Employee Login requires Employee Identity Mapping:** the auth user has to map to an existing employee record before any schedule data can be scoped safely.
- **Portal UI requires an RLS-safe Schedule Query:** the UI should never assemble employee schedule visibility by fetching broad admin data and filtering in the browser.
- **Time-Off Requests require an Approval Workflow:** request capture without manager/admin handling creates dead-end UX and operational debt.

## MVP Definition

### Launch With (v1)

- [ ] Secure employee login to a dedicated web portal
- [ ] Employee can see only their own assigned shifts
- [ ] Mobile-friendly "today / upcoming" schedule experience
- [ ] Clear account-linking and empty-state handling

### Add After Validation (v1.x)

- [ ] Attendance recap alongside schedule
- [ ] Better filters such as "today", "this week", and outlet grouping
- [ ] Simple profile/account page for employee-facing identity confirmation

### Future Consideration (v2+)

- [ ] Time-off request workflow
- [ ] Shift swap or open-shift claims
- [ ] Push/email reminders for future shifts

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Employee login | HIGH | MEDIUM | P1 |
| Own-schedule view | HIGH | MEDIUM | P1 |
| Mobile-first portal layout | HIGH | LOW | P1 |
| Account-linking / "not linked yet" UX | HIGH | LOW | P1 |
| Attendance recap | MEDIUM | MEDIUM | P2 |
| Time-off requests | HIGH | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Sources

- User milestone selection on 2026-03-22 - focused release, employee app, web portal, schedule view first
- Existing project context in `.planning/PROJECT.md` - deferred `M006` and current operational constraints
- Standard workforce/self-service portal expectations derived from the current product domain

---
*Feature research for: employee-facing schedule portal*
*Researched: 2026-03-22*
