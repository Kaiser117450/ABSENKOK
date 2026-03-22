# Phase 35: Multi-Device Acceptance Verification - Research

**Researched:** 2026-03-22
**Domain:** Live outlet-level acceptance verification for persistent device identity and multi-device admin flows
**Confidence:** HIGH (grounded in the current codebase, SQL migrations, phase 31-34 planning artifacts, and the milestone audit)

---

## Summary

Phase 35 is an acceptance-proof phase, not a feature-build phase. The repository already contains the implementation for persistent device UUIDs, `kiosk_devices` heartbeats, and the admin dashboard nickname/archive flows. The audit failure is specifically about missing live evidence that these paths work together on a real outlet after the Phase 34 rollout.

The correct planning posture is:

1. Treat Phase 34 rollout evidence as a hard prerequisite
2. Gather live proof for UUID persistence and dual-device same-outlet behavior before touching requirements
3. Verify nickname and archive flows against live Supabase rows, not UI-only observation
4. Update validation and requirement artifacts only after the proof is concrete

**Primary recommendation:** Split execution into two plans: first capture the foundational device-identity and dual-device evidence, then verify nickname/archive flows and synchronize planning artifacts.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HEALTH-01 | System generates and persists a unique Device ID per installation (UUIDv4). | `DeviceIdentityService` persists the UUID in `SharedPreferences`; missing piece is live logout/re-setup proof. |
| HEALTH-03 | Admin Dashboard displays health status for all connected devices within an outlet. | `AdminDashboardScreen` now reads `kiosk_devices`; missing piece is proof that two devices stay separate on one outlet. |
| HEALTH-04 | Admins can manually unlink/remove retired devices from the dashboard. | `archive_device` RPC and optimistic removal already exist; missing piece is live DB confirmation plus dashboard disappearance. |
| HEALTH-05 | Admins can assign custom nicknames to devices. | `set_device_nickname` RPC and optimistic UI already exist; missing piece is proof that the nickname persists in Supabase. |

---

## Current State Analysis

### 1. Phase 34 must be treated as a real dependency, not just roadmap metadata

Phase 35 depends on Phase 34 because the live acceptance checks need:

- `kiosk_devices`
- `upsert_kiosk_heartbeat`
- `set_device_nickname`
- `archive_device`

If the rollout proof from Phase 34 is missing or inconclusive, Phase 35 should stop and route back to Phase 34 instead of pretending the acceptance phase can proceed safely.

### 2. Device identity continuity is implemented in code already

The core code path exists:

- `DeviceIdentityService.getOrCreateDeviceUuid()` persists a UUIDv4 in `SharedPreferences`
- `HeartbeatService.start()` caches that UUID and sends it through `upsert_kiosk_heartbeat`
- the UUID survives logout because `stop()` only clears the in-memory cache, not stored preferences

That means Phase 35 should verify continuity by observing the same `device_uuid` before and after logout/re-setup on the same physical device, not by rebuilding the implementation.

### 3. The multi-device outlet dashboard path is also already implemented

The admin dashboard now:

- loads from `kiosk_devices`
- filters active devices
- shows one card per device
- allows nickname and archive actions through RPCs

The gap is evidence: the audit explicitly says there is no completed proof that two devices on one outlet remain separate without overwrite races, and no proof that nickname/archive persist against live data.

### 4. The draft validation files are part of the problem

The audit does not only complain about missing execution. It also calls out that:

- `31-VALIDATION.md` is still draft
- `32-VALIDATION.md` is still draft
- manual milestone-critical flows remain unchecked

So the Phase 35 plan must leave behind evidence that updates those validation artifacts, not only a local note inside a new phase folder.

---

## Project Constraints That Must Shape the Plan

From `STATE.md` and the milestone audit:

- production database is live for 4 active outlets
- database work already requires explicit user confirmation and should be complete by Phase 34
- Phase 35 should avoid speculative app-code changes unless live proof exposes a real defect
- requirements must not be marked complete from implementation-only evidence

Operationally, this means the plan should:

- front-load prerequisite checking
- use exact SQL queries for every live proof step
- record device/outlet identifiers and timestamps in validation artifacts
- keep requirement updates behind a proof gate

---

## Recommended Execution Strategy

### Step 1: Lock the prerequisite before the first live acceptance step

Execution should review `34-VALIDATION.md` and confirm the rollout evidence exists before starting outlet-level checks. If Phase 34 did not leave behind usable proof, Phase 35 should record the blocker and stop.

### Step 2: Build one operator-facing acceptance packet

Before any manual testing, Phase 35 should consolidate:

- the prerequisite check
- the UUID persistence procedure
- the dual-device same-outlet procedure
- the nickname and archive procedures
- exact SQL queries for each checkpoint

This keeps the operator from improvising midway through a live verification run.

### Step 3: Verify UUID persistence on the same physical device

The requirement is not "UUID exists." It is "one installation keeps one UUID across logout and re-setup." The clean proof is:

1. capture a recent `device_uuid` for device A
2. log out that same device
3. re-run kiosk setup on that same device
4. observe that the next heartbeat still uses the same `device_uuid`

If the second setup produces a new row with a different UUID, HEALTH-01 is not satisfied.

### Step 4: Verify two-device separation on one outlet

The critical integration proof is not just two rows in `kiosk_devices`; it is that:

- both rows are active for the same outlet
- both rows keep distinct `device_uuid` values
- admin dashboard shows the two devices independently

This is the missing 31 -> 32 integration proof flagged by the audit.

### Step 5: Verify nickname and archive against live Supabase data

Nickname and archive cannot be accepted on UI observation alone:

- nickname must round-trip into `kiosk_devices.nickname`
- archive must set `is_active = false`
- dashboard refresh must stop showing the archived device

The best execution flow is to use the two devices from the previous step so one stays active while the other gets archived.

### Step 6: Synchronize planning artifacts only after proof exists

After all live evidence succeeds, execution should update:

- `31-VALIDATION.md`
- `32-VALIDATION.md`
- `35-VALIDATION.md`
- `REQUIREMENTS.md`
- `STATE.md`

It should not edit `v6.0-MILESTONE-AUDIT.md` directly. A fresh audit should derive the new state from the evidence.

---

## Verification Queries to Reuse During Execution

### Phase 34 prerequisite review

First review `.planning/phases/34-v6-supabase-rollout-evidence/34-VALIDATION.md`.

If the operator needs a minimal live object check before continuing:

```sql
SELECT proname
FROM pg_proc
WHERE proname IN ('upsert_kiosk_heartbeat', 'set_device_nickname', 'archive_device')
ORDER BY proname;
```

### UUID baseline and post re-setup check

```sql
SELECT device_uuid, outlet_id, nickname, is_active, last_heartbeat_at, updated_at
FROM kiosk_devices
ORDER BY updated_at DESC NULLS LAST
LIMIT 10;
```

```sql
SELECT device_uuid, outlet_id, nickname, is_active, last_heartbeat_at, updated_at
FROM kiosk_devices
WHERE device_uuid = '<DEVICE_UUID_FROM_BASELINE>'
ORDER BY updated_at DESC NULLS LAST
LIMIT 5;
```

### Dual-device same-outlet proof

```sql
SELECT device_uuid, outlet_id, nickname, battery_level, pending_sync_count, last_heartbeat_at, is_active
FROM kiosk_devices
WHERE outlet_id = '<TARGET_OUTLET_ID>'
  AND is_active = TRUE
ORDER BY last_heartbeat_at DESC NULLS LAST;
```

### Nickname persistence proof

```sql
SELECT id, device_uuid, nickname, is_active, updated_at
FROM kiosk_devices
WHERE outlet_id = '<TARGET_OUTLET_ID>'
ORDER BY updated_at DESC NULLS LAST;
```

### Archive proof

```sql
SELECT id, device_uuid, nickname, is_active, updated_at
FROM kiosk_devices
WHERE id = '<ARCHIVED_DEVICE_ID>';
```

---

## Pitfalls

### Pitfall 1: Treating Phase 34 as optional

If the rollout evidence is not real, every later proof step becomes ambiguous. The plan must stop instead of masking that dependency failure.

### Pitfall 2: Accepting "same session" as UUID persistence

HEALTH-01 is about logout/re-setup continuity on the same installation. Merely observing repeated heartbeats in one uninterrupted session does not prove it.

### Pitfall 3: Mistaking one device heartbeating twice for dual-device proof

The same-outlet proof requires two distinct `device_uuid` values tied to the same outlet, not one device generating multiple fresh timestamps.

### Pitfall 4: Verifying nickname or archive only in the UI

The acceptance proof must include Supabase state:

- nickname persisted in `kiosk_devices.nickname`
- archive flipped `is_active` to `false`

### Pitfall 5: Updating requirements before validation artifacts are synchronized

If `REQUIREMENTS.md` moves to complete while `31-VALIDATION.md` and `32-VALIDATION.md` still read like drafts, the next milestone audit will remain ambiguous.

---

## Validation Architecture

### Dimension 1: Prerequisite integrity

- Phase 34 rollout evidence exists and is reviewable before Phase 35 starts
- required RPCs and table are present in production

### Dimension 2: Device identity continuity

- same physical device keeps one `device_uuid` across logout and re-setup
- proof includes timestamps and the exact UUID observed

### Dimension 3: Same-outlet multi-device integrity

- two active rows exist for one outlet
- each row has a different `device_uuid`
- admin dashboard shows both devices independently

### Dimension 4: Admin flow persistence

- nickname persists in Supabase and remains visible after reload
- archived device is hidden from active dashboard state and marked inactive in DB

### Dimension 5: Evidence integrity

- validation artifacts record actual execution results
- requirements flip to complete only after live proof exists
- stale draft validation status from phases 31 and 32 is explicitly closed

### Recommended task split

- Plan 01: prerequisite packet + UUID persistence + dual-device same-outlet proof
- Plan 02: nickname/archive proof + planning artifact synchronization

This keeps foundational verification in wave 1 and lets the evidence sync happen only after the live checks have actually succeeded.

---

## Sources

### Primary

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/STATE.md`
- `.planning/v6.0-MILESTONE-AUDIT.md`
- `.planning/phases/34-v6-supabase-rollout-evidence/34-VALIDATION.md`
- `.planning/phases/31-device-identity-foundation/31-VALIDATION.md`
- `.planning/phases/32-multi-device-dashboard/32-VALIDATION.md`
- `lib/services/device_identity_service.dart`
- `lib/services/heartbeat_service.dart`
- `lib/screens/admin/admin_dashboard_screen.dart`
- `sql/phase_31_kiosk_devices_20260320.sql`
- `sql/phase_32_device_mgmt_20260322.sql`
