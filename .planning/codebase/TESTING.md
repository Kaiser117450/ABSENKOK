# Testing Patterns

**Analysis Date:** 2026-04-14

## Test Framework

**Runner:**
- Flutter tests use `flutter_test` from `pubspec.yaml`; no `dart_test.yaml`, `flutter_test_config.dart`, or `integration_test/` directory was detected.
- The portal slice does not ship a JavaScript test runner. `package.json` exposes `astro check` and `astro build`, but no `vitest`, `jest`, or `playwright` config is present.

**Assertion Library:**
- Assertions use `expect(...)` with stock `flutter_test` matchers such as `isTrue`, `isFalse`, `orderedEquals`, `contains`, and `findsOneWidget` across `test/services/`, `test/models/`, `test/widgets/`, and `test/screens/`.

**Run Commands:**
```bash
flutter test
flutter test test/services/report_export_parity_test.dart
flutter test test/screens/kiosk/kiosk_scan_server_time_test.dart
flutter test --no-test-assets
powershell -ExecutionPolicy Bypass -File tool/release_preflight.ps1
npm run check
npm run build
```

## Test File Organization

**Location:**
- Production areas are mirrored under `test/`: `test/models/`, `test/services/`, `test/providers/`, `test/screens/admin/`, `test/screens/kiosk/`, and `test/widgets/`.
- Shared fixture code lives in `test/fixtures/report_export_parity_fixture.dart`.
- Root-level focused tests still exist where the feature is tiny or cross-cutting: `test/device_identity_service_test.dart`.
- Milestone/rollout contract tests live in explicit phase folders such as `test/phase32/`, `test/phase50/`, `test/phase51/`, `test/phase52/`, `test/phase53/`, `test/phase56/`, and `test/phase57/`.

**Naming:**
- Most files follow `{feature}_test.dart`: `test/services/sentry_service_test.dart`, `test/models/attendance_policy_recap_day_test.dart`, `test/widgets/employee_contract_badge_test.dart`.
- Widget/screen behavior tests often encode the feature scenario directly: `test/screens/admin/admin_dashboard_schedule_gap_test.dart`, `test/screens/kiosk/kiosk_scan_server_time_test.dart`.
- Source-contract tests are named around the rollout artifact they lock: `test/phase57/strict_recap_sql_contract_test.dart`, `test/phase53/security_hardening_acceptance_contract_test.dart`.

**Structure:**
```text
test/
├── fixtures/
│   └── report_export_parity_fixture.dart
├── models/
├── providers/
├── services/
├── screens/
│   ├── admin/
│   └── kiosk/
├── widgets/
└── phase32/, phase50/ ... phase57/
```

## Test Structure

**Suite Organization:**
```dart
void main() {
  group('SyncService queue replay order', () {
    test('queued rows replay in ascending queueOrder', () async {
      final fakeAuthority = _FakeKioskScanAuthorityService();
      final result = await SyncService.syncPendingLogs(
        connectivityProbe: () async => [ConnectivityResult.wifi],
        pendingLogsLoader: () async => [_pendingLog(localId: 'queue-1', queueOrder: 1)],
        authorityService: fakeAuthority,
      );

      expect(result.synced, 1);
      expect(fakeAuthority.requests.map((request) => request.queueOrder), orderedEquals([1]));
    });
  });
}
```

**Patterns:**
- Files normally start with local builders or harness helpers, then `group(...)`, then `test(...)` / `testWidgets(...)`: `test/services/schedule_gap_notice_service_test.dart`, `test/screens/admin/admin_reports_policy_recap_test.dart`, `test/widgets/payroll_matrix_table_test.dart`.
- `TestWidgetsFlutterBinding.ensureInitialized()` is used in tests that need platform bindings or `SharedPreferences`: `test/providers/app_provider_biometric_test.dart`, `test/services/biometric_service_test.dart`.
- Widget tests wrap UI in `MaterialApp` and usually `Scaffold` before pumping: `test/widgets/overlay_pill_widget_test.dart`, `test/screens/admin/admin_dashboard_schedule_gap_test.dart`, `test/screens/admin/rekap_harian_test.dart`.
- Long or scrollable screens use `pumpAndSettle()` and `scrollUntilVisible(...)` before assertions: `test/screens/admin/central_dashboard_screen_test.dart`, `test/screens/admin/chart_dashboard_screen_test.dart`, `test/screens/admin/admin_reports_payroll_matrix_test.dart`.

## Mocking

**Framework:** No `mockito`, `mocktail`, or generated mocking code was detected.

**Patterns:**
```dart
class FakeAdminPolicyRecapDatasetService
    extends AdminPolicyRecapDatasetService {
  FakeAdminPolicyRecapDatasetService(this.result);

  final AdminPolicyRecapDatasetResult result;

  @override
  AdminPolicyRecapDatasetResult build({...}) => result;
}
```

- Tests prefer handwritten fakes and subclass overrides: `FakeAdminPolicyRecapDatasetService` in `test/services/schedule_gap_notice_service_test.dart`, `_FakeKioskScanAuthorityService` in `test/services/sync_service_order_test.dart`.
- Dependency injection beats global mocking. Service methods accept callbacks or providers directly: `SyncService.syncPendingLogs(...)`, `PayrollPdfMatrixExportService(...)`, `PayrollSpreadsheetExportService(...)`.
- Screen tests rely on debug/test constructors instead of stubbing internals: `KioskScanScreen.testable` in `lib/screens/kiosk/kiosk_scan_screen.dart`, `KioskIdleScreen.testable` in `lib/screens/kiosk/kiosk_idle_screen.dart`, `ChartDashboardScreen.testable` in `lib/screens/admin/chart_dashboard_screen.dart`, `CentralDashboardScreen.injected` in `lib/screens/admin/central_dashboard_screen.dart`.
- Preference-driven tests seed platform state with `SharedPreferences.setMockInitialValues(...)`: `test/providers/app_provider_biometric_test.dart`.

**What to Mock:**
- Service boundaries, async loaders, temp-directory providers, and persistence probes.
- Provider state containers in widget tests via `ProviderContainer()` plus `UncontrolledProviderScope`: `test/screens/kiosk/kiosk_scan_server_time_test.dart`, `test/screens/admin/chart_dashboard_screen_test.dart`.

**What NOT to Mock:**
- Domain models and value objects. Most tests use real `Employee`, `AttendanceLog`, `AttendancePolicyRecapDay`, `PayrollMatrixRow`, and `PayrollMatrixDayCell` instances.
- Widget keys and real layout surfaces. Tests assert against rendered keys and text rather than fake widgets: `test/widgets/overlay_pill_widget_test.dart`, `test/widgets/payroll_matrix_table_test.dart`.

## Fixtures and Factories

**Test Data:**
```dart
final bundle = buildReportExportParityFixtureBundle();
final recapDataset = service.build(
  employees: bundle.employees,
  strictRows: bundle.strictRows,
  attendanceLogs: bundle.attendanceLogs,
  outletId: bundle.outletId,
  outletName: bundle.outletName,
  outletOperatingMode: bundle.outletOperatingMode,
);
```

- The main shared fixture is `test/fixtures/report_export_parity_fixture.dart`. It builds one canonical mixed strict/fallback reporting dataset reused by `test/services/report_export_parity_test.dart`, `test/services/payroll_pdf_matrix_export_service_test.dart`, `test/services/payroll_spreadsheet_export_service_test.dart`, and `test/screens/admin/admin_reports_payroll_matrix_test.dart`.
- Most other files keep small local factories at the top of the test: `buildRecap` in `test/screens/admin/admin_reports_policy_recap_test.dart`, `buildEntry` in `test/screens/admin/admin_dashboard_schedule_gap_test.dart`, `buildDataset` in `test/widgets/payroll_matrix_table_test.dart`, `_pendingLog` in `test/services/sync_service_order_test.dart`.
- There is no JSON fixture directory or golden-image fixture suite in the current repo.

**Location:**
- Shared reusable fixture code: `test/fixtures/`.
- File-backed source contracts: phase tests such as `test/phase57/strict_recap_sql_contract_test.dart` and `test/phase53/security_hardening_acceptance_contract_test.dart` read real `sql/` or `tool/` files from the repo with `File(...).readAsStringSync()`.

## Coverage

**Requirements:** No enforced coverage target or coverage threshold was detected.

**View Coverage:**
```bash
flutter test --coverage
```

**Current State:**
- No `coverage/` directory, LCOV gate, or GitHub Actions workflow directory is present in the repo.
- Coverage is strongest in the payroll/reporting stack (`test/services/report_export_parity_test.dart`, `test/services/payroll_pdf_matrix_export_service_test.dart`, `test/services/payroll_spreadsheet_export_service_test.dart`), policy recap UI (`test/screens/admin/admin_reports_policy_recap_test.dart`, `test/screens/admin/rekap_harian_test.dart`), kiosk server-time flows (`test/screens/kiosk/kiosk_scan_server_time_test.dart`), and shared widgets (`test/widgets/overlay_pill_widget_test.dart`).

## Test Types

**Unit Tests:**
- Pure model and service rules are covered in `test/models/` and `test/services/`.
- Examples: `test/models/attendance_policy_recap_day_test.dart`, `test/services/sync_service_order_test.dart`, `test/services/sentry_service_test.dart`, `test/services/attendance_policy_recap_service_test.dart`.

**Widget Tests:**
- Admin, kiosk, and shared widget behavior is exercised with `testWidgets(...)`: `test/screens/admin/`, `test/screens/kiosk/`, `test/widgets/`.
- These tests focus on text, keys, button behavior, chip visibility, and scrollable layouts instead of pixel-perfect golden output.

**Artifact/Export Tests:**
- Spreadsheet export tests generate real `.xlsx` files, decode them with `Excel.decodeBytes`, and inspect ZIP/XML internals via `ZipDecoder`: `test/services/payroll_spreadsheet_export_service_test.dart`.
- PDF export tests generate real files and inspect serialized preview/file content for forbidden-field exclusion: `test/services/payroll_pdf_matrix_export_service_test.dart`.

**Source-Contract Tests:**
- Rollout/contract tests assert that SQL and PowerShell helper files exist and contain required tokens: `test/phase57/strict_recap_sql_contract_test.dart`, `test/phase53/security_hardening_acceptance_contract_test.dart`, `test/phase51/sql_role_guard_contract_test.dart`, `test/phase52/portal_recovery_contract_test.dart`.

**E2E Tests:**
- `integration_test/` was not detected.
- No Playwright, Jest, or Vitest suite was detected for the Astro portal.

## Common Patterns

**Provider-aware widget harness:**
```dart
final container = ProviderContainer();
addTearDown(container.dispose);

await tester.pumpWidget(
  UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: KioskScanScreen.testable(...)),
  ),
);
```

- This pattern appears in `test/screens/kiosk/kiosk_scan_server_time_test.dart`, `test/screens/kiosk/kiosk_scan_streak_test.dart`, and `test/screens/admin/chart_dashboard_screen_test.dart`.

**Key-driven assertions:**
```dart
expect(find.byKey(const Key('payroll-employee-rail')), findsOneWidget);
expect(find.byKey(const Key('overlay-pill-attendance')), findsOneWidget);
```

- Shared widgets expose stable keys specifically for tests: `test/widgets/payroll_matrix_table_test.dart`, `test/widgets/overlay_pill_widget_test.dart`, `test/widgets/color_picker_field_test.dart`.

**Injected screen seams:**
- `CentralDashboardScreen.injected` swaps network loaders in `test/screens/admin/central_dashboard_screen_test.dart`.
- `ChartDashboardScreen.testable` injects debug datasets in `test/screens/admin/chart_dashboard_screen_test.dart`.
- `KioskScanScreen.testable` and `KioskIdleScreen.testable` bypass hardware/network dependencies in `test/screens/kiosk/kiosk_scan_server_time_test.dart`.

**Real file generation:**
- Export tests create temp directories with `Directory.systemTemp.createTemp(...)`, clean them in `tearDown(...)`, and assert on the produced filenames and bytes: `test/services/payroll_spreadsheet_export_service_test.dart`, `test/services/payroll_pdf_matrix_export_service_test.dart`.

## Verification Tooling

**Repo-local tooling:**
- `tool/release_preflight.ps1` is the main scripted verification lane. It asserts the pinned Android toolchain and then runs `flutter analyze --no-fatal-infos --no-fatal-warnings`, `flutter test --no-test-assets`, and `android\\gradlew.bat :app:compileReleaseSources`.
- `tool/security_hardening_acceptance.ps1` is part of the verified rollout surface indirectly locked by `test/phase53/security_hardening_acceptance_contract_test.dart`.

**Portal verification:**
- `package.json` exposes `npm run check` -> `astro check` and `npm run build` -> `astro build`.
- The portal slice currently uses build/typecheck verification only; no behavior-test harness was detected under `src/`.

**Automation state:**
- No `.github/workflows/` directory was detected, so verification remains repo-local and script-driven rather than CI-enforced.

---

*Testing analysis: 2026-04-14*
