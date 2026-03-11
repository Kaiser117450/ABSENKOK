# Architecture Research: v2.0 Feature Integration

**Domain:** NFC attendance kiosk — Flutter/Supabase, Android-only
**Researched:** 2025-07-14
**Confidence:** HIGH (based on full codebase analysis of 47 Dart source files)

## Current Architecture Snapshot

```
┌─────────────────────────────────────────────────────────────────────┐
│                     OVERLAY PROCESS (separate)                       │
│  overlay_task.dart → KioskOverlayUI (Flutter overlay window)         │
│  Receives data via FlutterOverlayWindow.overlayListener stream       │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ shareData() wire payload
┌──────────────────────────────┴──────────────────────────────────────┐
│                        MAIN APP PROCESS                              │
├─────────────────────────────────────────────────────────────────────┤
│  PRESENTATION: screens/admin/  screens/kiosk/  screens/setup/        │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  │
│  │Dashboard │  │  Employees   │  │   Reports    │  │   Outlets   │  │
│  │ (realtime)│  │ (CRUD+NFC)  │  │ (PDF/CSV)    │  │  (admin)    │  │
│  └────┬─────┘  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘  │
│       │               │                 │                  │         │
├───────┴───────────────┴─────────────────┴──────────────────┴────────┤
│  STATE: providers/app_provider.dart (Riverpod StateNotifier)         │
│  AppState: kioskSession, isAdmin, isKepalaGerai, detectedEmployee    │
├─────────────────────────────────────────────────────────────────────┤
│  SERVICES:                                                           │
│  ┌────────────┐ ┌─────────┐ ┌──────────┐ ┌────────────────────────┐ │
│  │SupabaseCF  │ │SqliteSvc│ │ SyncSvc  │ │KioskBackgroundService  │ │
│  │(direct SQL)│ │(offline) │ │(queue→SB)│ │(foreground+notif+pill) │ │
│  └────────────┘ └─────────┘ └──────────┘ └────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────┤
│  MODELS: Employee, AttendanceLog, Outlet, KioskSession, PendingLog   │
│          OverlayPillState, DailySummary, EmployeeBadge               │
├─────────────────────────────────────────────────────────────────────┤
│  CORE: constants.dart, theme.dart, supabase_client.dart              │
└─────────────────────────────────────────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │   SUPABASE BACKEND   │
                    │  PostgreSQL + Auth    │
                    │  + Realtime channels  │
                    └─────────────────────┘
```

### Key Architecture Facts

| Fact | Detail |
|------|--------|
| **No service layer abstraction** | Screens call `SupabaseClientFactory.admin.from('employees')` directly — no SupabaseService class |
| **Employee model** | `lib/models/employee.dart` — has `isActive` bool but NO archive fields yet |
| **Overlay is separate process** | `overlay_task.dart` runs in its own Flutter engine via `@pragma('vm:entry-point')` |
| **Overlay data flow** | Main app → `FlutterOverlayWindow.shareData(jsonString)` → overlay listens via `overlayListener` stream |
| **Overlay modes** | `OverlayPillMode.idle` (clock + outlet name) and `OverlayPillMode.event` (scan feedback, auto-expires) |
| **Background keepalive** | `flutter_foreground_task` foreground service, 10s repeat interval |
| **Notification rotation** | 5s Timer in `KioskBackgroundService._rotateNotification()` updates pill + notification |
| **Supabase queries** | Direct `.from('table').select()` in screen `_loadData()` methods — no repository pattern |
| **Realtime** | Per-screen channel subscriptions (dashboard subscribes `attendance_logs`, employees subscribes `employees`) |
| **Admin shell** | `ShellRoute` wrapping 4 routes: dashboard, employees, reports, outlets |
| **Bottom nav** | `_EnakkoBottomNav` in `admin_shell.dart` — indexes 0-3, Gerai hidden for kepala_gerai |

## Feature 1: Soft-Archive Karyawan

### Integration Architecture

**Database change (Supabase SQL):**
```sql
ALTER TABLE employees
  ADD COLUMN is_archived BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN archived_at TIMESTAMPTZ,
  ADD COLUMN archived_by TEXT;  -- admin user ID who archived

-- Index for fast "active only" queries
CREATE INDEX idx_employees_not_archived ON employees (id) WHERE is_archived = false;
```

**Why `is_archived` instead of reusing `is_active`:**
- `is_active` already means "can scan NFC" — toggled on/off operationally
- `is_archived` means "removed from active workforce" — different lifecycle state
- An employee can be `is_active=false` but NOT archived (just temporarily disabled)
- Archived employees should disappear from ALL active lists AND schedule assignments

### Component Map: Files to Modify vs Create

| Action | File | What Changes |
|--------|------|-------------|
| **MODIFY** | `lib/models/employee.dart` | Add `isArchived`, `archivedAt`, `archivedBy` fields + `fromJson`/`toJson`/`copyWith` |
| **MODIFY** | `lib/screens/admin/admin_employees_screen.dart` | Add `.eq('is_archived', false)` to `_loadData()` query (line ~82). Add "Arsipkan" to PopupMenuButton (line ~725). Add archive toggle filter UI. |
| **MODIFY** | `lib/screens/admin/admin_dashboard_screen.dart` | Filter archived employees from counts (line ~66 `_loadEmployeeCount()`) |
| **MODIFY** | `lib/screens/admin/shift_scheduler_screen.dart` | Filter `is_archived=false` when loading employees for schedule assignment |
| **MODIFY** | `lib/services/employee_cache_service.dart` | Ensure cached employees exclude archived (kiosk NFC lookup) |
| **CREATE** | `lib/screens/admin/archived_employees_screen.dart` | "Riwayat Karyawan" screen: list archived employees, restore action |
| **MODIFY** | `lib/app.dart` | Add route `/admin/employees/archived` under ShellRoute |
| **MODIFY** | `lib/screens/admin/admin_shell.dart` | No bottom nav change needed — access via button on employees screen |

### Data Flow: Archive an Employee

```
Admin taps "Arsipkan" on _EmployeeCard PopupMenuButton
    ↓
Confirmation dialog (show employee name + warning about schedules)
    ↓
SupabaseClientFactory.admin
  .from('employees')
  .update({
    'is_archived': true,
    'archived_at': DateTime.now().toIso8601String(),
    'archived_by': Supabase.instance.client.auth.currentUser?.id,
  })
  .eq('id', employee.id)
    ↓
Realtime subscription fires → _loadData() refreshes list
    ↓
Employee disappears from active list (filtered by is_archived=false)
```

### Data Flow: View Archived Employees

```
Admin taps "Riwayat Karyawan" button on AdminEmployeesScreen
    ↓
context.push('/admin/employees/archived')
    ↓
ArchivedEmployeesScreen loads:
  SupabaseClientFactory.admin
    .from('employees')
    .select('*')
    .eq('is_archived', true)
    .order('archived_at', ascending: false)
    ↓
List with "Pulihkan" button → sets is_archived=false, clears archived_at
```

### Critical Design Decision: Route vs Dialog

**Use a full screen** (`/admin/employees/archived`), NOT a dialog or tab.
- Archived employees list could grow unbounded
- Needs its own search/filter capability
- Keeps admin_employees_screen.dart focused on active employees
- Navigate via button at top of employees screen: "📁 Riwayat (N)"

**Navigation pattern:** Use `context.push()` (not `context.go()`) so it stacks on top of admin shell, with back button to return.

## Feature 2: Batch CSV Import

### Integration Architecture

**New dependency needed:**
```yaml
# pubspec.yaml
dependencies:
  file_picker: ^8.0.0+1   # Native file picker for CSV selection
  csv: ^6.0.0              # CSV parsing (RFC 4180 compliant)
```

**Why these packages:**
- `file_picker` — battle-tested Flutter file picker, supports Android, returns `PlatformFile` with bytes
- `csv` — proper CSV parsing with quote handling, delimiter detection. Don't hand-roll CSV parsing.

### Component Map

| Action | File | What Changes |
|--------|------|-------------|
| **CREATE** | `lib/screens/admin/csv_import_screen.dart` | Full CSV import screen with preview, validation, progress |
| **CREATE** | `lib/services/csv_import_service.dart` | CSV parsing logic, validation, batch Supabase INSERT |
| **MODIFY** | `lib/app.dart` | Add route `/admin/employees/import` |
| **MODIFY** | `lib/screens/admin/admin_employees_screen.dart` | Add "Import CSV" button next to "Tambah" button |

### Data Flow: CSV Import

```
Admin taps "Import CSV" button on AdminEmployeesScreen
    ↓
context.push('/admin/employees/import')
    ↓
CsvImportScreen shows instructions + "Pilih File" button
    ↓
FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'])
    ↓
CsvImportService.parseAndValidate(bytes) returns List<CsvEmployeeRow>
    ↓
Preview table rendered (name, jabatan, gerai, photo_url, validation status)
    ↓
Admin reviews, fixes errors inline, taps "Import N Karyawan"
    ↓
CsvImportService.bulkInsert(rows):
  - Batch into chunks of 50 (Supabase has ~1000 row limit per INSERT)
  - For each chunk:
      SupabaseClientFactory.admin
        .from('employees')
        .insert(chunk.map((r) => r.toSupabasePayload()).toList())
  - Progress callback updates UI
    ↓
Result summary: "12 berhasil, 2 gagal (duplikat kode)"
    ↓
Navigate back → Realtime subscription refreshes employee list
```

### CSV Format Specification

```csv
nama,jabatan,kode_karyawan,gerai,photo_url
Ahmad Rizki,Kasir,EK-001,Enakko Dago,
Siti Nurhaliza,Koki,EK-002,Enakko Pasteur,https://example.com/photo.jpg
```

### Validation Rules (in CsvImportService)

| Field | Rule | Error Message |
|-------|------|---------------|
| `nama` | Required, min 3 chars | "Nama wajib diisi (min 3 karakter)" |
| `jabatan` | Optional | — |
| `kode_karyawan` | Optional, unique if provided | "Kode karyawan duplikat" |
| `gerai` | Required, must match existing outlet name | "Gerai '{name}' tidak ditemukan" |
| `photo_url` | Optional, valid URL format if provided | "Format URL tidak valid" |

### Bulk Insert Strategy

**Use Supabase `.insert()` with array (NOT individual inserts):**
```dart
// CsvImportService
static Future<ImportResult> bulkInsert(List<CsvEmployeeRow> rows) async {
  // 1. Resolve outlet names → IDs
  final outlets = await SupabaseClientFactory.admin
      .from('outlets').select('id, name').eq('is_active', true);
  final outletMap = {for (var o in outlets) o['name']: o['id']};

  // 2. Batch insert (50 per batch to stay under Supabase limits)
  final batches = _chunk(rows, 50);
  int success = 0, failed = 0;

  for (final batch in batches) {
    try {
      await SupabaseClientFactory.admin.from('employees').insert(
        batch.map((r) => {
          'name': r.nama,
          'position': r.jabatan,
          'employee_code': r.kodeKaryawan,
          'home_outlet_id': outletMap[r.gerai],
          'photo_url': r.photoUrl,
          'is_active': true,
          'is_archived': false,
        }).toList(),
      );
      success += batch.length;
    } on PostgrestException catch (e) {
      // If batch fails, fall back to individual inserts
      for (final row in batch) {
        try { /* individual insert */ success++; }
        catch (_) { failed++; }
      }
    }
  }
  return ImportResult(success: success, failed: failed);
}
```

**Why batch-then-fallback:** Fast path for clean data (1 request per 50 rows), graceful degradation for rows with conflicts.

## Feature 3: Quick Kepala Gerai Setup

### Integration: SQL Script Only (No App Changes)

This is explicitly an **outside-app** feature — admin runs SQL in Supabase SQL editor.

**Deliverable:** A documented SQL script in `scripts/setup_kepala_gerai.sql`

```sql
-- Quick Setup: Promote user to Kepala Gerai
-- USAGE: Replace 'email@example.com' with target email
--        Replace 'OUTLET_UUID_HERE' with target outlet ID

-- Step 1: Find the user
SELECT id, email, raw_user_meta_data->>'app_role' as current_role
FROM auth.users
WHERE email = 'email@example.com';

-- Step 2: Set role + managed outlet
UPDATE auth.users
SET raw_user_meta_data = raw_user_meta_data
  || '{"app_role": "kepala_gerai"}'::jsonb,
    raw_app_meta_data = raw_app_meta_data
  || '{"app_role": "kepala_gerai", "managed_outlet_id": "OUTLET_UUID_HERE"}'::jsonb
WHERE email = 'email@example.com';

-- Step 3: Verify
SELECT id, email,
  raw_user_meta_data->>'app_role' as role,
  raw_app_meta_data->>'managed_outlet_id' as outlet
FROM auth.users
WHERE email = 'email@example.com';
```

**No app code changes needed.** The existing `app.dart` (lines 171-185) already reads `app_role` and `managed_outlet_id` from user metadata on auth state change. The GoRouter redirect (lines 71-73) already restricts kepala_gerai from `/admin/outlets`.

| File | Impact |
|------|--------|
| `scripts/setup_kepala_gerai.sql` | **CREATE** — new SQL script |
| App code | **NO CHANGES** — existing auth flow handles this |

## Feature 4: Persistent Live Activity Pill (Idle Mode with Break Status)

### Current Overlay Architecture (What Exists)

```
┌─────────────────────────────────────────────────────────┐
│  MAIN APP PROCESS                                        │
│                                                          │
│  app.dart._applyLifecyclePolicy():                       │
│    onBackground → showLiveNotification() + showOverlayPill()
│    onResume (if !keepOverlay) → hideOverlayPill()        │
│                                                          │
│  KioskBackgroundService:                                 │
│    _rotateTimer (5s) → _rotateNotification()             │
│      → updateLiveNotification()                          │
│      → updateOverlayState(_buildIdleOverlayState())      │
│                                                          │
│  Data sent via: FlutterOverlayWindow.shareData(json)     │
└──────────────────────┬──────────────────────────────────┘
                       │ OverlayPillState JSON
┌──────────────────────┴──────────────────────────────────┐
│  OVERLAY PROCESS (overlay_task.dart)                     │
│                                                          │
│  KioskOverlayUI listens: FlutterOverlayWindow.overlayListener
│  Parses OverlayPillState.fromRaw()                       │
│  Modes:                                                  │
│    idle  → shows outlet name + clock + "Kiosk aktif"     │
│    event → shows attendance type + accent + auto-expires  │
│  Clock fallback: 30s Timer if no payload for 2 min       │
└─────────────────────────────────────────────────────────┘
```

### What Needs to Change for Persistent Idle Mode with Break Status

The existing architecture is **almost ready**. The key gap: the overlay currently only shows static idle info (outlet name + clock). For v2.0 it needs to:

1. **Show real-time break status** — "Ahmad sedang istirahat (12 min)" 
2. **Show fun facts when nobody's on break** — rotating trivia
3. **Stay visible when app is in foreground** (currently hides on resume)
4. **Update break timer every ~30s** without killing battery

### New OverlayPillMode: `liveIdle`

**Extend the existing `OverlayPillMode` enum:**

```dart
// overlay_pill_state.dart
enum OverlayPillMode {
  idle,      // existing: clock + outlet
  event,     // existing: scan feedback (auto-expires)
  liveIdle,  // NEW: break status or fun fact (persistent)
}
```

**New fields in `OverlayPillState`:**

```dart
// New fields for liveIdle mode
final String subtitle;        // "Ahmad • Istirahat" or fun fact text
final int breakStartEpochMs;  // when break started (for timer calc)
final String breakEmployee;   // employee name on break (empty = fun fact mode)
```

### Data Flow: Supabase Realtime → Overlay

```
┌─────────────────────────────────────────────────────────────────┐
│  SUPABASE                                                        │
│  attendance_logs table: INSERT event (type='break')              │
└──────────────┬──────────────────────────────────────────────────┘
               │ Realtime channel notification
┌──────────────┴──────────────────────────────────────────────────┐
│  MAIN APP: NEW LiveActivityDataService                           │
│                                                                  │
│  Subscribes to: attendance_logs INSERT where                     │
│    scan_outlet_id = current kiosk outlet                         │
│    type IN ('break', 'kembali', 'pulang')                        │
│                                                                  │
│  Maintains state:                                                │
│    _currentBreaks: Map<employeeId, BreakInfo>                    │
│    When 'break' → add to map with timestamp                      │
│    When 'kembali'/'pulang' → remove from map                     │
│                                                                  │
│  Every 30s (or on break state change):                           │
│    Build OverlayPillState(mode: liveIdle, ...)                   │
│    → KioskBackgroundService.updateOverlayState(state)            │
└──────────────┬──────────────────────────────────────────────────┘
               │ FlutterOverlayWindow.shareData()
┌──────────────┴──────────────────────────────────────────────────┐
│  OVERLAY PROCESS                                                 │
│  KioskOverlayUI receives liveIdle state                          │
│  If breakEmployee not empty:                                     │
│    Show: "☕ Ahmad • Istirahat 12m" with break accent color       │
│    Timer: calculate elapsed from breakStartEpochMs locally       │
│  If breakEmployee empty:                                         │
│    Show: fun fact text with neutral accent                        │
└─────────────────────────────────────────────────────────────────┘
```

### Component Map

| Action | File | What Changes |
|--------|------|-------------|
| **MODIFY** | `lib/models/overlay_pill_state.dart` | Add `liveIdle` mode, `subtitle`, `breakStartEpochMs`, `breakEmployee` fields |
| **CREATE** | `lib/services/live_activity_data_service.dart` | Supabase realtime subscription for break status, fun fact rotation, state builder |
| **MODIFY** | `lib/overlay_task.dart` | Handle `liveIdle` mode rendering — break timer display, fun fact display |
| **MODIFY** | `lib/services/kiosk_background_service.dart` | Integrate LiveActivityDataService into rotation timer, change `_buildIdleOverlayState` to consult break data |
| **MODIFY** | `lib/app.dart` | Change `_applyLifecyclePolicy` — don't hide overlay on resume when `keepOverlayInForeground` is true (already partially supported via the flag) |
| **MODIFY** | `lib/screens/kiosk/kiosk_idle_screen.dart` | Initialize LiveActivityDataService on kiosk start |

### Critical Constraint: Overlay Runs in Separate Isolate

**The overlay process (`overlay_task.dart`) CANNOT access Supabase directly.** It has its own Flutter engine with no access to the main app's Supabase client, providers, or services.

**Solution (already in place):** All data flows through `FlutterOverlayWindow.shareData()` → `overlayListener`. The overlay only renders what it receives. The main app process handles all Supabase subscriptions and pushes precomputed state.

**Timer calculation in overlay:** The overlay receives `breakStartEpochMs` and calculates elapsed time locally using `widget.now()`. This avoids sending updates every second from the main process — the overlay's 30s clock timer handles display updates.

### LiveActivityDataService Design

```dart
// lib/services/live_activity_data_service.dart
class LiveActivityDataService {
  static LiveActivityDataService? _instance;
  RealtimeChannel? _channel;
  Timer? _funFactTimer;

  // Current break state
  final Map<String, _BreakInfo> _activeBreaks = {};

  // Fun facts pool (hardcoded, rotates)
  static const _funFacts = [
    '🍗 Ayam goreng terlezat sejak 2019',
    '📊 14 karyawan, 4 gerai',
    '⏰ Kiosk aktif 24/7',
    '🏆 0 absensi terlewat minggu ini',
    // ... more facts
  ];
  int _funFactIndex = 0;

  void start({required String outletId}) {
    _channel?.unsubscribe();
    _channel = SupabaseClientFactory.kiosk
        .channel('live_activity:$outletId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'attendance_logs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'scan_outlet_id',
            value: outletId,
          ),
          callback: _onAttendanceInsert,
        )
        .subscribe();

    // Rotate fun facts every 30s when nobody on break
    _funFactTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pushOverlayUpdate();
    });
  }

  void _onAttendanceInsert(PostgresChangePayload payload) {
    final data = payload.newRecord;
    final type = data['type'] as String?;
    final empId = data['employee_id'] as String?;
    if (type == null || empId == null) return;

    if (type == 'break') {
      _activeBreaks[empId] = _BreakInfo(
        employeeName: '...', // Resolve from cache
        startedAt: DateTime.now(),
      );
    } else if (type == 'kembali' || type == 'pulang') {
      _activeBreaks.remove(empId);
    }
    _pushOverlayUpdate();
  }

  void _pushOverlayUpdate() {
    final state = buildCurrentState();
    KioskBackgroundService.updateOverlayState(state);
  }

  OverlayPillState buildCurrentState() {
    if (_activeBreaks.isNotEmpty) {
      final entry = _activeBreaks.values.first;
      return OverlayPillState(
        mode: OverlayPillMode.liveIdle,
        outlet: _outletName,
        time: _formatClock(DateTime.now()),
        attendanceType: 'break',
        accentHex: '#F59E0B', // amber for break
        subtitle: '${entry.employeeName} • Istirahat',
        breakStartEpochMs: entry.startedAt.millisecondsSinceEpoch,
        breakEmployee: entry.employeeName,
      );
    }
    // No breaks — show fun fact
    _funFactIndex = (_funFactIndex + 1) % _funFacts.length;
    return OverlayPillState(
      mode: OverlayPillMode.liveIdle,
      outlet: _outletName,
      time: _formatClock(DateTime.now()),
      attendanceType: 'masuk',
      accentHex: '#22C55E',
      subtitle: _funFacts[_funFactIndex],
      breakStartEpochMs: 0,
      breakEmployee: '',
    );
  }

  void stop() {
    _channel?.unsubscribe();
    _funFactTimer?.cancel();
    _activeBreaks.clear();
  }
}
```

### Overlay UI Changes for liveIdle Mode

The expanded pill layout needs a third row for the subtitle:

```
┌──────────────────────────────────────────────┐
│  [A]  Enakko Dago           ☕    14:32      │
│       ● Istirahat • Ahmad (12m)              │
└──────────────────────────────────────────────┘

OR (fun fact mode):

┌──────────────────────────────────────────────┐
│  [A]  Enakko Dago                  14:32     │
│       🍗 Ayam goreng terlezat sejak 2019     │
└──────────────────────────────────────────────┘
```

**Overlay window height change:** Current `_kOverlayWindowHeight = 96` is sufficient — the expanded pill is 56px within a 96px window. The subtitle fits within existing space by using the second row area.

### Background Persistence: Already Solved

The foreground service (`flutter_foreground_task`) keeps the main app process alive. The `_rotateTimer` (5s) in `KioskBackgroundService` already pushes updates to the overlay. 

**What changes:** Instead of only pushing clock time, the rotation timer also consults `LiveActivityDataService.buildCurrentState()` to include break data.

**Supabase Realtime in background:** Supabase Realtime uses WebSocket which stays alive as long as the process is alive. The foreground service ensures this. No additional work needed.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Putting Supabase Calls in Overlay Process

**What people do:** Try to initialize Supabase in `overlay_task.dart` to fetch break data directly.
**Why it's wrong:** The overlay runs in a separate Flutter engine with no access to `.env`, no Supabase initialization, no auth session. It would crash or ANR.
**Do this instead:** All Supabase calls stay in main process. Push precomputed state to overlay via `shareData()`.

### Anti-Pattern 2: Adding is_archived to Every Existing Query One-by-One

**What people do:** Hunt down every `.from('employees').select()` call and add `.eq('is_archived', false)`.
**Why it's wrong:** Easy to miss queries, creates maintenance burden, violates DRY.
**Do this instead:** Create a Supabase view `active_employees` or use a helper method:
```dart
// In a query helper or extension
static PostgrestFilterBuilder<List<Map<String, dynamic>>> activeEmployees() {
  return SupabaseClientFactory.admin
      .from('employees')
      .select('*')
      .eq('is_archived', false);
}
```
Even better: use a Supabase PostgreSQL view for this since RLS policies can't be relied on (kiosk uses anon key).

### Anti-Pattern 3: Individual Inserts for CSV Import

**What people do:** Loop through CSV rows and INSERT one at a time.
**Why it's wrong:** 100 employees = 100 HTTP requests = slow, rate-limit risk, poor UX.
**Do this instead:** Batch INSERT with array payload, fallback to individual on conflict.

### Anti-Pattern 4: Polling Supabase for Break Status

**What people do:** Timer that queries `attendance_logs` every N seconds to check who's on break.
**Why it's wrong:** Wastes bandwidth, battery, and Supabase quota. Scales poorly.
**Do this instead:** Supabase Realtime subscription (already used in dashboard). Push-based, zero polling.

## Build Order & Dependencies

### Recommended Phase Structure

```
Phase 1: Soft-Archive (Foundation)     ← No dependencies, modifies Employee model
    ↓
Phase 2: CSV Import                    ← Depends on Phase 1 (needs is_archived field)
    ↓
Phase 3: Kepala Gerai SQL Script       ← Independent, can parallel with Phase 2
    ↓
Phase 4: Live Activity Pill            ← Independent of 1-3, but largest scope
```

### Dependency Graph

```
Employee model change (is_archived) ──→ Soft-archive screens
         │
         └──→ CSV import (needs to set is_archived=false on new rows)

KioskBackgroundService ──→ LiveActivityDataService (integrates into rotation timer)
OverlayPillState model ──→ overlay_task.dart rendering
Supabase Realtime ──→ LiveActivityDataService break detection
```

### Why This Order

1. **Soft-archive first:** Modifies the `Employee` model which everything depends on. Once `is_archived` field exists, all subsequent features account for it. Small, testable, shippable independently.

2. **CSV import second:** Needs the updated Employee model (sets `is_archived: false` on import). Also builds on the employees screen where "Import CSV" button lives alongside the archive UI.

3. **Kepala Gerai SQL third (or parallel):** Zero app code changes. Just a documented SQL script. Can be delivered anytime but logically groups with "admin tools."

4. **Live activity pill last:** Largest scope, touches overlay process + main process + new service + Supabase Realtime. No dependency on archive/import features. Benefits from all other features being stable before touching the sensitive overlay/background system.

## Integration Points Summary

### Files Modified (Across All Features)

| File | Features That Touch It |
|------|----------------------|
| `lib/models/employee.dart` | Archive (add fields) |
| `lib/models/overlay_pill_state.dart` | Live Activity (add liveIdle mode + fields) |
| `lib/screens/admin/admin_employees_screen.dart` | Archive (filter query, menu item, archive button) + CSV (import button) |
| `lib/screens/admin/admin_dashboard_screen.dart` | Archive (filter archived from counts) |
| `lib/screens/admin/shift_scheduler_screen.dart` | Archive (filter archived from schedule) |
| `lib/services/kiosk_background_service.dart` | Live Activity (integrate LiveActivityDataService) |
| `lib/services/employee_cache_service.dart` | Archive (exclude archived from NFC lookup) |
| `lib/overlay_task.dart` | Live Activity (render liveIdle mode) |
| `lib/app.dart` | Archive (add route) + CSV (add route) + Live Activity (lifecycle policy tweak) |
| `pubspec.yaml` | CSV Import (add file_picker, csv packages) |

### Files Created

| File | Feature |
|------|---------|
| `lib/screens/admin/archived_employees_screen.dart` | Archive |
| `lib/screens/admin/csv_import_screen.dart` | CSV Import |
| `lib/services/csv_import_service.dart` | CSV Import |
| `lib/services/live_activity_data_service.dart` | Live Activity |
| `scripts/setup_kepala_gerai.sql` | Kepala Gerai Setup |

### Database Changes

| Change | Feature |
|--------|---------|
| `ALTER TABLE employees ADD is_archived, archived_at, archived_by` | Archive |
| `CREATE INDEX idx_employees_not_archived` | Archive |
| Optional: `CREATE VIEW active_employees` | Archive (optimization) |

## Sources

- **HIGH confidence** — all findings based on direct codebase analysis:
  - `lib/overlay_task.dart` (574 lines) — full overlay rendering architecture
  - `lib/services/kiosk_background_service.dart` (581 lines) — foreground service + overlay data push
  - `lib/models/overlay_pill_state.dart` (149 lines) — wire protocol for overlay data
  - `lib/models/employee.dart` (80 lines) — current Employee model
  - `lib/screens/admin/admin_employees_screen.dart` (~1500 lines) — current CRUD patterns
  - `lib/app.dart` (249 lines) — routing + lifecycle
  - `lib/providers/app_provider.dart` — global state shape
  - `lib/services/employee_cache_service.dart` — NFC lookup cache
  - `lib/core/supabase_client.dart` — Supabase client factory
  - `pubspec.yaml` — current dependencies
  - `liveaction.md` — reference guide for live activity implementation patterns
- Supabase PostgREST bulk insert — Supabase documentation, `.insert()` accepts `List<Map>` (training data, MEDIUM confidence)
- `file_picker` ^8.0.0 and `csv` ^6.0.0 — pub.dev packages (training data, MEDIUM confidence — verify versions before adding)

---
*Architecture research for: Absensi Enakko v2.0 Admin Tools + Live Activity*
*Researched: 2025-07-14*
