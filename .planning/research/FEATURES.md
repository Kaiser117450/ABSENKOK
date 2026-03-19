# Project Research — FEATURES

**Dimension:** Feature scope, table stakes, differentiators
**Focus:** Sync visibility, kiosk/device health, recovery/reconciliation, failure surfaces

## Feature Categories & Scope

### 1. Kiosk/Device Health Heartbeat
**Table Stakes:**
- Tablet periodically pings Supabase (e.g., every 5-15 mins).
- Records `battery_level`, `is_charging`, `app_version`.
- Admin dashboard displays a warning if an outlet's kiosk hasn't pinged in > 30 minutes.

### 2. Sync Visibility
**Table Stakes:**
- Admin dashboard shows "Pending Syncs" count per outlet.
- Real-time or polled indicator inside the app showing "Online" vs "Offline (X scans queued)".

### 3. Recovery / Reconciliation
**Table Stakes:**
- Admin UI button for "Force Sync" on the tablet.
- Automatic retry with exponential backoff for failed syncs.
**Differentiators:**
- Conflict resolution logs if an attendance scan was rejected by the server but exists locally.

### 4. Failure Surfaces & Repair
**Table Stakes:**
- Sentry integration to capture silent exceptions that block the UI or background tasks.
- Visual indicator (e.g., red dot) if the background isolate (`KioskBackgroundService`) fails.

## Dependencies on Existing System
- `OfflineQueueService` needs to be modified to broadcast its queue size.
- Ensure the heartbeat logic runs in `KioskBackgroundService` (foreground task) so it works even if the screen is off or app is in background.
