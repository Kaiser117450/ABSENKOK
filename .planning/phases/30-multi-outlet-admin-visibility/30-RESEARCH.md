# Phase 30: Multi-Outlet Admin Visibility — Research

**Researched:** 2026-03-20
**Phase Goal:** Expose health metrics and sync warnings on the Admin Dashboard
**Requirements:** HLTH-03, HLTH-04, SYNC-03

## Executive Summary

Phase 30 adds three visibility features to the existing admin dashboard: offline kiosk warnings (>30 min no heartbeat), low battery warnings (<20%), and pending sync counts per outlet. All data already exists in the `outlets` table heartbeat columns (Phase 27). No new SQL RPCs are needed — the existing `_loadOutlets()` already fetches `SELECT *` which includes heartbeat fields. The Outlet model already parses all heartbeat fields. The work is purely **UI presentation + conditional logic** on the admin dashboard.

## Critical Dependency: Phase 27 Migration

⚠ **BLOCKER**: The heartbeat columns (`last_heartbeat_at`, `battery_level`, `is_charging`, `pending_sync_count`, `app_version`) have NOT been applied to the production Supabase database. The migration SQL exists at `sql/phase_27_heartbeat_columns_20260320.sql` but was never run via `apply_migration`.

**Resolution:** Phase 30 Plan must include applying this migration FIRST, before any UI work. All 5 columns are nullable with no DEFAULT — safe for production (existing rows unaffected).

## Validation Architecture

### Dimension 1: Functional Correctness
- Offline warning appears when `DateTime.now().difference(outlet.lastHeartbeatAt) > 30 minutes` OR `lastHeartbeatAt == null`
- Battery warning appears when `outlet.batteryLevel != null && outlet.batteryLevel! < 20`
- Sync count shows when `outlet.pendingSyncCount != null && outlet.pendingSyncCount! > 0`

### Dimension 2: Edge Cases
- `lastHeartbeatAt` is null (kiosk never sent heartbeat) → treat as "Offline" / "Belum Terhubung"
- `batteryLevel` is null → don't show battery warning (kiosk hasn't reported yet)
- `pendingSyncCount` is null or 0 → don't show sync warning
- All 4 outlets offline simultaneously → all should show warnings
- `isCharging` is true but battery < 20% → still show warning (charging but still low)

### Dimension 3: Integration
- `_loadOutlets()` in admin_dashboard_screen.dart already fetches `SELECT *` from outlets; heartbeat fields already parsed by `Outlet.fromJson()`
- Realtime channel `dashboard:employees` reloads outlets periodically
- No new API calls needed — existing data flow is sufficient

### Dimension 4: Performance
- No additional DB queries — heartbeat data piggybacks on existing outlet fetch
- DateTime.now() comparison is O(1) per outlet
- At most 4-8 outlets — no pagination needed

## Existing Code Analysis

### 1. Admin Dashboard (`admin_dashboard_screen.dart` — 1912 lines)
- **`_loadOutlets()`** (line 69-95): Fetches `SELECT *` from `outlets` where `is_active = true`, returns `List<Outlet>`. Already includes heartbeat fields.
- **`_buildOutletFilter()`**: Renders outlet names as filter chips. This is the natural place to inject health indicators.
- **`_buildStatGrid()`** (line 607): 2×2 stat cards for Masuk/Istirahat/Pulang/Backup. Could add a health summary row below.
- **`_buildQuickActions()`** (line 695): Horizontal scrolling action buttons. Already has "Belum Pulang" with badge count — pattern to follow.

### 2. Outlet Model (`models/outlet.dart` — 68 lines)
- All heartbeat fields already exist: `lastHeartbeatAt`, `batteryLevel`, `isCharging`, `pendingSyncCount`, `appVersion`
- `fromJson()` already parses all fields correctly
- No model changes needed

### 3. HeartbeatService (`services/heartbeat_service.dart` — 164 lines)
- Sends heartbeat every 15 min with battery, charging status, pending sync count, app version
- Updates `outlets` table directly via `.update()` on `outlet.id`
- Retry with 3 attempts + exponential backoff

### 4. Admin Outlets Screen (`admin_outlets_screen.dart` — 1051 lines)
- Shows outlet cards with name, address, device status, active toggle
- Currently does NOT show any heartbeat data
- Could be enhanced to show health status, but Phase 30 scope is **dashboard**, not outlet management screen

### 5. Theme (`core/theme.dart`)
- Key colors for status indicators:
  - `AppColors.danger` (#DC2626) — for offline/critical warnings
  - `AppColors.warning` (#F59E0B) — for low battery / sync pending  
  - `AppColors.success` (#16A34A) — for online/healthy
  - `AppColors.textMuted` (#9CA3AF) — for unknown/no data states

### 6. Chart Dashboard (`chart_dashboard_screen.dart`)
- Analytics dashboard with attendance rate, donut chart, weekly trend, overtime, leaderboard
- Uses `AppCard` widget extensively
- Pattern: section header (12px, w700, textSecondary) → content

## Recommended Approach

### Option A: Add health section to main dashboard (RECOMMENDED)
Add a "Status Kiosk" section between the stat grid and the outlet filter on `admin_dashboard_screen.dart`. This shows a card per outlet with:
- Online/Offline status badge (based on heartbeat age)
- Battery level bar with warning icon if < 20%
- Pending sync count badge

**Pros:** Highly visible, naturally fits dashboard flow, no new screen needed
**Cons:** Dashboard is already 1912 lines — adding more UI increases file size

### Option B: Add health status to outlet filter chips
Enhance existing outlet filter chips with small status dots (green/red/amber).

**Pros:** Minimal change, integrates into existing UI
**Cons:** Too subtle, chips are small — hard to show all three metrics

### Recommended: **Option A** — Dedicated "Status Kiosk" section card

## Implementation Pattern

The section should follow the existing dashboard card pattern:
```dart
Widget _buildKioskHealthSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Section header matching existing pattern
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text('Status Kiosk', style: TextStyle(...)),
      ),
      // One card per outlet
      ..._outlets.map((outlet) => _KioskHealthCard(outlet: outlet)),
    ],
  );
}
```

Each card shows:
1. **Outlet name** + **status badge** (Online/Offline/Belum Terhubung)
2. **Battery indicator** (icon + level %) — warning color if < 20%
3. **Pending sync badge** — count with amber background if > 0
4. **Last seen** — relative time ("5 menit lalu", "2 jam lalu", ">30 mnt — Offline!")

## No New Dependencies

- No new packages needed
- No new SQL RPCs needed
- No new Supabase Edge Functions needed
- No new models needed (Outlet already has all fields)

## Files to Modify

1. **`sql/phase_27_heartbeat_columns_20260320.sql`** → Apply migration to production via `apply_migration`
2. **`lib/screens/admin/admin_dashboard_screen.dart`** → Add kiosk health section + outlet health helper methods
3. _(Optional)_ Extract `_KioskHealthCard` as reusable widget to `lib/widgets/kiosk_health_card.dart` if it exceeds ~100 lines

## RESEARCH COMPLETE
