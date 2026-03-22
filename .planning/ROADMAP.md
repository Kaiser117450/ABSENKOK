# Milestone v6.0 Roadmap

**Goal:** Provide chain-wide oversight for admins across all outlets and decouple device health tracking to support multiple devices natively.

| # | Phase | Goal | Requirements | Criteria |
|---|-------|------|--------------|----------|
| 31 | 2/2 | Complete   | 2026-03-20 | 3 |
| 32 | 2/2 | Complete    | 2026-03-22 | 4 |
| 33 | 2/2 | Complete    | 2026-03-22 | 3 |
| 34 | 2/2 | Complete    | 2026-03-22 | 3 |
| 35 | 0/? | Planned     | 2026-03-22 | 4 |
| 36 | 0/? | Planned     | 2026-03-22 | 4 |

---

## Phase Details

### Phase 31: Device Identity Foundation
**Goal:** Establish persistent device tracking via UUIDv4 and decouple the database schema to support multiple devices.
**Requirements:** [HEALTH-01, HEALTH-02]

**Success Criteria:**
1. App successfully generates and persists a random UUIDv4 in `SharedPreferences` upon first boot.
2. `HeartbeatService` upserts device data into the new `kiosk_devices` table instead of updating the `outlets` table.
3. RLS policies on `kiosk_devices` explicitly allow outlets to upsert their own device statuses.

### Phase 32: Multi-Device Dashboard
**Goal:** Redesign the Admin 'Status Kiosk' section to handle and display multiple devices natively.
**Requirements:** [HEALTH-03, HEALTH-04, HEALTH-05]
**Plans:** 2/2 plans complete

Plans:
- [ ] 32-01-PLAN.md — KioskDevice model, SQL RPCs (set_device_nickname, archive_device), unit tests
- [ ] 32-02-PLAN.md — KioskDeviceCard widget, dashboard migration, bridge removal, human verification

**Success Criteria:**
1. Admin Dashboard lists every active device independently with its own real-time battery and sync status.
2. Admins can tap a device to assign an intuitive nickname (e.g., "Kiosk Depan").
3. Admins can archive/unlink a retired device so it no longer appears as permanently Offline.
4. Overwriting race conditions from two separate devices logging into the same outlet are completely eliminated.

### Phase 33: Multi-Outlet Control Center
**Goal:** Provide an overarching central view (M005) combining metrics from all outlets across the entire restaurant chain.
**Requirements:** [ADMIN-01, ADMIN-02]
**Plans:** 2/2 plans complete

Plans:
- [ ] 33-01-PLAN.md — central dashboard RPCs + analytics service contracts/tests
- [ ] 33-02-PLAN.md — central admin UI + role-aware routing + outlet drilldown

**Success Criteria:**
1. A new primary "Central Dashboard" view aggregates total connected devices and overall battery health across *all* outlets.
2. Firm-wide daily attendance rate is aggregated and presented in real-time.
3. Central admin can drill down from the chain-wide view into an individual outlet's specific health.

### Phase 34: v6.0 Supabase Rollout Evidence
**Goal:** Apply the pending v6.0 SQL migrations with explicit user confirmation and capture deployment proof that unblocks live milestone verification.
**Requirements:** [HEALTH-02]
**Gap Closure:** Closes audit gaps for missing SQL deployment evidence across phases 31-33.
**Depends on:** Phase 33

**Success Criteria:**
1. `sql/phase_31_kiosk_devices_20260320.sql`, `sql/phase_32_device_mgmt_20260322.sql`, and `sql/phase_33_central_dashboard_20260322.sql` are applied in Supabase with user confirmation before each database step.
2. Planning artifacts record deployment evidence and live proof that kiosk heartbeats reach `kiosk_devices`.
3. Phase 31-33 follow-up verification work no longer depends on unresolved "must apply SQL first" prerequisites.

### Phase 35: Multi-Device Acceptance Verification
**Goal:** Execute live outlet-level verification for persistent device identity and the multi-device admin flows, then turn draft validation into auditable evidence.
**Requirements:** [HEALTH-01, HEALTH-03, HEALTH-04, HEALTH-05]
**Gap Closure:** Closes audit gaps for missing 31->32 integration proof and outlet-level E2E flows.
**Depends on:** Phase 34

**Success Criteria:**
1. UUID persistence across logout and re-setup is verified on the same physical device and recorded in planning artifacts.
2. Two devices can operate on the same outlet without overwriting each other, with live heartbeat evidence captured from `kiosk_devices`.
3. Nickname and archive flows are verified against live Supabase data and documented as executed verification, not draft intent.
4. Requirements `HEALTH-01`, `HEALTH-03`, `HEALTH-04`, and `HEALTH-05` can be marked satisfied by a fresh milestone audit.

### Phase 36: Central Dashboard Acceptance Verification
**Goal:** Verify the central dashboard against live production data and role-aware routing, then close the remaining v6.0 milestone audit gaps.
**Requirements:** [ADMIN-01, ADMIN-02]
**Gap Closure:** Closes audit gaps for missing 32->33 integration proof and central-dashboard E2E verification.
**Depends on:** Phase 35

**Success Criteria:**
1. Full admin lands on the central dashboard with live chain-wide KPIs after the v6.0 SQL rollout is confirmed.
2. Central dashboard drilldown opens the outlet dashboard with the correct preselected outlet, while `kepala_gerai` remains outlet-scoped.
3. Displayed attendance and device aggregates are checked against live Supabase data and recorded as evidence.
4. Milestone documentation is updated so a fresh `$gsd-audit-milestone` can pass without manual interpretation or missing proof.
