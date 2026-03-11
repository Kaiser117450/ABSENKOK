# Technology Stack

**Analysis Date:** 2026-03-11

## Languages

**Primary:**
- Dart ^3.3.0 - Flutter app language, all business logic, UI, services
- Kotlin - Android native integration (NFC handling, notification customization at `android/app/src/main/kotlin/`)

**Secondary:**
- Python - Build scripts and code transformation tools (multiple `fix_*.py` and `convert_*.py` scripts for codebase maintenance)

## Runtime

**Environment:**
- Flutter SDK stable channel (revision 582a0e7c5581dc0ca5f7bfd8662bb8db6f59d536)
- Dart SDK >=3.3.0 <4.0.0

**Package Manager:**
- pub (Flutter's package manager)
- Lockfile: `pubspec.lock` present and committed

## Frameworks

**Core:**
- Flutter SDK - Cross-platform mobile framework (Android primary target)
- Material Design - UI component library via `flutter/material.dart`

**State Management:**
- flutter_riverpod ^2.6.1 - Global and screen-level state management via providers in `lib/providers/`

**Navigation:**
- go_router ^14.8.1 - Declarative routing with type-safe navigation in `lib/app.dart`

**Testing:**
- flutter_test (SDK) - Unit and widget testing framework
- flutter_lints ^5.0.0 - Dart static analysis and linting rules

**Build/Dev:**
- flutter_launcher_icons ^0.14.3 - Generates Android adaptive icons from `assets/icon.png`
- ProGuard - Android code minification and obfuscation (enabled for release builds in `android/app/build.gradle.kts`)

## Key Dependencies

**Backend & Data:**
- supabase_flutter ^2.8.4 - PostgreSQL database client, authentication, realtime subscriptions to `attendance_logs`, `employees`, `outlets` tables
- sqflite ^2.4.1 - SQLite local database for offline attendance queue (table: `pending_logs` in `absensi_enakko.db`)
- path_provider ^2.1.5 - Cross-platform path resolution for local database storage
- shared_preferences ^2.3.3 - Key-value storage for kiosk session (`kiosk_session_v1`, `overlay_keep_foreground_v1`)

**Hardware Integration:**
- nfc_manager ^3.5.0 - Universal NFC reader supporting e-KTP, e-Toll, Flazz, bank cards, all ISO 14443-A/B/4, FeliCa, Mifare technologies in `lib/services/nfc_service.dart`
- geolocator ^13.0.2 - GPS location capture (best-effort, 5s timeout, medium accuracy) in `lib/services/location_service.dart`

**Background Processing:**
- flutter_foreground_task ^8.14.0 - Android foreground service for background NFC scanning without app open (service type: `connectedDevice`)
- flutter_local_notifications ^18.0.0 - Local push notifications for NFC scan alerts
- flutter_overlay_window ^0.5.0 - System-wide floating overlay (Dynamic Island-style pill UI) with `SYSTEM_ALERT_WINDOW` permission

**Network & Sync:**
- connectivity_plus ^6.1.4 - Network state checking before sync operations in `lib/services/sync_service.dart`
- http ^1.2.2 - HTTP client for custom header injection in kiosk authentication

**UI & UX:**
- google_fonts ^6.2.1 - Custom typography loading
- cached_network_image ^3.3.1 - Image caching for employee photos
- toastification ^2.3.0 - In-app toast notifications (Dynamic Island style)
- confetti ^0.8.0 - Success screen celebration animation in `lib/screens/kiosk/kiosk_scan_screen.dart`

**Data Processing:**
- pdf ^3.10.8 - PDF document generation for attendance reports in `lib/services/pdf_service.dart`
- printing ^5.13.4 - PDF preview and sharing via native Android print dialog
- screenshot ^3.0.0 - Widget-to-image capture for schedule exports
- share_plus ^10.1.4 - Native share sheet for CSV/PDF export
- intl ^0.19.0 - Date/time formatting and internationalization (Indonesian locale `id_ID`)

**Utilities:**
- uuid ^4.5.1 - UUID v4 generation for local log IDs (`local_id` in `pending_logs` table)
- path ^1.9.1 - Path manipulation for file operations
- flutter_dotenv ^5.2.1 - Environment variable loading from `.env` (Supabase credentials)

## Configuration

**Environment:**
- Configuration via `.env` file (loaded in `lib/main.dart` via `flutter_dotenv`)
- Required variables:
  - `SUPABASE_URL` - Supabase project URL
  - `SUPABASE_ANON_KEY` - Supabase anonymous key for client initialization
- `.env` file is listed in `pubspec.yaml` assets but must NOT be committed to git (secrets)

**Build:**
- `pubspec.yaml` - Dependency manifest, app version 1.1.0+8006
- `android/app/build.gradle.kts` - Android build configuration:
  - applicationId: `com.enakko.absensi_enakko_flutter`
  - minSdk: 24 (Android 7.0)
  - targetSdk: flutter.targetSdkVersion (latest stable)
  - compileSdk: flutter.compileSdkVersion
  - Java/Kotlin target: JVM 17
  - Release: ProGuard enabled, resources shrunk, signed with debug keys
  - Output filename: `ABSENKOK-v${versionName}.apk`
- `analysis_options.yaml` - Dart analyzer configuration
- `devtools_options.yaml` - Flutter DevTools settings

**Assets:**
- `assets/icon.png` - App launcher icon source
- `assets/images/` - Image assets directory
- Adaptive icon background: `#FF0000` (red, Enakko brand color)

## Platform Requirements

**Development:**
- Flutter SDK stable channel
- Android Studio / VS Code with Flutter plugin
- Android SDK with API 24+ for development devices
- JDK 17 for Android builds

**Production:**
- Target: Android 7.0+ (API 24+)
- NFC hardware required (`android.hardware.nfc` marked as required in `AndroidManifest.xml`)
- Permissions: INTERNET, NFC, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, VIBRATE, FOREGROUND_SERVICE, FOREGROUND_SERVICE_CONNECTED_DEVICE, POST_NOTIFICATIONS (Android 13+), SYSTEM_ALERT_WINDOW, REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
- Deployment target: Standalone APK for kiosk Android tablets with NFC readers
- No iOS support (iOS platform excluded from launcher icons config)

---

*Stack analysis: 2026-03-11*
