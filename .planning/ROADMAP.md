# Milestone v6.1 Roadmap

**Goal:** Launch the first employee-facing web portal so staff can view their own schedules without touching kiosk or admin-only surfaces.
**Starting Phase:** 37
**Status:** Requirements Mapped

| # | Phase | Goal | Requirements | Criteria |
|---|-------|------|--------------|----------|
| 37 | 3/4 | In Progress|  | 4 |
| 38 | Employee Schedule Read Model | Build the employee-scoped schedule data path with current-week visibility and cross-day consistency. | SCHED-01, SCHED-02, SCHED-03 | 4 |
| 39 | Employee Portal Schedule UX | Ship the phone-friendly schedule experience with safe account states and portal-only logout. | AUTH-04, LINK-02, PORT-01, PORT-02 | 4 |

---

## Phase Details

### Phase 37: Portal Foundation & Employee Auth
**Goal:** Extend the Astro website into a protected employee portal with provisioning, fast name-search sign-in, and stable employee identity resolution.
**Requirements:** [AUTH-01, AUTH-02, AUTH-03, LINK-01]
**Plans:** 3/4 plans executed

Plans:

- [ ] 37-01: Portal account contract, search index, and provisioning function
- [ ] 37-02: Admin employee portal provisioning flow
- [ ] 37-03: Astro portal auth and search infrastructure
- [ ] 37-04: Protected portal shell and employee context

**Details:**
- Portal foundation keeps the public Astro marketing pages static and opts only portal routes into on-demand rendering
- Employee portal auth is provisioned server-side through Supabase Auth plus a one-to-one employee mapping contract
- Portal login uses indexed name search with duplicate-safe identity cards before password sign-in
- The first protected portal page will stop at identity resolution and a shell placeholder so Phase 38 can focus only on schedule data

**Success Criteria:**
1. Website repo supports protected employee portal routes without breaking public marketing pages.
2. Admin can provision initial employee portal credentials without requiring employee-code setup first.
3. Employee can find themselves through fast name search, sign in with password, and stay authenticated across refresh on protected routes.
4. An authenticated portal session resolves to exactly one employee record before any schedule query is executed.

### Phase 38: Employee Schedule Read Model
**Goal:** Expose a safe, employee-scoped schedule query path that matches existing scheduling rules.
**Requirements:** [SCHED-01, SCHED-02, SCHED-03]
**Depends on:** Phase 37

**Success Criteria:**
1. Server-side schedule queries or RPCs return only the authenticated employee's schedule data.
2. Employee can retrieve today's assigned shift with outlet, shift label, and start/end times.
3. Employee can retrieve upcoming assigned shifts for at least the current week.
4. Overnight and cross-day shifts are represented consistently with the system's existing logical-day rules.

### Phase 39: Employee Portal Schedule UX
**Goal:** Deliver the mobile-first employee portal pages that surface schedule data safely and clearly.
**Requirements:** [AUTH-04, LINK-02, PORT-01, PORT-02]
**Depends on:** Phase 38

**Success Criteria:**
1. Portal pages are usable on a phone-sized browser without reusing the admin planning grid.
2. Portal clearly distinguishes loading, empty schedule, not-linked, and error states.
3. If the employee account is not linked, the portal blocks schedule access and shows a clear next-step message.
4. Employee can sign out of the portal without affecting kiosk or admin sessions.
