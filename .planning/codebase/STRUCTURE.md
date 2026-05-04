# Codebase Structure

**Analysis Date:** 2026-04-14

## Directory Layout

```text
absensi_enakko_flutter/
├── lib/                    # Flutter app bootstrap, kiosk, admin, services, models, widgets
├── src/                    # Astro marketing site + employee portal
├── supabase/
│   └── functions/          # Supabase Edge Functions
├── sql/                    # SQL migrations and repair scripts
├── android/                # Android native bridge, manifests, resources, Gradle config
├── assets/                 # Flutter-owned assets
├── public/                 # Astro static public files
├── test/                   # Flutter unit, widget, and phase tests
├── docs/                   # Runbooks and rollout/acceptance docs
├── tool/                   # Windows build and release PowerShell scripts
├── .planning/              # Roadmap, phase, milestone, and codebase-map artifacts
├── pubspec.yaml            # Flutter app manifest
├── package.json            # Astro app manifest
├── astro.config.mjs        # Astro + Vercel config
├── analysis_options.yaml   # Flutter analyzer config
└── vercel.json             # Vercel deployment config
```

## Directory Purposes

**`lib/`:**
- Purpose: production Flutter application code
- Contains: bootstrap in `lib/main.dart`, router in `lib/app.dart`, overlay entry in `lib/overlay_task.dart`, shared runtime code under `lib/core/`, `lib/models/`, `lib/providers/`, `lib/services/`, `lib/widgets/`, and UI under `lib/screens/`
- Key files: `lib/main.dart`, `lib/app.dart`, `lib/overlay_task.dart`, `lib/providers/app_provider.dart`

**`lib/screens/`:**
- Purpose: Flutter UI grouped by surface
- Contains: kiosk setup in `lib/screens/setup/`, kiosk runtime in `lib/screens/kiosk/`, admin runtime in `lib/screens/admin/`
- Key files: `lib/screens/setup/setup_screen.dart`, `lib/screens/kiosk/kiosk_idle_screen.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`, `lib/screens/admin/admin_dashboard_screen.dart`, `lib/screens/admin/admin_reports_screen.dart`, `lib/screens/admin/admin_shell.dart`

**`lib/screens/admin/widgets/`:**
- Purpose: complex admin-only subcomponents that are too large or specialized for `lib/widgets/`
- Contains: payroll matrix views, schedule views, rollout panels, schedule-gap sheets
- Key files: `lib/screens/admin/widgets/payroll_matrix_table.dart`, `lib/screens/admin/widgets/policy_recap_payroll_support_section.dart`, `lib/screens/admin/widgets/admin_schedule_gap_notice_sheet.dart`

**`lib/services/`:**
- Purpose: Flutter business logic and platform integration seams
- Contains: offline queue, scan authority, background service, analytics, reporting, export, onboarding, streaks, scheduling, badges
- Key files: `lib/services/sqlite_service.dart`, `lib/services/sync_service.dart`, `lib/services/kiosk_scan_authority_service.dart`, `lib/services/kiosk_background_service.dart`, `lib/services/admin_policy_recap_dataset_service.dart`, `lib/services/payroll_matrix_builder.dart`

**`src/`:**
- Purpose: Astro web application for the public landing site and employee portal
- Contains: routes in `src/pages/`, layouts in `src/layouts/`, presentational components in `src/components/`, request-scoped server helpers in `src/lib/`, global styling in `src/styles/global.css`
- Key files: `src/middleware.ts`, `src/pages/index.astro`, `src/pages/portal/index.astro`, `src/pages/portal/login.astro`, `src/lib/portal/schedule.ts`, `src/lib/supabase/server.ts`

**`supabase/functions/`:**
- Purpose: privileged backend entry points that must not live in the Flutter or Astro client
- Contains: one folder per function, each with `index.ts`
- Key files: `supabase/functions/create-admin-user/index.ts`, `supabase/functions/clear-must-change-password/index.ts`, `supabase/functions/provision-employee-portal-user/index.ts`

**`sql/`:**
- Purpose: additive database migrations, RPC definitions, and repair scripts
- Contains: phase-stamped migration files and repair scripts
- Key files: `sql/phase_56_server_time_scan_authority_20260327.sql`, `sql/phase_57_strict_recap_evaluation_engine_20260327.sql`, `sql/repair_employee_portal_accounts_20260325.sql`

**`android/`:**
- Purpose: Android-specific project code and configuration for the Flutter app
- Contains: Gradle files, manifests, Kotlin platform bridge, notification layouts, XML resources
- Key files: `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/MainActivity.kt`, `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/KioskNotificationHelper.kt`

**`test/`:**
- Purpose: Flutter tests grouped by runtime layer and by milestone contract
- Contains: general tests under `test/models/`, `test/providers/`, `test/services/`, `test/widgets/`, `test/screens/`, plus milestone-specific regression suites like `test/phase50/` and `test/phase57/`
- Key files: `test/services/report_export_parity_test.dart`, `test/screens/admin/admin_reports_payroll_matrix_test.dart`, `test/screens/kiosk/kiosk_scan_server_time_test.dart`, `test/phase52/portal_recovery_contract_test.dart`

**`tool/`:**
- Purpose: scripted Windows build and release automation
- Contains: release preflight, release build, environment setup, acceptance runners
- Key files: `tool/release_preflight.ps1`, `tool/release_build.ps1`, `tool/release_env.ps1`

**`docs/`:**
- Purpose: operational documentation and rollout evidence
- Contains: release contracts, runbooks, payroll acceptance docs, security rollout docs
- Key files: `docs/android-release-runbook.md`, `docs/android-release-contract.md`, `docs/payroll-rollout-acceptance.md`

**`.planning/`:**
- Purpose: tracked planning and milestone artifacts
- Contains: active state in `.planning/STATE.md`, roadmap and requirements, archived milestones, phase plans, research, and the codebase map in `.planning/codebase/`
- Key files: `.planning/STATE.md`, `.planning/ROADMAP.md`, `.planning/PROJECT.md`, `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`

## Key File Locations

**Entry Points:**
- `lib/main.dart`: Flutter process bootstrap
- `lib/app.dart`: Flutter router and root `MaterialApp.router`
- `lib/overlay_task.dart`: overlay-only Flutter entry point
- `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/MainActivity.kt`: Android bridge registration
- `src/middleware.ts`: Astro portal request gate
- `src/pages/index.astro`: public marketing entry
- `src/pages/portal/index.astro`: authenticated portal home
- `src/pages/portal/auth/search.ts`: public employee chooser endpoint
- `supabase/functions/*/index.ts`: backend function entry points

**Configuration:**
- `pubspec.yaml`: Flutter dependencies, assets, version
- `analysis_options.yaml`: Flutter analyzer/lint config
- `package.json`: Astro scripts and dependencies
- `astro.config.mjs`: Astro adapter, site, security, and Vite config
- `tsconfig.json`: TypeScript config for the Astro app
- `android/build.gradle.kts`, `android/app/build.gradle.kts`, `android/settings.gradle.kts`: Android build config
- `.env`: runtime environment file present at repo root
- `.env.example`: non-secret environment template at repo root

**Core Logic:**
- `lib/providers/app_provider.dart`: persisted mobile session state and role flags
- `lib/services/kiosk_scan_authority_service.dart`: kiosk RPC seam
- `lib/services/sqlite_service.dart`: offline queue persistence
- `lib/services/sync_service.dart`: queued replay in deterministic order
- `lib/services/admin_policy_recap_dataset_service.dart`: strict-plus-fallback recap merge
- `lib/services/payroll_matrix_builder.dart`: payroll matrix dataset builder
- `src/lib/portal/employee.ts`: portal employee resolution
- `src/lib/portal/schedule.ts`: portal schedule loader and date slicing
- `src/lib/supabase/server.ts`: SSR Supabase client
- `src/lib/supabase/admin.ts`: service-role admin helper

**Testing:**
- `test/services/`: business-logic tests, especially reporting, recap, sync, and export
- `test/screens/admin/`: admin widget tests for dashboard, reports, and scheduler flows
- `test/screens/kiosk/`: kiosk scan and server-time tests
- `test/widgets/`: shared widget rendering tests
- `test/phase50/` through `test/phase57/`: milestone contract and security regressions

## Naming Conventions

**Files:**
- Flutter code uses `snake_case.dart`: `lib/screens/kiosk/kiosk_scan_screen.dart`, `lib/services/payroll_spreadsheet_export_service.dart`, `lib/models/kiosk_session.dart`
- Astro pages use route-shaped filenames: `src/pages/index.astro`, `src/pages/portal/index.astro`, `src/pages/portal/login.astro`
- Astro API routes use kebab-case filenames under route folders: `src/pages/portal/auth/sign-in.ts`, `src/pages/portal/auth/sign-out.ts`
- Edge Functions use folder-per-function with `index.ts`: `supabase/functions/create-admin-user/index.ts`
- SQL migrations are phase-stamped and date-stamped: `sql/phase_55_schedule_policy_foundation_20260326.sql`
- Repair scripts use `repair_<name>_<date>.sql`: `sql/repair_employee_portal_accounts_20260325.sql`

**Directories:**
- Flutter groups by architectural layer first, then feature: `lib/screens/admin/`, `lib/screens/kiosk/`, `lib/services/`, `lib/models/`, `lib/widgets/`
- Astro groups by runtime role: `src/pages/`, `src/lib/`, `src/components/`, `src/layouts/`, `src/styles/`
- Test directories mirror runtime ownership: `test/services/`, `test/screens/admin/`, `test/screens/kiosk/`, `test/widgets/`
- Planning directories follow artifact type: `.planning/phases/`, `.planning/milestones/`, `.planning/research/`, `.planning/codebase/`

## Where to Add New Code

**New kiosk screen or kiosk flow:**
- UI: `lib/screens/kiosk/`
- Shared business logic: `lib/services/`
- Router registration: `lib/app.dart`
- Tests: `test/screens/kiosk/` and `test/services/`

**New admin screen or admin workflow:**
- Screen: `lib/screens/admin/`
- Complex reusable subview: `lib/screens/admin/widgets/`
- Shell navigation or route update: `lib/screens/admin/admin_shell.dart` and `lib/app.dart`
- Tests: `test/screens/admin/`

**New Flutter model or shared widget:**
- Model: `lib/models/`
- Cross-surface widget: `lib/widgets/`
- If the widget is tightly coupled to admin reports or scheduling, prefer `lib/screens/admin/widgets/`

**New portal page or portal endpoint:**
- Page route: `src/pages/portal/`
- Public/auth endpoint: `src/pages/portal/auth/`
- Loader or business logic: `src/lib/portal/`
- Layout or presentational component: `src/layouts/` or `src/components/portal/`

**New server-side Supabase helper:**
- SSR cookie-scoped helper: `src/lib/supabase/server.ts` or a neighboring file in `src/lib/supabase/`
- Service-role helper: `src/lib/supabase/admin.ts` or a neighboring file in `src/lib/supabase/`

**New backend contract:**
- Edge Function: `supabase/functions/<function-name>/index.ts`
- Database migration or RPC definition: `sql/phase_<nn>_<slug>_YYYYMMDD.sql`
- Repair script: `sql/repair_<slug>_YYYYMMDD.sql`

**New release or operational artifact:**
- Automation script: `tool/`
- Runbook or checklist: `docs/`
- Planning or roadmap artifact: `.planning/`

## Special Directories

**`assets/` and `src/assets/images/`:**
- Purpose: brand and UI image assets for Flutter and Astro
- Generated: No
- Committed: Yes

**`public/`:**
- Purpose: Astro public static assets served as-is
- Generated: No
- Committed: Yes

**`build/`, `.dart_tool/`, `.astro/`, `supabase/.temp/`, `android/.gradle/`:**
- Purpose: generated build caches and local tool output
- Generated: Yes
- Committed: No

**Phase test directories such as `test/phase50/` and `test/phase57/`:**
- Purpose: milestone-specific regression contracts that do not fit the generic layer buckets
- Generated: No
- Committed: Yes

**Root maintenance scripts such as `fix_*.py`, `run_*.py`, `step*.py`, and `convert_*.py`:**
- Purpose: one-off repository maintenance and recovery helpers
- Generated: No
- Committed: Yes

**Adjacent recovery copies such as `lib/services/sqlite_service.dart.checkpoint2` and `lib/models/attendance_log.dart.checkpoint2`:**
- Purpose: manual backup artifacts beside source files
- Generated: Manually
- Committed: Yes

---

*Structure analysis: 2026-04-14*
