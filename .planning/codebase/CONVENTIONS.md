# Coding Conventions

**Analysis Date:** 2026-04-14

## Naming Patterns

**Files:**
- Flutter and test files use `snake_case.dart`: `lib/services/sync_service.dart`, `lib/screens/admin/admin_reports_screen.dart`, `test/services/report_export_parity_test.dart`.
- Screen widgets keep the `{feature}_screen.dart` pattern: `lib/screens/kiosk/kiosk_scan_screen.dart`, `lib/screens/admin/shift_scheduler_screen.dart`.
- Admin-only reusable widgets live under `lib/screens/admin/widgets/` with feature-first names: `lib/screens/admin/widgets/payroll_matrix_table.dart`, `lib/screens/admin/widgets/policy_recap_payroll_support_section.dart`.
- Shared widgets live under `lib/widgets/` with `app_` or domain nouns: `lib/widgets/app_card.dart`, `lib/widgets/attendance_policy_badge.dart`, `lib/widgets/outlet_mode_badge.dart`.
- Tests mirror production areas under `test/`: `test/services/`, `test/screens/admin/`, `test/screens/kiosk/`, `test/widgets/`, and `test/fixtures/`.

**Functions:**
- Public APIs use `camelCase` verbs and nouns: `buildPayrollMatrix` in `lib/services/payroll_matrix_builder.dart`, `filterPolicyRecapRows` in `lib/screens/admin/admin_reports_screen.dart`, `reportExportParityKey` in `test/fixtures/report_export_parity_fixture.dart`.
- Private helpers use a leading underscore: `_buildRowKey` in `lib/services/admin_policy_recap_dataset_service.dart`, `_loadActionState` in `lib/screens/kiosk/kiosk_scan_screen.dart`, `_configureSheetLayout` in `lib/services/payroll_spreadsheet_export_service.dart`.
- Test helpers follow `buildX`, `pumpX`, and `_FakeX` naming: `buildRecap` in `test/screens/admin/admin_reports_policy_recap_test.dart`, `pumpScanScreen` in `test/screens/kiosk/kiosk_scan_server_time_test.dart`, `_FakeKioskScanAuthorityService` in `test/services/sync_service_order_test.dart`.

**Variables:**
- Local state and fields use `camelCase`: `_selectedOutletId`, `_policyRecapRows`, `_successScannedAtWitaLabel`, `managedOutletId` in `lib/screens/admin/admin_reports_screen.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`, and `lib/providers/app_provider.dart`.
- Boolean fields usually read as `isX`, `hasX`, or `mustX`: `isLoading`, `isKepalaGerai`, `hasBiometricHardware`, `mustChangePassword` in `lib/providers/app_provider.dart`; `isCompatibilityMode` in `lib/services/admin_policy_recap_dataset_service.dart`.

**Types:**
- Domain models and DTOs use `PascalCase` with `const` constructors when immutable: `AppState` in `lib/providers/app_provider.dart`, `PayrollMatrixRow` in `lib/models/payroll_matrix_row.dart`, `PayrollPdfDocumentPreview` in `lib/services/payroll_pdf_matrix_export_service.dart`.
- Enums expose storage/UI mapping through getters or extensions: `AttendancePolicyStatus.storageValue` and `.label` in `lib/models/attendance_policy_recap_day.dart`, `PolicyRecapFilterLabel` in `lib/screens/admin/admin_reports_screen.dart`.

## Code Style

**Formatting:**
- The repo relies on the stock Dart formatter; `analysis_options.yaml` only includes `package:flutter_lints/flutter.yaml`.
- Two-space indentation, trailing commas, and vertically split argument lists are standard in UI-heavy files such as `lib/app.dart`, `lib/screens/admin/admin_reports_screen.dart`, and `lib/screens/kiosk/kiosk_scan_screen.dart`.
- Large files use banner separators to break sections: `lib/app.dart`, `lib/screens/admin/chart_dashboard_screen.dart`, `lib/services/pdf_report_service.dart`.

**Linting:**
- No repo-specific lint overrides are enabled in `analysis_options.yaml`.
- Inline suppressions are used sparingly for pragmatic cases, especially low-level logging paths such as `lib/services/sync_service.dart`.
- Newer UI code prefers `withValues(alpha: ...)` instead of deprecated opacity helpers, for example in `lib/screens/admin/admin_reports_screen.dart`.

## Import Organization

**Order:**
1. Dart SDK imports such as `dart:async`, `dart:io`, and `dart:typed_data`.
2. Flutter and framework imports such as `package:flutter/...`, `package:flutter_riverpod/...`, and `package:go_router/...`.
3. Third-party packages such as `package:supabase_flutter/...`, `package:fl_chart/...`, and `package:syncfusion_flutter_xlsio/...`.
4. App-local imports, either relative or package-style.

**Path Aliases:**
- There are no custom import aliases configured in the Dart app.
- Older/root files lean on relative imports: `lib/app.dart`, `lib/providers/app_provider.dart`, `lib/services/sync_service.dart`.
- Newer admin/reporting code and most tests prefer `package:absensi_enakko_flutter/...`: `lib/services/admin_policy_recap_dataset_service.dart`, `lib/screens/admin/admin_reports_screen.dart`, `test/widgets/payroll_matrix_table_test.dart`.
- Tests still use relative imports for nearby fixtures and a few older production imports: `test/services/report_export_parity_test.dart`, `test/services/payroll_pdf_matrix_export_service_test.dart`, `test/screens/admin/central_dashboard_screen_test.dart`.

## State Management & Navigation

**Riverpod:**
- Global session and mode state are centralized in a single `StateNotifierProvider`: `appProvider` in `lib/providers/app_provider.dart`.
- Screens that need lifecycle work use `ConsumerStatefulWidget`: `lib/screens/admin/admin_reports_screen.dart`, `lib/screens/admin/admin_dashboard_screen.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`, `lib/screens/setup/setup_screen.dart`.
- `ref.read(...)` is used in event handlers, `initState`, and async loaders; `ref.watch(...)` and `select(...)` stay inside `build` for reactive UI, as seen in `lib/app.dart`, `lib/screens/admin/admin_shell.dart`, and `lib/screens/admin/admin_dashboard_screen.dart`.
- State mutation stays inside `AppNotifier` methods plus `AppState.copyWith(...)`; callers do not mutate provider state directly.

**Navigation:**
- Routing lives in `routerProvider` inside `lib/app.dart`; there is no separate `lib/app_router.dart` in the current repo.
- Redirect rules are centralized in one `GoRouter.redirect` block in `lib/app.dart` and gate loading, admin, kepala-gerai, kiosk, and setup flows.
- Admin routes are wrapped by a `ShellRoute` and `AdminShell` in `lib/app.dart`.
- Screen-level navigation still uses `context.go(...)` and `context.pop()`, for example in `lib/screens/kiosk/kiosk_scan_screen.dart`.

## Service Conventions

**Construction:**
- Pure business-rule services favor immutable result objects plus synchronous `build(...)` methods: `lib/services/admin_policy_recap_dataset_service.dart` and `lib/services/schedule_gap_notice_service.dart`.
- Imperative services expose static or singleton-like APIs: `SyncService.syncPendingLogs` in `lib/services/sync_service.dart`, `PdfReportService.generateAttendanceReport` in `lib/services/pdf_report_service.dart`, and `AnalyticsService.instance` consumers across `lib/screens/admin/`.
- Test seams are added with optional callback/provider parameters instead of a mocking framework: `SyncService.syncPendingLogs(...)`, `PayrollPdfMatrixExportService(...)`, and `PayrollSpreadsheetExportService(...)`.

**Async/UI boundary:**
- Async screen loaders usually set loading flags first, run work in `try/catch`, then guard `setState` with `mounted`: `lib/screens/admin/central_dashboard_screen.dart`, `lib/screens/admin/chart_dashboard_screen.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`.
- Long-running UI work is kicked off with `Future.wait` or `unawaited(...)` rather than nested callbacks: `lib/screens/admin/chart_dashboard_screen.dart`, `lib/app.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`.

## Error Handling

**Patterns:**
- UI-facing flows usually catch, log, and degrade gracefully instead of rethrowing into the widget tree: `lib/screens/kiosk/kiosk_scan_screen.dart`, `lib/screens/admin/central_dashboard_screen.dart`, `lib/services/analytics_service.dart`, `lib/services/heartbeat_service.dart`.
- Offline-first paths fall back to cached or queued data when remote work fails: `lib/screens/kiosk/kiosk_scan_screen.dart`, `lib/screens/admin/shift_scheduler_screen.dart`, `lib/providers/app_provider.dart`.
- Supabase/auth-specific branches use typed exception handling when the failure path matters: `on PostgrestException` in `lib/services/sync_service.dart` and `lib/services/csv_import_service.dart`, `on AuthException` in `lib/screens/admin/admin_login_screen.dart`, `on FunctionException` in `lib/services/admin_onboarding_service.dart`.
- Parser/export code throws fast on invalid input with `StateError` or `ArgumentError`: `lib/models/attendance_policy_recap_day.dart`, `lib/services/payroll_pdf_matrix_export_service.dart`, `lib/services/payroll_spreadsheet_export_service.dart`.

## Logging

**Framework:** `debugPrint` is the default logging path.

**Patterns:**
- Context-prefixed logs are standard: `[KioskScan]` in `lib/screens/kiosk/kiosk_scan_screen.dart`, `[Dashboard]` in `lib/screens/admin/admin_dashboard_screen.dart`, `[Heartbeat]` in `lib/services/heartbeat_service.dart`, `[BgService]` in `lib/services/kiosk_background_service.dart`, `[AnalyticsService]` in `lib/services/analytics_service.dart`.
- Some low-level/background code still uses `print` with lint suppression for raw stack dumps or queue tracing: `lib/services/sync_service.dart`, `lib/services/nfc_service.dart`, `lib/services/location_service.dart`, `lib/services/payroll_spreadsheet_export_service.dart`.

## Comments

**When to Comment:**
- Use brief intent comments around guards, rollout-sensitive logic, and fallbacks: `lib/app.dart`, `lib/providers/app_provider.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`.
- Use doc comments for reusable or testable APIs: `lib/screens/admin/central_dashboard_screen.dart`, `lib/services/sentry_service.dart`, `lib/services/pdf_report_service.dart`.

**JSDoc/TSDoc:**
- The Flutter slice uses Dart doc comments (`///`).
- The Astro slice in `src/` does not define a parallel doc-comment convention in the current repo.

## Function Design

**Size:**
- Large orchestration files are common for complex screens and exports: `lib/screens/admin/admin_reports_screen.dart`, `lib/screens/kiosk/kiosk_scan_screen.dart`, `lib/services/payroll_spreadsheet_export_service.dart`, `lib/services/payroll_pdf_matrix_export_service.dart`.
- Even inside large files, logic is usually broken into many small private helpers and sectioned widgets instead of nested inline code.

**Parameters:**
- Builder-style methods prefer named required parameters: `AdminPolicyRecapDatasetService.build(...)`, `ScheduleGapNoticeService.build(...)`, `PayrollPdfMatrixExportService.buildPayrollPdf(...)`.
- Test-only seams also use named parameters instead of positional flags: `KioskScanScreen.testable(...)`, `CentralDashboardScreen.injected(...)`, `ChartDashboardScreen.testable(...)`.

**Return Values:**
- Rich return objects are preferred over loose maps when data leaves a boundary: `AdminPolicyRecapDatasetResult` in `lib/services/admin_policy_recap_dataset_service.dart`, `PayrollMatrixDataset` in `lib/models/payroll_matrix_row.dart`.
- Lightweight record typedefs are used for internal-only results: `_ReportStats` in `lib/services/pdf_report_service.dart`, `SyncResult` in `lib/services/sync_service.dart`.

## Module Design

**Exports:**
- No barrel files were detected under `lib/`; callers import concrete files directly.

**Barrel Files:**
- Not used in the Flutter slice or the portal slice.

**Boundaries:**
- Shared UI primitives live in `lib/widgets/`; admin-specific composite widgets live in `lib/screens/admin/widgets/`; business logic lives in `lib/services/`; state stays in `lib/providers/`; models stay in `lib/models/`.
- Newer reporting work keeps pure transformation logic in services/models and leaves screens as orchestration/composition layers. The clearest chain is `lib/services/admin_policy_recap_dataset_service.dart` -> `lib/services/payroll_matrix_builder.dart` -> `lib/screens/admin/admin_reports_screen.dart`.
- The Astro portal currently contributes build/typecheck scripts through `package.json`, but no separate JavaScript testing or barrel-file convention is defined under `src/`.

---

*Convention analysis: 2026-04-14*
