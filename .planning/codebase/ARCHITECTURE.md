# Architecture

**Analysis Date:** 2026-04-14

## Pattern Overview

**Overall:** Multi-surface monorepo built around one shared Supabase backend.

**Key Characteristics:**
- `lib/` contains one Flutter application that switches between setup, kiosk, and admin runtime through `GoRouter` in `lib/app.dart`.
- `src/` contains a separate Astro application for the public landing site and the authenticated employee portal.
- `supabase/functions/` and `sql/` hold backend contracts that both frontends assume exist.
- `android/` contains the native notification and permission bridge used by the kiosk runtime.
- `.planning/`, `docs/`, and `tool/` live beside production code and support release, roadmap, and verification workflows without being runtime layers themselves.

## Layers

**Flutter Bootstrap & Session Shell:**
- Purpose: initialize the mobile runtime, hydrate persisted session state, and gate routes.
- Location: `lib/main.dart`, `lib/app.dart`, `lib/providers/app_provider.dart`, `lib/core/admin_session_claims.dart`, `lib/core/supabase_client.dart`
- Contains: `.env` load, Sentry init, Supabase init, SQLite warmup, NFC warmup, `AppState`, redirect logic, lifecycle-to-background policy
- Depends on: `SharedPreferences`, `Supabase`, `flutter_riverpod`, `go_router`
- Used by: all Flutter screens under `lib/screens/`

**Kiosk Attendance Runtime:**
- Purpose: activate devices, read NFC tags, resolve authority context, submit or queue scans, and keep the kiosk visible in background.
- Location: `lib/screens/setup/setup_screen.dart`, `lib/screens/kiosk/kiosk_idle_screen.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`, `lib/services/nfc_service.dart`, `lib/services/kiosk_scan_authority_service.dart`, `lib/services/sqlite_service.dart`, `lib/services/sync_service.dart`, `lib/services/employee_cache_service.dart`, `lib/services/kiosk_background_service.dart`, `lib/overlay_task.dart`, `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/MainActivity.kt`, `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/KioskNotificationHelper.kt`
- Contains: device activation, scan context fetch, live submit, queued fallback submit, background notification/overlay management, local retry queue, backup-outlet handling
- Depends on: `AppState.kioskSession`, Supabase RPCs, SQLite, Android-specific plugins
- Used by: `/setup`, `/kiosk`, `/kiosk/scan`, `/kiosk/diagnostics`

**Admin Operations & Reporting:**
- Purpose: outlet-scoped operations, live dashboards, employee management, policy recap, and export generation.
- Location: `lib/screens/admin/`, `lib/screens/admin/widgets/`, `lib/services/analytics_service.dart`, `lib/services/badge_service.dart`, `lib/services/schedule_gap_notice_service.dart`, `lib/services/attendance_policy_recap_service.dart`, `lib/services/admin_policy_recap_dataset_service.dart`, `lib/services/payroll_matrix_builder.dart`, `lib/services/payroll_pdf_matrix_export_service.dart`, `lib/services/payroll_spreadsheet_export_service.dart`, `lib/services/admin_onboarding_service.dart`
- Contains: dashboard views, central network summary, report filters, policy recap tiles, payroll matrix widgets, PDF/XLSX export, admin account creation, forced password-change clearing
- Depends on: Supabase tables and RPCs, `AppState.isAdmin`, `AppState.isKepalaGerai`, reporting models under `lib/models/`
- Used by: `/admin/*` shell routes plus `/admin/chart-dashboard`

**Portal SSR Layer:**
- Purpose: serve the public landing site and the authenticated employee portal.
- Location: `src/pages/`, `src/layouts/`, `src/components/`, `src/lib/portal/`, `src/lib/supabase/`, `src/middleware.ts`
- Contains: marketing page composition, portal shell, employee login/search endpoints, server-side schedule loaders, SSR Supabase cookie handling
- Depends on: Astro request/response context, Supabase SSR cookies, portal RPCs
- Used by: `/`, `/portal`, `/portal/login`, `/portal/auth/*`

**Backend Contract Layer:**
- Purpose: hold privileged server entry points and database contracts shared by Flutter and Astro.
- Location: `supabase/functions/create-admin-user/index.ts`, `supabase/functions/clear-must-change-password/index.ts`, `supabase/functions/provision-employee-portal-user/index.ts`, `sql/`
- Contains: auth-user creation, metadata mutation, portal provisioning, additive migration and RPC definitions
- Depends on: Supabase service-role environment and database objects defined in `sql/phase_*`
- Used by: `lib/services/admin_onboarding_service.dart`, `lib/screens/admin/change_password_screen.dart`, `src/pages/portal/auth/sign-in.ts`, server-side portal helpers

## Data Flow

**Flutter Startup and Route Gating:**

1. `lib/main.dart` loads `.env`, initializes Sentry, Supabase, SQLite, and NFC, then runs `ProviderScope`.
2. `lib/providers/app_provider.dart` loads `KioskSession`, overlay preferences, and biometric flags from `SharedPreferences`.
3. `lib/app.dart` reads `AppState` and redirects into `/setup`, `/kiosk`, or `/admin/*`; `/admin/login` remains reachable before kiosk checks, and `mustChangePassword` forces `/admin/change-password`.

**Kiosk Activation and Scan Recording:**

1. `lib/screens/setup/setup_screen.dart` calls the `activate_kiosk_device` RPC and persists a `KioskSession`.
2. `lib/screens/kiosk/kiosk_idle_screen.dart` starts `KioskBackgroundService`, probes NFC availability, refreshes pending-count state, and subscribes to connectivity recovery.
3. On tag detection, `kiosk_idle_screen.dart` resolves an employee from `lib/services/employee_cache_service.dart` or the `employees` table, then fetches authority context through `lib/services/kiosk_scan_authority_service.dart`.
4. `lib/screens/kiosk/kiosk_scan_screen.dart` submits live scans through the `record_kiosk_scan` RPC.
5. If live submit fails but local context exists, `kiosk_scan_screen.dart` writes a queued entry through `lib/services/sqlite_service.dart` and triggers best-effort replay through `lib/services/sync_service.dart`.
6. `lib/services/kiosk_background_service.dart`, `lib/overlay_task.dart`, and the Kotlin bridge publish live notification and overlay state around the same kiosk session.

**Admin Recap and Payroll Export:**

1. `lib/screens/admin/admin_reports_screen.dart` loads raw attendance rows, active employees, and strict recap rows for the selected outlet or for all active outlets.
2. `lib/services/attendance_policy_recap_service.dart` calls `get_admin_schedule_policy_recap` per outlet and normalizes nested RPC payloads into `AttendancePolicyRecapDay`.
3. `lib/services/admin_policy_recap_dataset_service.dart` merges strict recap rows with synthesized fallback rows from `lib/services/legacy_payroll_recap_fallback_service.dart`.
4. `lib/services/payroll_matrix_builder.dart` converts merged recap rows plus active employees into a dated `PayrollMatrixDataset`.
5. `lib/services/payroll_pdf_matrix_export_service.dart` and `lib/services/payroll_spreadsheet_export_service.dart` render the same dataset into PDF and XLSX outputs.
6. `lib/screens/admin/admin_dashboard_screen.dart`, `lib/screens/admin/central_dashboard_screen.dart`, and `lib/screens/admin/chart_dashboard_screen.dart` provide the operational views on top of direct table queries, RPC aggregates, and realtime subscriptions.

**Portal Login and Schedule Rendering:**

1. `src/pages/portal/login.astro` hosts the chooser UI and queries `src/pages/portal/auth/search.ts`.
2. `src/pages/portal/auth/search.ts` normalizes the query via `src/lib/portal/auth.ts` and calls the `search_portal_employees` RPC through `src/lib/supabase/server.ts`.
3. `src/pages/portal/auth/sign-in.ts` derives a hidden portal email/password, tries `supabase.auth.signInWithPassword()`, and can provision the auth account through `src/lib/portal/provision.ts` when admin env vars are available.
4. `src/middleware.ts` refreshes SSR cookies, caches `portalUser` in `Astro.locals`, and redirects unauthenticated requests away from protected `/portal/*` routes.
5. `src/lib/portal/employee.ts` resolves the authenticated employee through the `resolve_portal_employee` RPC.
6. `src/lib/portal/schedule.ts` calls `get_portal_schedule_overview`, derives today/current-week/next-week groupings, and `src/lib/portal/home.ts` maps that result into page-ready state for `src/pages/portal/index.astro`.

## State Management

**Flutter state:**
- Global mobile session state lives in `AppState` and `AppNotifier` in `lib/providers/app_provider.dart`.
- Route decisions in `lib/app.dart` stay reactive because `_AppStateListenable` bridges Riverpod changes into `GoRouter.refreshListenable`.
- Kiosk flow mixes global session flags in `AppState` with local widget state in `lib/screens/kiosk/kiosk_idle_screen.dart` and `lib/screens/kiosk/kiosk_scan_screen.dart`.
- Admin screens keep most loading, filtering, and pagination state inside the screen widget that owns the query.

**Portal state:**
- Portal state is request-scoped, not client-store scoped.
- `src/lib/portal/*.ts` returns discriminated unions so pages branch on `state.kind` or `ok` instead of sharing a long-lived client cache.

## Key Abstractions

**`AppState` / `AppNotifier`:**
- Purpose: single mobile session envelope for kiosk/admin mode, managed outlet, pending queue count, overlay preference, and biometric flags
- Examples: `lib/providers/app_provider.dart`
- Pattern: immutable state object plus Riverpod `StateNotifier`

**`KioskSession`:**
- Purpose: persisted kiosk binding between a device UUID and an outlet
- Examples: `lib/models/kiosk_session.dart`, persisted from `lib/screens/setup/setup_screen.dart`
- Pattern: JSON-serializable session object stored in `SharedPreferences`

**`KioskScanAuthorityService`:**
- Purpose: one RPC-backed seam for both pre-scan context and final scan recording
- Examples: `lib/services/kiosk_scan_authority_service.dart`, `lib/screens/kiosk/kiosk_idle_screen.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`, `lib/services/sync_service.dart`
- Pattern: wrapper around `get_kiosk_scan_context` and `record_kiosk_scan` with defensive payload unwrapping

**`AdminPolicyRecapDatasetResult` + `buildPayrollMatrix()`:**
- Purpose: reporting seam that turns strict recap rows and fallback synthesis into exportable matrix rows
- Examples: `lib/services/admin_policy_recap_dataset_service.dart`, `lib/services/payroll_matrix_builder.dart`, `lib/screens/admin/admin_reports_screen.dart`
- Pattern: pure data-build pipeline feeding multiple output formats

**Portal loader unions:**
- Purpose: typed request-scoped state for SSR pages without client-state hydration
- Examples: `src/lib/portal/home.ts`, `src/lib/portal/schedule.ts`, `src/lib/portal/employee.ts`
- Pattern: typed `ok`/`reason` and `kind` unions returned instead of throwing into the page

**Supabase SSR/admin clients:**
- Purpose: separate cookie-scoped and service-role server clients in the portal
- Examples: `src/lib/supabase/server.ts`, `src/lib/supabase/admin.ts`, `src/lib/supabase/env.ts`
- Pattern: explicit server-only factory functions; service-role access never reaches browser code

## Entry Points

**Flutter app entry:**
- Location: `lib/main.dart`
- Triggers: Android app launch
- Responsibilities: `.env` load, Sentry init, `Supabase.initialize()`, `SqliteService.getDatabase()`, `NfcService.init()`, `runApp()`

**Flutter route shell:**
- Location: `lib/app.dart`
- Triggers: every Flutter navigation event and auth/session state change
- Responsibilities: redirect guards, shell route construction, lifecycle-to-background policy

**Overlay entry:**
- Location: `lib/overlay_task.dart`
- Triggers: `flutter_overlay_window` overlay runtime
- Responsibilities: render and update the compact/expanded kiosk pill independently of the main app tree

**Android bridge entry:**
- Location: `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/MainActivity.kt`
- Triggers: Flutter engine creation
- Responsibilities: register notification and MIUI permission `MethodChannel`s, create the kiosk notification channel

**Marketing site entry:**
- Location: `src/pages/index.astro`
- Triggers: public website requests
- Responsibilities: assemble the landing page from static Astro components under `src/components/`

**Portal request gate:**
- Location: `src/middleware.ts`
- Triggers: every Astro request under `/portal`
- Responsibilities: refresh cookies, resolve `portalUser`, enforce protected-route redirects

**Portal home entry:**
- Location: `src/pages/portal/index.astro`
- Triggers: authenticated portal requests
- Responsibilities: call `loadPortalHome()`, branch on typed state, render `src/layouts/PortalLayout.astro` plus portal components

**Portal auth endpoints:**
- Location: `src/pages/portal/auth/search.ts`, `src/pages/portal/auth/sign-in.ts`, `src/pages/portal/auth/sign-out.ts`
- Triggers: chooser search, login submit, logout submit
- Responsibilities: public employee search, session creation, local-scope portal sign-out

**Supabase function entries:**
- Location: `supabase/functions/*/index.ts`
- Triggers: function invocations from Flutter or portal workflows
- Responsibilities: privileged auth-user creation and metadata mutation

## Error Handling

**Strategy:** defensive, boundary-local fallbacks instead of central exception bubbling.

**Patterns:**
- `lib/main.dart` allows Supabase init to fail soft by logging and launching anyway; runtime callers check `supabaseReady`.
- `lib/providers/app_provider.dart` always clears `isLoading` in `finally`, and `lib/app.dart` adds a 5-second unblock safety net.
- `lib/screens/kiosk/kiosk_scan_screen.dart` downgrades failed live submissions into queued offline writes when authority context can be trusted locally.
- `lib/services/attendance_policy_recap_service.dart` and `lib/services/kiosk_scan_authority_service.dart` aggressively normalize nested RPC responses before model parsing.
- `src/lib/portal/*.ts` returns typed unions so Astro pages can render blocked states instead of crashing the request.
- `src/middleware.ts` appends refreshed cookies even when redirecting, so portal auth recovery and route protection stay in one place.

## Cross-Cutting Concerns

**Authentication:** Flutter admin state comes from `lib/core/admin_session_claims.dart`; kiosk activation is RPC-based in `lib/screens/setup/setup_screen.dart`; portal auth is cookie-based SSR in `src/middleware.ts` and `src/lib/supabase/server.ts`.

**Offline resilience:** `lib/services/sqlite_service.dart`, `lib/services/sync_service.dart`, and `lib/services/employee_cache_service.dart` make kiosk scans resilient to connectivity loss and repeated taps.

**Realtime refresh:** `lib/screens/admin/admin_dashboard_screen.dart` and `lib/screens/admin/central_dashboard_screen.dart` subscribe to Postgres changes for attendance, employee, outlet, and kiosk-device data.

**Privileged backend operations:** `lib/services/admin_onboarding_service.dart` and `lib/screens/admin/change_password_screen.dart` call Supabase Edge Functions; portal sign-in can provision missing portal auth users through `src/lib/portal/provision.ts`.

**Shared reporting semantics:** `lib/services/admin_policy_recap_dataset_service.dart`, `lib/services/payroll_matrix_builder.dart`, `lib/services/payroll_pdf_matrix_export_service.dart`, and `lib/services/payroll_spreadsheet_export_service.dart` deliberately share one recap-to-matrix seam.

**Shared brand assets:** `pubspec.yaml` bundles both `assets/images/` and `src/assets/images/`, so branding assets are reused across Flutter and Astro surfaces.

---

*Architecture analysis: 2026-04-14*
