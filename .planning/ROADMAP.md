# Milestone v6.0 Roadmap

**Goal:** Provide chain-wide oversight for admins across all outlets and decouple device health tracking to support multiple devices natively.

| # | Phase | Goal | Requirements | Criteria |
|---|-------|------|--------------|----------|
| 31 | 2/2 | Complete   | 2026-03-20 | 3 |
| 32 | Multi-Device Dashboard | Visualize and manage individual kiosk devices per outlet. | HEALTH-03, HEALTH-04, HEALTH-05 | 4 |
| 33 | Multi-Outlet Control Center | Aggregated chain-wide dashboard for central admins. | ADMIN-01, ADMIN-02 | 3 |

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
**Plans:** 2 plans

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

**Success Criteria:**
1. A new primary "Central Dashboard" view aggregates total connected devices and overall battery health across *all* outlets.
2. Firm-wide daily attendance rate is aggregated and presented in real-time.
3. Central admin can drill down from the chain-wide view into an individual outlet's specific health.
