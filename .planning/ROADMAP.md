# Milestone v6.1 Roadmap

**Goal:** Launch the first employee-facing web portal so staff can view their own schedules without touching kiosk or admin-only surfaces.
**Starting Phase:** 37
**Status:** Requirements Mapped

| # | Phase | Goal | Requirements | Criteria |
|---|-------|------|--------------|----------|
| 37 | Portal Foundation & Employee Auth | Extend the Astro site into a protected employee portal with code+password access and employee identity resolution. | AUTH-01, AUTH-02, AUTH-03, LINK-01 | 4 |
| 38 | Employee Schedule Read Model | Build the employee-scoped schedule data path with current-week visibility and cross-day consistency. | SCHED-01, SCHED-02, SCHED-03 | 4 |
| 39 | Employee Portal Schedule UX | Ship the phone-friendly schedule experience with safe account states and portal-only logout. | AUTH-04, LINK-02, PORT-01, PORT-02 | 4 |

---

## Phase Details

### Phase 37: Portal Foundation & Employee Auth
**Goal:** Extend the Astro website into a protected employee portal with provisioning, sign-in, and stable employee identity resolution.
**Requirements:** [AUTH-01, AUTH-02, AUTH-03, LINK-01]

**Success Criteria:**
1. Website repo supports protected employee portal routes without breaking public marketing pages.
2. Admin can provision initial employee portal credentials using employee code plus password.
3. Employee can sign in with those credentials and stay authenticated across refresh on protected routes.
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
