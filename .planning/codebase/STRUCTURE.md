# Codebase Structure

**Analysis Date:** 2026-03-04

## Directory Layout

```text
absensi_enakko_flutter/
|- lib/
|  |- main.dart
|  |- app.dart
|  |- overlay_task.dart
|  |- core/
|  |- models/
|  |- providers/
|  |- services/
|  `- screens/
|- android/
|- assets/
|- test/
|- .planning/codebase/
|- pubspec.yaml
|- analysis_options.yaml
`- README.md
```

## Top-Level Folders and Purpose

- `lib/`: all Dart application code.
- `android/`: Android host app, permissions, MethodChannel handlers, and custom notification layouts.
- `assets/`: static images (`assets/icon.png`, `assets/images/logo_enakko.png`).
- `test/`: widget and model tests (overlay and report placeholders included).
- `.planning/codebase/`: planning artifacts used by GSD mapping flow.
- `.codex/skills/`: local skill definitions and workflow adapters.

## `lib/` Module Map

### Boot and App Shell

- `lib/main.dart`: runtime bootstrap (dotenv, Supabase init, SQLite init, NFC warm-up, app launch).
- `lib/app.dart`: router definition, redirects, app lifecycle handling, auth listener.
- `lib/overlay_task.dart`: second Flutter entrypoint for floating overlay UI.

### Core

- `lib/core/constants.dart`: app constants (DB version, NFC debounce, sync retries, UI timings).
- `lib/core/theme.dart`: design tokens and `ThemeData` builder.
- `lib/core/supabase_client.dart`: central Supabase client access (`admin` and `kiosk`).

### State

- `lib/providers/app_provider.dart`: `AppState` + `AppNotifier` + `appProvider`.
- This is the only global Riverpod state file; most other state remains local to screens.

### Models

- Attendance and sync: `lib/models/attendance_log.dart`, `lib/models/pending_log.dart`.
- Identity and session: `lib/models/employee.dart`, `lib/models/outlet.dart`, `lib/models/kiosk_session.dart`.
- Scheduling: `lib/models/shift_schedule.dart`, `lib/models/time_off_request.dart`.
- Overlay payload contract: `lib/models/overlay_pill_state.dart`.

### Services

- NFC and scanning: `lib/services/nfc_service.dart`.
- Offline queue: `lib/services/sqlite_service.dart`.
- Queue sync to cloud: `lib/services/sync_service.dart`.
- Employee cache and backup mode cache: `lib/services/employee_cache_service.dart`.
- Background and overlay control: `lib/services/kiosk_background_service.dart`.
- Location capture: `lib/services/location_service.dart`.
- Scheduling helpers and persistence: `lib/services/schedule_generator.dart`, `lib/services/schedule_sqlite_service.dart`.
- PDF export: `lib/services/pdf_service.dart`.

### Screens

- Setup: `lib/screens/setup/setup_screen.dart`.
- Kiosk runtime: `lib/screens/kiosk/kiosk_idle_screen.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`.
- Admin shell: `lib/screens/admin/admin_shell.dart`, `lib/screens/admin/admin_login_screen.dart`.
- Admin modules:
  - dashboard: `lib/screens/admin/admin_dashboard_screen.dart`
  - employees: `lib/screens/admin/admin_employees_screen.dart`
  - reports: `lib/screens/admin/admin_reports_screen.dart`
  - outlets: `lib/screens/admin/admin_outlets_screen.dart`
  - scheduling: `lib/screens/admin/shift_scheduler_screen.dart`
  - sakit/izin input dialog: `lib/screens/admin/sakit_izin_dialog.dart`

## Native and Platform Structure

- Android manifest and permissions: `android/app/src/main/AndroidManifest.xml`.
- Flutter activity + MethodChannels: `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/MainActivity.kt`.
- Custom notification rendering: `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/KioskNotificationHelper.kt`.
- Notification layouts: `android/app/src/main/res/layout/notification_kiosk.xml`, `android/app/src/main/res/layout/notification_kiosk_expanded.xml`.

## Naming Conventions in This Repository

- Dart files use `snake_case` (`admin_reports_screen.dart`, `schedule_sqlite_service.dart`).
- Screen files follow `*_screen.dart` under role folders (`lib/screens/admin/`, `lib/screens/kiosk/`, `lib/screens/setup/`).
- Service files follow `*_service.dart` under `lib/services/`.
- Model files are singular nouns (`employee.dart`, `outlet.dart`, `kiosk_session.dart`).
- Class and enum type names use `PascalCase` (`AppState`, `AttendanceType`, `ShiftTemplate`).
- Variables and methods use `camelCase`; private members are prefixed with `_`.
- The repo currently includes local recovery copies (`.backup`, `.backup2`, `.backup3`, `.checkpoint`) alongside some source files in `lib/`.

## Where Key Concerns Live

- Role-based navigation and guards: `lib/app.dart`.
- Session persistence and role flags: `lib/providers/app_provider.dart`.
- Kiosk activation RPC and device session creation: `lib/screens/setup/setup_screen.dart`.
- NFC detection + fast/slow employee lookup path: `lib/screens/kiosk/kiosk_idle_screen.dart` and `lib/services/nfc_service.dart`.
- Attendance submission and offline-first insert: `lib/screens/kiosk/kiosk_scan_screen.dart` + `lib/services/sqlite_service.dart`.
- Cloud sync retry and dedupe policy: `lib/services/sync_service.dart`.
- Floating overlay UI and payload parsing: `lib/overlay_task.dart` + `lib/models/overlay_pill_state.dart`.
- Live notification orchestration: `lib/services/kiosk_background_service.dart` + Android Kotlin helper files.
- Employee CRUD and NFC card assignment: `lib/screens/admin/admin_employees_screen.dart`.
- Outlet CRUD and password RPC workflows: `lib/screens/admin/admin_outlets_screen.dart`.
- Daily report and rekap computation logic: `lib/screens/admin/admin_reports_screen.dart`.
- Shift scheduling, cloud write-through, and offline cache fallback: `lib/screens/admin/shift_scheduler_screen.dart` + `lib/services/schedule_sqlite_service.dart`.
- Sakit/izin admin input and schedule mutation: `lib/screens/admin/sakit_izin_dialog.dart`.

## Practical Planning Notes

- High-churn files for product changes are concentrated in `lib/screens/admin/*.dart` and `lib/screens/kiosk/*.dart`.
- Offline behavior depends on schema in `lib/services/sqlite_service.dart` and schedule cache in `lib/services/schedule_sqlite_service.dart`.
- Changes to notification or overlay behavior are cross-layer and usually require edits in both `lib/services/kiosk_background_service.dart` and `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/*.kt`.
- The repository is feature-rich but does not isolate data access behind repositories, so structural refactors should plan for direct Supabase calls inside UI files.
