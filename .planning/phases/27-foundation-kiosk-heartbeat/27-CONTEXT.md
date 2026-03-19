# Phase 27: Foundation & Kiosk Heartbeat - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Expand the existing `outlets` row with kiosk heartbeat fields and make the current Android kiosk background service report device health every 15 minutes. This phase covers liveness and payload behavior only; admin warning surfaces, kiosk diagnostics UI, and crash reporting stay in later phases.

</domain>

<decisions>
## Implementation Decisions

### Heartbeat timing
- Send the first heartbeat immediately when the kiosk enters its idle session through `KioskBackgroundService.start(session)`.
- After the first send, use a rolling 15-minute cadence instead of aligning to wall-clock quarter hours.
- If the process or service restarts unexpectedly, send a fresh heartbeat immediately on restart.
- When kiosk session is cleared or logout happens, do not clear heartbeat fields; let the last heartbeat age out naturally for later offline detection.

### Offline retry behavior
- If a scheduled heartbeat happens while the tablet has no internet, retry immediately when connectivity returns during the same kiosk session.
- If Supabase is reachable but the heartbeat write fails, do up to 2 quick retries in that cycle, then wait for the next scheduled heartbeat.
- After a long outage ends, send one fresh snapshot only; do not replay missed heartbeat intervals.
- Heartbeat recovery should stay independent from attendance sync so kiosk health still updates even when there are no pending logs.

### Payload semantics
- `pending_sync_count` should count SQLite rows whose `sync_status` is `pending` or `failed`.
- Sample `pending_sync_count` at the exact moment the heartbeat is sent.
- Store `app_version` in `version+build` format, for example `3.1.2+8009`.
- If battery status cannot be read in a heartbeat cycle, still send the heartbeat and keep battery fields null instead of sending a fake `0%` value or skipping the whole heartbeat.

### Claude's Discretion
- Exact implementation for reconnect detection and scheduling hooks inside the existing foreground/background service structure.
- Exact retry backoff spacing for the 2 quick write retries.
- Exact package and adapter choices for reading app version and battery state, as long as the stored payload matches the decisions above.

</decisions>

<specifics>
## Specific Ideas

- Heartbeat data should represent the kiosk's latest real state, not a replayed history of missed intervals.
- Stored app version should stay support-friendly by including the build number, not just the semantic version.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/services/kiosk_background_service.dart`: Existing Android foreground-service shell and kiosk lifecycle entry point.
- `lib/services/sqlite_service.dart`: Already exposes `countPendingLogs()` and defines the queue statuses used for `pending_sync_count`.
- `lib/models/kiosk_session.dart`: Already carries `outletId`, `outletName`, and `deviceId` for the active kiosk.
- `lib/screens/admin/admin_outlets_screen.dart` and `lib/screens/admin/admin_dashboard_screen.dart`: Already read `outlets` directly, so new fields can flow through the existing model/query path later.

### Established Patterns
- Kiosk session is persisted under `kiosk_session_v1` and background service startup currently begins from `KioskIdleScreen.initState()`.
- `SyncService` is best-effort and connectivity-aware, but Phase 27 heartbeat should remain logically independent from attendance sync attempts.
- `outlets` records are currently fetched with `select('*')` and mapped through `Outlet.fromJson`, so new outlet fields will require model expansion but fit the current data-access style.

### Integration Points
- Supabase `outlets` table and `lib/models/outlet.dart` need the new heartbeat/device-health fields.
- `KioskBackgroundService` and its task handler are the natural home for 15-minute heartbeat scheduling, restart behavior, and retry policy.
- `SqliteService.countPendingLogs()` is the current source of truth for queue count semantics.
- `pubspec.yaml` already defines the app version string, while battery support will require a new Android-capable dependency.

</code_context>

<deferred>
## Deferred Ideas

- Heartbeat history or audit-trail storage beyond the latest `outlets` snapshot would be a separate capability.
- Immediate admin/dashboard surfacing of offline or low-battery status belongs to Phase 30.

</deferred>

---

*Phase: 27-foundation-kiosk-heartbeat*
*Context gathered: 2026-03-19*
