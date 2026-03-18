# Requirements: Absensi Enakko v4.0 — Smart Attendance + Admin Dashboard

**Defined:** 2026-03-18
**Core Value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.

## v4.0 Requirements

### Bug Fix

- [x] **BUG-01**: NFC registration flow prevents double-scan crash — if NFC card is scanned twice during registration, app handles it gracefully without force close

### Admin Onboarding

- [ ] **ADMIN-01**: Admin can create a new Kepala Gerai user account directly from the app (Supabase Auth with auto-generated email and password)
- [ ] **ADMIN-02**: Admin can copy or share the generated credentials (email + password) to WhatsApp for the new Kepala Gerai
- [ ] **ADMIN-03**: Credential sharing generates a PDF document with account details, creation timestamp, outlet assignment, and audit trail info
- [ ] **ADMIN-04**: Supabase Edge Function handles user creation server-side (service_role key never in APK)

### Core Analytics (BETA)

- [ ] **ANLYT-01**: Admin/Kepala Gerai can see attendance rate card on dashboard showing daily/weekly/monthly hadir percentage with concrete counts (e.g., "Hadir 14/16 hari — 87.5%")
- [ ] **ANLYT-02**: Admin/Kepala Gerai can see overtime tracking — hours worked vs shift template duration, flagged when exceeding threshold
- [x] **ANLYT-03**: Admin/Kepala Gerai receives notification when employee has not scanned pulang after configurable threshold (default 10 hours from masuk)
- [x] **ANLYT-04**: Missing clock-out notifications are batched per outlet ("3 karyawan belum pulang di Outlet A") not individual alerts

### Smart Attendance (BETA)

- [ ] **SMART-01**: System analyzes last 30 days of masuk timestamps per employee and computes median arrival time per day-of-week
- [ ] **SMART-02**: Admin/Kepala Gerai receives notification when employee is late >5 minutes from their usual pattern time
- [ ] **SMART-03**: Pattern detection runs in background isolate and caches results — never blocks NFC scan handler
- [ ] **SMART-04**: Employees with fewer than 5 data points for a day-of-week are skipped (insufficient data)

### Gamification

- [x] **GAME-01**: System tracks consecutive on-time attendance streak per employee using noon-rule logical days
- [ ] **GAME-02**: Streak counter is visible on kiosk scan result screen after successful masuk
- [ ] **GAME-03**: Auto-badge awards at streak milestones (7-day, 30-day, 90-day) using existing badge system
- [ ] **GAME-04**: Streak leaderboard visible on admin dashboard (top 5 employees by current streak)

### Dashboard & Visualization

- [ ] **DASH-01**: Kepala Gerai can see mini chart dashboard — single scrollable screen with attendance rate donut chart, weekly trend bar chart, streak leaderboard, overtime alerts
- [ ] **DASH-02**: Dashboard uses fl_chart for chart rendering — lightweight, pure Dart, suitable for 24/7 kiosk
- [ ] **DASH-03**: Admin can see cross-outlet attendance comparison as grouped bar chart (admin-only, kepala gerai sees own outlet only)
- [ ] **DASH-04**: Chart dashboard handles memory properly for 24/7 kiosk operation (AutomaticKeepAliveClientMixin, proper disposal)
- [x] **DASH-05**: All chart aggregations computed via Supabase RPC functions (server-side PostgreSQL), not fetch-all-and-compute-in-Dart

## Future Requirements

### Schedule UX Improvement
- **SCHED-01**: Schedule grid tap-to-cycle shift assignment (GRID-D1)
- **SCHED-02**: Schedule grid copy-week feature (GRID-D2)
- **SCHED-03**: Schedule grid today-column highlight (GRID-D3)

### Workflow
- **FLOW-01**: Time-off request approval workflow
- **FLOW-02**: Keterlambatan (late arrival) automatic flagging vs shift start time

### Advanced
- **ADV-01**: Employee-facing mobile app (view own attendance)
- **ADV-02**: QR code backup scan when NFC fails

## Out of Scope

| Feature | Reason |
|---------|--------|
| ML-based absence prediction | Insufficient data (89 logs, 14 employees) — need 200+ employees with 6+ months data |
| Complex gamification (XP, levels, rewards shop) | Over-engineering for 14 restaurant employees |
| Real-time push to employee personal phones | Employees use shared kiosk, don't have app on personal phones |
| Automated schedule adjustment from patterns | Schedules are owner/kepala gerai decisions, not algorithmic |
| GPS/geofencing validation | Fixed NFC kiosk = location proof; GPS adds zero value |
| Firebase/FCM push notifications | Local notification via existing infrastructure sufficient for kiosk; avoids Kotlin 1.9.25 compatibility risk |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUG-01 | Phase 23 | Complete |
| ADMIN-01 | Phase 26 | Pending |
| ADMIN-02 | Phase 26 | Pending |
| ADMIN-03 | Phase 26 | Pending |
| ADMIN-04 | Phase 26 | Pending |
| ANLYT-01 | Phase 24 | Pending |
| ANLYT-02 | Phase 24 | Pending |
| ANLYT-03 | Phase 24 | Complete |
| ANLYT-04 | Phase 24 | Complete |
| SMART-01 | Phase 24 | Pending |
| SMART-02 | Phase 24 | Pending |
| SMART-03 | Phase 24 | Pending |
| SMART-04 | Phase 24 | Pending |
| GAME-01 | Phase 23 | Complete |
| GAME-02 | Phase 25 | Pending |
| GAME-03 | Phase 25 | Pending |
| GAME-04 | Phase 25 | Pending |
| DASH-01 | Phase 25 | Pending |
| DASH-02 | Phase 25 | Pending |
| DASH-03 | Phase 25 | Pending |
| DASH-04 | Phase 25 | Pending |
| DASH-05 | Phase 23 | Complete |

**Coverage:**
- v4.0 requirements: 20 total
- Mapped to phases: 20
- Unmapped: 0

---
*Requirements defined: 2026-03-18*
*Last updated: 2026-03-18 — Traceability populated during roadmap creation*
