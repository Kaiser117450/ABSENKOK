# External Integrations

**Analysis Date:** 2026-03-11

## APIs & External Services

**Backend as a Service:**
- Supabase - PostgreSQL database, authentication, realtime subscriptions, RPC functions
  - SDK/Client: `supabase_flutter ^2.8.4`
  - Auth: `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `.env`
  - Initialization: `lib/main.dart` (lines 59-72) with PKCE auth flow
  - Client factory: `lib/core/supabase_client.dart` exposes `SupabaseClientFactory.admin` and `SupabaseClientFactory.kiosk`
  - Global readiness flag: `supabaseReady` boolean in `lib/main.dart`

## Data Storage

**Databases:**

**Primary: Supabase (PostgreSQL)**
- Connection: Environment variables `SUPABASE_URL` + `SUPABASE_ANON_KEY`
- Client: `supabase_flutter` SDK with anon key (kiosk) and email/password auth (admin)

**Supabase Tables:**

| Table Name | Purpose | Key Fields | Access Pattern |
|------------|---------|------------|----------------|
| `employees` | Employee records | `id`, `name`, `nfc_uid`, `home_outlet_id`, `position`, `is_active`, `employee_code`, `photo_url`, `active_badge_id` | CRUD in `lib/screens/admin/admin_employees_screen.dart`, realtime subscription for updates |
| `outlets` | Restaurant locations | `id`, `name`, `is_active`, `kiosk_password` (bcrypt hash) | CRUD in `lib/screens/admin/admin_outlets_screen.dart`, filter queries by `is_active=true` |
| `attendance_logs` | Attendance records | `employee_id`, `scan_outlet_id`, `type` (masuk/break/pulang/kembali/sakit/izin), `scanned_at`, `lat`, `lng`, `device_id`, `local_id` (unique), `is_backup`, `notes` | INSERT in `lib/services/sync_service.dart`, SELECT queries in reports `lib/screens/admin/admin_reports_screen.dart`, realtime subscription in dashboard |
| `badges` | Employee badge definitions | `id`, `name`, `icon_url`, `color` | SELECT all in `lib/services/badge_service.dart` (in-memory cache), UPDATE `employees.active_badge_id` for assignment |
| `schedules` | Shift schedule headers | `id`, `name`, `start_date`, `end_date`, `outlet_id` | CRUD in `lib/screens/admin/shift_scheduler_screen.dart` |
| `schedule_entries` | Individual shift assignments | `schedule_id`, `employee_id`, `date`, `shift_type` | Batch INSERT/DELETE in shift scheduler |
| `time_off_requests` | Sakit/izin requests | `employee_id`, `start_date`, `end_date`, `type` (sakit/izin), `reason`, `status` | CRUD in `lib/screens/admin/sakit_izin_list_screen.dart`, INSERT in dialog, queries in scheduler for calendar view |

**Realtime Subscriptions:**
- `dashboard:attendance_logs` - Subscribes to INSERT events on `attendance_logs` table in `lib/screens/admin/admin_dashboard_screen.dart` (line 317)
- `dashboard:employees` - Subscribes to ALL events on `employees` table in dashboard (line 333)
- `employees:realtime` - Subscribes to ALL events on `employees` table in employees screen (line 61 of `lib/screens/admin/admin_employees_screen.dart`)

**Supabase RPC Functions:**
- `verify_kiosk_password` - Server-side bcrypt password verification for kiosk setup
  - Params: `p_outlet_name` (string), `p_password` (string)
  - Returns: `{ outlet_id, outlet_name, success }` or null
  - Called in `lib/screens/setup/setup_screen.dart` (lines 58-65)
  - Timeout: 15 seconds to prevent ANR

**Local: SQLite Offline Queue**
- Database: `absensi_enakko.db` (v5)
- Connection: `sqflite` package via `lib/services/sqlite_service.dart`
- Client: `sqflite` ORM
- WAL mode enabled for concurrent reads

**SQLite Tables:**
- `pending_logs` - Offline attendance queue
  - Schema: `local_id` (TEXT PK), `employee_id`, `scan_outlet_id`, `type`, `lat`, `lng`, `device_id`, `scanned_at`, `sync_status` (pending/uploading/synced/failed), `retry_count`, `is_backup`, `notes`, `created_at`
  - Indexes: `idx_sync_status`, `idx_created_at DESC`
  - Version migrations: v1→v2 dropped selfie columns, v3 updated CHECK constraints, v4 added `is_backup` and `notes`, v5 added sakit/izin types
  - Cleanup: Old synced logs deleted after 7 days in `lib/services/sqlite_service.dart`

**File Storage:**
- Supabase Storage - NOT USED (no `.storage()` calls detected)
- Employee photos: External URLs stored in `employees.photo_url` field (no local storage or Supabase buckets)

**Caching:**
- In-memory badge cache - `lib/services/badge_service.dart` caches all badge records on first fetch
- In-memory employee cache - `lib/services/employee_cache_service.dart` caches active employees filtered by outlet
- Image cache - `cached_network_image` package caches employee photos from URLs

## Authentication & Identity

**Auth Provider:**
- Supabase Auth - Email/password authentication for admin users
  - Implementation: PKCE auth flow configured in `lib/main.dart` (line 62-64)
  - Admin login: `lib/screens/admin/admin_login_screen.dart` uses `Supabase.instance.client.auth.signInWithPassword()`
  - Kiosk mode: Anonymous client with outlet_id stored in SharedPreferences (`kiosk_session_v1` key)
  - Session persistence: SharedPreferences for kiosk (replaced SecureStorage to avoid ANR issues noted in `pubspec.yaml` line 24)

**Roles:**
- `admin` - Full access (email/password auth via Supabase Auth)
- `kepala_gerai` - Outlet manager with restricted access to single outlet (stored in `managedOutletId` in `lib/providers/app_provider.dart`)
- Kiosk - No authentication, outlet identity verified via `verify_kiosk_password` RPC at setup time

## Hardware Integration

**NFC Reader:**
- Implementation: `nfc_manager` package in `lib/services/nfc_service.dart`
- Supported cards: e-KTP (NfcA), e-Toll (MifareClassic), Flazz BCA (NfcF/FeliCa), bank cards (IsoDep), Mifare Ultralight, ISO 14443-B, ISO 15693
- Universal UID extraction: Priority fallback across 8 NFC technologies (lines 40-79 of `nfc_service.dart`)
- Intent filters: `ACTION_TECH_DISCOVERED`, `ACTION_NDEF_DISCOVERED`, `ACTION_TAG_DISCOVERED` in `AndroidManifest.xml`
- NFC tech filter: `android/app/src/main/res/xml/nfc_tech_filter.xml` (declares supported NFC technology types)
- Hardware requirement: Marked as required in manifest (`android:required="true"`)
- Initialization: 3-second timeout in `lib/main.dart` (lines 79-85)
- Debounce: 1500ms to prevent double scans (`AppConstants.nfcDebounceMs`)

**GPS Location:**
- Implementation: `geolocator` package in `lib/services/location_service.dart`
- Strategy: Best-effort capture, never throws errors, returns null if unavailable
- Accuracy: Medium (balance between battery and precision)
- Timeout: 5 seconds for position acquisition
- Permissions: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` in `AndroidManifest.xml`
- Usage: Captured at attendance scan time, stored in `attendance_logs.lat/lng` fields

**Foreground Service:**
- Implementation: `flutter_foreground_task` in `lib/services/kiosk_background_service.dart`
- Purpose: Keep kiosk alive for background NFC scanning without app open
- Service type: `connectedDevice` (declared in `AndroidManifest.xml`)
- Permissions: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `RECEIVE_BOOT_COMPLETED`
- Notification: Custom pill-style persistent notification via MethodChannel to Kotlin (`com.enakko.kiosk/notification`)

**System Overlay:**
- Implementation: `flutter_overlay_window` in `lib/overlay_task.dart`
- Purpose: Dynamic Island-style floating pill showing kiosk status/time
- Permission: `SYSTEM_ALERT_WINDOW`
- Entry point: `overlayMain()` with `@pragma('vm:entry-point')` to prevent tree-shaking
- Window size: 380x96 pixels
- Auto-collapse: 3 seconds after scan event

## Network & Connectivity

**Connectivity Monitoring:**
- Package: `connectivity_plus` in `lib/services/sync_service.dart`
- Usage: Check network state before attempting Supabase sync (line 19)
- Offline handling: Failed syncs marked as 'failed' in SQLite, retry count incremented

**HTTP Client:**
- Package: `http ^1.2.2`
- Purpose: Custom header injection for kiosk authentication (noted in `pubspec.yaml` line 48)
- Usage: Direct HTTP calls for scenarios requiring custom auth headers beyond Supabase SDK

## Monitoring & Observability

**Error Tracking:**
- Strategy: Console logging only
- Uncaught errors: Logged via `FlutterError.onError` and `PlatformDispatcher.instance.onError` in `lib/main.dart` (lines 31-38)
- Service errors: Logged with `debugPrint()` in individual services (e.g., sync failures in `lib/services/sync_service.dart`)
- No external crash reporting service (Sentry, Firebase Crashlytics, etc.)

**Logs:**
- Production: `debugPrint()` calls throughout codebase (stripped in release builds by Flutter)
- Sync operations: Console output for sync success/failure counts (`[Sync] Done: X synced, Y failed`)
- NFC operations: Debug output for UID extraction and scan events

## CI/CD & Deployment

**Hosting:**
- Distribution: Manual APK distribution (no Play Store deployment detected)
- Build output: `ABSENKOK-v{versionName}.apk` generated in `android/app/build/outputs/apk/release/`

**CI Pipeline:**
- None detected (no `.github/workflows/`, `.gitlab-ci.yml`, or similar config files)

**Build Process:**
- Manual: `flutter build apk --release` with ProGuard/R8 minification enabled
- Obfuscation: Enabled for release builds (ProGuard rules in `android/app/proguard-rules.pro`)
- Signing: Debug keys used for release builds (line 33 of `android/app/build.gradle.kts`)

## Background Sync

**Sync Service:**
- Implementation: `lib/services/sync_service.dart`
- Trigger: Manual via admin UI or periodic background (details in `kiosk_background_service.dart`)
- Strategy: Batch upload pending logs from SQLite to Supabase `attendance_logs` table
- Batch size: 50 records (`AppConstants.syncBatchSize`)
- Max retries: 5 (`AppConstants.syncMaxRetries`)
- Duplicate handling: PostgrestException code '23505' (unique constraint violation on `local_id`) treated as success
- Cleanup: Synced logs deleted after successful upload

## Document Generation

**PDF Generation:**
- Implementation: `pdf` package in `lib/services/pdf_service.dart`
- Use cases:
  - Per-scan attendance report (`AttendancePerScanPdfRow` model)
  - Daily summary report (`AttendanceDailyPdfRow` model)
- Font loading: `rootBundle` for custom fonts
- Output: PDF file saved to device storage via `path_provider`
- Sharing: `printing` package for native print/share dialog

**CSV Export:**
- Implementation: Manual CSV string generation in report screens
- Sharing: `share_plus` package via native Android share sheet

**Screenshot Export:**
- Implementation: `screenshot` package
- Use case: Schedule calendar widget-to-image conversion in `lib/screens/admin/shift_scheduler_screen.dart`

## Webhooks & Callbacks

**Incoming:**
- None detected (no webhook endpoints or listeners)

**Outgoing:**
- None detected (no webhook POST calls to external services)

## Environment Configuration

**Required env vars:**
- `SUPABASE_URL` - Supabase project API endpoint (format: `https://{project-ref}.supabase.co`)
- `SUPABASE_ANON_KEY` - Supabase anonymous/public API key for client initialization

**Secrets location:**
- `.env` file at project root (loaded in `lib/main.dart` line 54)
- `.env` is in `.gitignore` (must be configured per deployment)

**Session storage:**
- Kiosk session: SharedPreferences key `kiosk_session_v1` (outlet_id, outlet_name, device_id JSON)
- Overlay preference: SharedPreferences key `overlay_keep_foreground_v1` (boolean)

## Special Integrations

**Locale & Internationalization:**
- Implementation: `intl` package with Indonesian locale
- Initialization: `initializeDateFormatting('id_ID')` in `lib/main.dart` (lines 27-28)
- Default locale: `id_ID` for date/time formatting throughout app

**Device Orientation:**
- Locked to portrait mode via `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` in `lib/main.dart` (lines 41-43)

**Battery Optimization:**
- Permission: `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` in manifest
- Purpose: Prevent Android from killing foreground service during kiosk operation

---

*Integration audit: 2026-03-11*
