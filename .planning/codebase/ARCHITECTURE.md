# Architecture

**Analysis Date:** 2026-03-04

## Pattern

- The app is a layered Flutter client with a hybrid style:
  - Feature-first screens under `lib/screens/...`
  - Shared app state in a single Riverpod notifier in `lib/providers/app_provider.dart`
  - Static service classes for external I/O in `lib/services/...`
- It is not strict Clean Architecture:
  - UI screens call Supabase directly in several places (`lib/screens/admin/...`, `lib/screens/kiosk/...`)
  - There is no repository interface layer between UI and backend.
- Runtime modes are role based:
  - Setup and kiosk operator mode
  - Admin and kepala_gerai mode with route-level access guards in `lib/app.dart`.

## Layers

### 1) Bootstrap and Runtime Wiring

- `lib/main.dart` initializes locale, dotenv, Supabase, SQLite, NFC warm-up, and launches `ProviderScope`.
- `lib/app.dart` wires `GoRouter`, auth-state listener, lifecycle hooks, and `MaterialApp.router`.

### 2) Routing and Access Control

- `routerProvider` in `lib/app.dart` is the route policy boundary.
- Redirect logic uses `AppState` flags (`isLoading`, `isAdmin`, `isKepalaGerai`, `kioskSession`) to guard `/setup`, `/kiosk/*`, and `/admin/*`.
- `ShellRoute` wraps admin pages via `lib/screens/admin/admin_shell.dart`.

### 3) Presentation Layer

- Setup flow: `lib/screens/setup/setup_screen.dart`.
- Kiosk flow: `lib/screens/kiosk/kiosk_idle_screen.dart` and `lib/screens/kiosk/kiosk_scan_screen.dart`.
- Admin flow: `lib/screens/admin/admin_dashboard_screen.dart`, `lib/screens/admin/admin_employees_screen.dart`, `lib/screens/admin/admin_reports_screen.dart`, `lib/screens/admin/admin_outlets_screen.dart`, `lib/screens/admin/shift_scheduler_screen.dart`.
- UI holds significant orchestration logic (queries, transformations, dialog flows), not just rendering.

### 4) App State Layer

- Global state shape lives in `AppState` (`lib/providers/app_provider.dart`).
- Mutations are centralized in `AppNotifier`:
  - kiosk session persistence
  - role flags
  - detected employee
  - pending sync count
  - backup mode metadata
  - overlay preference.

### 5) Service and Integration Layer

- NFC abstraction: `lib/services/nfc_service.dart`.
- Offline queue storage: `lib/services/sqlite_service.dart`.
- Queue upload orchestration: `lib/services/sync_service.dart`.
- Employee fast-path cache and backup TTL cache: `lib/services/employee_cache_service.dart`.
- Background notification and overlay orchestration: `lib/services/kiosk_background_service.dart`.
- Schedule local cache: `lib/services/schedule_sqlite_service.dart`.
- Schedule export: `lib/services/pdf_service.dart`.
- Best-effort geo capture: `lib/services/location_service.dart`.

### 6) Data and Model Layer

- Core entities and enums in `lib/models/*.dart`:
  - attendance (`attendance_log.dart`, `pending_log.dart`)
  - identity (`employee.dart`, `outlet.dart`, `kiosk_session.dart`)
  - scheduling (`shift_schedule.dart`, `time_off_request.dart`)
  - overlay payload (`overlay_pill_state.dart`).

### 7) Native Platform Layer

- Android host bridge in `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/MainActivity.kt`.
- Notification renderer in `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/KioskNotificationHelper.kt`.
- MethodChannels connect Dart service code to native notification and MIUI permission APIs.

## Data Flow

### Kiosk attendance flow (primary business flow)

1. Device bootstraps from `lib/main.dart`.
2. Session is loaded from SharedPreferences via `AppNotifier.loadSession()` in `lib/providers/app_provider.dart`.
3. `lib/screens/kiosk/kiosk_idle_screen.dart` starts NFC listener via `NfcService.startListener`.
4. Card UID resolution path:
   - Fast path: `EmployeeCacheService.get()` and backup TTL cache.
   - Slow path: Supabase lookup on `employees` using `SupabaseClientFactory.kiosk`.
5. User is routed to action screen (`/kiosk/scan`).
6. `lib/screens/kiosk/kiosk_scan_screen.dart` writes pending attendance to SQLite with `SqliteService.insertPendingLog`.
7. Background sync attempts upload via `SyncService.syncPendingLogs` and marks rows synced or failed.
8. UI updates pending badge from `SqliteService.countPendingLogs`.
9. Overlay and live notification are updated through `KioskBackgroundService.updateOverlayState`.

### Admin auth and route flow

1. Login in `lib/screens/admin/admin_login_screen.dart` uses Supabase auth.
2. Role (`admin` or `kepala_gerai`) is stored in `AppState` through notifier setters.
3. Route redirect policy in `lib/app.dart` enforces role visibility:
   - kepala_gerai blocked from `/admin/outlets`
   - kiosk session users redirected to `/kiosk` when not in admin mode.

### Schedule write-through flow

1. `lib/screens/admin/shift_scheduler_screen.dart` loads schedules from Supabase first.
2. Results are cached locally via `ScheduleSQLiteService.saveSchedule`.
3. Save action writes a new cloud schedule row plus bulk `schedule_entries`, then soft-disables the old schedule.
4. SQLite is updated as local fallback cache regardless of cloud success.

## Key Abstractions

- `AppState` and `AppNotifier` in `lib/providers/app_provider.dart`: single shared application state boundary.
- `NfcService` in `lib/services/nfc_service.dart`: multi-tech UID extraction plus session listener lifecycle.
- `SqliteService` in `lib/services/sqlite_service.dart`: offline queue schema, migrations, retry bookkeeping.
- `SyncService` in `lib/services/sync_service.dart`: transport and dedupe policy (`PostgrestException` code `23505` treated as already synced).
- `EmployeeCacheService` in `lib/services/employee_cache_service.dart`: two TTL caches (5 minutes employee data, 5 hours backup choice).
- `OverlayPillState` in `lib/models/overlay_pill_state.dart`: versioned wire payload contract between app isolate and overlay isolate.
- `ScheduleSQLiteService` in `lib/services/schedule_sqlite_service.dart`: local schedule persistence and time-off cache queries.

## Entry Points

- Flutter app entry: `main()` in `lib/main.dart`.
- Overlay isolate entry: `overlayMain()` in `lib/overlay_task.dart`.
- Root widget boundary: `AbsensiEnakkoApp` in `lib/app.dart`.
- Route graph entry: `routerProvider` in `lib/app.dart`.
- Android embedding entry: `MainActivity.configureFlutterEngine()` in `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/MainActivity.kt`.

## Practical Planning Notes

- Most feature work touches both screen logic and services because the architecture is screen-driven, not repository-driven.
- Sync and offline behavior depends on SQLite schema in `lib/services/sqlite_service.dart`; schema changes are high-impact.
- Role policy changes should be designed around `lib/app.dart` redirects first, then screen-level affordances.
- Notification and overlay changes usually require coordinated Dart and Kotlin edits across `lib/services/kiosk_background_service.dart` and Android Kotlin helpers.
