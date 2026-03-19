# Project Research — ARCHITECTURE

**Dimension:** System architecture and integration points
**Focus:** Sync visibility, kiosk/device health, recovery/reconciliation, failure surfaces

## Data Flow & Integration Points

### 1. Supabase Modifications (Additive)
We need to extend the `outlets` table to include health metrics.
- Add columns: `last_heartbeat_at` (timestamptz), `battery_level` (int2), `is_charging` (bool), `pending_sync_count` (int4), `app_version` (text).
- Update RPC functions to return these fields for the Admin Dashboard.

### 2. Flutter App Architecture

**Heartbeat mechanism:**
- Hook into the existing `KioskBackgroundService` which uses `flutter_foreground_task`.
- Every X ticks (e.g. 5 mins), execute `Supabase.instance.client.rpc('update_kiosk_health', ...)` or direct `update()` on `outlets`.
- This ensures health is tracked even if the app UI is not in focus.

**Sync queue state management:**
- Expose a `ValueNotifier<int>` or `Stream<int>` in `OfflineQueueService` to track the un-synced queue size.
- Bind this to a small UI indicator icon within the app's `AppCard` or top app bar.

**Sentry wrapper:**
- Wrap `main()` with `SentryFlutter.init(...)`.
- The `try/catch` in `KioskBackgroundService` (implemented in v1.1) must call `Sentry.captureException(...)` so isolated failures don't disappear into a void.

## Build Order Strategy
1. **Supabase Schema Expansion:** Add the health columns and create the update logic RPC.
2. **Kiosk Health & Heartbeat Engine:** Implement the battery/version polling and background heartbeat.
3. **Sync Visibility UI:** Implement queue count broadcasts and UI displays.
4. **Sentry & Failure Logging:** Add the crash reporting wrapper across the app.
