# Technology Stack

**Analysis Date:** 2026-04-14

## Languages

**Primary:**
- Dart >=3.3.0 <4.0.0 - The main product language for the Android kiosk app, admin UI, providers, and services under `lib/`, with tests under `test/`.
- TypeScript - The Astro portal server code and Supabase admin helpers under `src/lib/`, plus Supabase Edge Functions under `supabase/functions/`.
- Kotlin 1.9.25 - Android-native bridge code in `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/`.
- SQL - Supabase schema, RLS, RPC, and rollout scripts under `sql/phase_*.sql` and `sql/repair_*.sql`.
- PowerShell - Windows build and release automation under `tool/release_env.ps1`, `tool/release_preflight.ps1`, and `tool/release_build.ps1`.

**Secondary:**
- Astro component syntax - UI templates in `src/pages/`, `src/components/`, and `src/layouts/`.
- CSS - Global portal styling in `src/styles/global.css`.
- Python - Repo-local maintenance helpers such as `fix_*.py`, `convert_*.py`, and `run_fixes.py`; these are support scripts, not runtime code.

## Runtime

**Environment:**
- Flutter mobile runtime - App entrypoint is `lib/main.dart`; Android is the only tracked runtime surface.
- Android runtime - Native packaging and manifest live under `android/`, with NFC, notification, overlay, and foreground-service support wired through `android/app/src/main/AndroidManifest.xml`.
- Node.js build/runtime for Astro - `package.json` provides the Astro toolchain for `src/`; no `.nvmrc` or `engines` field is tracked at the repo root.
- Deno runtime for Supabase Edge Functions - Function entrypoints live in `supabase/functions/create-admin-user/index.ts`, `supabase/functions/clear-must-change-password/index.ts`, and `supabase/functions/provision-employee-portal-user/index.ts`.
- Java split contract - Android source and Kotlin compilation target Java 17 in `android/app/build.gradle.kts`, while the tracked Windows release lane requires Java 21 JBR in `tool/release_env.ps1`.

**Package Manager:**
- `pub` - Flutter and Dart packages are declared in `pubspec.yaml`.
- Lockfile: `pubspec.lock` is present.
- `npm` - Astro and web packages are declared in `package.json`.
- Lockfile: `package-lock.json` is present.
- Deno imports are pulled directly inside `supabase/functions/*/index.ts`; no tracked `deno.json` or `supabase/config.toml` is present in `supabase/`.

## Frameworks

**Core:**
- Flutter - Main kiosk and admin application framework, bootstrapped in `lib/main.dart` and `lib/app.dart`.
- Riverpod (`flutter_riverpod` ^2.6.1) - Global app state in `lib/providers/app_provider.dart`.
- GoRouter (`go_router` ^14.8.1) - App navigation and redirect guards in `lib/app.dart`.
- Astro (`astro` ^5.18.1) - Marketing site plus employee portal under `src/`, with public pages in `src/pages/index.astro` and portal pages in `src/pages/portal/`.
- Tailwind CSS 4 (`tailwindcss` ^4.2.1 + `@tailwindcss/vite` ^4.2.1) - Portal styling pipeline configured in `astro.config.mjs` and imported by `src/styles/global.css`.
- Supabase - Shared backend platform consumed by Flutter in `lib/main.dart` and by the portal SSR layer in `src/middleware.ts` and `src/lib/supabase/`.

**Testing:**
- `flutter_test` - Primary test runner for the app and services under `test/`.
- `flutter_lints` ^5.0.0 - Analyzer baseline enabled by `analysis_options.yaml`.
- `@astrojs/check` ^0.9.7 - Astro project validation via the `check` script in `package.json`.
- TypeScript strict config - `tsconfig.json` extends `astro/tsconfigs/strict`.

**Build/Dev:**
- Gradle 8.14 - Android wrapper pinned in `android/gradle/wrapper/gradle-wrapper.properties`.
- Android Gradle Plugin 8.11.1 - Pinned in `android/settings.gradle.kts`.
- Kotlin Android plugin 1.9.25 - Pinned in `android/settings.gradle.kts`.
- `@astrojs/vercel` ^9.0.5 - Astro deployment adapter configured in `astro.config.mjs`.
- `@astrojs/sitemap` ^3.7.1 - Sitemap integration configured in `astro.config.mjs`.
- Release automation - The tracked release lane is `tool/release_env.ps1` -> `tool/release_preflight.ps1` -> `tool/release_build.ps1`.

## Key Dependencies

**Critical:**
- `supabase_flutter` ^2.8.4 - Mobile backend access for auth, RPC, realtime, and Edge Functions across `lib/main.dart`, `lib/core/supabase_client.dart`, and many `lib/services/*.dart` files.
- `@supabase/ssr` ^0.9.0 - SSR cookie-aware portal auth client used in `src/middleware.ts` and `src/lib/supabase/server.ts`.
- `@supabase/supabase-js` ^2.99.3 - Portal admin helpers in `src/lib/supabase/admin.ts` and Deno Edge Functions in `supabase/functions/*/index.ts`.
- `nfc_manager` ^3.5.0 - NFC session handling in `lib/services/nfc_service.dart` and scan availability checks in `lib/screens/kiosk/kiosk_idle_screen.dart`.
- `sqflite` ^2.4.1 - Offline attendance queue and schedule cache in `lib/services/sqlite_service.dart` and `lib/services/schedule_sqlite_service.dart`.
- `shared_preferences` ^2.3.3 - Session, overlay, biometric, and installation ID persistence in `lib/providers/app_provider.dart` and `lib/services/device_identity_service.dart`.
- `sentry_flutter` ^9.14.0 - Release-only crash reporting in `lib/main.dart` and `lib/services/sentry_service.dart`.

**Infrastructure:**
- `flutter_foreground_task` ^8.14.0 - Persistent kiosk service control in `lib/services/kiosk_background_service.dart`.
- `flutter_local_notifications` ^18.0.0 - Notification fallback and local alerts in `lib/services/kiosk_background_service.dart`, `lib/services/missing_clockout_service.dart`, and `lib/services/pattern_detection_service.dart`.
- `flutter_overlay_window` ^0.5.0 - Floating pill overlay runtime in `lib/overlay_task.dart` and `lib/services/kiosk_background_service.dart`.
- `connectivity_plus` ^6.1.4 - Sync and heartbeat network checks in `lib/services/sync_service.dart` and `lib/services/heartbeat_service.dart`.
- `battery_plus` ^6.2.3 and `package_info_plus` ^8.1.0 - Device heartbeat payloads in `lib/services/heartbeat_service.dart` and diagnostics in `lib/screens/kiosk/kiosk_diagnostics_screen.dart`.
- `local_auth` ^3.0.1 - Biometric support in `lib/services/biometric_service.dart`.
- `pdf` ^3.10.8, `printing` ^5.13.4, and `share_plus` ^10.1.4 - PDF generation and share flows in `lib/services/pdf_service.dart`, `lib/services/pdf_report_service.dart`, `lib/services/payroll_pdf_matrix_export_service.dart`, and `lib/screens/admin/create_admin_screen.dart`.
- `syncfusion_flutter_xlsio` ^29.2.11 and `syncfusion_officechart` ^29.2.11 - Payroll spreadsheet export in `lib/services/payroll_spreadsheet_export_service.dart`.
- `csv` ^6.0.0 and `file_picker` ^8.1.0 - CSV import/export flows in `lib/services/csv_import_service.dart` and `lib/screens/admin/csv_import_screen.dart`.
- `fl_chart` ^0.69.0 - Chart dashboard visuals in `lib/screens/admin/chart_dashboard_screen.dart`.
- `two_dimensional_scrollables` ^0.3.8 - Large schedule and payroll grid widgets in `lib/screens/admin/widgets/schedule_table_view.dart`, `lib/screens/admin/widgets/schedule_cells.dart`, and `lib/screens/admin/widgets/payroll_matrix_table.dart`.
- `cached_network_image` ^3.3.1 - Employee/outlet image rendering in `lib/widgets/badge_avatar.dart` and `lib/screens/kiosk/kiosk_idle_screen.dart`.
- `url_launcher` ^6.3.1 - WhatsApp credential handoff in `lib/screens/admin/create_admin_screen.dart`.
- `@fontsource/inter` ^5.2.8 - Portal typography imported by `src/styles/global.css`.

## Configuration

**Environment:**
- Root `.env` is present and loaded by `lib/main.dart`; `.env.example` is also present at the repo root. Contents were not inspected.
- Flutter runtime expects `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SENTRY_DSN` in `lib/main.dart`.
- Portal server code reads `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and optional fallback `PUBLIC_SUPABASE_URL` / `PUBLIC_SUPABASE_ANON_KEY` in `src/lib/supabase/env.ts`.
- Portal auth derives internal passwords from `PORTAL_SECRET` in `src/lib/portal/auth.ts`; the code has a fallback string, so deployments should override it explicitly.
- Astro site URL and allowed domains are driven by `PUBLIC_SITE_URL`, `VERCEL_PROJECT_PRODUCTION_URL`, `VERCEL_BRANCH_URL`, and `VERCEL_URL` in `astro.config.mjs`.
- Android release scripts honor `ABSENKOK_JAVA_HOME` in `tool/release_env.ps1`, and smoke verification can also rely on `ANDROID_HOME` or `ANDROID_SDK_ROOT` in `tool/release_build.ps1`.
- Android signing expects a private `android/key.properties` file referenced by `android/app/build.gradle.kts`; the file exists locally, but its contents were not inspected.

**Build:**
- `pubspec.yaml` - Flutter dependency graph, asset list, and app version (`8.7.0+8700`).
- `analysis_options.yaml` - Analyzer and lint baseline for the Flutter codebase.
- `package.json` - Astro scripts and web dependency graph.
- `astro.config.mjs` - Astro static output, Vercel adapter, sitemap integration, Tailwind Vite plugin, and allowed-domain security policy.
- `vercel.json` - Static cache headers for `_astro` assets and `.webp` files.
- `tsconfig.json` - Strict Astro TypeScript config.
- `android/settings.gradle.kts` - AGP/Kotlin pins and Flutter Gradle plugin loader.
- `android/app/build.gradle.kts` - Android app build, signing, desugaring, ABI output naming, Java 17 target, and release shrink/minify settings.
- `android/gradle/wrapper/gradle-wrapper.properties` - Gradle wrapper pin.
- `tool/release_env.ps1`, `tool/release_preflight.ps1`, `tool/release_build.ps1` - Tracked Windows release contract and artifact staging.
- Legacy root `build_flutter.ps1` is not present in the current repo root; the active tracked automation lives under `tool/`.

## Platform Requirements

**Development:**
- Flutter 3.41.1 is the tracked release contract in `tool/release_env.ps1` and `tool/release_preflight.ps1`.
- Java 21 Android Studio JBR is required for the tracked release lane in `tool/release_env.ps1`.
- Java/Kotlin source compilation targets Java 17 in `android/app/build.gradle.kts`.
- Android SDK, adb, and the Gradle wrapper under `android/` are required for local Android builds and smoke verification.
- Node.js and npm are required for the Astro portal in `package.json`.
- No iOS target is configured; `pubspec.yaml` disables iOS launcher icon generation and the repo contains only Android-native platform code.

**Production:**
- Mobile target is Android with required NFC hardware, foreground service permissions, overlay permission, and notification permission declared in `android/app/src/main/AndroidManifest.xml`.
- The Flutter app is packaged as versioned APK artifacts named by `android/app/build.gradle.kts` and staged by `tool/release_build.ps1` under `build/releases/android/ABSENKOK-v<versionName>+<versionCode>/`.
- The web target is Vercel-backed Astro deployment via `@astrojs/vercel` in `astro.config.mjs`, with static marketing output plus non-prerendered portal/auth routes such as `src/pages/portal/index.astro` and `src/pages/portal/auth/sign-in.ts`.
- The backend target is the shared Supabase project consumed by both the Flutter app and the Astro portal, with schema and RPC rollout source in `sql/` and privileged function code in `supabase/functions/`.

---

*Stack analysis: 2026-04-14*
