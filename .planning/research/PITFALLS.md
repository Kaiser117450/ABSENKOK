# Project Research — PITFALLS

**Dimension:** Common mistakes and prevention
**Focus:** Sync visibility, kiosk/device health, recovery/reconciliation, failure surfaces

## Common Mistakes & Warning Signs

### 1. Battery Drain via Aggressive Polling
**The Pitfall:** Setting the heartbeat interval to < 1 minute will keep the radio active constantly, draining the tablet battery faster than a weak charger can supply.
**The Fix:** Heartbeats should be constrained to 10-15 minute intervals, or only trigger when a meaningful state change occurs (e.g. battery drops 5%, or plugged/unplugged event).

### 2. Throttling/Supabase Rate Limits
**The Pitfall:** If `pending_sync` attempts to retry continuously without backoff during a prolonged offline state, it will hammer Supabase when it comes online, risking HTTP 429 Too Many Requests.
**The Fix:** Implement standard exponential backoff in the `OfflineQueueService`.

### 3. Sentry Log Spam
**The Pitfall:** NFC reads frequently throw "Tag lost" exceptions when users tap their card too quickly. Sentry will log thousands of these, eating up the quota.
**The Fix:** Specifically filter out known/benign exceptions. E.g., `if (e is NfcException && e.message.contains('Tag lost')) return;`.

### 4. Isolate Memory Leaks
**The Pitfall:** `Sentry` and some `battery_plus` classes might attempt to use `MethodChannels` from inside the background isolate (`KioskBackgroundService`). Sometimes this fails if the plugin doesn't support background isolate execution.
**The Fix:** Ensure all device reads (battery, version) are processed in the main thread and passed to the background service, or verify the plugins explicitly support isolate execution. (Safe approach: `flutter_foreground_task` handles IPC, send battery status to it).
