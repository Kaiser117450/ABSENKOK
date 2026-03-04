# Technology Stack

## Scope Snapshot
- Project type is Flutter app (`project_type: app`) in `.metadata`.
- Active platform in this repository is Android (`android/` exists, while `ios/`, `web/`, `macos/`, `linux/`, and `windows/` are not present).
- Main app entrypoint is `lib/main.dart`, and overlay entrypoint is `lib/overlay_task.dart`.

## Languages and Build DSL
- Dart is the primary language across `lib/` and `test/`.
- Kotlin is used for Android-native integrations in `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/MainActivity.kt` and `android/app/src/main/kotlin/com/enakko/absensi_enakko_flutter/KioskNotificationHelper.kt`.
- XML is used for Android manifests, resources, notification layouts, and NFC tech filters in `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/layout/`, and `android/app/src/main/res/xml/`.
- Gradle Kotlin DSL is used in `android/build.gradle.kts`, `android/app/build.gradle.kts`, and `android/settings.gradle.kts`.

## Runtime and Toolchain
- Flutter channel and revision are tracked in `.metadata` (`stable`, revision `582a0e7c5581dc0ca5f7bfd8662bb8db6f59d536`).
- Dart SDK constraint in `pubspec.yaml` is `>=3.3.0 <4.0.0`.
- Resolved lockfile SDK floor in `pubspec.lock` is Dart `>=3.10.3 <4.0.0` and Flutter `>=3.38.4`.
- Android Gradle Plugin is `8.11.1` in `android/settings.gradle.kts`.
- Kotlin Android plugin is pinned to `1.9.25` in `android/settings.gradle.kts`.
- Gradle wrapper distribution is `8.14` in `android/gradle/wrapper/gradle-wrapper.properties`.
- Java/Kotlin target is 17 in `android/app/build.gradle.kts`.
- `minSdk = 24` is explicit in `android/app/build.gradle.kts`.
- `targetSdk` and `compileSdk` are delegated to Flutter values in `android/app/build.gradle.kts`.

## App Framework and Architecture
- Flutter Material app shell with router is in `lib/app.dart`.
- State management uses Riverpod (`flutter_riverpod`) via `lib/providers/app_provider.dart`.
- Navigation uses GoRouter with role/session redirects in `lib/app.dart`.
- Theme and design tokens are centralized in `lib/core/theme.dart`.
- Supabase client factory is centralized in `lib/core/supabase_client.dart`.
- Kiosk + admin feature split is visible under `lib/screens/kiosk/` and `lib/screens/admin/`.
- Service layer lives under `lib/services/` (NFC, sync, SQLite, background notification/overlay, PDF export).

## Major Dependency Set (Current Constraints)
- Backend/cloud: `supabase_flutter` declared in `pubspec.yaml` (resolved to `2.12.0` in `pubspec.lock`).
- Offline DB: `sqflite`, `path_provider`, `path` in `pubspec.yaml` and used by `lib/services/sqlite_service.dart` and `lib/services/schedule_sqlite_service.dart`.
- Device/NFC: `nfc_manager` in `pubspec.yaml`, used by `lib/services/nfc_service.dart` and `lib/screens/kiosk/kiosk_idle_screen.dart`.
- Location: `geolocator` in `pubspec.yaml`, used by `lib/services/location_service.dart`.
- Connectivity: `connectivity_plus` in `pubspec.yaml`, used by `lib/services/sync_service.dart`.
- Notifications/foreground/overlay: `flutter_foreground_task`, `flutter_local_notifications`, `flutter_overlay_window` in `pubspec.yaml`, used by `lib/services/kiosk_background_service.dart`.
- UI and UX: `toastification`, `confetti`, `cached_network_image`, `google_fonts` in `pubspec.yaml`, used in `lib/app.dart`, `lib/screens/kiosk/`, `lib/screens/admin/`, and `lib/core/theme.dart`.
- Export/reporting: `pdf`, `share_plus` in `pubspec.yaml`, used by `lib/services/pdf_service.dart` and `lib/screens/admin/admin_reports_screen.dart`.
- Environment loading: `flutter_dotenv` in `pubspec.yaml`, used by `lib/main.dart`.

## Declared But Not Currently Imported in `lib/`
- `http` is declared in `pubspec.yaml` but has no current import usage under `lib/`.
- `uuid` is declared in `pubspec.yaml` but has no current import usage under `lib/`.
- `printing` is declared in `pubspec.yaml` but no import usage under `lib/`.
- `screenshot` is declared in `pubspec.yaml` but no import usage under `lib/`.

## Build and Release Configuration
- Release build enables code shrinking and resource shrinking in `android/app/build.gradle.kts` (`isMinifyEnabled = true`, `isShrinkResources = true`).
- Release currently signs with debug signing config in `android/app/build.gradle.kts`.
- ProGuard rules are customized in `android/app/proguard-rules.pro` for foreground task, NFC, overlay, and notification classes.
- Core library desugaring is enabled with `com.android.tools:desugar_jdk_libs:2.1.4` in `android/app/build.gradle.kts`.
- MultiDex is enabled in `android/app/build.gradle.kts`.
- Root and subproject build output are redirected to `../../build` in `android/build.gradle.kts`.
- Gradle JVM flags are tuned in `android/gradle.properties` (`-Xmx3g`, G1GC, daemon disabled).

## Config, Assets, and Analysis
- Environment variables are loaded from `.env` and bundled as Flutter asset via `pubspec.yaml`.
- Supabase init keys are read from `dotenv.env` in `lib/main.dart`.
- App icon generation is configured via `flutter_launcher_icons` in `pubspec.yaml` (`ios: false`, Android enabled).
- Analyzer uses `flutter_lints` via `analysis_options.yaml`.
- Test harness is Flutter test with specs under `test/`.

## Practical Planning Notes
- This is an Android-first codebase with heavy native permission and background-service behavior (`android/app/src/main/AndroidManifest.xml`, `lib/services/kiosk_background_service.dart`).
- Offline-first attendance logging is core architecture (`lib/services/sqlite_service.dart` plus `lib/services/sync_service.dart`).
- Supabase is both admin and kiosk backend through one shared client factory (`lib/core/supabase_client.dart`), so future auth hardening likely affects both flows.
