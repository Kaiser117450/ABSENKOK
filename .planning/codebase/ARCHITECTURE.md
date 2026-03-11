# Architecture

**Analysis Date:** 2024-12-20

## Pattern Overview

**Overall:** Feature-based layered architecture with Riverpod state management

**Key Characteristics:**
- Clear separation between Kiosk Mode (NFC attendance scanning) and Admin Mode (management dashboard)
- Offline-first architecture with SQLite queue for unreliable network environments
- Supabase backend with realtime subscriptions for live dashboard updates
- Provider-based state management using flutter_riverpod
- Platform-specific services (Android foreground service, NFC, overlay windows)

## Layers

**Presentation Layer (Screens & Widgets):**
- Purpose: UI components organized by feature (admin/kiosk/setup)
- Location: `lib/screens/`, `lib/widgets/`
- Contains: StatefulWidgets/ConsumerWidgets, UI logic, navigation
- Depends on: Providers, Services, Models, Theme
- Used by: Router, ShellRoute wrappers

**State Management Layer (Providers):**
- Purpose: Global application state and reactive data flow
- Location: `lib/providers/`
- Contains: StateNotifier classes, Provider definitions
- Depends on: Models, SharedPreferences for persistence
- Used by: All screens via `ref.watch()` and `ref.read()`

**Service Layer:**
- Purpose: Business logic, external integrations, platform features
- Location: `lib/services/`
- Contains: NFC scanning, SQLite operations, Supabase sync, background services, caching
- Depends on: Models, Core utilities, Platform plugins
- Used by: Screens, Providers for data operations

**Data Layer (Models):**
- Purpose: Data structures and domain objects
- Location: `lib/models/`
- Contains: Immutable data classes with fromJson/toJson serialization
- Depends on: Nothing (pure data)
- Used by: All layers

**Core Layer:**
- Purpose: App-wide utilities, constants, theme, Supabase client factory
- Location: `lib/core/`
- Contains: Constants, theme definitions, client factories
- Depends on: Nothing
- Used by: All layers

## Data Flow

**Kiosk NFC Scan Flow:**

1. User taps NFC card on device (`kiosk_idle_screen.dart`)
2. `NfcService.extractUid()` reads hardware UID from any card type
3. Check `EmployeeCacheService` for cached employee (5-min TTL)
4. If cache miss, fetch employee from Supabase `employees` table by `nfc_uid`
5. Check if employee is scanning at home outlet or backup outlet
6. Navigate to `kiosk_scan_screen.dart` with detected employee
7. User selects attendance type (masuk/break/pulang/kembali/sakit/izin)
8. `SqliteService.insertPendingLog()` writes to local queue with `sync_status='pending'`
9. `SyncService.syncPendingLogs()` uploads to Supabase when connectivity available
10. On success, mark log as `sync_status='synced'` in SQLite
11. Background service shows notification and overlay pill with employee name

**Admin Dashboard Realtime Flow:**

1. Admin logs in via Supabase Auth (`admin_login_screen.dart`)
2. `AppProvider` detects auth state change and sets `isAdmin=true` or `isKepalaGerai=true`
3. Router redirects to `/admin/dashboard`
4. `AdminDashboardScreen` loads outlets, employees, attendance logs via Supabase queries
5. Subscribe to Supabase Realtime channel on `attendance_logs` table
6. On INSERT event, refresh logs list and update counters
7. Display live attendance data grouped by outlet with shimmer loading states

**State Management:**
- Global state in `AppProvider` (StateNotifier): kiosk session, admin mode, detected employee, pending count
- Local component state via StatefulWidget for UI-only concerns (animations, form inputs)
- Shared state persisted to SharedPreferences (kiosk session) for app restart recovery

## Key Abstractions

**KioskSession:**
- Purpose: Represents an active kiosk device registered to an outlet
- Examples: `lib/models/kiosk_session.dart`
- Pattern: Immutable data class with JSON serialization, persisted to SharedPreferences

**Employee:**
- Purpose: Staff member with NFC card UID, home outlet, position, active badge
- Examples: `lib/models/employee.dart`
- Pattern: Immutable model with copyWith for updates, nullable nfc_uid for pre-registration

**AttendanceLog:**
- Purpose: Single attendance event (masuk/break/pulang/kembali/sakit/izin)
- Examples: `lib/models/attendance_log.dart`
- Pattern: Enum-based type system with color/emoji/label extensions

**PendingLog:**
- Purpose: Offline queue record with sync status tracking
- Examples: `lib/models/pending_log.dart`
- Pattern: SQLite-backed queue with retry count and status enum (pending/uploading/synced/failed)

**Service Abstractions:**
- `NfcService`: Universal NFC UID extraction for e-KTP, e-Toll, Flazz, bank cards (8 card types)
- `SqliteService`: Offline queue CRUD with schema migrations
- `SyncService`: Background sync worker with connectivity check and batch processing
- `EmployeeCacheService`: In-memory cache with TTL (5 min for employee, 5 hours for backup mode)
- `KioskBackgroundService`: Android foreground service + notification + overlay pill management

## Entry Points

**Main Entry:**
- Location: `lib/main.dart`
- Triggers: App launch
- Responsibilities: Initialize Supabase, SQLite, NFC hardware, date formatting, error handlers, run ProviderScope

**Router Entry:**
- Location: `lib/app.dart` (routerProvider)
- Triggers: Navigation events, AppState changes via GoRouter refreshListenable
- Responsibilities: Route guards (setup/kiosk/admin separation), auth redirects, lifecycle management

**Overlay Entry:**
- Location: `lib/overlay_task.dart` (overlayMain)
- Triggers: Launched by KioskBackgroundService.showOverlayPill() via flutter_overlay_window
- Responsibilities: Render floating Dynamic Island-style pill notification for kiosk activity

## Error Handling

**Strategy:** Defensive programming with graceful degradation

**Patterns:**
- Try-catch blocks in async operations with setState error messages
- Timeout wrappers on network calls (15s for RPC, 3s for NFC init)
- Offline queue system: SQLite stores failed syncs for automatic retry
- Null safety throughout with nullable types for optional fields
- Error state UI: Empty state widgets, shimmer placeholders, toast notifications
- ANR prevention: Replaced SecureStorage with SharedPreferences for session (no blocking I/O)
- NFC availability polling: Periodic checks for NFC enabled state changes

## Cross-Cutting Concerns

**Logging:** `debugPrint()` throughout with prefixed tags (e.g., `[Sync]`, `[NfcService]`, `[AppNotifier]`)

**Validation:** Form validators in setup/login screens, server-side password verification via Supabase RPC

**Authentication:**
- Kiosk mode: Anonymous Supabase client + outlet password verified via `verify_kiosk_password` RPC
- Admin mode: Supabase Auth email/password with `app_role` metadata (admin/kepala_gerai)
- Role-based routing: Admin sees all outlets, Kepala Gerai sees only managed outlet

**Realtime Updates:**
- Supabase Realtime channels subscribed in admin screens
- Channel cleanup in dispose() to prevent memory leaks
- Live counters updated on INSERT/UPDATE/DELETE events

**Background Processing:**
- Android foreground service keeps kiosk alive in background
- Periodic sync triggered by app lifecycle events
- Overlay pill shows kiosk status without opening app

**Offline Resilience:**
- SQLite WAL mode for concurrent reads during sync
- Connectivity check before sync attempts
- Duplicate detection via local_id unique constraint on Supabase
- Old synced logs cleaned automatically (retention policy)

**Platform Integration:**
- Android-specific: Foreground service, NFC, SYSTEM_ALERT_WINDOW overlay permission
- iOS support limited (NFC requires foreground app, no background service)
- Orientation locked to portrait for kiosk tablets

---

*Architecture analysis: 2024-12-20*
