# Milestone Research Summary
**Milestone:** v5.0 (Ops hardening + reliability)
**Date Captured:** 2026-03-19

## Key Findings

### Stack Additions Required
- **`battery_plus`**: Device battery and charging state tracking.
- **`sentry_flutter`**: Application crash and exception monitoring.
- *Recommendation:* Keep dependencies lean. Use existing `OfflineQueueService` + updated Supabase columns rather than adding full background-sync frameworks.

### Scope & Differentiators
- **Heartbeat System:** Kiosks ping Supabase every ~10 mins with battery, app version, and unsynced count. Admin dashboard displays warnings if a kiosk is 'AWOL' (no ping > 30 mins) or low battery.
- **Sync Visibility:** Visual indicators locally on the tablet and remotely for Admins showing exactly how many scans are queued offline.
- **Diagnostics UI:** A "Force Sync" and manual troubleshooting surface for Area Managers/Branch Heads.

### Architectural Impact
- **Database:** Additative modification to `outlets` table (`last_heartbeat_at`, `battery_level`, `is_charging`, `pending_sync_count`, `app_version`).
- **Foreground Isolate:** The existing `flutter_foreground_task` must handle periodic heartbeats safely. Due to isolate limitations, device metrics (like battery) might need to be captured on the main thread and passed to the isolate via IPC.
- **Main App:** Sentry wrapper initialized in `main()`, with critical `try/catch` catches routed to Sentry implicitly.

### Pitfalls to Avoid (CRITICAL)
1. **Sentry Quota Spam:** Filter out expected NFC "Tag Lost" errors.
2. **Battery Drain:** Do not ping Supabase too aggressively. 10+ minute interval is recommended.
3. **Isolate MethodChannel Errors:** Beware of using Flutter plugins (`battery_plus`) inside background isolates without verifying background support. Pass data from main thread over SendPort if needed.
