# Coding Conventions

Last updated: 2026-03-04

## Scope and source of truth
- This document reflects active app code in `lib/` and lint config in `analysis_options.yaml`.
- The repository also contains many snapshot files (`*.dart.backup`, `*.dart.checkpoint`). Follow active `.dart` files for planning and implementation decisions.
- Key reference files for conventions are `lib/main.dart`, `lib/app.dart`, `lib/providers/app_provider.dart`, `lib/services/sqlite_service.dart`, and `lib/services/sync_service.dart`.

## Style baseline
- Lints are inherited from `package:flutter_lints/flutter.yaml` through `analysis_options.yaml`.
- No project-specific lint overrides are currently configured in `analysis_options.yaml`.
- Dart style is standard: 2-space indentation, trailing commas in multiline widget trees, and `const` constructors/widgets where practical.
- Imports generally follow `dart:` first, `package:` second, then relative imports (example patterns in `lib/app.dart` and `lib/screens/setup/setup_screen.dart`).

## Naming conventions
- File names are snake_case, for example `lib/screens/admin/admin_login_screen.dart` and `lib/services/kiosk_background_service.dart`.
- Screen files usually use the `_screen.dart` suffix under `lib/screens/`.
- Service files usually use the `_service.dart` suffix under `lib/services/`.
- Provider files use `_provider.dart`, for example `lib/providers/app_provider.dart`.
- Model files use singular nouns (`lib/models/employee.dart`, `lib/models/attendance_log.dart`, `lib/models/overlay_pill_state.dart`).
- Types use PascalCase (`AppState`, `AppNotifier`, `KioskOverlayUI`, `AttendanceLog`).
- Methods and variables use lowerCamelCase (`loadSession`, `setBackupMode`, `pendingCount`).
- Private members and helper types use a leading underscore (`_AppStateListenable`, `_ScanStep`, `_kNotifIdScan`).
- Provider identifiers end with `Provider` (`appProvider`, `routerProvider`).

## Architectural patterns
- Routing and route guards are centralized in `lib/app.dart` via a `GoRouter` provider.
- Shared application state is centralized in `lib/providers/app_provider.dart` using `StateNotifierProvider`.
- UI workflows live in `lib/screens/`, while side-effect and IO logic lives in `lib/services/`.
- Model parsing and data shape logic stays in `lib/models/` with factory constructors and helpers.
- App-wide constants and theme tokens are centralized in `lib/core/constants.dart` and `lib/core/theme.dart`.
- Services are mostly static API surfaces instead of injected instances (`SqliteService`, `SyncService`, `NfcService`, `LocationService`).

## State management conventions
- Global state uses Riverpod: `StateNotifierProvider<AppNotifier, AppState>` in `lib/providers/app_provider.dart`.
- `AppState` is immutable (`final` fields + `copyWith`) and uses explicit clear flags (`clearKiosk`, `clearEmployee`, `clearBackup`) to avoid ambiguous null writes.
- Screens mix Riverpod state and local widget state:
  - Shared cross-screen data via `ref.watch` and `ref.read`.
  - Transient UI flags via `setState` (loading/error/animation), for example in `lib/screens/admin/admin_login_screen.dart` and `lib/screens/kiosk/kiosk_scan_screen.dart`.
- Startup and lifecycle side effects use `WidgetsBinding.instance.addPostFrameCallback` and `WidgetsBindingObserver` in `lib/app.dart`.

## Data and serialization patterns
- Models commonly use `const` constructors and `factory ...fromJson` (`lib/models/employee.dart`, `lib/models/kiosk_session.dart`, `lib/models/shift_schedule.dart`).
- Parsing is defensive with nullable casts and defaults (`as String? ?? ''`, `as bool? ?? false`) in files like `lib/models/attendance_log.dart`.
- Enum string mapping is centralized in extensions, for example `AttendanceTypeExt` in `lib/models/attendance_log.dart`.
- Record typedefs are used for compact multi-value returns (`SyncResult` in `lib/services/sync_service.dart`, `LatLng` in `lib/services/location_service.dart`).

## Async and side-effect conventions
- External boundaries (network, device APIs, storage) are wrapped in `try/catch`.
- Risky operations commonly use explicit timeout guards, for example in `lib/main.dart`, `lib/screens/setup/setup_screen.dart`, and `lib/screens/admin/admin_login_screen.dart`.
- `mounted` checks are standard before calling `setState` after async gaps.
- Best-effort behavior is preferred over app-breaking failures:
  - `LocationService.getCurrentPosition()` returns `null` on failure (`lib/services/location_service.dart`).
  - `AppNotifier.loadSession()` always unblocks loading in `finally` (`lib/providers/app_provider.dart`).
  - Sync flow marks failed rows and continues processing (`lib/services/sync_service.dart`).

## Error handling and logging conventions
- Typed exceptions are handled where available (`AuthException`, `PostgrestException`).
- Generic catch blocks often include stack traces for diagnostics (`catch (e, stack)`).
- User-visible failures are surfaced through local UI state (`_error`) in screen widgets, rather than rethrowing to UI.
- Logging is tag-based with bracket prefixes (`[main]`, `[Sync]`, `[BgService]`, `[KioskIdle]`).
- Both `debugPrint` and `print` are in use; `print` usage is explicitly lint-suppressed where intentional (`lib/services/sync_service.dart`, `lib/services/nfc_service.dart`, `lib/services/location_service.dart`).
- Global uncaught error hooks are set in `lib/main.dart` (`FlutterError.onError`, `PlatformDispatcher.instance.onError`).

## Practical guardrails for new code
- Put new cross-screen state in `AppState` and mutate via `AppNotifier` methods.
- Keep widgets focused on orchestration and rendering; place IO in services under `lib/services/`.
- Reuse timing/retry constants in `lib/core/constants.dart` instead of adding magic numbers.
- Keep the established failure pattern: timeout guard, typed catch where possible, mounted check, and user-safe fallback message.
- Preserve tag-based logs for troubleshooting and avoid silent catches unless non-blocking behavior is intentional.
