# Codebase Structure

**Analysis Date:** 2024-12-20

## Directory Layout

```
absensi_enakko_flutter/
├── lib/
│   ├── core/                 # App-wide utilities and configuration
│   ├── models/               # Data classes and domain objects
│   ├── providers/            # Riverpod state management
│   ├── screens/              # Feature-organized UI screens
│   │   ├── admin/            # Admin dashboard and management screens
│   │   ├── kiosk/            # NFC scanning kiosk screens
│   │   └── setup/            # Initial device setup screen
│   ├── services/             # Business logic and platform integrations
│   ├── widgets/              # Reusable UI components
│   ├── app.dart              # Router configuration and root app widget
│   ├── main.dart             # Entry point and initialization
│   └── overlay_task.dart     # Overlay window entry point
├── android/                  # Android native project
├── assets/                   # Static resources (images, etc.)
├── test/                     # Unit and widget tests
├── .env                      # Environment variables (Supabase credentials)
├── pubspec.yaml              # Dependencies and project metadata
└── README.md                 # Project documentation
```

## Directory Purposes

**`lib/core/`:**
- Purpose: Shared utilities, constants, theme, and client factories
- Contains: Configuration files, theme definitions, Supabase client wrapper
- Key files: `constants.dart`, `theme.dart`, `supabase_client.dart`

**`lib/models/`:**
- Purpose: Data structures representing domain entities
- Contains: Immutable classes with JSON serialization (fromJson/toJson)
- Key files: `employee.dart`, `attendance_log.dart`, `kiosk_session.dart`, `outlet.dart`, `pending_log.dart`, `shift_schedule.dart`, `time_off_request.dart`, `employee_badge.dart`, `daily_summary.dart`, `overlay_pill_state.dart`

**`lib/providers/`:**
- Purpose: Global state management with Riverpod
- Contains: StateNotifier classes and provider definitions
- Key files: `app_provider.dart` (main app state: kiosk session, admin mode, detected employee)

**`lib/screens/admin/`:**
- Purpose: Admin dashboard and management interfaces
- Contains: Screens accessible only to authenticated admin/kepala_gerai users
- Key files: 
  - `admin_shell.dart` (wrapper with AppBar + BottomNav)
  - `admin_login_screen.dart` (Supabase Auth login)
  - `admin_dashboard_screen.dart` (realtime attendance overview)
  - `admin_employees_screen.dart` (CRUD for employees + NFC registration)
  - `admin_outlets_screen.dart` (outlet management, admin-only)
  - `admin_reports_screen.dart` (CSV export, date range filtering)
  - `shift_scheduler_screen.dart` (shift schedule management)
  - `badge_management_screen.dart` (employee badge/uniform tracking)
  - `sakit_izin_list_screen.dart` (sick leave and permission requests)
  - `sakit_izin_dialog.dart` (dialog for sakit/izin input)

**`lib/screens/kiosk/`:**
- Purpose: NFC attendance scanning interface for kiosk devices
- Contains: Idle screen (NFC listener) and scan confirmation screen
- Key files: 
  - `kiosk_idle_screen.dart` (main NFC scan listener with pulse animation)
  - `kiosk_scan_screen.dart` (attendance type selection after NFC tap)

**`lib/screens/setup/`:**
- Purpose: Initial device setup for kiosk mode
- Contains: Outlet selection and password verification screen
- Key files: `setup_screen.dart` (verifies kiosk password via Supabase RPC)

**`lib/services/`:**
- Purpose: Business logic, external integrations, platform features
- Contains: NFC handling, SQLite queue, sync logic, caching, background services
- Key files:
  - `nfc_service.dart` (universal NFC UID extraction for 8+ card types)
  - `sqlite_service.dart` (offline queue CRUD with schema migrations)
  - `sync_service.dart` (background sync to Supabase with retry logic)
  - `employee_cache_service.dart` (in-memory cache with TTL, mutex locking)
  - `kiosk_background_service.dart` (Android foreground service + notifications)
  - `location_service.dart` (GPS coordinates for attendance logs)
  - `badge_service.dart` (employee badge data fetching)
  - `pdf_service.dart`, `pdf_report_service.dart` (PDF generation for reports)
  - `schedule_generator.dart`, `schedule_sqlite_service.dart` (shift scheduling)

**`lib/widgets/`:**
- Purpose: Reusable UI components used across screens
- Contains: Custom widgets for consistent design system
- Key files:
  - `app_card.dart` (standardized card component)
  - `app_badge.dart` (badge/chip component)
  - `app_empty_state.dart` (empty state placeholder)
  - `app_toast.dart` (toast notification helper)
  - `badge_avatar.dart` (employee avatar with badge overlay)
  - `shimmer_skeleton.dart` (loading placeholder skeleton)

## Key File Locations

**Entry Points:**
- `lib/main.dart`: App initialization (Supabase, SQLite, NFC, date formatting, error handlers)
- `lib/app.dart`: Router configuration with GoRouter, auth guards, ShellRoute for admin
- `lib/overlay_task.dart`: Overlay window entry point (Dynamic Island-style pill)

**Configuration:**
- `lib/core/constants.dart`: App-wide constants (DB version, sync settings, UI timings)
- `lib/core/theme.dart`: Material theme, colors, text styles
- `lib/core/supabase_client.dart`: Supabase client factory (admin/kiosk clients)
- `.env`: Supabase URL and anon key (NOT committed to git)
- `pubspec.yaml`: Dependencies, app version, SDK constraints

**Core Logic:**
- `lib/providers/app_provider.dart`: Global app state (kiosk session, admin mode, detected employee, pending count, backup mode)
- `lib/services/nfc_service.dart`: NFC scanning with universal UID extraction
- `lib/services/sqlite_service.dart`: Offline queue with pending_logs table
- `lib/services/sync_service.dart`: Background sync worker

**Testing:**
- `test/`: Unit and widget tests (currently minimal)

## Naming Conventions

**Files:**
- `snake_case.dart` for all Dart files
- Screen files: `{feature}_{screen_type}.dart` (e.g., `admin_dashboard_screen.dart`, `kiosk_idle_screen.dart`)
- Service files: `{domain}_service.dart` (e.g., `nfc_service.dart`, `sqlite_service.dart`)
- Model files: `{entity}.dart` (e.g., `employee.dart`, `attendance_log.dart`)
- Widget files: `{component_name}.dart` (e.g., `app_card.dart`, `shimmer_skeleton.dart`)

**Directories:**
- `snake_case/` for all directories
- Feature grouping: `screens/{feature}/` (e.g., `screens/admin/`, `screens/kiosk/`)

**Classes:**
- `PascalCase` for class names
- Screens: `{Feature}{Descriptor}Screen` (e.g., `AdminDashboardScreen`, `KioskIdleScreen`)
- Widgets: `{ComponentName}` or `_{PrivateComponentName}` for internal widgets (e.g., `AppCard`, `_EnakkoAppBar`)
- Models: `{EntityName}` (e.g., `Employee`, `AttendanceLog`, `KioskSession`)
- Services: `{Domain}Service` (e.g., `NfcService`, `SqliteService`, `SyncService`)
- Providers: `{Feature}Provider` or `{Feature}Notifier` (e.g., `AppNotifier`, `appProvider`)

**Variables:**
- `camelCase` for variables and parameters
- Private fields: `_fieldName` with underscore prefix
- Boolean flags: `isActive`, `hasKiosk`, `_isLoading`
- Controllers: `{purpose}Ctrl` suffix (e.g., `_outletNameCtrl`, `_passwordCtrl`)

**Constants:**
- `camelCase` for const variables in classes
- UPPER_SNAKE_CASE for static const in utility classes (e.g., `AppConstants.kioskSessionKey`)

## Where to Add New Code

**New Admin Screen:**
- Primary code: `lib/screens/admin/{feature}_screen.dart`
- Add route in `lib/app.dart` under ShellRoute routes
- Add navigation item in `lib/screens/admin/admin_shell.dart` (_EnakkoBottomNav)
- Add realtime subscription if data updates needed
- Tests: `test/screens/admin/{feature}_screen_test.dart`

**New Kiosk Screen:**
- Primary code: `lib/screens/kiosk/{feature}_screen.dart`
- Add route in `lib/app.dart` under `/kiosk` GoRoute
- Handle NFC state management via `AppProvider`
- Tests: `test/screens/kiosk/{feature}_screen_test.dart`

**New Feature/Mode:**
- Create new directory: `lib/screens/{feature}/`
- Add router entry in `lib/app.dart`
- Add auth guard logic in router redirect function
- Update `AppProvider` if new state needed

**New Component/Module:**
- Implementation: `lib/widgets/{component_name}.dart`
- Export commonly-used widgets for easy imports
- Follow existing widget patterns (StatelessWidget or custom StatefulWidget)

**New Model:**
- Implementation: `lib/models/{entity}.dart`
- Include `fromJson` factory and `toJson` method for Supabase integration
- Use immutable fields (`final`) with `copyWith` for updates
- Add to Supabase table schema if needed

**New Service:**
- Implementation: `lib/services/{domain}_service.dart`
- Use static methods for stateless services (e.g., `NfcService`, `SqliteService`)
- Use singleton pattern for stateful services (e.g., `EmployeeCacheService.instance`)
- Add initialization in `lib/main.dart` if required on app startup

**Utilities:**
- Shared helpers: `lib/core/{utility_name}.dart`
- Constants: Add to `lib/core/constants.dart` (organized by category)
- Theme updates: `lib/core/theme.dart` (colors, text styles, component themes)

## Special Directories

**`.planning/`:**
- Purpose: GSD codebase mapping and planning documents
- Generated: Yes (by GSD tools)
- Committed: Yes (part of repository for reference)

**`build/`:**
- Purpose: Compiled output (APK, iOS app)
- Generated: Yes (by `flutter build`)
- Committed: No (in `.gitignore`)

**`.dart_tool/`:**
- Purpose: Dart analyzer cache and package metadata
- Generated: Yes (by Dart SDK)
- Committed: No (in `.gitignore`)

**`android/` and `ios/`:**
- Purpose: Native platform projects
- Generated: Initially by `flutter create`, modified for native features
- Committed: Yes (contains custom native code for foreground service, NFC config)

**`assets/`:**
- Purpose: Static resources (images, fonts, etc.)
- Generated: No (manually added)
- Committed: Yes

**`.env`:**
- Purpose: Environment variables (Supabase URL, anon key)
- Generated: No (manually created)
- Committed: No (in `.gitignore`, contains secrets)

## Backup and Checkpoint Files

**Pattern:** Files with `.backup`, `.backup2`, `.backup3`, `.checkpoint`, `.checkpoint2` suffixes

**Examples:**
- `lib/providers/app_provider.dart.backup`
- `lib/screens/admin/admin_dashboard_screen.dart.backup3`
- `lib/models/attendance_log.dart.checkpoint2`
- `lib/services/sync_service.dart.checkpoint2`

**Purpose:** Manual version control during development (likely created by fix scripts in root directory)

**Status:** Not used by app at runtime, can be cleaned up

**Fix Scripts in Root:**
- Multiple Python scripts (`fix_*.py`, `convert_*.py`, `step*.py`) for automated code transformations
- Shell scripts (`fix_*.sh`, `sed_*.sh`) for text replacements
- Likely used during refactoring/bug fixing iterations
- Not part of app runtime, development artifacts only

---

*Structure analysis: 2024-12-20*
