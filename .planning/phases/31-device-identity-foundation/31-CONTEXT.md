# Phase 31: Device Identity Foundation - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish persistent installation-level device tracking via UUIDv4 and decouple heartbeat storage from the `outlets` table so multiple devices can be supported per outlet. Nicknames, archive/unlink flows, and multi-device admin UI stay out of scope for this phase.

</domain>

<decisions>
## Implementation Decisions

### Identity lifetime
- One physical installation keeps the same device identity across kiosk logout and re-setup.
- Device identity should survive normal kiosk session churn instead of being recreated whenever setup runs again.
- Existing installs with the older short random ID should be upgraded automatically to UUIDv4 on next boot.
- If the stored identity is missing or corrupt, the app should regenerate it automatically so the kiosk remains usable.

### Transition safety
- Phase 31 must not visibly regress the current admin health experience while the data model moves to `kiosk_devices`.
- Both the Admin Dashboard "Status Kiosk" cards and the outlet list health indicator should remain accurate during the transition.
- Outlet-level heartbeat fields are a temporary compatibility bridge only and should stop being treated as live source data after Phase 32 lands.

### Outlet moves
- The same physical installation keeps the same identity when it is reassigned to a different outlet.
- Admin history should treat reassignment as one device moving outlets, not as separate device identities.
- Once a device moves away, the previous outlet should stop treating it as the current active device.
- Multiple distinct devices may report under one outlet at the same time; the exclusivity question applies to one device identity, not to outlet capacity.

### Claude's Discretion
- Exact storage/service structure for keeping installation identity separate from kiosk session state.
- Exact compatibility mechanism used to keep current outlet-based health surfaces accurate during the Phase 31 to Phase 32 transition.
- Reinstall or app-data-clear recovery UX beyond normal mobile defaults was not explicitly locked during discussion.

</decisions>

<specifics>
## Specific Ideas

- Operational reality to preserve: admins or kepala gerai may log into the same store account from multiple devices, so health/battery reporting must stop overwriting one device with another.
- The user is comfortable leaving internal implementation details to planning as long as persistence and transition safety stay intact.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/models/kiosk_session.dart`: already carries `outlet_id`, `outlet_name`, and `device_id` through kiosk lifecycle.
- `lib/providers/app_provider.dart`: existing SharedPreferences persistence pattern for kiosk session and other non-sensitive kiosk state.
- `lib/services/heartbeat_service.dart`: existing heartbeat timer, retry, battery/version, and pending-sync payload assembly can be reused for the new table target.
- `lib/services/kiosk_background_service.dart`: already owns heartbeat start/stop with kiosk lifecycle.
- `pubspec.yaml`: `uuid` package already exists in dependencies for local log IDs, so UUIDv4 generation does not require a new package.

### Established Patterns
- SharedPreferences is the accepted store for non-sensitive kiosk/device state in this app.
- Production database work must be additive and non-destructive.
- Admin health surfaces currently read outlet-level fields directly, so backward compatibility matters until the UI is refactored.
- Kiosk background behavior already treats heartbeat as a continuous service concern rather than a one-off request.

### Integration Points
- `lib/screens/setup/setup_screen.dart`: replace setup-time short random ID generation with persistent installation identity retrieval.
- `lib/providers/app_provider.dart`: ensure session clearing does not destroy installation identity.
- `lib/services/heartbeat_service.dart`: move writes from `outlets` to `kiosk_devices` while preserving temporary compatibility for existing admin surfaces.
- `lib/models/outlet.dart`, `lib/screens/admin/admin_dashboard_screen.dart`, and `lib/screens/admin/admin_outlets_screen.dart`: existing outlet-level health reads define the transition bridge requirements.
- `sql/phase_27_heartbeat_columns_20260320.sql`: current outlet-level heartbeat schema is the compatibility baseline that Phase 31 will decouple from.

</code_context>

<deferred>
## Deferred Ideas

- Device nicknames such as "Kiosk Depan" belong to Phase 32.
- Manual archive/unlink of retired or replaced devices belongs to Phase 32.
- Rich multi-device admin presentation and management belong to Phase 32.

</deferred>

---

*Phase: 31-device-identity-foundation*
*Context gathered: 2026-03-20*
