# Phase 33: Multi-Outlet Control Center - Research

**Researched:** 2026-03-22
**Domain:** Flutter admin analytics + Supabase RPC aggregation + role-aware dashboard routing
**Confidence:** HIGH (grounded in current code, SQL migrations, prior phase outputs, and existing test patterns)

---

## Summary

Phase 32 solved per-device health inside one outlet, but the app still lacks a real chain-wide control center for full admins:

- `AdminDashboardScreen` can show all logs/devices when no outlet is selected, but it does not compute central KPIs or outlet rollup cards.
- `ChartDashboardScreen` is strictly single-outlet because it requires `outletId` and `AnalyticsService` only exposes per-outlet methods.
- Existing SQL already provides `get_outlet_comparison()` and `kiosk_devices`, so the missing work is not a new stack, but a new aggregation layer plus an admin-only entry view.

**Primary recommendation:** keep `AdminDashboardScreen` as the outlet-operations/detail dashboard (and the default surface for `kepala_gerai`), add a new admin-only `CentralDashboardScreen` as the primary `/admin/dashboard` view, and let that central screen drill into an outlet-scoped detail route that reuses the existing outlet dashboard patterns.

This approach satisfies the roadmap without collapsing two different jobs into one screen:

- `CentralDashboardScreen`: firm-wide overview for `admin`
- `AdminDashboardScreen`: outlet-specific operational health/detail
- `ChartDashboardScreen`: deeper outlet analytics once an outlet is chosen

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ADMIN-01 | Admin Central Dashboard aggregates and displays health/status for ALL outlets in one view. | `kiosk_devices` already stores per-device heartbeat state; a rollup RPC can aggregate outlet/device health for one central screen. |
| ADMIN-02 | Admin Central Dashboard displays aggregate firm-wide daily attendance rate. | Existing attendance RPC logic already computes per-outlet rates; Phase 33 needs a chain-wide daily variant and central presentation. |
</phase_requirements>

---

## Current State Analysis

### 1. Current admin entry flow is not central-dashboard aware yet

From `lib/app.dart`:

- both `admin` and `kepala_gerai` currently redirect to `/admin/dashboard`
- `/admin/dashboard` always builds `AdminDashboardScreen()`
- `/admin/chart-dashboard` requires `outletId` and is not shell-scoped

This means Phase 33 should introduce role-aware routing rather than forcing `kepala_gerai` through a central-admin screen they should not see.

### 2. `AdminDashboardScreen` is already the outlet-detail surface

From `lib/screens/admin/admin_dashboard_screen.dart`:

- `_selectedOutletId` already scopes logs, open shifts, and device cards
- `kepala_gerai` is locked to `managedOutletId`
- the screen already loads operational details: logs, open shifts, device cards, employee counts
- the "Lihat Dashboard" button pushes `/admin/chart-dashboard?outletId=$outletId`

This is strong evidence that the existing dashboard should remain the outlet drilldown destination, not be replaced wholesale.

### 3. Current central analytics primitives are partial

Existing SQL in `sql/phase23_rpc_functions.sql`:

- `get_attendance_rates(outlet_id, start, end)` returns one outlet's attendance rate
- `get_weekly_trend(outlet_id, days)` returns one outlet's trend
- `get_outlet_comparison(start, end)` returns per-outlet attendance rates across active outlets

What is still missing for Phase 33:

- one chain-wide summary payload for central KPIs
- one outlet health rollup payload combining `kiosk_devices` + attendance into drilldown cards
- role-safe routing so only full admins see the central surface

### 4. Device health data is ready for aggregation

From `sql/phase_31_kiosk_devices_20260320.sql` and Phase 32 outputs:

- `kiosk_devices` holds one row per physical device
- `is_active` already supports archive/retire behavior
- `nickname`, `battery_level`, `is_charging`, `pending_sync_count`, `last_heartbeat_at`, `outlet_id` are all present
- `AdminDashboardScreen` already queries `kiosk_devices` and renders one `KioskDeviceCard` per device

So ADMIN-01 does **not** require a new device schema. It needs rollups and a better top-level view.

### 5. Existing project memory sets a hard constraint

From `.planning/STATE.md`:

> All dashboard aggregations must use Supabase RPC (server-side), not fetch-all-in-Dart

That rules out any plan that loads all attendance rows/device rows into Flutter and aggregates there for the central screen.

---

## Recommended Architecture

### Recommendation: separate central view from outlet detail view

**Do this:**

1. Add `CentralDashboardScreen` for full admins only.
2. Keep `AdminDashboardScreen` for outlet detail and `kepala_gerai`.
3. Add a dedicated outlet-detail route so central cards can drill into one outlet cleanly.

**Why this is the best fit:**

- preserves existing outlet operations UI instead of overloading it
- avoids breaking `kepala_gerai` flows that already assume `/admin/dashboard`
- matches the roadmap wording: a new primary central-admin view
- minimizes risk by reusing proven outlet detail code

### Suggested route shape

```dart
// Admin login redirect stays /admin/dashboard

// app.dart
GoRoute(
  path: '/admin/dashboard',
  builder: (context, state) {
    final appState = ref.read(appProvider);
    return appState.isAdmin
        ? const CentralDashboardScreen()
        : const AdminDashboardScreen();
  },
),

GoRoute(
  path: '/admin/outlet-dashboard',
  builder: (context, state) => AdminDashboardScreen(
    initialOutletId: state.uri.queryParameters['outletId'],
  ),
),
```

This preserves `kepala_gerai` behavior while making central dashboard the default for full admins.

### Suggested service/model split

Extend `AnalyticsService` instead of creating a brand-new service, because Phase 23 already established it as the dashboard aggregation boundary.

Recommended new models:

- `CentralDashboardSummary`
- `OutletControlCenterRow`

Recommended new methods:

- `getCentralDashboardSummary({required DateTime date})`
- `getOutletControlCenter({required DateTime date})`

This keeps all dashboard aggregation logic in one place and fits the existing test file `test/services/analytics_service_test.dart`.

---

## SQL / RPC Design

### New RPC 1: `get_central_dashboard_summary`

Purpose: one JSON payload for the top cards on the central dashboard.

Recommended output:

```json
{
  "total_outlets": 4,
  "connected_devices": 7,
  "offline_devices": 1,
  "low_battery_devices": 2,
  "pending_sync_devices": 1,
  "daily_attendance_rate": 84.6
}
```

Recommended inputs:

- `p_date DATE DEFAULT CURRENT_DATE`

Rules:

- admin-only
- count only `outlets.is_active = true`
- count only `kiosk_devices.is_active = true`
- device is offline if `last_heartbeat_at < NOW() - INTERVAL '30 minutes'`
- low battery if `battery_level < 20`
- attendance rate should use **today's** active employees across all outlets

### New RPC 2: `get_outlet_control_center`

Purpose: outlet drilldown list for the central screen.

Recommended row shape:

```json
[
  {
    "outlet_id": "...",
    "outlet_name": "Gerai Panakkukang",
    "connected_devices": 2,
    "offline_devices": 0,
    "low_battery_devices": 1,
    "pending_sync_devices": 0,
    "daily_attendance_rate": 91.7,
    "last_heartbeat_at": "2026-03-22T06:10:00Z"
  }
]
```

Why a second RPC instead of folding everything into one giant payload:

- smaller, testable data contracts
- closer to existing `AnalyticsService` section-per-section loading pattern
- easier to refresh and reason about in Flutter

### Reuse rule for attendance math

The chain-wide daily rate must stay consistent with Phase 23 logic:

- numerator: distinct `(employee_id, logical day)` with `type='masuk'`
- denominator: active employees for the same scope

Do **not** invent a different formula for the central dashboard. Reuse the same reasoning as `get_attendance_rates`, only broaden the scope from one outlet to all active outlets.

---

## Flutter UI Pattern

### New screen: `lib/screens/admin/central_dashboard_screen.dart`

This screen should load:

- central summary cards
- per-outlet control-center rows

Recommended sections:

1. hero/summary cards:
   - total connected devices
   - offline devices
   - low battery devices
   - firm-wide attendance rate today
2. outlet control center list:
   - outlet name
   - device counts / health badges
   - daily attendance rate
   - tap to drill into outlet detail

### New widget: `lib/widgets/outlet_control_card.dart`

Reason:

- `AdminDashboardScreen` is already very large
- a reusable outlet rollup card keeps the central screen focused
- card tap can own the drilldown action

### Drilldown target

Tapping an outlet card should navigate to an outlet-scoped operational dashboard, not back into the same central view.

Recommended target:

```dart
context.push('/admin/outlet-dashboard?outletId=${row.outletId}');
```

That destination can reuse:

- existing `AdminDashboardScreen` sections
- existing `ChartDashboardScreen` button flow
- existing `KioskDeviceCard` grouping and status logic

---

## Role and Navigation Rules

### Admin

- lands on `CentralDashboardScreen`
- can drill into any outlet
- can still access existing employees/reports/outlets flows

### Kepala Gerai

- must **not** see the central screen
- continues to land on outlet-scoped `AdminDashboardScreen`
- remains locked to `managedOutletId`

This means Phase 33 is not just a widget feature. It is also a routing and access-control feature.

---

## Realtime / Refresh Strategy

The central screen needs refresh triggers when these sources change:

- `attendance_logs`
- `employees`
- `kiosk_devices`
- optionally `outlets`

Existing dashboard code already uses Supabase realtime subscriptions and refresh callbacks. Phase 33 can follow the same pattern:

- central summary reload on any relevant table change
- outlet row list reload on the same callback

Given the project size (4 outlets in production), simple full-section reloads are acceptable. No pagination or advanced caching is required.

---

## Validation Architecture

### Dimension 1: Functional Correctness

- central summary cards show aggregate device health across all active outlets
- firm-wide daily attendance rate updates from server-side aggregate data
- outlet list shows one rollup card per active outlet
- tapping an outlet opens an outlet-specific detail view

### Dimension 2: Role Safety

- `admin` sees the central dashboard at `/admin/dashboard`
- `kepala_gerai` continues to see the outlet dashboard at `/admin/dashboard`
- `kepala_gerai` cannot navigate into central-only routes

### Dimension 3: Data Contract Consistency

- new RPCs return stable JSON structures matching Dart model parsers
- daily attendance math remains aligned with Phase 23 attendance-rate semantics
- archived devices are excluded from central health counts

### Dimension 4: Performance / Data Shape

- chain-wide dashboard uses RPCs, not full raw attendance/device fetches into Flutter
- central screen loads in two bounded queries (summary + outlet rows), not N queries per outlet
- realtime refresh reloads summary/rows without additional per-card queries

### Dimension 5: Regression Safety

Phase 33 should add automated coverage in existing test patterns:

- `test/services/analytics_service_test.dart`
  - new JSON parsing tests for `CentralDashboardSummary`
  - new JSON parsing tests for `OutletControlCenterRow`
  - null/empty result behavior when `supabaseReady == false`
- `test/screens/admin/central_dashboard_screen_test.dart`
  - admin renders central summary section
  - admin renders outlet control cards
  - tapping outlet card triggers drilldown callback/navigation
- `test/screens/admin/admin_dashboard_screen_test.dart` or route-level test
  - `initialOutletId` or forced outlet route selects the correct outlet detail

### Wave 0 Testing Need

There is no existing central dashboard test file, so this phase should create at least:

- `test/screens/admin/central_dashboard_screen_test.dart`

The existing Flutter test stack already covers the rest. No new test framework is needed.

---

## Common Pitfalls

### Pitfall 1: Aggregating in Dart instead of SQL RPCs

**What goes wrong:** the central screen fetches raw logs/devices and computes totals client-side, violating project memory and scaling poorly.

**Avoid by:** implementing central aggregates as SECURITY DEFINER RPCs and only parsing final JSON in Flutter.

### Pitfall 2: Breaking `kepala_gerai` by replacing `/admin/dashboard`

**What goes wrong:** outlet managers are redirected into a central screen they are not allowed to use.

**Avoid by:** making `/admin/dashboard` role-aware and keeping the existing outlet dashboard path for managers.

### Pitfall 3: Reusing `ChartDashboardScreen` as the central screen

**What goes wrong:** that screen is built around a required single `outletId`; forcing central behavior into it creates empty-state bugs and mixed responsibilities.

**Avoid by:** building a dedicated central screen and using `ChartDashboardScreen` only after drilldown.

### Pitfall 4: Counting inactive/archived devices in health metrics

**What goes wrong:** retired kiosks make outlets look unhealthy forever.

**Avoid by:** filtering `kiosk_devices.is_active = true` in all central RPCs.

### Pitfall 5: Inconsistent attendance-rate math

**What goes wrong:** central daily rate does not match outlet rates because it uses a different denominator or dedupe rule.

**Avoid by:** deriving the chain-wide rate from the same active-employee / distinct-daily-presence logic as Phase 23.

### Pitfall 6: Drilldown lands on a screen with no outlet locked

**What goes wrong:** user taps an outlet card but arrives at a generic dashboard with "Semua" still selected.

**Avoid by:** adding an explicit outlet-detail route or `initialOutletId` parameter and consuming it in `AdminDashboardScreen`.

---

## Code Examples

### Suggested Dart models

```dart
class CentralDashboardSummary {
  final int totalOutlets;
  final int connectedDevices;
  final int offlineDevices;
  final int lowBatteryDevices;
  final int pendingSyncDevices;
  final double dailyAttendanceRate;

  const CentralDashboardSummary({...});
  factory CentralDashboardSummary.fromJson(Map<String, dynamic> json) { ... }
}

class OutletControlCenterRow {
  final String outletId;
  final String outletName;
  final int connectedDevices;
  final int offlineDevices;
  final int lowBatteryDevices;
  final int pendingSyncDevices;
  final double dailyAttendanceRate;
  final DateTime? lastHeartbeatAt;

  const OutletControlCenterRow({...});
  factory OutletControlCenterRow.fromJson(Map<String, dynamic> json) { ... }
}
```

### Suggested service methods

```dart
Future<CentralDashboardSummary?> getCentralDashboardSummary({
  required DateTime date,
}) async { ... }

Future<List<OutletControlCenterRow>> getOutletControlCenter({
  required DateTime date,
}) async { ... }
```

---

## Files Likely Involved

### New

- `lib/screens/admin/central_dashboard_screen.dart`
- `lib/widgets/outlet_control_card.dart`
- `test/screens/admin/central_dashboard_screen_test.dart`
- `sql/phase_33_central_dashboard_20260322.sql`

### Modified

- `lib/app.dart`
- `lib/screens/admin/admin_dashboard_screen.dart`
- `lib/services/analytics_service.dart`
- `test/services/analytics_service_test.dart`
- possibly `lib/screens/admin/admin_shell.dart` if route selection needs to treat outlet-detail route as dashboard tab

---

## Sources

### Primary

- `lib/screens/admin/admin_dashboard_screen.dart`
- `lib/screens/admin/chart_dashboard_screen.dart`
- `lib/services/analytics_service.dart`
- `lib/app.dart`
- `lib/providers/app_provider.dart`
- `lib/widgets/kiosk_device_card.dart`
- `sql/phase23_rpc_functions.sql`
- `sql/phase_31_kiosk_devices_20260320.sql`
- `.planning/STATE.md`
- `.planning/phases/30-multi-outlet-admin-visibility/30-RESEARCH.md`
- `.planning/phases/32-multi-device-dashboard/32-RESEARCH.md`

### Supporting

- `.planning/codebase/STACK.md`
- `.planning/codebase/ARCHITECTURE.md`
- `.planning/codebase/CONVENTIONS.md`
- `test/services/analytics_service_test.dart`
- `test/screens/admin/chart_dashboard_screen_test.dart`

---

## RESEARCH COMPLETE
