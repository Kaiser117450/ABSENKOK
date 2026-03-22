# Phase 32: Multi-Device Dashboard - Research

**Researched:** 2026-03-22
**Domain:** Flutter admin UI + Supabase RLS/RPC — multi-device health display, nickname assignment, archive/unlink
**Confidence:** HIGH (all findings grounded in existing codebase; no speculative library choices)

---

## Summary

Phase 31 established the `kiosk_devices` table and the `upsert_kiosk_heartbeat` SECURITY DEFINER RPC. HeartbeatService currently dual-writes: RPC primary (kiosk_devices) + bridge to `outlets` for backward compat. Phase 32 is the payoff: migrate the admin dashboard's "Status Kiosk" section to read from `kiosk_devices` instead of `outlets`, then add nickname and archive management.

The current dashboard renders one `KioskHealthCard` per outlet. After this phase it renders one card per kiosk device, grouped under its outlet. A device can have a nickname, and admins can archive retired devices (set `is_active = false`) so they vanish from the live list. Once the admin dashboard migrates away from the `outlets` heartbeat bridge, the bridge write in HeartbeatService can be removed.

The race condition described in success criterion 4 is already architecturally solved by Phase 31 (each physical device has a unique UUID primary key in `kiosk_devices`; two devices on the same outlet produce two distinct rows instead of clobbering each other). Phase 32 only needs to surface that correctly in the UI and remove the single-device assumption in `KioskHealthCard`.

**Primary recommendation:** Create a `KioskDevice` model mirroring `kiosk_devices` columns, write two new SECURITY DEFINER RPCs (`set_device_nickname`, `archive_device`), replace `KioskHealthCard(outlet:)` with `KioskDeviceCard(device:)`, and update dashboard data loading to query `kiosk_devices` grouped by outlet.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| HEALTH-03 | Admin Dashboard displays health status for all connected devices within an outlet. | `kiosk_devices` table already populated by HeartbeatService; dashboard just needs to query it instead of outlets. |
| HEALTH-04 | Admins can manually unlink/remove retired devices from the dashboard. | `kiosk_devices.is_active` boolean already in schema; needs an RPC + UI action. |
| HEALTH-05 | Admins can assign custom nicknames to devices (e.g., "Kiosk Pintu Depan"). | `kiosk_devices.nickname` TEXT column already in schema; needs an RPC + UI dialog. |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase_flutter | already in pubspec | Query kiosk_devices, call RPCs for nickname/archive | Project-wide Supabase client |
| flutter (Material) | already in pubspec | AlertDialog for nickname input, InkWell/GestureDetector for card actions | No new dependency needed |

### No New Dependencies
All required functionality is achievable with the existing stack. No new packages.

**Installation:**
```
No changes to pubspec.yaml required.
```

---

## Architecture Patterns

### New Model: `KioskDevice`

Create `lib/models/kiosk_device.dart` mirroring the `kiosk_devices` columns from Phase 31.

```dart
// lib/models/kiosk_device.dart
class KioskDevice {
  final String id;           // kiosk_devices.id (UUID PK)
  final String deviceUuid;   // kiosk_devices.device_uuid
  final String? outletId;
  final DateTime? lastHeartbeatAt;
  final int? batteryLevel;
  final bool? isCharging;
  final int? pendingSyncCount;
  final String? appVersion;
  final String? nickname;
  final bool isActive;

  // Derived: "online" = heartbeat within 30 minutes
  bool get isOnline =>
      lastHeartbeatAt != null &&
      DateTime.now().difference(lastHeartbeatAt!).inMinutes <= 30;

  factory KioskDevice.fromJson(Map<String, dynamic> json) { ... }
}
```

### Dashboard Data Loading

Replace `_loadOutlets()` outlet-heartbeat approach with a query to `kiosk_devices`:

```dart
// In admin_dashboard_screen.dart
Future<void> _loadKioskDevices() async {
  final data = await SupabaseClientFactory.admin
      .from('kiosk_devices')
      .select('*')
      .eq('is_active', true)
      .order('outlet_id')
      .order('created_at');

  setState(() {
    _kioskDevices = (data as List)
        .map((e) => KioskDevice.fromJson(e))
        .toList();
  });
}
```

The dashboard still needs `_loadOutlets()` for other sections (attendance logs, outlet selector). Only the "Status Kiosk" section switches data source.

### Grouping Devices Under Outlet

In `_buildKioskHealthSection()`, group `_kioskDevices` by `outletId`, then for the selected outlet filter render one `KioskDeviceCard` per device.

```dart
final devicesForOutlet = _kioskDevices
    .where((d) => _selectedOutletId == null || d.outletId == _selectedOutletId)
    .toList();
```

### New Widget: `KioskDeviceCard`

Replace `KioskHealthCard(outlet:)` with `KioskDeviceCard(device:, onNickname:, onArchive:)`.

- Display: nickname ?? deviceUuid (first 8 chars), online status dot, battery, pending sync badge
- Long-press or trailing menu icon → popup with "Beri Nama" (nickname) and "Arsipkan" (archive)
- Follows the same visual pattern as existing `KioskHealthCard`

### Nickname Dialog

Standard `showDialog(AlertDialog)` with a `TextField`. On confirm, call `set_device_nickname` RPC. Optimistic UI: update local state immediately, let RPC persist.

```dart
await Supabase.instance.client.rpc('set_device_nickname', params: {
  'p_device_id': device.id,
  'p_nickname': nicknameController.text.trim(),
});
```

### Archive Action

Confirm with a brief `showDialog` ("Hapus kiosk ini dari daftar?"). On confirm, call `archive_device` RPC, then remove from `_kioskDevices` list.

### New SQL RPCs

Two new SECURITY DEFINER functions needed (admin role writes to `kiosk_devices`):

```sql
-- set_device_nickname: admin-only write
CREATE OR REPLACE FUNCTION set_device_nickname(
  p_device_id UUID,
  p_nickname   TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE kiosk_devices
  SET nickname = p_nickname, updated_at = NOW()
  WHERE id = p_device_id;
END;
$$;

-- archive_device: sets is_active = false
CREATE OR REPLACE FUNCTION archive_device(
  p_device_id UUID
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE kiosk_devices
  SET is_active = false, updated_at = NOW()
  WHERE id = p_device_id;
END;
$$;
```

**Why SECURITY DEFINER:** `admin_read_kiosk_devices` policy only grants SELECT. UPDATE is not covered by existing RLS. Using SECURITY DEFINER RPCs matches the existing `upsert_kiosk_heartbeat` and `verify_kiosk_password` patterns.

**Alternative:** Add an explicit `UPDATE` RLS policy scoped to `get_app_role() = 'admin'`. Either approach works; SECURITY DEFINER RPCs are the established pattern in this codebase, so prefer that for consistency.

### Bridge Write Removal in HeartbeatService

After the admin dashboard reads from `kiosk_devices`, the bridge block in `HeartbeatService._sendWithRetry()` (lines 181-205) can be removed in this phase. This eliminates the dual-write overhead and the race condition (two devices clobbering the same `outlets` row). Leave a comment during the phase: remove bridge when Phase 32 dashboard migration lands.

### Recommended Project Structure (changes only)

```
lib/
├── models/
│   └── kiosk_device.dart         # NEW — mirrors kiosk_devices table
├── widgets/
│   └── kiosk_device_card.dart    # NEW — replaces KioskHealthCard for devices
├── screens/admin/
│   └── admin_dashboard_screen.dart  # MODIFIED — new data load + section
├── services/
│   └── heartbeat_service.dart    # MODIFIED — remove bridge write
sql/
└── phase_32_device_mgmt_YYYYMMDD.sql  # NEW — set_device_nickname + archive_device RPCs
```

### Anti-Patterns to Avoid

- **Do not remove `_loadOutlets()`**: Other dashboard sections (attendance logs, outlet selector header, report generation) still depend on the `_outlets` list. Only "Status Kiosk" migrates.
- **Do not add direct UPDATE calls from the Flutter client**: Existing RLS does not grant UPDATE to admins via the client. Use SECURITY DEFINER RPCs.
- **Do not re-use `KioskHealthCard` as-is**: It is bound to `Outlet` model. Create `KioskDeviceCard` bound to `KioskDevice` model.
- **Do not display raw UUIDs as device names**: Default label should be nickname ?? `"Kiosk ${deviceUuid.substring(0, 8)}"` so the UI is always readable.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Admin write protection | Custom client-side auth check before UPDATE | SECURITY DEFINER RPC (matches established pattern) |
| Real-time device refresh | Polling timer | Supabase realtime subscription on `kiosk_devices` (matches existing `_subscribeRealtime()` pattern in dashboard) |
| Nickname persistence | SharedPreferences on admin side | `kiosk_devices.nickname` column + RPC |

---

## Common Pitfalls

### Pitfall 1: Forgetting `is_active = true` filter on device query
**What goes wrong:** Archived devices reappear in the dashboard after a page refresh.
**How to avoid:** Always filter `kiosk_devices` with `.eq('is_active', true)` in the data load query.

### Pitfall 2: Race condition in nickname / archive if device heartbeats mid-action
**What goes wrong:** Heartbeat upsert overwrites `is_active = true` after an archive action if `upsert_kiosk_heartbeat` unconditionally sets is_active.
**How to avoid:** The current `upsert_kiosk_heartbeat` RPC does NOT update `is_active` — only `set` columns in the ON CONFLICT clause. Confirm `is_active` is not in the upsert's `DO UPDATE SET` list (it is not in the Phase 31 SQL). This is already safe.

### Pitfall 3: Displaying stale offline status if dashboard data is not refreshed after archive
**What goes wrong:** Archived device still shows offline in the UI momentarily.
**How to avoid:** Remove the device from `_kioskDevices` optimistically in `setState()` immediately on archive, before the RPC returns.

### Pitfall 4: Outlet selector shows "0 devices" for inactive outlets
**What goes wrong:** If all `kiosk_devices` for an outlet are archived, the outlet still shows in the outlet dropdown but the kiosk section is empty.
**How to avoid:** Keep the outlet selector driven by `_outlets` (from `outlets` table), not from `kiosk_devices`. The section header can say "Tidak ada kiosk aktif" if the device list is empty.

### Pitfall 5: Two devices sending heartbeats for same outlet — overwriting race
**What goes wrong:** This was the original motivation for Phase 31. It is already eliminated at the database level (unique `device_uuid` primary key, each upsert only touches its own row). Phase 32 only needs to ensure the UI does not re-collapse them into one card.
**How to avoid:** Map one `KioskDeviceCard` per `KioskDevice` row; never aggregate multiple devices into a single card.

---

## Code Examples

### Realtime Subscription on kiosk_devices

The existing dashboard already uses `_subscribeRealtime()` for attendance logs. Extend it:

```dart
// Source: existing _subscribeRealtime() pattern in admin_dashboard_screen.dart
_kioskDevicesChannel = SupabaseClientFactory.admin
    .channel('kiosk_devices_changes')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'kiosk_devices',
      callback: (payload) => _loadKioskDevices(),
    )
    .subscribe();
```

### Nickname Dialog Pattern

```dart
Future<void> _showNicknameDialog(KioskDevice device) async {
  final controller = TextEditingController(text: device.nickname ?? '');
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Beri Nama Kiosk'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: 'Kiosk Pintu Depan'),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
      ],
    ),
  );
  if (confirmed == true && controller.text.trim().isNotEmpty) {
    // Optimistic update
    setState(() {
      _kioskDevices = _kioskDevices.map((d) =>
        d.id == device.id ? d.copyWith(nickname: controller.text.trim()) : d
      ).toList();
    });
    await Supabase.instance.client.rpc('set_device_nickname', params: {
      'p_device_id': device.id,
      'p_nickname': controller.text.trim(),
    });
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | Phase |
|--------------|------------------|-------|
| `KioskHealthCard` reads from `Outlet` model (outlets table) | `KioskDeviceCard` reads from `KioskDevice` model (kiosk_devices table) | Phase 32 |
| HeartbeatService dual-writes to outlets bridge | HeartbeatService writes only to kiosk_devices | Phase 32 |
| One card per outlet | One card per physical device, grouped under outlet | Phase 32 |

---

## Open Questions

1. **Should nickname update be in a bottom sheet or AlertDialog?**
   - What we know: All existing dialogs in this codebase use `AlertDialog`.
   - Recommendation: Use `AlertDialog` for consistency; no bottom sheet pattern established yet.

2. **Should archive require a confirmation dialog?**
   - What we know: This is a destructive action (device stops appearing in admin dashboard).
   - Recommendation: Yes — a brief `AlertDialog` with "Arsipkan" confirm button. Archived devices can be restored by setting `is_active = true` via direct Supabase dashboard if needed (no need to build a restore UI in Phase 32).

3. **Should the Phase 32 migration SQL also add an RLS UPDATE policy for admins, or rely solely on SECURITY DEFINER RPCs?**
   - Recommendation: SECURITY DEFINER RPCs only — matches established project pattern, keeps RLS simple.

---

## Validation Architecture

Test framework: flutter_test (already in project). No new framework needed.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Notes |
|--------|----------|-----------|-------|
| HEALTH-03 | `KioskDevice.isOnline` returns true when heartbeat within 30 min | unit | `test/models/kiosk_device_test.dart` |
| HEALTH-03 | `KioskDevice.isOnline` returns false when heartbeat > 30 min ago | unit | same file |
| HEALTH-04 | Archive RPC call removes device from UI list (optimistic) | widget | can test state mutation in isolation |
| HEALTH-05 | Nickname stored in `KioskDevice.nickname` and displayed in card | widget | verify card shows nickname over raw UUID |

### Wave 0 Gaps
- [ ] `test/models/kiosk_device_test.dart` — covers HEALTH-03 isOnline logic
- [ ] `test/widgets/kiosk_device_card_test.dart` — covers HEALTH-04, HEALTH-05 display

---

## Sources

### Primary (HIGH confidence)
- `sql/phase_31_kiosk_devices_20260320.sql` — exact schema for `kiosk_devices` table and `upsert_kiosk_heartbeat` RPC
- `lib/services/heartbeat_service.dart` — dual-write implementation and bridge write location
- `lib/screens/admin/admin_dashboard_screen.dart` — existing `_buildKioskHealthSection()` and data loading patterns
- `lib/widgets/kiosk_health_card.dart` — widget to replace
- `lib/models/outlet.dart` — heartbeat fields to migrate away from
- `.planning/STATE.md` — key decisions 31-01, 31-02, confirmed dual-write intent

### Secondary (MEDIUM confidence)
- Supabase RLS + SECURITY DEFINER pattern established by `verify_kiosk_password` (referenced in STATE.md multiple times)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; everything reuses existing patterns
- Architecture: HIGH — schema and code both present; migration path is clear
- Pitfalls: HIGH — derived from actual code inspection, not speculation

**Research date:** 2026-03-22
**Valid until:** 2026-04-22 (stable Flutter/Supabase stack; schema is fixed by Phase 31)
