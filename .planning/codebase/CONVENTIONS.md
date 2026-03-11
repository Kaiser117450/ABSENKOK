# Coding Conventions

**Analysis Date:** 2024-12-20

## Naming Patterns

**Files:**
- Dart files: `snake_case.dart` (e.g., `admin_dashboard_screen.dart`, `nfc_service.dart`, `shift_schedule.dart`)
- Screens: `{feature}_{type}_screen.dart` pattern (e.g., `kiosk_idle_screen.dart`, `admin_employees_screen.dart`)
- Services: `{feature}_service.dart` pattern (e.g., `sqlite_service.dart`, `sync_service.dart`, `badge_service.dart`)
- Models: single noun, snake_case (e.g., `employee.dart`, `attendance_log.dart`, `kiosk_session.dart`)
- Widgets: `app_{widget_name}.dart` for reusable widgets (e.g., `app_card.dart`, `app_toast.dart`, `badge_avatar.dart`)

**Classes:**
- PascalCase for class names: `AdminDashboardScreen`, `NfcService`, `AppToast`, `ShimmerSkeleton`
- State classes: `_{ClassName}State` with leading underscore (private): `_AdminEmployeesScreenState`, `_ShimmerSkeletonState`
- Enums: PascalCase enum name, camelCase values: `AttendanceType { masuk, breakTime, pulang, kembali, sakit, izin }`
- Models: plain class name matching domain concept: `Employee`, `Outlet`, `AttendanceLog`, `KioskSession`

**Functions:**
- camelCase for functions and methods: `loadSession()`, `extractUid()`, `_formatUid()`
- Private methods prefixed with underscore: `_loadData()`, `_subscribeRealtime()`, `_buildEmployeeListShimmer()`
- Widget builder methods: `_build{ComponentName}` pattern: `_buildEmployeeListShimmer()`, `_buildSmartButtons()`
- Async futures: descriptive verb names with `async`: `Future<void> _loadOutlets() async`

**Variables:**
- camelCase for local variables and fields: `isLoading`, `scannedAt`, `selectedOutletId`
- Private fields prefixed with underscore: `_loading`, `_employees`, `_searchCtrl`, `_confettiCtrl`
- Boolean flags: `is{State}` or `has{State}` prefix: `isActive`, `isBackupMode`, `hasKiosk`, `isDraft`, `isWeekly`
- Controllers: `{name}Ctrl` suffix: `_searchCtrl`, `_confettiCtrl`, `_successScaleCtrl`
- Streams/Channels: descriptive name + type: `_channel` (RealtimeChannel), `dataStream` (Stream<String>)

**Constants:**
- SCREAMING_SNAKE_CASE for static const: `AppConstants.kioskSessionKey`, `AppColors.primary`
- Static const colors: `static const Color primary = Color(0xFFDC2626);`
- String constants in dedicated class: `AppConstants` in `lib/core/constants.dart`

## Code Style

**Formatting:**
- Tool used: Dart formatter (default Flutter SDK formatter)
- Line length: No explicit limit enforced (analysis_options.yaml uses flutter_lints defaults)
- Indentation: 2 spaces (Dart standard)
- Trailing commas: Used consistently for multi-line parameter lists and widget trees

**Linting:**
- Linter: `flutter_lints: ^5.0.0` (in pubspec.yaml dev_dependencies)
- Config: `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`
- Custom rules: None explicitly enabled/disabled — uses flutter_lints defaults
- Inline suppressions: `// ignore: avoid_print` used for production logging, `// ignore: unused_import` for overlay_task entry point

## Import Organization

**Order:**
1. Dart SDK imports: `dart:async`, `dart:io`, `dart:typed_data`, `dart:ui`
2. Flutter framework imports: `package:flutter/material.dart`, `package:flutter/services.dart`
3. Third-party package imports: `package:supabase_flutter/...`, `package:flutter_riverpod/...`, `package:go_router/...`
4. Relative imports (local project code): `../../core/supabase_client.dart`, `../../models/employee.dart`, `../../widgets/app_card.dart`

**Example from `lib/main.dart`:**
```dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'overlay_task.dart';
import 'services/nfc_service.dart';
import 'services/sqlite_service.dart';
```

**Path Aliases:**
- None configured — relative imports used throughout (`../../core/...`, `../../models/...`)
- Common pattern: imports organized by distance (local scope → app-wide core)

## State Management

**Framework:** Riverpod (`flutter_riverpod: ^2.6.1`)

**Pattern:**
- `StateNotifier<T>` for global app state: `AppNotifier extends StateNotifier<AppState>`
- `ConsumerStatefulWidget` for screens that read providers: `AdminEmployeesScreen extends ConsumerStatefulWidget`
- Local `setState()` for UI-only state (loading flags, search queries, form state)

**Provider Definition:**
```dart
// lib/providers/app_provider.dart
final appProvider = StateNotifierProvider<AppNotifier, AppState>(
  (ref) => AppNotifier(),
);
```

**Reading State:**
```dart
// In ConsumerWidget/ConsumerState:
final appState = ref.read(appProvider);      // One-time read
final appState = ref.watch(appProvider);     // Rebuild on change
ref.read(appProvider.notifier).setAdminMode(true); // Call notifier methods
```

**State Model Pattern:**
- Immutable state class with `copyWith` factory:
```dart
class AppState {
  final KioskSession? kioskSession;
  final bool isAdmin;
  final bool isLoading;
  
  const AppState({
    this.kioskSession,
    this.isAdmin = false,
    this.isLoading = true,
  });
  
  AppState copyWith({
    KioskSession? kioskSession,
    bool clearKiosk = false,
    bool? isAdmin,
    bool? isLoading,
  }) => AppState(
    kioskSession: clearKiosk ? null : (kioskSession ?? this.kioskSession),
    isAdmin: isAdmin ?? this.isAdmin,
    isLoading: isLoading ?? this.isLoading,
  );
}
```

## Widget Composition

**Preferred Pattern:** Stateless composition with builder methods for complex sections

**Example from `lib/screens/admin/admin_employees_screen.dart`:**
```dart
class _AdminEmployeesScreenState extends ConsumerState<AdminEmployeesScreen> {
  // Private builder methods for logical sections
  Widget _buildEmployeeListShimmer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Column(
        children: List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: const [
                  ShimmerSkeleton(width: 52, height: 52, borderRadius: 26),
                  SizedBox(width: 14),
                  Expanded(child: Column(...)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: _loading ? _buildEmployeeListShimmer() : _buildEmployeeList(),
    );
  }
}
```

**Const Constructors:**
- Heavily used for performance: `const EdgeInsets.all(16)`, `const SizedBox(width: 14)`, `const ShimmerSkeleton(...)`
- Widgets marked `const` whenever possible: `const AppCard(...)`, `const BadgeAvatar(...)`

## Error Handling

**Pattern:** Try-catch with graceful degradation, no throwing to user

**Supabase Query Errors:**
```dart
// lib/services/sync_service.dart
try {
  await client.from('attendance_logs').insert({...});
  await SqliteService.markLogSynced(log.localId);
  synced++;
} on PostgrestException catch (e) {
  if (e.code == '23505') {
    // Duplicate local_id — already synced, treat as success
    await SqliteService.markLogSynced(log.localId);
    synced++;
  } else {
    // ignore: avoid_print
    print('[Sync] Supabase error for ${log.localId}: ${e.message}');
    await SqliteService.markLogFailed(log.localId);
    failed++;
  }
} catch (e, stack) {
  // ignore: avoid_print
  print('[Sync] Failed to sync ${log.localId}: $e\n$stack');
  await SqliteService.markLogFailed(log.localId);
  failed++;
}
```

**Initialization Errors:**
```dart
// lib/main.dart
try {
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  supabaseReady = true;
} catch (e) {
  debugPrint('[main] Supabase.initialize error: $e');
}
```

**UI Error States:**
```dart
// lib/screens/kiosk/kiosk_scan_screen.dart
setState(() {
  _step = _ScanStep.error;
  _errorMessage = 'Terjadi kesalahan, coba lagi';
});

// Auto-reset after delay
_resetTimer = Timer(const Duration(milliseconds: 2500), () {
  if (mounted) context.pop();
});
```

**Timeout Guards:**
```dart
// lib/main.dart - NFC init with timeout
await NfcService.init().timeout(
  const Duration(seconds: 3),
  onTimeout: () {
    debugPrint('[main] NfcService.init() timed out — NFC may be off');
    return false;
  },
);
```

## Logging

**Framework:** `debugPrint` (Flutter standard)

**Patterns:**
- Prefix with context: `debugPrint('[main] Supabase.initialize error: $e');`
- Use `// ignore: avoid_print` for production logs: `// ignore: avoid_print\nprint('[Sync] Done: $synced synced');`
- Stack traces included for unexpected errors: `print('[Sync] Failed: $e\n$stack');`

**When to Log:**
- Initialization steps: `[main]`, `[NfcService]`
- Sync operations: `[Sync]`
- Background service state: `[KioskBackgroundService]`
- Error recovery: `[AppNotifier]`

**Never Logged:**
- User input (e.g., employee names, NFC UIDs in logs)
- Supabase credentials
- Session tokens

## Supabase API Calls

**Client Access:**
```dart
// lib/core/supabase_client.dart
static SupabaseClient get admin => Supabase.instance.client;
static SupabaseClient get kiosk => Supabase.instance.client;
```

**Query Pattern:**
```dart
// Select with filter, order, limit
final data = await SupabaseClientFactory.kiosk
    .from('attendance_logs')
    .select('type, scanned_at')
    .eq('employee_id', employeeId)
    .gte('scanned_at', cutoff)
    .order('scanned_at', ascending: false)
    .limit(1)
    .maybeSingle()
    .timeout(const Duration(seconds: 4));
```

**Insert Pattern:**
```dart
await client.from('attendance_logs').insert({
  'employee_id': log.employeeId,
  'scan_outlet_id': log.scanOutletId,
  'type': log.type.value,
  'scanned_at': log.scannedAt,
  'is_backup': log.isBackup,
  'notes': log.notes,
});
```

**Joined Queries:**
```dart
// Select with joins (automatic foreign key expansion)
.select('*, employees(id, name, photo_url, active_badge_id), outlets(id, name)')
```

**Realtime Subscriptions:**
```dart
_channel = SupabaseClientFactory.admin
    .channel('employees:realtime')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'employees',
      callback: (_) => _loadData(),
    )
    .subscribe();

// Cleanup in dispose
_channel?.unsubscribe();
```

**Filter Before Transform:**
```dart
// CORRECT: .eq() called before .order() (PostgrestFilterBuilder has .eq())
var empFilter = SupabaseClientFactory.admin
    .from('employees')
    .select('*')
    .eq('home_outlet_id', managedOutletId);  // Filter first
final empData = await empFilter.order('name');  // Then transform

// INCORRECT: .order() first makes .eq() unavailable (PostgrestTransformBuilder)
```

## Toast/Snackbar Usage

**Preferred:** `AppToast` wrapper for `toastification` package

**Location:** `lib/widgets/app_toast.dart`

**Patterns:**
```dart
// Success (green, 3s auto-close)
AppToast.success(context, 'Data berhasil disimpan');

// Error (red, 4s auto-close)
AppToast.error(context, 'Terjadi kesalahan, coba lagi');

// Info (blue, 3s auto-close)
AppToast.info(context, 'Sinkronisasi berjalan di latar belakang');
```

**Implementation:**
```dart
static void success(BuildContext context, String message) {
  toastification.show(
    context: context,
    type: ToastificationType.success,
    style: ToastificationStyle.flat,
    title: Text(
      message,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    autoCloseDuration: const Duration(seconds: 3),
    showProgressBar: false,
  );
}
```

**Required Setup:**
- `ToastificationWrapper` wraps `MaterialApp` in `lib/app.dart`:
```dart
@override
Widget build(BuildContext context) {
  return ToastificationWrapper(
    child: MaterialApp.router(...),
  );
}
```

## Shimmer Loading Pattern

**Widget:** `ShimmerSkeleton` in `lib/widgets/shimmer_skeleton.dart`

**Usage:**
```dart
ShimmerSkeleton(width: 200, height: 20)
ShimmerSkeleton(height: 14, borderRadius: 4)
ShimmerSkeleton(width: double.infinity, height: 16)  // Full width
```

**Implementation:**
- Pure Flutter `AnimationController` + `LinearGradient`
- No external shimmer packages
- 1500ms repeat animation
- Gray gradient colors: `#E5E7EB → #F3F4F6 → #E5E7EB`

**Pattern in Screens:**
```dart
Widget _buildEmployeeListShimmer() {
  return Column(
    children: List.generate(
      5,
      (index) => AppCard(
        child: Row(
          children: const [
            ShimmerSkeleton(width: 52, height: 52, borderRadius: 26),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerSkeleton(width: 140, height: 14, borderRadius: 4),
                  SizedBox(height: 6),
                  ShimmerSkeleton(width: 100, height: 12, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

@override
Widget build(BuildContext context) {
  return _loading ? _buildEmployeeListShimmer() : _buildActualContent();
}
```

## Model Serialization

**Pattern:** `fromJson` factory + `toJson` method

**Example from `lib/models/employee.dart`:**
```dart
class Employee {
  final String id;
  final String name;
  final String? nfcUid;
  final bool isActive;
  
  const Employee({
    required this.id,
    required this.name,
    this.nfcUid,
    required this.isActive,
  });
  
  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    id: json['id'] as String,
    name: json['name'] as String,
    nfcUid: json['nfc_uid'] as String?,
    isActive: json['is_active'] as bool? ?? true,
  );
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nfc_uid': nfcUid,
    'is_active': isActive,
  };
  
  Employee copyWith({String? nfcUid, bool? isActive}) => Employee(
    id: id,
    name: name,
    nfcUid: nfcUid ?? this.nfcUid,
    isActive: isActive ?? this.isActive,
  );
}
```

**Enum Extensions:**
```dart
enum AttendanceType { masuk, breakTime, pulang, kembali, sakit, izin }

extension AttendanceTypeExt on AttendanceType {
  String get value {
    switch (this) {
      case AttendanceType.masuk: return 'masuk';
      case AttendanceType.breakTime: return 'break';
      // ...
    }
  }
  
  static AttendanceType fromString(String s) {
    switch (s) {
      case 'masuk': return AttendanceType.masuk;
      case 'break': return AttendanceType.breakTime;
      default: return AttendanceType.masuk;
    }
  }
}
```

## Comments

**When to Comment:**
- Complex business logic: `// Safety net: no record in 24h → _lastType = null → Masuk shown (correct)`
- Platform-specific behavior: `// Android-specific lifecycle handling`
- Non-obvious intent: `// Duplicate local_id — already synced, treat as success`
- Entry points: `// @pragma("vm:entry-point")` for overlay background task
- Sync/offline queue flows: `// 1. Check network connectivity\n// 2. INSERT to Supabase\n// 3. Mark synced in SQLite`

**When NOT to Comment:**
- Self-explanatory code (no "// Load data" before `_loadData()`)
- Variable names that describe themselves: `isLoading`, `_employees`, `scannedAt`

**Doc Comments:**
- Used for public APIs and widgets:
```dart
/// Centralized toast helper wrapping toastification with brand-consistent defaults.
///
/// Requires [ToastificationWrapper] or [Toastification] at the widget tree root.
///
/// Usage:
/// ```dart
/// AppToast.success(context, 'Data berhasil disimpan');
/// AppToast.error(context, 'Terjadi kesalahan, coba lagi');
/// ```
class AppToast {
```

**Section Separators:**
```dart
// ── Smart break: fetch last attendance ────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Admin Dashboard Screen
// ─────────────────────────────────────────────────────────────────────────────
```

## Async/Await Patterns

**Future<void> for Side Effects:**
```dart
Future<void> _loadData() async {
  setState(() => _loading = true);
  try {
    final data = await SupabaseClientFactory.admin.from('employees').select('*');
    if (mounted) setState(() => _employees = data);
  } catch (e) {
    if (mounted) setState(() => _loadError = e.toString());
  }
}
```

**Timeout Guards:**
```dart
final data = await query
    .maybeSingle()
    .timeout(const Duration(seconds: 4));
```

**Mounted Checks:**
```dart
if (mounted) {
  setState(() => _loading = false);
}
```

**Unawaited Calls:**
```dart
// lib/app.dart
import 'dart:async';

unawaited(_applyLifecyclePolicy(state));
```

**Future.wait for Parallel:**
```dart
await Future.wait([
  _loadOutlets(),
  _loadEmployeeCount(),
  _loadOpenShifts(),
]);
```

---

*Convention analysis: 2024-12-20*
