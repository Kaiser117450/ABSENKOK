# test/services/AGENTS.md

<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-05 | Updated: 2026-04-05 -->

## Purpose

Service unit tests. 25 test files covering all business logic services. This is the largest and most critical test directory.

## Key Files

| File | Description |
|---|---|
| `analytics_service_test.dart` | Analytics and reporting service |
| `attendance_policy_recap_service_test.dart` | Attendance policy recap logic |
| `admin_policy_recap_dataset_service_test.dart` | Admin policy recap dataset builder |
| `biometric_service_test.dart` | Biometric authentication service |
| `csv_import_service_test.dart` | CSV employee import parsing and validation |
| `kiosk_scan_authority_service_test.dart` | Scan authority and permission checks |
| `missing_clockout_service_test.dart` | Missing clock-out detection and handling |
| `nfc_service_test.dart` | NFC tag reading and writing |
| `pattern_detection_test.dart` | Arrival/departure pattern analysis |
| `payroll_matrix_builder_test.dart` | Payroll matrix construction logic |
| `payroll_matrix_semantics_test.dart` | Payroll matrix cell meaning and rules |
| `payroll_pdf_matrix_export_service_test.dart` | PDF export of payroll matrix |
| `payroll_rollout_acceptance_service_test.dart` | Payroll rollout acceptance criteria |
| `payroll_spreadsheet_export_service_test.dart` | Spreadsheet export of payroll data |
| `payroll_validation_bundle_service_test.dart` | Payroll validation bundle checks |
| `pdf_report_service_test.dart` | General PDF report generation |
| `pdf_service_color_test.dart` | PDF color and styling |
| `report_export_parity_test.dart` | PDF vs spreadsheet export parity |
| `schedule_gap_notice_service_test.dart` | Schedule gap detection and notices |
| `sentry_service_test.dart` | Sentry error reporting integration |
| `streak_badge_service_test.dart` | Attendance streak badge logic |
| `streak_service_test.dart` | Attendance streak calculation |
| `sync_service_order_test.dart` | Offline sync queue ordering |
| `live_content_provider_test.dart` | Live content/realtime provider |
| `legacy_payroll_recap_fallback_service_test.dart` | Legacy payroll recap fallback |

## For AI Agents

- Every service in `lib/services/` should have a corresponding test here
- Tests mock Supabase and SQLite — never use real connections
- Run individual test: `flutter test test/services/specific_test.dart`
- **Payroll tests are the most complex** — matrix builder, semantics, validation, export
- Streak and pattern tests validate time-series logic
- Sync service tests verify offline-first queue ordering
