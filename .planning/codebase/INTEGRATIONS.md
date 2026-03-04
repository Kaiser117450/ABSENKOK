# Integrations Map

## Scope
- This document maps external and native integrations used by the current code under `lib/` and `android/`.
- Integration bootstrap starts in `lib/main.dart` and Android permission wiring is in `android/app/src/main/AndroidManifest.xml`.

## Supabase Backend Integration
- Supabase is initialized in `lib/main.dart` using `SUPABASE_URL` and `SUPABASE_ANON_KEY` loaded from `.env`.
- Shared client factory is in `lib/core/supabase_client.dart` (`SupabaseClientFactory.admin` and `.kiosk` currently return the same `Supabase.instance.client`).
- Kiosk setup calls RPC `verify_kiosk_password` in `lib/screens/setup/setup_screen.dart`.
- Admin login uses `signInWithPassword` in `lib/screens/admin/admin_login_screen.dart`.
- Admin logout uses `auth.signOut()` in `lib/screens/admin/admin_login_screen.dart` and `lib/screens/admin/admin_shell.dart`.
- Auth role routing (`app_role`, `managed_outlet_id`) is applied in `lib/app.dart` and `lib/screens/admin/admin_login_screen.dart`.

## Supabase Tables Used by App Code
- `attendance_logs` is queried/inserted from `lib/services/sync_service.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`, `lib/screens/admin/admin_dashboard_screen.dart`, and `lib/screens/admin/admin_reports_screen.dart`.
- `employees` is queried/updated/inserted from `lib/screens/kiosk/kiosk_idle_screen.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`, `lib/screens/admin/admin_employees_screen.dart`, `lib/screens/admin/admin_dashboard_screen.dart`, and `lib/screens/admin/shift_scheduler_screen.dart`.
- `outlets` is queried/updated from `lib/screens/admin/admin_outlets_screen.dart`, `lib/screens/admin/admin_dashboard_screen.dart`, `lib/screens/admin/admin_employees_screen.dart`, and `lib/screens/admin/admin_reports_screen.dart`.
- `schedules` is queried/inserted/updated in `lib/screens/admin/shift_scheduler_screen.dart`.
- `schedule_entries` is queried/inserted in `lib/screens/admin/shift_scheduler_screen.dart`.
- `time_off_requests` is queried/inserted in `lib/screens/admin/shift_scheduler_screen.dart`.

## Supabase RPC Contracts
- `verify_kiosk_password` in `lib/screens/setup/setup_screen.dart` (device activation by outlet name + password).
- `create_outlet_with_password` in `lib/screens/admin/admin_outlets_screen.dart` and `lib/screens/admin/admin_dashboard_screen.dart`.
- `update_outlet_password` in `lib/screens/admin/admin_outlets_screen.dart`.

## Supabase Realtime Channels
- `employees:realtime` on `employees` table in `lib/screens/admin/admin_employees_screen.dart`.
- `dashboard:attendance_logs` on `attendance_logs` inserts in `lib/screens/admin/admin_dashboard_screen.dart`.
- `dashboard:employees` on `employees` changes in `lib/screens/admin/admin_dashboard_screen.dart`.

## Local Database Integrations (Offline First)
- Local attendance queue DB is managed in `lib/services/sqlite_service.dart` using `sqflite` and file name from `lib/core/constants.dart` (`absensi_enakko.db`).
- Queue table is `pending_logs` with sync lifecycle (`pending`, `uploading`, `synced`, `failed`) in `lib/services/sqlite_service.dart`.
- Cloud sync loop is in `lib/services/sync_service.dart` and checks network via `connectivity_plus` before upload.
- Duplicate insert handling depends on Postgres error code `23505` in `lib/services/sync_service.dart`.
- Local schedule cache DB is in `lib/services/schedule_sqlite_service.dart` (`shift_schedules.db`, tables `schedules` and `time_off_requests`).

## NFC Integration
- Dart NFC abstraction is in `lib/services/nfc_service.dart` using `nfc_manager`.
- Listener lifecycle is started from `lib/screens/kiosk/kiosk_idle_screen.dart`.
- Android NFC intent filters and required feature are declared in `android/app/src/main/AndroidManifest.xml`.
- Full tech filter list is in `android/app/src/main/res/xml/nfc_tech_filter.xml`.
- Main activity is `singleTop` and receives NFC intents in `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/MainActivity.kt`.

## Location Integration
- GPS capture uses `geolocator` in `lib/services/location_service.dart`.
- Attendance submit flow calls best-effort location capture in `lib/screens/kiosk/kiosk_scan_screen.dart`.
- Required location permissions are declared in `android/app/src/main/AndroidManifest.xml`.

## Notifications, Foreground Service, and Overlay
- Orchestration service is `lib/services/kiosk_background_service.dart`.
- Method channel `com.enakko.kiosk/notification` bridges to Kotlin in `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/MainActivity.kt` and `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/KioskNotificationHelper.kt`.
- Method channel `com.enakko.kiosk/miui_perms` is used for MIUI/HyperOS permission deep-link in the same `MainActivity.kt`.
- Custom RemoteViews notification layouts are in `android/app/src/main/res/layout/notification_kiosk.xml` and `android/app/src/main/res/layout/notification_kiosk_expanded.xml`.
- Android foreground task service class is declared in `android/app/src/main/AndroidManifest.xml` (`com.pravera.flutter_foreground_task.service.ForegroundTaskService`).
- Floating overlay entrypoint is `overlayMain()` in `lib/overlay_task.dart` and runtime control uses `flutter_overlay_window` in `lib/services/kiosk_background_service.dart`.
- Overlay permission (`SYSTEM_ALERT_WINDOW`) and notification permission (`POST_NOTIFICATIONS`) are requested through this flow.

## Session and Local Preferences Integration
- Kiosk session persistence uses `shared_preferences` in `lib/providers/app_provider.dart`.
- Keys are defined in `lib/core/constants.dart` (`kioskSessionKey`, `overlayKeepForegroundKey`).

## File Export and Share Integrations
- CSV export writes to temp storage via `path_provider` and shares via `share_plus` in `lib/screens/admin/admin_reports_screen.dart`.
- PDF schedule export is generated via `pdf` and shared via `share_plus` in `lib/services/pdf_service.dart`.
- Android file sharing path mapping exists in `android/app/src/main/res/xml/file_paths.xml`.

## Remote Media Integration
- Employee photo URLs are rendered via `cached_network_image` in `lib/screens/kiosk/kiosk_idle_screen.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`, and `lib/screens/admin/admin_dashboard_screen.dart`.
- Storage backend is not called directly via Supabase Storage SDK in current code; app consumes URL strings from `employees.photo_url` records.

## Environment and Secret Wiring
- `.env` currently defines `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `KIOSK_JWT`.
- Runtime code reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `lib/main.dart`.
- `KIOSK_JWT` is present in `.env` but has no direct usage under `lib/` today.

## Integration Gaps and Planning Risks
- No external crash/error telemetry integration is configured (no Sentry/Crashlytics usage under `lib/`).
- Admin and kiosk share one Supabase client surface in `lib/core/supabase_client.dart`; separation of privileges relies on backend policy and flow control.
- Android permissions are broad in `android/app/src/main/AndroidManifest.xml` (including legacy storage permissions), so future SDK policy updates may require cleanup.
