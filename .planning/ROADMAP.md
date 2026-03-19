# ROADMAP — v5.0 Ops hardening + reliability

**Starting Phase:** 27
**Status:** Requirements Mapped

## Phases

### Phase 27: Foundation & Kiosk Heartbeat
**Goal:** Expand `outlets` table and implement background heartbeat with device metrics.
**Requirements:** HLTH-01, HLTH-02, SYNC-01, SYNC-02
**Plans:** 2/2 plans complete

Plans:
- [ ] 27-01-PLAN.md — SQL migration, Outlet model expansion, battery_plus + package_info_plus deps
- [ ] 27-02-PLAN.md — HeartbeatService implementation + KioskBackgroundService wiring

**Success Criteria:**
1. Supabase `outlets` table has `last_heartbeat_at`, `battery_level`, `is_charging`, `pending_sync_count`, and `app_version` columns.
2. `battery_plus` package is integrated and successfully reads battery status on Android.
3. Kiosk background isolate sends ping to Supabase every 15 minutes with all metrics.

### Phase 28: Failure Surfaces & Crash Reporting
**Goal:** Integrate Sentry for crash reporting to catch silent native/isolate failures.
**Requirements:** FAIL-01, FAIL-02, FAIL-03
**Plans:** 1 plan

Plans:
- [ ] 28-01-PLAN.md — Sentry integration, NFC noise filter, background failure capture with throttle

**Success Criteria:**
1. `sentry_flutter` is initialized in `main()`.
2. NFC `Tag lost` exceptions are filtered and not sent to Sentry.
3. Errors inside the `KioskBackgroundService` isolate are explicitly captured and sent to Sentry.

### Phase 29: Diagnostics & Recovery Tools
**Goal:** Expose sync visibility on the kiosk and provide tools to force reconcile.
**Requirements:** SYNC-04, RECV-01, RECV-02, RECV-03

**Success Criteria:**
1. Kiosk idle screen displays a visual indicator when there are pending attendance logs in SQLite.
2. Secret/Admin-gated Diagnostic screen contains a "Force Sync" button.
3. Pressing "Force Sync" triggers `OfflineQueueService` to process queue immediately with visual UI feedback (Toast).

### Phase 30: Multi-Outlet Admin Visibility
**Goal:** Expose the health metrics and sync warnings on the Admin Dashboard.
**Requirements:** HLTH-03, HLTH-04, SYNC-03

**Success Criteria:**
1. Admin dashboard highlights outlets that haven't sent a heartbeat in >30 minutes ("Offline").
2. Outlets with <20% battery show a clear warning icon.
3. Outlets with pending offline syncs (`pending_sync_count > 0`) show the exact count on the dashboard.
