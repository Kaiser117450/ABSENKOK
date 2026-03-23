# Roadmap: Absensi Enakko

## Milestones

- ◆ **v6.3 Employee Attendance Recap** — Phases 42-44 planned 2026-03-23.
- ✅ **v6.2 Dashboard & Report Foundation** — Phases 40-41 shipped 2026-03-23. Archive: [`milestones/v6.2-ROADMAP.md`](milestones/v6.2-ROADMAP.md)
- ✅ **v6.1 Employee Portal** — Phases 37-39 shipped 2026-03-23. Archive: [`milestones/v6.1-ROADMAP.md`](milestones/v6.1-ROADMAP.md)
- ✅ **v6.0 Multi-Outlet & Multi-Device Control** — Phases 31-36 shipped 2026-03-22. Archive: [`milestones/v6.0-ROADMAP.md`](milestones/v6.0-ROADMAP.md)
- ✅ **v5.0 Observability & Recovery** — Phases 27-30 shipped 2026-03-20. Archive: [`milestones/v5.0-ROADMAP.md`](milestones/v5.0-ROADMAP.md)
- ✅ **v4.0 Smart Attendance + Admin Dashboard** — Phases 23-26 shipped 2026-03-19. Archive: [`milestones/v4.0-ROADMAP.md`](milestones/v4.0-ROADMAP.md)
- ✅ **v3.0 Schedule Grid + Landing Website** — Phases 17-19 shipped 2026-03-13. Archive: [`milestones/v3.0-ROADMAP.md`](milestones/v3.0-ROADMAP.md)
- ✅ **v2.0 Admin Tools + Live Activity** — Phases 13-16 shipped 2026-03-12. Archive: [`milestones/v2.0-ROADMAP.md`](milestones/v2.0-ROADMAP.md)
- ✅ **v1.1 Bug Fix + Edge Cases + Features** — Phases 1-12 shipped 2026-03-05. Archive: [`milestones/v1.1-ROADMAP.md`](milestones/v1.1-ROADMAP.md)

## Current Milestone: v6.3 Employee Attendance Recap

**Status:** Planned
**Phases:** 42-44
**Requirements:** 7 mapped / 7 total
**Next phase:** Phase 43 — Portal Attendance Recap Surface

## Phase Overview

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| 42 | 2/2 | Complete    | 2026-03-23 | 3 |
| 43 | 3/3 | Complete   | 2026-03-23 | 3 |
| 44 | Portal Exception States & Hardening | Surface follow-up days clearly and close the cross-repo hardening gap before implementation drift returns. | `ATTN-05`, `PORT-04` | 3 |

## Phases

### Phase 42: Attendance Recap Read Model

**Goal:** Build an authenticated portal recap contract that turns attendance logs and schedule context into one trusted employee-specific dataset.
**Depends on:** Phase 39 portal read path hardening
**Requirements:** `ATTN-02`, `ATTN-03`

**Success criteria:**
1. Portal recap reads are employee-scoped and do not accept client-supplied employee identifiers.
2. The recap contract returns recent logical workdays with the timestamps needed to explain each attendance outcome.
3. Overnight or cross-day attendance is grouped consistently with the product's existing logical-day rules.

### Phase 43: Portal Attendance Recap Surface

**Goal:** Deliver the recap entry point and main mobile-first portal experience using the trusted read model from Phase 42.
**Depends on:** Phase 42
**Requirements:** `ATTN-01`, `ATTN-04`, `PORT-03`
**Plans:** 3/3 plans complete

Plans:
- [ ] `43-01-PLAN.md` — Shared recap summary and recent-history components
- [ ] `43-02-PLAN.md` — Portal shell navigation and home recap entry point
- [ ] `43-03-PLAN.md` — Attendance recap page wiring

**Success criteria:**
1. Employee can open the recap inside the existing portal shell without leaving the employee-facing flow.
2. The portal shows month-to-date summary counts and recent day-by-day history from one recap dataset.
3. The recap surface is phone-friendly and consistent with the current portal design language.

### Phase 44: Portal Exception States & Hardening

**Goal:** Make problem days understandable to employees and close the milestone with aligned portal, SQL, and planning artifacts.
**Depends on:** Phase 43
**Requirements:** `ATTN-05`, `PORT-04`

**Success criteria:**
1. Days needing follow-up are clearly labeled, including incomplete attendance outcomes and scheduled days without a completed attendance record.
2. Loading, empty, and error states are explicit and usable inside the portal shell.
3. The shipped recap path, SQL contract, and planning artifacts all describe the same implementation surface.

## Coverage Check

- All 7 active requirements map to exactly one phase.
- No active requirement is left unmapped.
- Request submission, approvals, and reminder notifications remain outside the v6.3 roadmap.
