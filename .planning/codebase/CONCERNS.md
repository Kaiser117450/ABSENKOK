# CONCERNS.md - Technical Debt, Bugs, and Risks

Last updated: 2026-03-04

## Priority Action Queue (Actionable)

### P0-1. Secrets and privileged token are shipped in the app bundle
- Type: Security risk
- Paths: `.env`, `pubspec.yaml`, `.gitignore`, `lib/main.dart`
- Evidence: `.env` includes live `SUPABASE_*` values and `KIOSK_JWT`, and `pubspec.yaml` ships `.env` as an app asset.
- Impact: Secrets can leak via APK extraction or accidental commit; token compromise can enable unauthorized API use.
- Actions:
1. Remove `KIOSK_JWT` from client-side config and rotate existing keys.
2. Keep only safe public config client-side; move privileged operations to server RPC.
3. Add `.env` to `.gitignore` and enforce a `.env.example` workflow.

### P0-2. Android release build uses debug signing key
- Type: Security and release integrity risk
- Paths: `android/app/build.gradle.kts`
- Evidence: `release { signingConfig = signingConfigs.getByName("debug") }`.
- Impact: Production APK trust/distribution is weak and can break store/compliance expectations.
- Actions:
1. Configure a dedicated release keystore and CI-protected signing credentials.
2. Block release artifacts when debug signing is detected.

### P0-3. Offline queue can become permanently unsyncable with no recovery UX
- Type: Known bug and reliability risk
- Paths: `lib/services/sqlite_service.dart`, `lib/services/sync_service.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`
- Evidence: `getPendingLogs()` excludes `retry_count >= syncMaxRetries`, while `countPendingLogs()` still counts them.
- Impact: Badge can stay non-zero forever, logs stop syncing, operators get no remediation path.
- Actions:
1. Add dead-letter state (`permanent_failed`) and explicit admin retry/reset flow.
2. Show actionable UI when records exceed retry cap.
3. Record last error reason and timestamp per failed row.

### P0-4. Schedule save is non-atomic across multiple Supabase writes
- Type: Data integrity bug
- Paths: `lib/screens/admin/shift_scheduler_screen.dart`
- Evidence: Save flow inserts a new schedule, inserts entries, then deactivates old schedule in separate calls.
- Impact: Partial failure can leave duplicate active schedules or empty active schedules.
- Actions:
1. Replace multi-step client write with a single transactional RPC.
2. Enforce DB constraint: one active schedule per outlet and period.
3. Add rollback/idempotency key behavior.

## High Priority Risks (P1)

### P1-1. Role boundary is unclear between kiosk and admin operations
- Type: Security and maintainability risk
- Paths: `lib/core/supabase_client.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`, `lib/screens/kiosk/kiosk_idle_screen.dart`
- Evidence: `SupabaseClientFactory.admin` and `.kiosk` return the same singleton client; kiosk flow updates `employees.home_outlet_id` directly.
- Impact: Privilege assumptions are fragile and can drift from intended RLS model.
- Actions:
1. Split client usage by explicit role contract (kiosk-only RPCs vs admin-only RPCs).
2. Move outlet reassignment to audited server RPC with policy checks.

### P1-2. Open shift query is unfiltered and computed fully client-side
- Type: Access-control and performance risk
- Paths: `lib/screens/admin/admin_dashboard_screen.dart`
- Evidence: `_loadOpenShifts()` fetches all matching `attendance_logs` in 32h window, no outlet scoping in query.
- Impact: Excess payload on larger datasets; potential overexposure if RLS is permissive.
- Actions:
1. Apply outlet filter in query for kepala_gerai context.
2. Push open-shift computation to DB view/RPC with bounded result size.

### P1-3. Reporting screens rely on wide selects and high in-memory processing
- Type: Performance risk
- Paths: `lib/screens/admin/admin_reports_screen.dart`, `lib/screens/admin/admin_dashboard_screen.dart`
- Evidence: Multiple `select('*')` and joined `employees(*)`, `outlets(*)`; daily summary fetches up to 5000 rows then aggregates on device.
- Impact: UI latency and memory spikes as data grows.
- Actions:
1. Use narrow column selects and server-side aggregation.
2. Add cursor/keyset pagination for large time ranges.
3. Add explicit warning/limits for oversized report windows.

### P1-4. Concurrent sync triggers can overlap without locking
- Type: Brittle behavior and load amplification
- Paths: `lib/services/sync_service.dart`, `lib/screens/kiosk/kiosk_idle_screen.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`, `lib/screens/admin/sakit_izin_dialog.dart`
- Evidence: `syncPendingLogs()` is called from several flows without a mutex or in-flight guard.
- Impact: Duplicate network load and noisy retry increments during unstable connectivity.
- Actions:
1. Add process-level sync mutex/debounce.
2. Queue sync requests and coalesce rapid triggers.

### P1-5. Android manifest requests legacy broad storage permissions
- Type: Security and compliance risk
- Paths: `android/app/src/main/AndroidManifest.xml`
- Evidence: `READ_EXTERNAL_STORAGE` and `WRITE_EXTERNAL_STORAGE` are declared.
- Impact: Over-privileged app profile and possible policy friction.
- Actions:
1. Remove unused broad storage permissions.
2. Use scoped storage or SAF only where required.

### P1-6. Repository hygiene risk from checkpoint/backup source files
- Type: Maintainability and merge risk
- Paths: `lib/**/*.backup*`, `lib/**/*.checkpoint*`, `.gitignore`
- Evidence: 20+ backup/checkpoint Dart files exist in source tree and `.gitignore` does not block them.
- Impact: Confusing search results, accidental edits, and higher merge conflict surface.
- Actions:
1. Add ignore rules for backup/checkpoint suffixes.
2. Remove stale artifacts from working tree and CI-check for new ones.

## Medium Priority Risks (P2)

### P2-1. Error handling is inconsistent (silent catch or raw stack exposure)
- Type: Reliability and UX risk
- Paths: `lib/providers/app_provider.dart`, `lib/screens/setup/setup_screen.dart`, `lib/screens/admin/admin_login_screen.dart`, `lib/services/sync_service.dart`
- Evidence: Many `catch (_) {}` swallow failures; some screens show raw exception/stack fragments.
- Impact: Hard to diagnose production failures; sensitive internals can leak to UI.
- Actions:
1. Standardize error policy (user-safe message + structured internal log).
2. Add centralized telemetry (Sentry/Crashlytics or Supabase error table).

### P2-2. Core screens are too large and tightly coupled
- Type: Maintainability risk
- Paths: `lib/screens/admin/admin_dashboard_screen.dart`, `lib/screens/kiosk/kiosk_idle_screen.dart`, `lib/screens/admin/admin_employees_screen.dart`, `lib/screens/admin/admin_reports_screen.dart`, `lib/screens/admin/shift_scheduler_screen.dart`
- Evidence: Multiple UI files exceed 1000 lines and mix data access, business logic, and rendering.
- Impact: High regression risk and low change velocity.
- Actions:
1. Extract domain services + view models/controllers.
2. Split widgets by feature slice and add focused tests per slice.

### P2-3. Schedule SQLite schema has no migration path
- Type: Technical debt
- Paths: `lib/services/schedule_sqlite_service.dart`
- Evidence: Database version is fixed at `1` with no `onUpgrade` strategy.
- Impact: Future schema changes risk runtime breakage or forced data loss.
- Actions:
1. Introduce schema versioning and tested migrations now, before next schema change.

### P2-4. Source comments and docs drift from implementation
- Type: Maintainability risk
- Paths: `lib/models/kiosk_session.dart`, `lib/core/supabase_client.dart`, `README.md`
- Evidence: Comments still mention secure storage while implementation uses SharedPreferences; README is still boilerplate.
- Impact: Onboarding and debugging confusion, incorrect architectural assumptions.
- Actions:
1. Align comments/docs with current auth/session design.
2. Replace README with operational setup, security assumptions, and troubleshooting.

### P2-5. Test coverage is shallow for critical flows
- Type: Quality risk
- Paths: `test/widget_test.dart`, `test/screens/admin/rekap_harian_test.dart`, `test/**`
- Evidence: Placeholder tests remain; critical flows (sync retry cap, schedule save transactionality, role routing, NFC race paths) are not covered.
- Impact: Regressions likely during upcoming refactors.
- Actions:
1. Add integration-style tests for sync + scheduler + role access.
2. Add regression tests for daily summary edge rules and offline queue lifecycle.

## Technical Debt Notes to Track
- `lib/services/schedule_generator.dart` still contains TODO balancing logic and currently returns unbalanced output as-is.
- `lib/screens/admin/shift_scheduler_screen.dart` starts with a stale generated-comment header, indicating documentation/code quality drift.
- `analysis_options.yaml` keeps default linting only; stricter rules would catch several current patterns earlier.
