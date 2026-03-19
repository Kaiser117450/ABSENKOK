# Requirements: Absensi Enakko v5.0 — Ops hardening + reliability

**Defined:** 2026-03-19
**Core Value:** Make the system safer to trust every day.

## v5.0 Requirements

### Kiosk/Device Health (HLTH)
- [x] **HLTH-01**: Kiosk tablet sends a background heartbeat to Supabase every 15 minutes.
- [x] **HLTH-02**: Heartbeat payload includes `battery_level` (%), `is_charging` (boolean), and `app_version` (string).
- [ ] **HLTH-03**: Admin dashboard displays a warning (e.g. "Offline") if an outlet's kiosk has not sent a heartbeat in over 30 minutes.
- [ ] **HLTH-04**: Admin dashboard displays low battery warning (< 20%) for any active kiosk.

### Sync Visibility (SYNC)
- [x] **SYNC-01**: System counts the number of pending offline scans currently queued in local SQLite.
- [x] **SYNC-02**: Pending sync count is sent as part of the 15-minute heartbeat payload (`pending_sync_count`).
- [ ] **SYNC-03**: Admin dashboard displays the number of unsynced logs per outlet.
- [ ] **SYNC-04**: Kiosk UI displays a visual indicator (icon or text) on the idle screen when there are pending offline syncs.

### Recovery & Repair (RECV)
- [ ] **RECV-01**: Kiosk UI provides a hidden or admin-gated "Force Sync" button on the settings/diagnostic screen.
- [ ] **RECV-02**: Force Sync bypasses the normal queue timer and immediately attempts to flush the offline SQLite queue to Supabase.
- [ ] **RECV-03**: Success or failure of the Force Sync is communicated via a Toast or Snackbar.

### Failure Surfaces (FAIL)
- [ ] **FAIL-01**: App integrates `sentry_flutter` to automatically capture and report unhandled Dart and native exceptions.
- [ ] **FAIL-02**: Sentry configuration explicitly filters out/ignores benign NFC `Tag lost` exceptions to prevent log spam.
- [ ] **FAIL-03**: The `KioskBackgroundService` isolate wraps its periodic task in a try/catch that reports directly to Sentry if a background failure occurs.

## Future Requirements

### Workflow
- **FLOW-01**: Time-off request approval workflow.
- **FLOW-02**: Keterlambatan (late arrival) automatic flagging vs shift start time.

### Roadmap Additions
- **M005**: Multi-outlet control center (chain-level oversight).
- **M006**: Employee-facing web app (self-service).

## Out of Scope

| Feature | Reason |
|---------|--------|
| iOS App | Kiosk is Android tablet only. |
| Aggressive < 1min heartbeat | Will silently drain tablet battery and hit Supabase rate limits. |
| Automatic remote restart | Android restricts remote restart without device root/MDM. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| HLTH-01 | Phase 27 | Complete |
| HLTH-02 | Phase 27 | Complete |
| HLTH-03 | Phase 30 | Pending |
| HLTH-04 | Phase 30 | Pending |
| SYNC-01 | Phase 27 | Complete |
| SYNC-02 | Phase 27 | Complete |
| SYNC-03 | Phase 30 | Pending |
| SYNC-04 | Phase 29 | Pending |
| RECV-01 | Phase 29 | Pending |
| RECV-02 | Phase 29 | Pending |
| RECV-03 | Phase 29 | Pending |
| FAIL-01 | Phase 28 | Pending |
| FAIL-02 | Phase 28 | Pending |
| FAIL-03 | Phase 28 | Pending |

**Coverage:**
- v5.0 requirements: 14 total
- Mapped to phases: 14
- Unmapped: 0

---
*Requirements defined: 2026-03-19*
