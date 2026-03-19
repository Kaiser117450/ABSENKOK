# Phase 27: Foundation & Kiosk Heartbeat - Research

**Researched:** 2026-03-20
**Domain:** Flutter background service scheduling, battery APIs, Supabase update, app version reading
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Send the first heartbeat immediately when the kiosk enters its idle session through `KioskBackgroundService.start(session)`.
- After the first send, use a rolling 15-minute cadence instead of aligning to wall-clock quarter hours.
- If the process or service restarts unexpectedly, send a fresh heartbeat immediately on restart.
- When kiosk session is cleared or logout happens, do not clear heartbeat fields; let the last heartbeat age out naturally for later offline detection.
- If a scheduled heartbeat happens while offline, retry immediately when connectivity returns during the same kiosk session.
- If Supabase is reachable but the heartbeat write fails, do up to 2 quick retries in that cycle, then wait for the next scheduled heartbeat.
- After a long outage ends, send one fresh snapshot only; do not replay missed heartbeat intervals.
- Heartbeat recovery must stay independent from attendance sync.
- `pending_sync_count` counts SQLite rows where `sync_status` is `pending` or `failed`.
- Sample `pending_sync_count` at the exact moment the heartbeat is sent.
- Store `app_version` in `version+build` format, e.g. `3.1.2+8009`.
- If battery status cannot be read, still send the heartbeat with battery fields null (not fake `0%`, not skipped).

### Claude's Discretion
- Exact implementation for reconnect detection and scheduling hooks inside the existing foreground/background service structure.
- Exact retry backoff spacing for the 2 quick write retries.
- Exact package and adapter choices for reading app version and battery state, as long as the stored payload matches the decisions above.

### Deferred Ideas (OUT OF SCOPE)
- Heartbeat history or audit-trail storage beyond the latest `outlets` snapshot.
- Immediate admin/dashboard surfacing of offline or low-battery status (belongs to Phase 30).
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| HLTH-01 | Kiosk tablet sends background heartbeat to Supabase every 15 minutes | Rolling `Timer.periodic` in main isolate within `KioskBackgroundService`; connectivity-gated update to `outlets` |
| HLTH-02 | Heartbeat payload includes `battery_level` (%), `is_charging` (boolean), and `app_version` (string) | `battery_plus` ^6.2.3 for battery, `package_info_plus` for version string |
| SYNC-01 | System counts pending offline scans in local SQLite | `SqliteService.countPendingLogs()` already exists and counts `pending` + `failed` rows |
| SYNC-02 | Pending sync count sent as part of 15-minute heartbeat payload (`pending_sync_count`) | Sampled at send time, included in the same Supabase update payload |
</phase_requirements>

---

## Summary

Phase 27 has three moving parts: a Supabase schema migration (additive columns on `outlets`), two new Flutter package integrations (`battery_plus` + `package_info_plus`), and a heartbeat scheduler wired into the existing `KioskBackgroundService`.

The schema work is straightforward — five nullable columns added to the live `outlets` table via `ALTER TABLE ADD COLUMN IF NOT EXISTS`. No row data is touched, no RLS changes are required unless the kiosk role currently lacks UPDATE on `outlets`. The existing `Outlet` model and its `fromJson`/`toJson` methods must be expanded to include the five new nullable fields.

The Flutter-side work lives in a new `HeartbeatService` class called from `KioskBackgroundService.start()` and `stop()`. A `Timer.periodic` fires the 15-minute cadence, and a `connectivity_plus` stream subscription triggers a retry on reconnect. Battery is read via `battery_plus` 6.x (NOT 7.x — that requires Kotlin 2.2.0 which breaks `nfc_manager`). App version is read once via `package_info_plus` and cached. The existing `_KioskTaskHandler.onRepeatEvent` remains a no-op; all heartbeat logic stays in the main isolate to have direct access to Supabase and SQLite.

**Primary recommendation:** Add `battery_plus: ^6.2.3` and `package_info_plus: ^8.1.0`. Keep all heartbeat logic in the main isolate. Use `Supabase.from('outlets').update().eq('id', outletId)` or a dedicated RPC depending on RLS posture.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| battery_plus | ^6.2.3 | Read battery level (int 0-100) and charging state (BatteryState enum) | Official Flutter Community Plus plugin; Flutter Favorite. **6.x is the latest series compatible with Kotlin 1.9.x** |
| package_info_plus | ^8.1.0 | Read `version` and `buildNumber` from pubspec at runtime | Official Plus plugin; single async call, Android-native cache, no Kotlin 2.x requirement |
| connectivity_plus | already in pubspec ^6.1.4 | Detect reconnect to trigger retry | Already a dependency; `Connectivity().onConnectivityChanged` stream used by SyncService |
| supabase_flutter | already in pubspec ^2.8.4 | `.update()` on `outlets` table | Existing pattern used across all services |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_foreground_task | already ^8.14.0 | Android foreground service wake lock | Already running; heartbeat piggybacks on this keep-alive without changes |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| battery_plus ^6.2.3 | battery_plus ^7.0.0 | 7.x requires Kotlin 2.2.0 — breaks nfc_manager (project locked to 1.9.25). Must use 6.x. |
| package_info_plus | Hardcoded version constant | Would go stale on every release; package reads live pubspec version at runtime |
| Timer.periodic in main isolate | WorkManager / AlarmManager via platform channel | Overkill while foreground service keeps the process alive; Timer is sufficient |
| Direct outlets UPDATE | Dedicated `kiosk_heartbeat` RPC | RPC is safer if kiosk role lacks UPDATE on outlets; REST update is simpler if RLS allows it |

**Installation (add to pubspec.yaml dependencies):**
```yaml
battery_plus: ^6.2.3
package_info_plus: ^8.1.0
```

**Version verification (confirmed against pub.dev 2026-03-20):**
- `battery_plus` 6.2.3: published ~7 months ago, requires AGP >=8.3.0 only (no Kotlin 2.x)
- `battery_plus` 7.0.0: Kotlin 2.2.0 REQUIRED — do not use
- `package_info_plus` 8.1.0: stable, no Kotlin 2.x requirement confirmed

---

## Architecture Patterns

### Recommended File Changes
```
lib/
├── models/outlet.dart                        # Add 5 new nullable fields + fromJson/toJson
├── services/heartbeat_service.dart           # NEW: owns Timer, retry, payload assembly
├── services/kiosk_background_service.dart    # Wire HeartbeatService.start/stop
sql/
└── phase_27_heartbeat_columns_20260320.sql   # ALTER TABLE outlets ADD COLUMN IF NOT EXISTS ...
```

### Pattern 1: Rolling Timer with Immediate First Fire
**What:** Fire once on start, then schedule repeating 15-minute timer.
**When to use:** Whenever the first data point must be captured immediately on session start.

```dart
// Source: CONTEXT.md decisions + Dart Timer API
static Future<void> start(KioskSession session) async {
  _session = session;
  await _sendHeartbeat();           // immediate first heartbeat
  _timer?.cancel();
  _timer = Timer.periodic(const Duration(minutes: 15), (_) async {
    await _sendHeartbeat();
  });
  _connectivitySub?.cancel();
  _connectivitySub = Connectivity()
      .onConnectivityChanged
      .listen((results) async {
    if (!results.contains(ConnectivityResult.none) && results.isNotEmpty) {
      // Debounce: skip if last heartbeat was within 30 seconds
      final now = DateTime.now();
      if (_lastSentAt == null ||
          now.difference(_lastSentAt!).inSeconds > 30) {
        await _sendHeartbeat();
      }
    }
  });
}
```

### Pattern 2: Battery Reading with Graceful Null Fallback
**What:** Attempt battery read; on any error return null fields without aborting the heartbeat.
**When to use:** All sensor reads in background tasks.

```dart
// Source: battery_plus README + CONTEXT.md decision
static Future<({int? level, bool? isCharging})> _readBattery() async {
  try {
    final battery = Battery();
    final level = await battery.batteryLevel;         // int 0-100
    final state = await battery.batteryState;
    final charging = state == BatteryState.charging ||
                     state == BatteryState.full;
    return (level: level, isCharging: charging);
  } catch (e) {
    debugPrint('[Heartbeat] battery read failed: $e');
    return (level: null, isCharging: null);
  }
}
```

### Pattern 3: App Version String Cached from package_info_plus
**What:** Read version once, cache as static string, reuse on every heartbeat cycle.
**When to use:** Any service that needs the pubspec version at runtime.

```dart
// Source: package_info_plus README
static String? _cachedVersion;

static Future<String> _getAppVersion() async {
  if (_cachedVersion != null) return _cachedVersion!;
  try {
    final info = await PackageInfo.fromPlatform();
    _cachedVersion = '${info.version}+${info.buildNumber}';
  } catch (e) {
    debugPrint('[Heartbeat] package info read failed: $e');
    _cachedVersion = 'unknown';
  }
  return _cachedVersion!;
}
```

### Pattern 4: Supabase Update for Heartbeat
**What:** Update known existing outlet row with new metric snapshot.
**When to use:** Updating a known existing row (outlet record already exists).

```dart
// Source: existing badge_service.dart pattern in codebase
await SupabaseClientFactory.kiosk
    .from('outlets')
    .update({
      'last_heartbeat_at': DateTime.now().toIso8601String(),
      'battery_level': batteryData.level,
      'is_charging': batteryData.isCharging,
      'pending_sync_count': pendingCount,
      'app_version': appVersion,
    })
    .eq('id', session.outletId);
```

### Pattern 5: Quick Retry on Write Failure (2 retries)
**What:** On Supabase write failure, retry twice with short backoff; then give up for the current cycle.

```dart
// Recommended backoff: 2s then 4s (simple linear, per Claude's Discretion)
static Future<void> _sendWithRetry(
    Map<String, dynamic> payload, String outletId) async {
  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      await SupabaseClientFactory.kiosk
          .from('outlets')
          .update(payload)
          .eq('id', outletId);
      return; // success
    } catch (e) {
      if (attempt == 2) {
        debugPrint('[Heartbeat] all retries exhausted: $e');
        return;
      }
      await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
    }
  }
}
```

### Anti-Patterns to Avoid
- **Using `battery_plus` ^7.x:** Requires Kotlin 2.2.0 — breaks `nfc_manager`. Pin to ^6.2.3.
- **Heartbeat inside `_KioskTaskHandler.onRepeatEvent`:** That callback runs in a separate isolate without initialized Supabase/SQLite. Keep heartbeat in the main isolate.
- **Replaying missed intervals after reconnect:** CONTEXT.md explicitly requires one fresh snapshot only.
- **Sending `battery_level: 0` when read fails:** `0` is indistinguishable from a dead battery. Use `null`.
- **Clearing heartbeat fields on logout:** CONTEXT.md says let them age out naturally.
- **Awaiting heartbeat from NFC scan path:** All heartbeat work is async and must not block the NFC scan callback.
- **NOT NULL columns in migration:** All five new columns must be nullable or have a DEFAULT — existing rows have no heartbeat data yet.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Battery level reading | Custom MethodChannel to Android BatteryManager | `battery_plus` | Handles all states (charging/full/discharging/unknown/connectedNotCharging), works across OEMs |
| App version reading | Hardcoded constant in Dart | `package_info_plus` | Reads live pubspec.yaml version; survives version bumps without code change |
| Network detection | Manual HTTP ping loop | `connectivity_plus` stream | Already a dependency; stream fires on state change, no polling overhead |

---

## Common Pitfalls

### Pitfall 1: battery_plus Version Constraint
**What goes wrong:** Pulling `battery_plus: ^7.0.0` introduces Kotlin 2.2.0 requirement, which breaks `nfc_manager`.
**Why it happens:** `battery_plus` 7.0.0 bumped Kotlin to 2.2.0 as a hard requirement per its changelog.
**How to avoid:** Pin to `^6.2.3` explicitly in pubspec.yaml.
**Warning signs:** Build error mentioning Kotlin version mismatch during `flutter build apk`.

### Pitfall 2: Heartbeat Timer Surviving Stop
**What goes wrong:** Orphan `_timer` fires after session ends, writing stale `outletId` to Supabase.
**Why it happens:** `stop()` is not symmetric with `start()`.
**How to avoid:** `HeartbeatService.stop()` must cancel both `_timer` and `_connectivitySub`. Call it in `KioskBackgroundService.stop()`.

### Pitfall 3: connectivity_plus Double-Fire on Reconnect
**What goes wrong:** `onConnectivityChanged` fires multiple rapid events on reconnect (per network interface), causing duplicate heartbeats.
**Why it happens:** The stream reflects each network interface change separately.
**How to avoid:** Track `_lastSentAt` timestamp; skip if last heartbeat was less than 30 seconds ago.

### Pitfall 4: `supabaseReady` Guard
**What goes wrong:** Heartbeat fires during startup before Supabase is initialized, throwing `StateError`.
**Why it happens:** `KioskBackgroundService.start()` can be called from `initState` before async init completes.
**How to avoid:** Check `if (!supabaseReady) return;` at the top of `_sendHeartbeat` — same guard used elsewhere in the codebase.

### Pitfall 5: NOT NULL Columns in Production Migration
**What goes wrong:** `ALTER TABLE outlets ADD COLUMN pending_sync_count INTEGER NOT NULL` fails on PostgreSQL when existing rows have no value.
**Why it happens:** PostgreSQL rejects NOT NULL without a DEFAULT for existing rows.
**How to avoid:** All five columns must be nullable (omit NOT NULL and DEFAULT). `last_heartbeat_at TIMESTAMPTZ`, `battery_level SMALLINT`, `is_charging BOOLEAN`, `pending_sync_count INTEGER`, `app_version TEXT` — all nullable.

### Pitfall 6: PackageInfo in Background Isolates
**What goes wrong:** `PackageInfo.fromPlatform()` may fail when called from a background isolate.
**Why it happens:** Plugin platform channels require a Flutter engine binding not available in raw isolates.
**How to avoid:** Call `PackageInfo.fromPlatform()` in the main isolate once, cache the result as a static field in `HeartbeatService`. Pass the cached string into the heartbeat payload.

### Pitfall 7: RLS Blocks Kiosk UPDATE on outlets
**What goes wrong:** `HeartbeatService` silently fails on every heartbeat with a Supabase 403 (RLS violation).
**Why it happens:** The `kiosk` Supabase role may have only SELECT on `outlets` and INSERT on `attendance_logs`.
**How to avoid:** Check existing RLS before writing migration. If kiosk role lacks UPDATE, add a targeted policy: `USING (device_id = current_setting('request.jwt.claims', true)::json->>'device_id')`. Alternatively use a Supabase Edge Function for the heartbeat write (never embed service_role key in APK).

---

## Code Examples

### SQL Migration
```sql
-- File: sql/phase_27_heartbeat_columns_20260320.sql
-- Safe: additive nullable columns only, no existing data touched

ALTER TABLE outlets ADD COLUMN IF NOT EXISTS last_heartbeat_at  TIMESTAMPTZ;
ALTER TABLE outlets ADD COLUMN IF NOT EXISTS battery_level      SMALLINT;
ALTER TABLE outlets ADD COLUMN IF NOT EXISTS is_charging        BOOLEAN;
ALTER TABLE outlets ADD COLUMN IF NOT EXISTS pending_sync_count INTEGER;
ALTER TABLE outlets ADD COLUMN IF NOT EXISTS app_version        TEXT;
```

### Outlet Model Expansion
```dart
// lib/models/outlet.dart additions
final DateTime? lastHeartbeatAt;
final int? batteryLevel;
final bool? isCharging;
final int? pendingSyncCount;
final String? appVersion;

// In Outlet.fromJson:
lastHeartbeatAt: json['last_heartbeat_at'] != null
    ? DateTime.parse(json['last_heartbeat_at'] as String)
    : null,
batteryLevel: json['battery_level'] as int?,
isCharging: json['is_charging'] as bool?,
pendingSyncCount: json['pending_sync_count'] as int?,
appVersion: json['app_version'] as String?,

// In toJson:
'last_heartbeat_at': lastHeartbeatAt?.toIso8601String(),
'battery_level': batteryLevel,
'is_charging': isCharging,
'pending_sync_count': pendingSyncCount,
'app_version': appVersion,
```

### Wiring into KioskBackgroundService
```dart
// In KioskBackgroundService.start() after existing setup:
await HeartbeatService.start(session);

// In KioskBackgroundService.stop():
HeartbeatService.stop();
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| battery_plus 5.x: only `charging`/`discharging`/`full` states | battery_plus 6.x: adds `connectedNotCharging` state | 6.0.0 | Check for `charging || full` for `is_charging: true`; `connectedNotCharging` means plugged in but not actually charging (some OEM behavior) |
| `battery_plus` 7.x mandates Kotlin 2.2.0 | Use 6.2.3 (last Kotlin 1.x compatible) | 7.0.0 | Version pin is mandatory for this project |

**Deprecated/outdated:**
- `battery` (non-plus): The original battery plugin — unmaintained, do not use.

---

## Open Questions

1. **RLS policy on `outlets` for kiosk UPDATE writes**
   - What we know: Kiosk client uses anon key with RLS. Existing RLS policies permit SELECT on `outlets` and INSERT on `attendance_logs`.
   - What's unclear: Whether kiosk role has UPDATE permission on `outlets`.
   - Recommendation: Early in Wave 1, executor runs `SELECT policyname, cmd FROM pg_policies WHERE tablename = 'outlets';` and adds an UPDATE policy if missing. If adding RLS feels risky, wrap in a `kiosk_heartbeat` RPC instead — the RPC runs under `SECURITY DEFINER` and can UPDATE internally.

2. **`SupabaseClientFactory.kiosk` vs Edge Function**
   - What we know: `service_role` key must never be in the APK (project rule). Kiosk client uses anon key.
   - What's unclear: If RLS-based UPDATE is blocked, an Edge Function is the safe alternative.
   - Recommendation: Try direct UPDATE with kiosk client first (simpler). Fall back to Edge Function only if RLS is not viable.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK built-in, already in dev_dependencies) |
| Config file | none — standard `flutter test` invocation |
| Quick run command | `flutter test test/services/heartbeat_service_test.dart` |
| Full suite command | `flutter test test/` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HLTH-01 | HeartbeatService.start() fires immediately then schedules 15-min timer | unit | `flutter test test/services/heartbeat_service_test.dart` | No — Wave 0 |
| HLTH-02 | Payload includes battery_level, is_charging, app_version with null fallback | unit | `flutter test test/services/heartbeat_service_test.dart` | No — Wave 0 |
| SYNC-01 | SqliteService.countPendingLogs() counts pending+failed rows only | unit | `flutter test test/services/sqlite_service_test.dart` | No — Wave 0 |
| SYNC-02 | pending_sync_count sampled at send time and included in payload | unit | `flutter test test/services/heartbeat_service_test.dart` | No — Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/services/heartbeat_service_test.dart`
- **Per wave merge:** `flutter test test/`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/services/heartbeat_service_test.dart` — covers HLTH-01, HLTH-02, SYNC-02
- [ ] `test/services/sqlite_service_test.dart` — covers SYNC-01 (`countPendingLogs` returns pending+failed count)
- [ ] `test/models/outlet_test.dart` — covers `Outlet.fromJson` with all five new heartbeat fields (null and non-null)

*(Note: `flutter_test` is already a dev_dependency in pubspec.yaml — no framework install needed.)*

---

## Sources

### Primary (HIGH confidence)
- [battery_plus pub.dev](https://pub.dev/packages/battery_plus) — confirmed version 7.0.0 requires Kotlin 2.2.0
- [battery_plus 6.2.3 pub.dev](https://pub.dev/packages/battery_plus/versions/6.2.3) — confirmed AGP >=8.3.0 only, no Kotlin 2.x requirement
- [battery_plus changelog pub.dev](https://pub.dev/packages/battery_plus/changelog) — Kotlin 2.x first appeared in 7.0.0
- [package_info_plus pub.dev](https://pub.dev/packages/package_info_plus) — version 9.0.0 current, API confirmed
- Codebase: `lib/services/kiosk_background_service.dart` — foreground service structure
- Codebase: `lib/services/sqlite_service.dart` — `countPendingLogs()` at line 158
- Codebase: `lib/services/sync_service.dart` — `connectivity_plus` usage pattern
- Codebase: `lib/models/outlet.dart` — current model structure to extend
- Codebase: `pubspec.yaml` — version `3.1.2+8009`, existing dependencies

### Secondary (MEDIUM confidence)
- [battery_plus README GitHub](https://github.com/fluttercommunity/plus_plugins/blob/main/packages/battery_plus/battery_plus/README.md) — BatteryState enum values including `connectedNotCharging`

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pub.dev versions confirmed, Kotlin constraint verified from official changelog
- Architecture: HIGH — based on direct reading of existing service files; Timer-in-main-isolate pattern is the only viable approach given isolate plugin limitations
- Pitfalls: HIGH — Kotlin constraint is a hard fact; others derived from direct codebase analysis
- SQL migration: HIGH — additive nullable columns is standard PostgreSQL, no data risk

**Research date:** 2026-03-20
**Valid until:** 2026-06-20 (stable ecosystem; re-check if Kotlin constraint is ever relaxed)
