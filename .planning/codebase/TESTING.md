# Testing Guide

Last updated: 2026-03-04

## Current test stack
- Primary framework: `flutter_test` (from `pubspec.yaml` under `dev_dependencies`).
- Lint baseline for tests: `flutter_lints` (same project-wide lint policy from `analysis_options.yaml`).
- No dedicated mocking package is installed (`mockito` and `mocktail` are not present in `pubspec.yaml`).
- No integration test package/folder currently exists (`integration_test/` is absent).

## Current test directory structure
- `test/widget_test.dart`
- `test/models/overlay_pill_state_test.dart`
- `test/widgets/overlay_pill_widget_test.dart`
- `test/screens/admin/rekap_harian_test.dart`

## What is actually covered today
- `test/models/overlay_pill_state_test.dart` contains real unit coverage for:
  - JSON and legacy payload parsing in `lib/models/overlay_pill_state.dart`.
  - Serialization (`toWirePayload`) contract checks.
  - Event expiry helper behavior.
- `test/widgets/overlay_pill_widget_test.dart` contains real widget coverage for `KioskOverlayUI` in `lib/overlay_task.dart`:
  - Idle/event rendering.
  - Event timeout reversion.
  - Tap-to-toggle expanded/collapsed behavior.
  - Legacy payload fallback handling.
  - Basic readability contrast assertions.
- `test/widget_test.dart` is placeholder-only and does not validate production features.
- `test/screens/admin/rekap_harian_test.dart` is currently spec-oriented placeholder tests that pass with `expect(true, isTrue)`.

## Current mocking and testability strategy
- Current tests avoid mock frameworks and instead use controllable inputs:
  - `StreamController<String>` is injected into `KioskOverlayUI` via `dataStream` in `test/widgets/overlay_pill_widget_test.dart`.
  - Deterministic timing is achieved through configurable durations (`clockTick`, `autoCollapseDelay`) on `KioskOverlayUI`.
- This codebase currently does not mock:
  - Supabase calls in files like `lib/screens/admin/admin_reports_screen.dart` and `lib/screens/kiosk/kiosk_idle_screen.dart`.
  - Method channels used by `lib/services/kiosk_background_service.dart` and `lib/screens/kiosk/kiosk_idle_screen.dart`.
  - Riverpod provider overrides for integration-style provider testing.

## Coverage posture
- Test files: 4 files under `test/`.
- Total declared test cases: 20 (mix of real and placeholder tests).
- Coverage artifact (`coverage/lcov.info`) is not committed/present right now.
- CI test automation is not configured (no `.github/workflows/` directory).
- Effective confidence is currently concentrated in overlay state parsing/rendering, with most app-critical flows still untested.

## Major testing gaps by area
- Authentication and setup flows:
  - `lib/screens/setup/setup_screen.dart`
  - `lib/screens/admin/admin_login_screen.dart`
- Global route guard and role routing:
  - `lib/app.dart`
- Riverpod state transitions and persistence:
  - `lib/providers/app_provider.dart`
- Offline queue and sync correctness:
  - `lib/services/sqlite_service.dart`
  - `lib/services/sync_service.dart`
- NFC/device and kiosk workflow behavior:
  - `lib/services/nfc_service.dart`
  - `lib/screens/kiosk/kiosk_idle_screen.dart`
  - `lib/screens/kiosk/kiosk_scan_screen.dart`
- Schedule generation and schedule offline store:
  - `lib/services/schedule_generator.dart`
  - `lib/services/schedule_sqlite_service.dart`
- Admin reporting and employee/outlet management screens:
  - `lib/screens/admin/admin_reports_screen.dart`
  - `lib/screens/admin/admin_employees_screen.dart`
  - `lib/screens/admin/admin_outlets_screen.dart`

## Practical test expansion priorities
- Priority 1: provider and service unit tests that do not require rendering.
  - Add focused tests for `AppNotifier` transitions in `lib/providers/app_provider.dart`.
  - Add data-layer tests for `lib/services/sqlite_service.dart` and `lib/services/sync_service.dart` error branches.
- Priority 2: route and auth behavior tests around `lib/app.dart` redirect logic.
- Priority 3: convert placeholder admin report specs into executable behavior tests against extracted pure functions from `lib/screens/admin/admin_reports_screen.dart`.
- Priority 4: add integration coverage for end-to-end kiosk flow once a stable Supabase test harness strategy is chosen.

## Suggested command baseline
- Run all tests: `flutter test`
- Run one test file: `flutter test test/widgets/overlay_pill_widget_test.dart`
- Generate local coverage artifact: `flutter test --coverage`
- Static analysis: `flutter analyze`

## Planning note
- When adding new tests, prefer extracting pure helpers from UI-heavy files to make behavior testable without platform dependencies.
- Keep test file placement aligned with source domains (`test/models/`, `test/widgets/`, `test/screens/...`, and future `test/services/`, `test/providers/`).
