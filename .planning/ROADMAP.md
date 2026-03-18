# ROADMAP.md — Absensi Enakko

## Milestones

- ✅ **v1.1 Bug Fix + Edge Cases + Features** — Phases 1-12 (shipped 2026-03-05)
- ✅ **v2.0 Admin Tools + Live Activity** — Phases 13-16 (shipped 2026-03-12)
- ✅ **v3.0 Schedule Grid + Landing Website** — Phases 17-19 (shipped 2026-03-13)
- ✅ **v3.1 Biometric Login + Badge Polish + Release** — Phases 20-22 (shipped 2026-03-18)
- [ ] **v4.0 Smart Attendance + Admin Dashboard** — Phases 23-26 (in progress)

## Phases

<details>
<summary>v1.1 Bug Fix + Edge Cases + Features (Phases 1-12) — SHIPPED 2026-03-05</summary>

- [x] Phase 1: Rekap Harian Bug Fixes (1/1 plan) — completed 2026-03-01
- [x] Phase 2: Kiosk Scan Cycle Edge Cases (3/3 plans) — completed 2026-03-01
- [x] Phase 3: Overlay Pill Implementation (4/4 plans) — completed 2026-03-02
- [x] Phase 4: PDF Export Engine (1/1 plan executed) — completed 2026-03-04
- [x] Phase 6: NFC Idle Screen Visual Enhancement (2/2 plans) — completed 2026-03-04
- [x] Phase 7: Admin UI System Polish (3/3 plans) — completed 2026-03-04
- [x] Phase 8: Schedule System Fix + Supabase Integration (2/2 plans) — completed 2026-03-03
- [x] Phase 8.1: PDF/CSV Export Fix (2/2 plans) — completed 2026-03-04
- [x] Phase 10: Sakit/Izin Direct Input — Gap Closure (2/2 plans) — completed 2026-03-05
- [x] Phase 11: Employee Badge System — Gap Closure (3/3 plans) — completed 2026-03-05
- [x] Phase 12: Kiosk Logout Bug Fix (1/1 plan) — completed 2026-03-05

Full details: `.planning/milestones/v1.1-ROADMAP.md`

</details>

<details>
<summary>v2.0 Admin Tools + Live Activity (Phases 13-16) — SHIPPED 2026-03-12</summary>

- [x] Phase 13: Soft-Archive Karyawan + Riwayat (3/3 plans) — completed 2026-03-11
- [x] Phase 14: Batch CSV Import (2/2 plans) — completed 2026-03-11
- [x] Phase 15: Kepala Gerai SQL Setup (SQL scripts) — completed 2026-03-11
- [x] Phase 16: Persistent Live Activity Pill (2/2 plans) — completed 2026-03-11

Full details: `.planning/milestones/v2.0-ROADMAP.md`

</details>

<details>
<summary>v3.0 Schedule Grid + Landing Website (Phases 17-19) — SHIPPED 2026-03-13</summary>

- [x] Phase 17: Schedule Grid UI Redesign (2/2 plans) — completed 2026-03-13
- [x] Phase 18: ABSENKOK Landing Website (2/2 plans) — completed 2026-03-13
- [x] Phase 19: Website Polish — Screenshots + About/Architecture + Tech Icons (2/2 plans) — completed 2026-03-13

Full details: `.planning/milestones/v3.0-ROADMAP.md`

</details>

<details>
<summary>v3.1 Biometric Login + Badge Polish + Release (Phases 20-22) — SHIPPED 2026-03-18</summary>

- [x] Phase 20: Biometric Login (2/2 plans) — completed 2026-03-18
- [x] Phase 21: Badge Color Picker (1/1 plan) — completed 2026-03-18
- [x] Phase 22: Production Release (1/1 plan) — completed 2026-03-18

Full details: `.planning/milestones/v3.1-ROADMAP.md`

</details>

### v4.0 Smart Attendance + Admin Dashboard (In Progress)

**Milestone Goal:** Solidify core attendance system with smart pattern detection, streamline admin onboarding for kepala gerai, and build comprehensive dashboard with charts and gamification.

- [x] **Phase 23: Bug Fix + Database Foundation** - Fix NFC double-scan crash and deploy all Supabase RPC functions and schema needed by downstream phases (completed 2026-03-18)
- [x] **Phase 24: Core Services + Analytics** - Build service layer (streak, pattern, chart data, missing clock-out) and attendance rate card with overtime tracking (completed 2026-03-18)
- [ ] **Phase 25: Dashboard UI + Visualization** - Chart dashboard screen with fl_chart, streak leaderboard, cross-outlet comparison, and gamification milestone badges
- [ ] **Phase 26: Admin Onboarding + Notification Polish** - Kepala Gerai creation via Edge Function with credential sharing and notification batching

## Phase Details

### Phase 23: Bug Fix + Database Foundation
**Goal**: NFC registration is crash-free and all database infrastructure (RPC functions, streak table, indexes) is deployed for downstream phases
**Depends on**: Nothing (first phase of v4.0)
**Requirements**: BUG-01, DASH-05, GAME-01
**Success Criteria** (what must be TRUE):
  1. Admin can register a new employee NFC card by scanning it twice in quick succession without the app crashing or freezing
  2. Four Supabase RPC functions are deployed and return correct data when called from the Flutter app (get_attendance_rates, get_weekly_trend, get_outlet_comparison, update_employee_streak)
  3. The employee_streaks table exists in Supabase with correct schema and RLS policies that scope data per outlet
**Plans:** 2/2 plans complete

Plans:
- [x] 23-01-PLAN.md — NFC double-scan crash fix (BUG-01)
- [x] 23-02-PLAN.md — Supabase RPC functions, employee_streaks table, and indexes (DASH-05, GAME-01)

### Phase 24: Core Services + Analytics
**Goal**: Admin/Kepala Gerai can see attendance rate metrics, overtime flags, and receive missing clock-out notifications — all powered by testable service layer
**Depends on**: Phase 23
**Requirements**: ANLYT-01, ANLYT-02, ANLYT-03, ANLYT-04, SMART-01, SMART-02, SMART-03, SMART-04
**Success Criteria** (what must be TRUE):
  1. Admin can see an attendance rate card on the dashboard showing daily/weekly/monthly percentage with concrete counts (e.g., "Hadir 14/16 hari — 87.5%")
  2. Admin can see overtime flagging when an employee works longer than their shift template duration
  3. Admin receives a single batched notification per outlet when employees have not scanned pulang after the configurable threshold ("3 karyawan belum pulang di Outlet A")
  4. Smart pattern detection computes median arrival times from last 30 days per employee per day-of-week, and admin receives notification when employee is late vs their usual pattern
  5. Pattern detection runs in background isolate and never blocks NFC scan handling (scan response stays under 2 seconds)
**Plans:** 3/3 plans complete

Plans:
- [x] 24-01-PLAN.md — Analytics service + attendance rate card + overtime alert UI (ANLYT-01, ANLYT-02)
- [x] 24-02-PLAN.md — Missing clock-out batched notification service (ANLYT-03, ANLYT-04)
- [x] 24-03-PLAN.md — Smart pattern detection with background isolate + late notification (SMART-01, SMART-02, SMART-03, SMART-04)

### Phase 25: Dashboard UI + Visualization
**Goal**: Kepala Gerai can see all key attendance metrics on a single scrollable dashboard screen with interactive charts and gamification
**Depends on**: Phase 24
**Requirements**: DASH-01, DASH-02, DASH-03, DASH-04, GAME-02, GAME-03, GAME-04
**Success Criteria** (what must be TRUE):
  1. Kepala Gerai can open a chart dashboard screen showing attendance rate donut chart, weekly trend bar chart, streak leaderboard (top 5), and overtime alerts — all on one scrollable page
  2. Admin can see cross-outlet attendance comparison as a grouped bar chart (kepala gerai sees only their own outlet)
  3. Employee sees their current attendance streak count on the kiosk scan result screen after successful masuk
  4. Employees receive auto-badge awards at streak milestones (7-day, 30-day, 90-day) using the existing badge system
  5. Dashboard navigated 100+ times in a 4-hour stress test without memory leak or performance degradation (AutomaticKeepAliveClientMixin + proper disposal)
**Plans**: TBD

### Phase 26: Admin Onboarding + Notification Polish
**Goal**: Admin can create new Kepala Gerai accounts directly from the app with secure server-side user creation and share credentials via WhatsApp
**Depends on**: Phase 23 (Edge Function infrastructure), Phase 24 (notification system)
**Requirements**: ADMIN-01, ADMIN-02, ADMIN-03, ADMIN-04
**Success Criteria** (what must be TRUE):
  1. Admin can create a new Kepala Gerai user account from within the app by entering name, email, and outlet assignment — password is auto-generated
  2. After creation, admin can tap a button to share the generated credentials (email + password) to WhatsApp
  3. Admin can generate a PDF document with the new account details, creation timestamp, outlet assignment, and audit trail
  4. User creation happens server-side via Supabase Edge Function — grep for "service_role" in lib/ returns zero hits
**Plans**: TBD

## Progress

**Execution Order:** 23 → 24 → 25 → 26 (sequential dependency chain; Phase 26 can start after Phase 23 + 24)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 23. Bug Fix + Database Foundation | v4.0 | 2/2 | Complete | 2026-03-18 |
| 24. Core Services + Analytics | 3/3 | Complete   | 2026-03-18 | 2026-03-18 |
| 25. Dashboard UI + Visualization | v4.0 | 0/TBD | Not started | - |
| 26. Admin Onboarding + Notification Polish | v4.0 | 0/TBD | Not started | - |

## Future Backlog (Not Scheduled)
- Schedule grid tap-to-cycle shift (SCHED-01)
- Schedule grid copy-week (SCHED-02)
- Schedule grid today-column highlight (SCHED-03)
- Time-off request approval workflow (FLOW-01)
- Keterlambatan automatic flagging vs shift start time (FLOW-02)
- Employee-facing mobile app (ADV-01)
- QR code backup when NFC fails (ADV-02)
- Live Activity pill device debugging (code delivered, needs on-device verification)
