# Architecture Research

**Domain:** Smart Attendance Features + Admin Dashboard (v4.0 milestone for existing Flutter NFC app)
**Researched:** 2026-03-18
**Confidence:** HIGH (existing codebase fully inspected, patterns well understood)

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         UI Layer (Screens)                              │
│  ┌──────────┐ ┌──────────────┐ ┌────────────┐ ┌──────────────────────┐ │
│  │ KioskScan│ │AdminDashboard│ │ ChartDash  │ │ OnboardingScreen     │ │
│  │ (NFC)    │ │ (existing)   │ │ (NEW)      │ │ (NEW - Kepala Gerai) │ │
│  └────┬─────┘ └──────┬───────┘ └─────┬──────┘ └──────────┬───────────┘ │
├───────┴──────────────┴───────────────┴────────────────────┴─────────────┤
│                      Service Layer (Business Logic)                      │
│  ┌──────────────┐ ┌────────────────┐ ┌──────────────┐ ┌──────────────┐ │
│  │ Attendance   │ │ PatternService │ │ StreakService │ │ UserMgmt     │ │
│  │ Service      │ │ (NEW)          │ │ (NEW)        │ │ Service(NEW) │ │
│  │ (existing)   │ │                │ │              │ │              │ │
│  └──────┬───────┘ └───────┬────────┘ └──────┬───────┘ └──────┬───────┘ │
│  ┌──────────────┐ ┌────────────────┐ ┌──────────────┐ ┌──────────────┐ │
│  │ NfcService   │ │ ChartData      │ │ Notification │ │ SyncService  │ │
│  │ (existing)   │ │ Service (NEW)  │ │ Service(mod) │ │ (existing)   │ │
│  └──────────────┘ └────────────────┘ └──────────────┘ └──────────────┘ │
├─────────────────────────────────────────────────────────────────────────┤
│                      State Layer (Riverpod)                              │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ AppProvider (existing) — NO changes needed for v4.0 features    │   │
│  └──────────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────┤
│                      Data Layer                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                   │
│  │ Supabase     │  │ SQLite       │  │ SharedPrefs  │                   │
│  │ (remote)     │  │ (offline)    │  │ (session)    │                   │
│  └──────────────┘  └──────────────┘  └──────────────┘                   │
└─────────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### Existing Components (to MODIFY)

| Component | Current Responsibility | v4.0 Modifications |
|-----------|----------------------|---------------------|
| `AdminDashboardScreen` | Today's logs, open shifts, stats cards | Add attendance rate card, streak highlights, link to chart dashboard |
| `KioskBackgroundService` | Foreground service, overlay pill, scan notif | Add missing clock-out check timer |
| `NfcService` | UID extraction from NFC tags | Add debounce lock for registration flow (double-scan fix) |
| `admin_shell.dart` / `app.dart` | GoRouter, admin nav shell | Add routes for new screens |
| `KioskScanScreen` | NFC scan + attendance logging | After masuk, compare against pattern for late notification |

### New Components (to CREATE)

| Component | Responsibility | Type |
|-----------|---------------|------|
| `AttendancePatternService` | Analyze historical attendance_logs, detect usual check-in times, flag late arrivals | Service |
| `StreakService` | Calculate consecutive attendance streaks per employee | Service |
| `ChartDataService` | Aggregate attendance data for chart rendering (rates, trends, comparisons) | Service |
| `UserManagementService` | Create Kepala Gerai users via Supabase Edge Function, generate passwords | Service |
| `MissingClockOutService` | Periodic check for employees who checked in but never clocked out | Service |
| `AttendancePattern` | Model for detected patterns (usual_check_in, usual_check_out, deviation) | Model |
| `EmployeeStreak` | Model for streak data (current_streak, longest_streak, last_attendance_date) | Model |
| `ChartDashboardScreen` | Full-page chart view with attendance rate, trends, cross-outlet comparison | Screen |
| `KepalaGeraiOnboardingScreen` | Form to create new Kepala Gerai user, auto-generate password, copy-to-clipboard | Screen |
| `StreakWidget` | Reusable widget showing streak fire icon + count | Widget |
| `AttendanceRateCard` | Dashboard card showing attendance percentage with mini sparkline | Widget |
| `MiniChartCard` | Small chart cards for the kepala gerai recap view | Widget |

## Recommended Project Structure (New Files Only)

```
lib/
├── models/
│   ├── attendance_pattern.dart    # NEW — pattern detection results
│   └── employee_streak.dart       # NEW — streak tracking model
├── services/
│   ├── attendance_pattern_service.dart  # NEW — historical pattern analysis
│   ├── streak_service.dart              # NEW — consecutive attendance calc
│   ├── chart_data_service.dart          # NEW — chart data aggregation
│   ├── user_management_service.dart     # NEW — Supabase Edge Function caller
│   └── missing_clockout_service.dart    # NEW — detect missing pulang
├── screens/
│   └── admin/
│       ├── chart_dashboard_screen.dart       # NEW — full chart page
│       ├── kepala_gerai_onboard_screen.dart   # NEW — user creation form
│       └── widgets/
│           ├── attendance_rate_card.dart   # NEW — rate % card
│           ├── mini_chart_card.dart        # NEW — sparkline/bar mini chart
│           └── streak_widget.dart          # NEW — streak display
└── (existing files modified in-place)
```

### Structure Rationale

- **Services stay flat** because the existing codebase uses a flat `services/` folder with no subdirectories. Adding subdirectories would break convention for only 5 new files.
- **New screens go under `screens/admin/`** because all new features are admin-facing. No new kiosk screens needed.
- **New widgets under `screens/admin/widgets/`** because they are dashboard-specific, not app-wide reusable widgets. App-wide widgets go in `widgets/`.
- **Models stay flat** — only 2 new model files, consistent with existing pattern.

## Architectural Patterns

### Pattern 1: Service Singleton with Supabase Guard

**What:** All new services follow the existing `BadgeService` pattern — singleton instance, `supabaseReady` guard before any Supabase call, in-memory caching with explicit refresh.
**When to use:** Every new service that hits Supabase.
**Trade-offs:** Simple and proven in this codebase. Not testable via DI, but the app has no DI framework and adding one is unnecessary for 4 outlets.

```dart
class AttendancePatternService {
  AttendancePatternService._();
  static final instance = AttendancePatternService._();

  Future<List<AttendancePattern>> analyzePatterns(String employeeId) async {
    if (!supabaseReady) return [];
    // Query attendance_logs for last 30 days
    // Compute median check-in time per day-of-week
    // Return pattern with deviation threshold
  }
}
```

### Pattern 2: Supabase RPC for Heavy Aggregation

**What:** Use Supabase PostgreSQL RPC functions for attendance rate calculations and cross-outlet comparisons instead of fetching all rows and computing in Dart.
**When to use:** Any aggregation involving more than ~200 rows or cross-table joins.
**Trade-offs:** Moves compute to the server (correct for aggregation), but requires SQL migration. Given the "additive migrations only" constraint, each RPC is a standalone `CREATE OR REPLACE FUNCTION`.

```dart
// In ChartDataService
Future<Map<String, double>> getAttendanceRates(String outletId, DateRange range) async {
  final result = await SupabaseClientFactory.admin.rpc('get_attendance_rates', params: {
    'p_outlet_id': outletId,
    'p_start': range.start.toIso8601String(),
    'p_end': range.end.toIso8601String(),
  });
  return Map<String, double>.from(result);
}
```

### Pattern 3: Timer-Based Background Check (Missing Clock-Out)

**What:** Reuse the existing `KioskBackgroundService` timer pattern to periodically check for missing clock-outs, rather than building a separate background isolate.
**When to use:** The missing clock-out notification feature.
**Trade-offs:** Piggybacks on existing foreground service (already running 24/7 in kiosk mode). Only fires notifications when app is in kiosk mode, which is the primary use case.

```dart
// Inside KioskBackgroundService — add to existing _rotateTimer callback
static Future<void> _checkMissingClockOuts() async {
  // Query Supabase for today's masuk without matching pulang
  // If found and time > scheduled shift end + 30min, fire notification
}
```

### Pattern 4: Stateless Chart Data Aggregation

**What:** `ChartDataService` returns plain Dart objects (maps/lists) that chart widgets consume. No chart-library-specific models in the service layer.
**When to use:** All chart data preparation.
**Trade-offs:** Chart library can be swapped without touching service code. Minor overhead of mapping data twice, but negligible for this scale.

## Data Flow

### Smart Pattern Detection Flow

```
attendance_logs (Supabase, last 30 days)
    |
    v
AttendancePatternService.analyzePatterns(employeeId)
    |
    v
[Compute median check-in time per day-of-week]
    |
    v
AttendancePattern { dayOfWeek, usualCheckIn, usualCheckOut, deviationMinutes }
    |
    v
KioskScanScreen — on masuk, compare scannedAt vs pattern.usualCheckIn
    |
    v
If late > threshold --> show notification via existing 3-tier system
```

### Streak Calculation Flow

```
attendance_logs (Supabase, ordered by scanned_at DESC)
    |
    v
StreakService.calculateStreak(employeeId)
    |
    v
[Walk backwards through masuk records, count consecutive work days]
    |
    v
EmployeeStreak { currentStreak, longestStreak, lastMasukDate }
    |
    v
AdminDashboard streak widget + kiosk scan success overlay
```

### Chart Dashboard Flow

```
Admin taps "Rekap" / Chart Dashboard
    |
    v
ChartDataService.getAttendanceRates()  <-- Supabase RPC
ChartDataService.getWeeklyTrend()      <-- Supabase RPC
ChartDataService.getOutletComparison() <-- Supabase RPC
    |
    v
ChartDashboardScreen renders fl_chart widgets
    |
    v
[Bar chart: daily rate], [Line chart: weekly trend], [Grouped bar: outlet comparison]
```

### Kepala Gerai Onboarding Flow

```
Admin taps "Tambah Kepala Gerai"
    |
    v
KepalaGeraiOnboardScreen — form: email, outlet selection
    |
    v
UserManagementService.createKepalaGerai(email, outletId)
    |
    v
Supabase Edge Function 'create-kepala-gerai'
    --> Validates caller JWT (must be admin)
    --> supabase.auth.admin.createUser({ email, password: autoGenerated })
    --> UPDATE raw_app_meta_data with app_role + managed_outlet_id
    |
    v
Returns generated password to Flutter
    --> Show in dialog --> Copy to clipboard / Share to WhatsApp
```

### Missing Clock-Out Detection Flow

```
KioskBackgroundService timer (every 30 minutes while kiosk active)
    |
    v
MissingClockOutService.checkOpenSessions(outletId)
    |
    v
Query: attendance_logs WHERE type='masuk' AND scanned_at > today
       LEFT JOIN attendance_logs WHERE type='pulang' — find unmatched
    |
    v
If employee has masuk > 10 hours ago with no pulang:
    --> Fire push notification to admin via existing notification system
```

### NFC Double-Scan Prevention Flow

```
Admin taps "Register NFC" for employee
    |
    v
NfcService.startSession() — sets _isRegistering = true lock
    |
    v
First NFC tap --> extract UID --> store in _pendingUid
    --> Immediately call NfcManager.instance.stopSession()
    --> Clear _isRegistering lock
    |
    v
If second tap arrives before stopSession completes:
    --> _isRegistering check --> reject duplicate
    |
    v
Confirm dialog --> save UID to employee record
```

## Database Changes (Supabase — Additive Only)

### New Tables

| Table | Purpose | Columns |
|-------|---------|---------|
| `employee_streaks` | Cache calculated streaks (avoid recomputing on every dashboard load) | `employee_id (PK, FK)`, `current_streak INT`, `longest_streak INT`, `last_masuk_date DATE`, `updated_at TIMESTAMPTZ` |

**Rationale:** Streaks are expensive to recalculate from raw logs every time. A cache table updated on each masuk scan keeps dashboard fast. At 200 employees, this avoids 200 sequential queries.

### New RPC Functions

| Function | Purpose | Parameters |
|----------|---------|------------|
| `get_attendance_rates` | Attendance % by outlet for date range | `p_outlet_id UUID, p_start TIMESTAMPTZ, p_end TIMESTAMPTZ` |
| `get_weekly_trend` | Daily attendance counts for last N days | `p_outlet_id UUID, p_days INT` |
| `get_outlet_comparison` | Side-by-side attendance rates across all outlets | `p_start TIMESTAMPTZ, p_end TIMESTAMPTZ` |
| `update_employee_streak` | Recalculate and cache streak for one employee | `p_employee_id UUID` |

**Rationale:** PostgreSQL aggregations (COUNT, GROUP BY, date_trunc) are faster and more correct than fetching hundreds of rows to Dart. RPC functions are additive -- no schema migration risk.

### New Edge Function

| Function | Purpose | Notes |
|----------|---------|-------|
| `create-kepala-gerai` | Server-side user creation with service_role | TypeScript, deployed via `supabase functions deploy` |

### Existing Tables -- No Schema Changes Required

The existing schema already has everything needed:
- **Pattern detection:** reads `attendance_logs.scanned_at` + `type` + `employee_id` (all exist)
- **Cross-outlet comparison:** reads `attendance_logs.scan_outlet_id` (exists)
- **Streak calculation:** reads `attendance_logs` WHERE `type = 'masuk'` (exists)

This is a significant architectural advantage -- v4.0 features are purely additive to the database.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Supabase Auth Admin API | Via Edge Function (not direct client call) | Keeps service_role key server-side. Flutter calls `supabase.functions.invoke()`. |
| Supabase Realtime | Existing subscription pattern on attendance_logs | Streak widget can piggyback on existing realtime channel in dashboard |
| fl_chart package | New dependency for chart rendering | Add to pubspec.yaml. Used only in `ChartDashboardScreen`. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `AttendancePatternService` <-> `KioskScanScreen` | Direct method call after NFC scan | Pattern service is read-only, called after attendance is logged |
| `StreakService` <-> `SyncService` | After successful sync, call `StreakService.updateStreak()` | Hook into `SyncService.syncPendingLogs()` success path |
| `ChartDataService` <-> `ChartDashboardScreen` | Async data fetch, returns plain maps | Screen manages its own loading state (matches existing dashboard pattern) |
| `MissingClockOutService` <-> `KioskBackgroundService` | Timer callback added to existing service | Runs every 30 min, uses existing notification infrastructure |
| `UserManagementService` <-> Supabase Edge Function | `supabase.functions.invoke()` | Returns JSON with generated password |

### Supabase Auth User Creation -- Security Architecture

The Supabase Flutter SDK `supabase.auth.admin.createUser()` requires the service_role key. Embedding this key in a mobile APK is a **security risk** even for internal apps (APK can be decompiled).

**Recommended approach:** Supabase Edge Function
- 1 small TypeScript file (~30 lines)
- Validates caller JWT, checks `app_role = 'admin'`
- Creates user with service_role, sets app_metadata
- Returns generated password
- Deployed via `supabase functions deploy create-kepala-gerai`
- Flutter calls: `Supabase.instance.client.functions.invoke('create-kepala-gerai', body: { email, outletId })`

## Suggested Build Order

The build order is driven by dependency chains and risk. Lower-risk, zero-dependency items first.

### Phase 1: Bug Fix + Database Foundation
1. **NFC double-scan prevention** -- Bug fix, touches only `NfcService` and registration flow. Zero dependencies. Ship immediately.
2. **Supabase RPC functions** -- Deploy SQL: `get_attendance_rates`, `get_weekly_trend`, `get_outlet_comparison`, `update_employee_streak`. Foundation for all dashboard features.
3. **`employee_streaks` table** -- CREATE TABLE, additive migration.

### Phase 2: Core Services (no UI yet)
4. **`StreakService`** -- Pure logic + Supabase calls. Testable in isolation. Hook into `SyncService` post-sync.
5. **`AttendancePatternService`** -- Pure logic reading attendance_logs. No dependencies on other new features.
6. **`ChartDataService`** -- Wraps RPC calls from Phase 1. Returns plain data.

### Phase 3: Dashboard UI
7. **`AttendanceRateCard` + `StreakWidget`** -- Add to existing `AdminDashboardScreen`. Small UI additions using services from Phase 2.
8. **`ChartDashboardScreen`** -- Full chart page with `fl_chart`. New route in GoRouter. Contains mini charts for kepala gerai recap.
9. **Cross-outlet comparison view** -- Part of `ChartDashboardScreen`, uses `get_outlet_comparison` RPC.

### Phase 4: Notifications + Onboarding
10. **Missing clock-out detection** -- `MissingClockOutService` + timer in `KioskBackgroundService`. Uses existing notification system.
11. **Late arrival notification** -- Triggered by `AttendancePatternService` comparison on each masuk scan.
12. **Kepala Gerai onboarding** -- Edge Function + `UserManagementService` + `KepalaGeraiOnboardScreen`. Isolated from all other features.

### Build Order Rationale

- **Phase 1 first** because the NFC bug is a production issue and RPC functions are prerequisites for all chart/dashboard work.
- **Phase 2 before Phase 3** because services must exist before UI can consume them. Services are independently testable.
- **Phase 3 before Phase 4** because dashboard is the highest-value visible feature for the product owner (kepala gerai "rekap 1 layar").
- **Phase 4 last** because notifications and onboarding are independent features with no downstream dependencies. The Edge Function for onboarding may need additional Supabase CLI setup.

## Anti-Patterns

### Anti-Pattern 1: Computing Aggregations in Dart

**What people do:** Fetch all attendance_logs rows and compute rates/trends in Dart.
**Why it's wrong:** With 89+ rows today growing to thousands, this wastes bandwidth and battery on a 24/7 tablet. Sorting/grouping in Dart is slower and more error-prone than PostgreSQL.
**Do this instead:** Use Supabase RPC functions for all aggregations. Return only the computed result.

### Anti-Pattern 2: Storing Streak State in AppProvider

**What people do:** Add `currentStreak` to `AppState` and recalculate on every provider rebuild.
**Why it's wrong:** AppProvider rebuilds frequently (session changes, pending count updates, NFC scans). Streak calculation hits Supabase -- this would cause unnecessary API calls.
**Do this instead:** `StreakService` caches in `employee_streaks` table. Dashboard reads cache. Cache updates only on successful attendance sync.

### Anti-Pattern 3: New Riverpod Providers for Each Feature

**What people do:** Create `streakProvider`, `patternProvider`, `chartProvider` etc.
**Why it's wrong:** The existing codebase uses a single `AppProvider` StateNotifier with local `setState()` in screens. Adding multiple providers introduces a different state management pattern, increasing cognitive load.
**Do this instead:** New services are singletons with their own caching. Screens call services directly and manage local state with `setState()` (matching existing `AdminDashboardScreen` pattern).

### Anti-Pattern 4: Embedding service_role Key in Flutter App

**What people do:** Initialize a second Supabase client with service_role key for admin user creation.
**Why it's wrong:** Service role key has full database access. APK decompilation exposes the key, even with obfuscation.
**Do this instead:** Supabase Edge Function validates caller JWT, then creates user server-side with service_role.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 4 outlets, 14 employees (NOW) | Current approach works. RPC functions are technically overkill but architecturally correct. |
| 20 outlets, 200 employees (DESIGNED FOR) | RPC functions essential. Streak cache table prevents N+1 queries. Chart data should have 5-min in-memory TTL. |
| 50+ outlets (HYPOTHETICAL) | Would need materialized views, pagination, and server-side caching. Not worth designing for now. |

### Scaling Priorities

1. **First bottleneck: Dashboard load time** -- At 20 outlets, loading charts on the main dashboard page would slow initial render. Fix: Chart dashboard is a separate screen (lazy loaded on navigation). Rate card uses a lightweight RPC returning a single number.
2. **Second bottleneck: Streak recalculation** -- At 200 employees, recalculating all streaks on every sync is wasteful. Fix: `update_employee_streak` RPC runs only for the specific employee who just scanned. Optional daily batch via pg_cron.

## Sources

- Existing codebase inspection (50+ Dart files, ~22,000 LOC) -- HIGH confidence
- Supabase Auth Admin API (auth.admin.createUser requires service_role) -- HIGH confidence
- Supabase Edge Functions (invoke from Flutter client via functions.invoke) -- HIGH confidence
- fl_chart Flutter package (widely used chart library) -- MEDIUM confidence (not verified via Context7)
- PostgreSQL aggregate functions (COUNT, GROUP BY, date_trunc) -- HIGH confidence

---
*Architecture research for: Absensi Enakko v4.0 Smart Attendance + Admin Dashboard*
*Researched: 2026-03-18*
