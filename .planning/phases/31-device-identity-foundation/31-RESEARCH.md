# Phase 31: Device Identity Foundation — Research

**Researched:** 2026-03-20
**Status:** Complete

## Executive Summary

Phase 31 must: (1) replace the per-setup random 12-char device ID with a persistent UUIDv4 installation identity, (2) create a `kiosk_devices` table and redirect `HeartbeatService` writes to it, (3) maintain backward compatibility so the current admin "Status Kiosk" section continues working until Phase 32 refactors it. Research covers the current codebase, database schema, RLS policies, and a concrete migration path.

---

## 1. Current Device ID Implementation

### Generation (setup_screen.dart:152-156)
```dart
String _generateDeviceId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random.secure();
  return List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
}
```
- Called every time `_activate()` runs (line 129) — a **new** random 12-char ID is generated on every kiosk setup.
- The ID is embedded in `KioskSession` and stored via `SharedPreferences` under key `kiosk_session_v1`.
- **Problem:** Re-running setup (logout + setup again) generates a different device ID. The same physical tablet gets a new identity each time.

### Where device_id is Used
| Location | Usage |
|----------|-------|
| `KioskSession.deviceId` | Carried in session throughout app lifecycle |
| `sqlite_service.dart:113` | Stored in local SQLite `pending_sync_logs` table |
| `sync_service.dart:45` | Sent to Supabase `attendance_logs.device_id` on sync |
| `sentry_service.dart:78` | Set as Sentry tag `device_id` for crash context |
| `pending_log.dart` | Model carries `deviceId` for local pending log records |
| `sakit_izin_dialog.dart:176` | Admin-input attendance uses hardcoded `'ADMIN_INPUT'` |
| `outlet.dart:40` | `Outlet` model has optional `deviceId` field from outlets table |

### KioskSession Model (kiosk_session.dart)
```dart
class KioskSession {
  final String outletId;
  final String outletName;
  final String deviceId;
}
```
- Persisted as JSON string in SharedPreferences under `AppConstants.kioskSessionKey` (`kiosk_session_v1`).
- `clearKioskSession()` in AppNotifier removes the entire session key — device ID is destroyed on logout.

---

## 2. Current Heartbeat Implementation

### HeartbeatService (heartbeat_service.dart)
- **Target:** Updates `outlets` table directly: `Supabase.instance.client.from('outlets').update(payload).eq('id', outletId)`
- **Payload:** `last_heartbeat_at`, `battery_level`, `is_charging`, `pending_sync_count`, `app_version`
- **Timer:** Every 15 minutes + immediate on start + connectivity restore (30s debounce)
- **Retry:** 3 attempts with exponential backoff (2s, 4s), Sentry on final failure
- **Lifecycle:** Started in `KioskBackgroundService.start(session)` → `HeartbeatService.start(session)`. Stopped in `KioskBackgroundService.stop()` → `HeartbeatService.stop()`.

### Key Issue
The heartbeat **updates** the outlet row. If two devices log into the same outlet, the second device's heartbeat overwrites the first. Admin sees only the last device's battery/status — previous device appears to vanish silently.

---

## 3. Database Schema Analysis

### outlets table (current production)
| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| id | uuid | NO | uuid_generate_v4() |
| name | text | NO | — |
| address | text | YES | — |
| lat | double precision | YES | — |
| lng | double precision | YES | — |
| device_id | text | YES | — |
| is_active | boolean | YES | true |
| created_at | timestamptz | YES | now() |
| kiosk_password_hash | text | YES | — |
| last_heartbeat_at | timestamptz | YES | — |
| battery_level | smallint | YES | — |
| is_charging | boolean | YES | — |
| pending_sync_count | integer | YES | — |
| app_version | text | YES | — |

**Note:** `device_id` on `outlets` is used to track "which device is registered" — it's the old 12-char random string. The heartbeat columns (added in Phase 27) are all nullable with no defaults — existing rows unaffected.

### RLS Policies on outlets
| Policy | Command | Qualifier |
|--------|---------|-----------|
| `admin_all_outlets` | ALL | `get_app_role() = 'admin'` |
| `anon_read_active_outlets` | SELECT | `is_active = true` |
| `auth_all_outlets` | ALL | `true` (any authenticated user) |

**Key finding:** The kiosk app uses anon key (not authenticated). Heartbeat writes currently succeed because `anon_read_active_outlets` allows SELECT but… wait — `auth_all_outlets` allows ALL for authenticated users. The kiosk app uses anon key, which hits `anon_read_active_outlets` (SELECT only). So how do heartbeats work?

Looking at `heartbeat_service.dart`: `Supabase.instance.client.from('outlets').update(payload).eq('id', outletId)` — this uses the default Supabase client. The app uses anon key auth. The `anon_read_active_outlets` policy only allows SELECT. This means heartbeat updates may be silently failing in production, OR there's a broader anon policy we're not seeing.

**Actually:** Re-reading the policies — `auth_all_outlets` has `polcmd: *` (ALL) with `qual: true`. This applies to the `authenticated` role. Since kiosk doesn't authenticate (uses anon key), heartbeats would only work if there's a permissive anon policy for UPDATE. The `anon_read_active_outlets` is SELECT only.

**Resolution needed:** Check if the kiosk actually authenticates via Supabase Auth or truly uses anon. The `setup_screen.dart` uses `Supabase.instance.client.rpc('verify_kiosk_password',...)` — this is an anon RPC call. But `heartbeat_service.dart` also uses `Supabase.instance.client` — same client. If heartbeats are working in production, then either:
1. The RPC calls bypass RLS, or
2. There's a liberal anon policy we can't see, or
3. The `auth_all_outlets` policy applies to `public` role (includes anon)

For the new `kiosk_devices` table, we must explicitly design RLS to allow anon INSERT/UPDATE (upsert) for heartbeats. Safest: use a Postgres function/RPC for the upsert to bypass row-level checks.

---

## 4. uuid Package Availability

**CONTEXT.md incorrectly states** that `uuid` package exists in pubspec.yaml. **It does NOT.** Grep returns no results for `uuid` in pubspec.yaml.

**Options for UUIDv4 generation:**
1. **Add `uuid` package** (^4.x) — standard Dart package, well-maintained, adds ~20KB
2. **Use Dart's built-in** — Dart doesn't have native UUID. Would need manual implementation.
3. **Use `crypto` + Random** — Can build RFC4122-compliant UUIDv4 from `Random.secure()`, but error-prone.

**Recommendation:** Add `uuid: ^4.5.1` to pubspec.yaml. It's the standard Dart approach and avoids hand-rolling UUID generation.

---

## 5. Proposed kiosk_devices Table Schema

```sql
CREATE TABLE IF NOT EXISTS kiosk_devices (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_uuid      TEXT NOT NULL UNIQUE,       -- The persistent UUIDv4 from the app
  outlet_id        UUID REFERENCES outlets(id),-- Current outlet assignment
  last_heartbeat_at TIMESTAMPTZ,
  battery_level    SMALLINT,
  is_charging      BOOLEAN,
  pending_sync_count INTEGER,
  app_version      TEXT,
  nickname         TEXT,                        -- Phase 32: admin-assigned name
  is_active        BOOLEAN DEFAULT TRUE,        -- Phase 32: archive/unlink
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);
```

**Key design decisions:**
- `device_uuid` is the app-generated UUIDv4, used as the upsert conflict key
- `outlet_id` tracks current outlet assignment — changes when device is moved
- `nickname` and `is_active` are nullable/defaulted for Phase 32 use — no harm adding now
- Separate `id` (Supabase-generated PK) from `device_uuid` (app-generated identity) for consistency with other tables

### Index
```sql
CREATE INDEX idx_kiosk_devices_outlet ON kiosk_devices(outlet_id);
```

### RLS for kiosk_devices
```sql
-- Enable RLS
ALTER TABLE kiosk_devices ENABLE ROW LEVEL SECURITY;

-- Anon role: can upsert their own device's heartbeat
-- Using a function to bypass RLS cleanly
CREATE OR REPLACE FUNCTION upsert_kiosk_heartbeat(
  p_device_uuid TEXT,
  p_outlet_id UUID,
  p_battery_level SMALLINT DEFAULT NULL,
  p_is_charging BOOLEAN DEFAULT NULL,
  p_pending_sync_count INTEGER DEFAULT NULL,
  p_app_version TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
  INSERT INTO kiosk_devices (device_uuid, outlet_id, last_heartbeat_at, battery_level, is_charging, pending_sync_count, app_version, updated_at)
  VALUES (p_device_uuid, p_outlet_id, NOW(), p_battery_level, p_is_charging, p_pending_sync_count, p_app_version, NOW())
  ON CONFLICT (device_uuid) DO UPDATE SET
    outlet_id = EXCLUDED.outlet_id,
    last_heartbeat_at = NOW(),
    battery_level = EXCLUDED.battery_level,
    is_charging = EXCLUDED.is_charging,
    pending_sync_count = EXCLUDED.pending_sync_count,
    app_version = EXCLUDED.app_version,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Using SECURITY DEFINER** because:
- Kiosk app uses anon key — can't rely on per-row RLS for upserts
- RPC functions bypass RLS when SECURITY DEFINER is used
- This matches the existing pattern (`verify_kiosk_password` RPC)
- Admin SELECT policy covers dashboard reads

**Admin policies (for dashboard reading):**
```sql
CREATE POLICY "admin_read_kiosk_devices" ON kiosk_devices FOR SELECT
  USING (get_app_role() = 'admin');
  
CREATE POLICY "auth_read_kiosk_devices" ON kiosk_devices FOR SELECT
  USING (true);  -- Authenticated users can read (matches outlets pattern)
```

---

## 6. Backward Compatibility Bridge

### Problem
Admin dashboard `_buildKioskHealthSection()` reads outlet heartbeat fields directly:
```dart
final activeOutlets = _outlets.where(...).toList();
// Uses outlet.lastHeartbeatAt, outlet.batteryLevel, etc.
```
`KioskHealthCard` also reads `outlet.lastHeartbeatAt`, `outlet.batteryLevel`, `outlet.isCharging`, `outlet.pendingSyncCount`.

### Solution: Dual-write in HeartbeatService
During Phase 31, `HeartbeatService._sendWithRetry()` should:
1. **Primary:** Call `upsert_kiosk_heartbeat` RPC (new table)
2. **Bridge:** Also update `outlets` table heartbeat fields (existing behavior) — this keeps admin UI working without changes

This dual-write is temporary. Phase 32 will refactor the admin dashboard to read from `kiosk_devices` table, at which point the outlet-level bridge writes can be removed.

### Alternative considered: Database trigger
Could create a trigger on `kiosk_devices` that copies latest heartbeat to `outlets`. Rejected because:
- Adds hidden complexity
- Harder to reason about in production debugging
- Dual-write in Dart is explicit, easy to remove

---

## 7. Installation Identity Lifecycle

### Current Flow
```
Setup Screen → _generateDeviceId() → embed in KioskSession → SharedPreferences
Logout → clearKioskSession() → removes SharedPreferences key → device ID lost
```

### Proposed Flow
```
App Boot → loadSession() → check SharedPreferences for 'installation_device_uuid'
  If missing → generate UUIDv4, store in SharedPreferences under 'installation_device_uuid'
  If present → use existing UUID

Setup Screen → _activate() → read installation UUID (don't generate new one)
  → embed in KioskSession → SharedPreferences

Logout → clearKioskSession() → removes 'kiosk_session_v1' key
  → 'installation_device_uuid' key is NOT removed — survives logout

Re-setup → _activate() → reads same installation UUID
  → same device identity, new session
```

### Key Changes
1. **New SharedPreferences key:** `AppConstants.installationDeviceUuidKey = 'installation_device_uuid_v1'`
2. **UUID generation:** In `AppNotifier.loadSession()` or a separate `DeviceIdentityService`
3. **Setup screen:** Remove `_generateDeviceId()`, read from persistent storage instead
4. **clearKioskSession():** Must NOT remove the installation device UUID key
5. **Upgrade path:** Existing 12-char device IDs → auto-upgrade to UUIDv4 on next boot (check format, regenerate if not UUID)

### Service Design: DeviceIdentityService
```dart
class DeviceIdentityService {
  static const _key = 'installation_device_uuid_v1';
  
  /// Get or create the persistent installation UUID.
  /// Called on app boot — never regenerated unless corrupt/missing.
  static Future<String> getOrCreateDeviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && _isValidUuid(existing)) {
      return existing;
    }
    // Generate new UUIDv4
    final uuid = Uuid().v4();
    await prefs.setString(_key, uuid);
    return uuid;
  }
  
  static bool _isValidUuid(String value) {
    return RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(value);
  }
}
```

---

## 8. Files to Modify

| File | Change | Risk |
|------|--------|------|
| `pubspec.yaml` | Add `uuid: ^4.5.1` dependency | Low |
| New: `lib/services/device_identity_service.dart` | Persistent UUID management | Low |
| `lib/core/constants.dart` | Add `installationDeviceUuidKey` constant | Low |
| `lib/providers/app_provider.dart` | Call `DeviceIdentityService.getOrCreateDeviceUuid()` in `loadSession()`, pass UUID to `KioskSession` | Medium — boot path |
| `lib/screens/setup/setup_screen.dart` | Remove `_generateDeviceId()`, use `DeviceIdentityService` instead | Medium |
| `lib/services/heartbeat_service.dart` | Add device UUID parameter, call `upsert_kiosk_heartbeat` RPC + bridge write | Medium — production heartbeat |
| `lib/models/kiosk_session.dart` | No change needed (already carries `deviceId`) | None |
| SQL migration | Create `kiosk_devices` table + `upsert_kiosk_heartbeat` RPC | High — production DB |

---

## 9. Risk Assessment

| Risk | Mitigation |
|------|------------|
| Heartbeat RPC fails on first deploy (before migration runs) | Dual-write: if RPC fails, fall back to outlet update only. Log warning. |
| Existing sessions have old 12-char device IDs | `DeviceIdentityService` auto-upgrades on next boot — old ID replaced with UUID |
| Admin dashboard briefly shows stale data | Bridge write keeps outlet columns updated — no visible change |
| Two devices in same outlet: outlet heartbeat still only shows last writer | Acceptable for Phase 31 — Phase 32 fixes this with per-device dashboard |
| UUID collision | UUIDv4 has negligible collision probability (1 in 5.3×10^36) |
| App data cleared / reinstall | New UUID generated — treated as new device. Acceptable per CONTEXT.md |

---

## Validation Architecture

### Testing Approach
1. **Unit test:** `DeviceIdentityService.getOrCreateDeviceUuid()` — verify persistence, UUID format validation, auto-upgrade from old format
2. **Unit test:** Heartbeat RPC call construction — verify payload matches function signature
3. **Integration test:** Verify `clearKioskSession()` does NOT remove installation UUID
4. **SQL test:** Run migration on test branch, verify `upsert_kiosk_heartbeat` RPC works
5. **Manual test:** Login → heartbeat → logout → re-login → verify same UUID in both `kiosk_devices` rows

### Success Criteria from ROADMAP
1. ✅ App generates and persists UUIDv4 in SharedPreferences on first boot → `DeviceIdentityService`
2. ✅ HeartbeatService upserts to `kiosk_devices` instead of `outlets` → RPC call + bridge
3. ✅ RLS on `kiosk_devices` allows outlet upsert → SECURITY DEFINER function

---

## RESEARCH COMPLETE
