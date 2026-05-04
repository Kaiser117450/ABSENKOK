# External Integrations

**Analysis Date:** 2026-04-14

## APIs & External Services

**Backend Platform:**
- Supabase - Shared backend for the Flutter app, Astro portal, SQL RPC layer, realtime subscriptions, and Edge Functions.
  - SDK/Client: `supabase_flutter` in `lib/main.dart` and `lib/core/supabase_client.dart`; `@supabase/ssr` in `src/middleware.ts` and `src/lib/supabase/server.ts`; `@supabase/supabase-js` in `src/lib/supabase/admin.ts` and `supabase/functions/*/index.ts`.
  - Auth: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` via `lib/main.dart` and `src/lib/supabase/env.ts`.
  - Mobile bootstrap: `lib/main.dart`.
  - Portal SSR/auth boundary: `src/middleware.ts`, `src/lib/portal/auth.ts`, `src/pages/portal/auth/sign-in.ts`, and `src/pages/portal/auth/sign-out.ts`.
  - Privileged server logic: `src/lib/portal/provision.ts` plus tracked Edge Functions in `supabase/functions/`.

**Observability:**
- Sentry - Release-only crash and background-failure reporting for the Flutter app.
  - SDK/Client: `sentry_flutter` in `lib/main.dart`.
  - Auth: `SENTRY_DSN`.
  - Filtering/throttling: `lib/services/sentry_service.dart`.

**Distribution / Hosting:**
- Vercel - Web hosting target for the Astro site and portal.
  - SDK/Client: `@astrojs/vercel` in `astro.config.mjs`.
  - Auth: Vercel environment variables are read in `astro.config.mjs` for allowed-domain generation.

**Messaging / Handoff Channels:**
- WhatsApp deep link - Admin credential sharing uses `url_launcher` in `lib/screens/admin/create_admin_screen.dart`.
  - SDK/Client: `url_launcher`.
  - Auth: none.
- Native Android share/print flows - Report and credential export uses `share_plus` and `printing` in `lib/services/pdf_service.dart`, `lib/services/pdf_report_service.dart`, `lib/screens/admin/admin_reports_screen.dart`, and `lib/screens/admin/create_admin_screen.dart`.

## Data Storage

**Databases:**
- Supabase PostgreSQL - The primary system of record for auth-aware operational data.
  - Connection: `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `lib/main.dart`; `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` in `src/lib/supabase/env.ts`.
  - Client: `supabase_flutter`, `@supabase/ssr`, and `@supabase/supabase-js`.
  - Core tables used by the Flutter app:
    - `employees` - queried and updated from `lib/screens/admin/admin_employees_screen.dart`, `lib/screens/kiosk/kiosk_idle_screen.dart`, `lib/services/csv_import_service.dart`, and `lib/services/live_content_provider.dart`.
    - `outlets` - managed from `lib/screens/admin/admin_outlets_screen.dart`, `lib/screens/admin/csv_import_screen.dart`, and `lib/screens/admin/archived_employees_screen.dart`.
    - `attendance_logs` - read/write paths in `lib/screens/admin/admin_dashboard_screen.dart`, `lib/screens/admin/admin_reports_screen.dart`, `lib/screens/admin/shift_scheduler_screen.dart`, `lib/services/analytics_service.dart`, and `lib/services/live_content_provider.dart`.
    - `kiosk_devices` - device status and heartbeat surface read by `lib/screens/admin/admin_dashboard_screen.dart` and `lib/screens/admin/central_dashboard_screen.dart`, with updates sent from `lib/services/heartbeat_service.dart`.
    - `badges` and `employee_streaks` - badge/streak features in `lib/services/badge_service.dart`, `lib/services/streak_service.dart`, and `lib/services/streak_badge_service.dart`.
    - `schedules`, `schedule_entries`, `time_off_requests`, and `shift_roles` - scheduling and policy surfaces in `lib/screens/admin/shift_scheduler_screen.dart`, `lib/services/schedule_sqlite_service.dart`, and `lib/services/shift_role_service.dart`.
  - Portal-specific tables and mappings:
    - `employee_portal_accounts` - portal account mapping used by `src/lib/portal/employee.ts`, `src/lib/portal/provision.ts`, and the SQL rollout files `sql/phase_37_employee_portal_foundation_20260322.sql` and `sql/repair_employee_portal_accounts_20260325.sql`.
  - RPCs used directly by current code:
    - Kiosk/device/auth RPCs: `activate_kiosk_device` in `lib/screens/setup/setup_screen.dart`; `get_kiosk_scan_context` and `record_kiosk_scan` in `lib/services/kiosk_scan_authority_service.dart`; `upsert_kiosk_heartbeat` in `lib/services/heartbeat_service.dart`; `set_device_nickname` and `archive_device` in `lib/screens/admin/admin_dashboard_screen.dart`.
    - Admin analytics RPCs: `get_attendance_rates`, `get_overtime_flags`, `get_missing_clockouts`, `get_central_dashboard_summary`, and `get_outlet_control_center` in `lib/services/analytics_service.dart`; `get_weekly_trend` and `get_outlet_comparison` in `lib/screens/admin/chart_dashboard_screen.dart`; `get_arrival_patterns` in `lib/services/pattern_detection_service.dart`; `get_admin_schedule_policy_recap` in `lib/services/attendance_policy_recap_service.dart`.
    - Portal RPCs: `resolve_portal_employee` in `src/lib/portal/employee.ts`; `get_portal_schedule_overview` in `src/lib/portal/schedule.ts`; `search_portal_employees` in `src/pages/portal/auth/search.ts`.

- Local SQLite - Offline-first persistence on the Android device.
  - Connection: local filesystem via `sqflite`.
  - Client: `lib/services/sqlite_service.dart` and `lib/services/schedule_sqlite_service.dart`.
  - Databases:
    - `absensi_enakko.db` - offline attendance queue defined by `AppConstants.dbName` in `lib/core/constants.dart` and created by `lib/services/sqlite_service.dart`.
    - `shift_schedules.db` - offline schedule cache created by `lib/services/schedule_sqlite_service.dart`.

**File Storage:**
- Local device filesystem only for generated operator artifacts.
  - PDF and export staging happens in `lib/services/pdf_service.dart`, `lib/services/pdf_report_service.dart`, `lib/services/payroll_pdf_matrix_export_service.dart`, `lib/services/payroll_spreadsheet_export_service.dart`, and `lib/screens/admin/csv_import_screen.dart`.
- Repo-tracked static assets are served from `assets/`, `public/`, and `src/assets/images/`.
- No Supabase Storage bucket integration is detected in `lib/`, `src/`, or `supabase/functions/`.

**Caching:**
- In-memory mobile caches:
  - Badge cache in `lib/services/badge_service.dart`.
  - Employee/live-content cache in `lib/services/live_content_provider.dart`.
  - Arrival pattern cache in `lib/services/pattern_detection_service.dart`.
  - Shift role cache in `lib/services/shift_role_service.dart`.
- Persistent mobile cache/state:
  - Kiosk session, overlay preference, biometric preference, and installation UUID in `SharedPreferences` through `lib/providers/app_provider.dart`, `lib/services/device_identity_service.dart`, and `lib/core/constants.dart`.
- Web caching:
  - Portal employee search explicitly disables caching with `Cache-Control: no-store` in `src/pages/portal/auth/search.ts`.
  - Static asset caching for `_astro` files and `.webp` files is set in `vercel.json`.

## Authentication & Identity

**Auth Provider:**
- Supabase Auth - Used across mobile admin login, portal sessions, and hidden portal identities.
  - Implementation:
    - Flutter app initializes Supabase PKCE auth in `lib/main.dart`.
    - Admin and kepala gerai sessions are handled through `Supabase.instance.client.auth` in `lib/app.dart`, `lib/screens/admin/admin_login_screen.dart`, and `lib/screens/admin/change_password_screen.dart`.
    - Portal sessions use SSR cookies through `src/middleware.ts` and `src/lib/supabase/server.ts`.
    - Portal employee identities are mapped server-side through `employee_portal_accounts` in `src/lib/portal/employee.ts`.
- Kiosk identity - Not a full auth session; activation is RPC-driven and backed by a persistent installation UUID.
  - Implementation: `lib/screens/setup/setup_screen.dart` calls `activate_kiosk_device`, and `lib/services/device_identity_service.dart` stores `installation_device_uuid_v1`.
- Optional device-local biometric gate - `lib/services/biometric_service.dart` and `lib/providers/app_provider.dart`.

## Monitoring & Observability

**Error Tracking:**
- Sentry - Release-mode error reporting only.
  - Flutter entrypoint: `lib/main.dart`.
  - Event filtering and throttled background capture: `lib/services/sentry_service.dart`.

**Logs:**
- Flutter uses `debugPrint()` and a few guarded `print()` paths in services such as `lib/services/sync_service.dart`, `lib/services/heartbeat_service.dart`, `lib/services/nfc_service.dart`, and `lib/services/location_service.dart`.
- Astro server routes and portal helpers use `console.error()` in files such as `src/pages/portal/auth/sign-in.ts` and `src/pages/portal/auth/search.ts`.
- Supabase Edge Functions use `console.error()` / thrown HTTP responses inside `supabase/functions/*/index.ts`.

## CI/CD & Deployment

**Hosting:**
- Web hosting is Vercel via `astro.config.mjs` and `vercel.json`.
- Mobile distribution is manual/operator-driven through `tool/release_preflight.ps1` and `tool/release_build.ps1`.
- Backend hosting is Supabase, with SQL rollout source under `sql/` and function source under `supabase/functions/`.

**CI Pipeline:**
- No GitHub Actions pipeline is tracked under `.github/workflows/`.
- The `.github/` directory contains GSD agent metadata and workflow templates under `.github/get-shit-done/`, but not an active CI runner for builds/tests/deployments.

## Environment Configuration

**Required env vars:**
- Flutter app:
  - `SUPABASE_URL` - read in `lib/main.dart`.
  - `SUPABASE_ANON_KEY` - read in `lib/main.dart`.
  - `SENTRY_DSN` - read in `lib/main.dart`.
- Astro portal server:
  - `SUPABASE_URL` or `PUBLIC_SUPABASE_URL` - read in `src/lib/supabase/env.ts`.
  - `SUPABASE_ANON_KEY` or `PUBLIC_SUPABASE_ANON_KEY` - read in `src/lib/supabase/env.ts`.
  - `SUPABASE_SERVICE_ROLE_KEY` - required by `src/lib/supabase/admin.ts` and `src/lib/portal/provision.ts`.
  - `PORTAL_SECRET` - used in `src/lib/portal/auth.ts` for hidden portal password derivation.
  - `PUBLIC_SITE_URL` - used in `astro.config.mjs`.
  - `VERCEL_PROJECT_PRODUCTION_URL`, `VERCEL_BRANCH_URL`, and `VERCEL_URL` - read in `astro.config.mjs` for allowed-domain generation.
- Supabase Edge Functions:
  - `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and, for `supabase/functions/provision-employee-portal-user/index.ts`, also `SUPABASE_ANON_KEY`.
- Android release tooling:
  - `ABSENKOK_JAVA_HOME` in `tool/release_env.ps1`.
  - Optional `ANDROID_HOME` / `ANDROID_SDK_ROOT` in `tool/release_build.ps1` for adb resolution.

**Secrets location:**
- Root `.env` and `.env.example` exist for local app/web configuration.
- Portal server secrets are consumed through runtime environment access in `src/lib/supabase/env.ts` and `src/lib/portal/auth.ts`.
- Android signing is wired to `android/key.properties` through `android/app/build.gradle.kts`; the file exists locally and should be treated as private.
- No tracked `supabase/config.toml` is present, so Supabase local CLI project config is not the source of truth in this repo.

## Webhooks & Callbacks

**Incoming:**
- No third-party webhook endpoints are detected.
- Server endpoints exist for portal auth/search under `src/pages/portal/auth/`, but they are application routes, not general-purpose webhook receivers.

**Outgoing:**
- No third-party webhook delivery integration is detected.
- The app and portal do make outbound calls to Supabase services and Edge Functions from `lib/`, `src/lib/`, and `supabase/functions/`, but no generic callback/webhook dispatcher is present.

---

*Integration audit: 2026-04-14*
