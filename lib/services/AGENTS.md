# Services — Business Logic Layer

<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-05 | Updated: 2026-04-05 -->

## Purpose

Core business logic services for the Absensi Enakko attendance system. 37 service files handling offline-first attendance, NFC scanning, payroll processing, scheduling, analytics, and PDF/Excel export.

## Key Files

| File | Responsibility |
|------|---------------|
| `sqlite_service.dart` | Offline attendance queue (SQLite CRUD) |
| `sync_service.dart` | Online/offline sync with retry logic |
| `nfc_service.dart` | NFC tag reading, UID extraction |
| `biometric_service.dart` | Fingerprint/face auth via `local_auth` |
| `location_service.dart` | GPS coordinates best-effort |
| `heartbeat_service.dart` | Kiosk device heartbeat reporting (battery, version) |
| `device_identity_service.dart` | Unique device identification |
| `sentry_service.dart` | Crash reporting via Sentry |
| `analytics_service.dart` | Usage analytics tracking |
| `kiosk_background_service.dart` | Foreground service for background NFC scanning |
| `kiosk_scan_authority_service.dart` | Server-time based scan validation |
| `employee_cache_service.dart` | Employee data caching |
| `schedule_generator.dart` | Auto-generate shift schedules |
| `schedule_sqlite_service.dart` | Offline schedule storage |
| `schedule_policy_service.dart` | Schedule policy evaluation |
| `schedule_gap_notice_service.dart` | Detect unscheduled days |
| `pattern_detection_service.dart` | Attendance pattern analysis |
| `streak_service.dart` | Attendance streak tracking |
| `streak_badge_service.dart` | Badge awards for streaks |
| `badge_service.dart` | Achievement badge management |
| `missing_clockout_service.dart` | Detect missed clock-outs |
| `live_content_provider.dart` | Real-time content updates |
| `csv_import_service.dart` | CSV employee import |
| `admin_onboarding_service.dart` | Admin setup wizard |
| `pdf_service.dart` | General PDF generation |
| `pdf_report_service.dart` | Attendance report PDFs |
| `payroll_matrix_builder.dart` | Build payroll matrix data structure |
| `payroll_matrix_semantics.dart` | Payroll cell semantic analysis |
| `payroll_pdf_matrix_export_service.dart` | Export payroll matrix as PDF |
| `payroll_spreadsheet_export_service.dart` | Export payroll as Excel (`syncfusion_flutter_xlsio`) |
| `payroll_validation_bundle_service.dart` | Validate payroll data integrity |
| `payroll_rollout_acceptance_service.dart` | Payroll acceptance workflow |
| `attendance_policy_recap_service.dart` | Policy-based attendance recap |
| `admin_policy_recap_dataset_service.dart` | Admin policy recap data builder |
| `legacy_payroll_recap_fallback_service.dart` | Legacy payroll compatibility |
| `live_content_provider.dart` | Real-time content updates |

## Architecture Notes

- **Pattern**: Static methods or singleton instances; async operations return `Future`s.
- **Offline-first**: SQLite services (`sqlite_service.dart`, `schedule_sqlite_service.dart`) handle local persistence. `sync_service.dart` reconciles with Supabase when online.
- **Supabase guard**: Most services depend on Supabase client — always check `supabaseReady` global bool before calling `Supabase.instance.client`.
- **Payroll cluster**: `payroll_matrix_builder`, `payroll_matrix_semantics`, `payroll_pdf_matrix_export_service`, `payroll_spreadsheet_export_service`, `payroll_validation_bundle_service`, and `payroll_rollout_acceptance_service` are tightly coupled. Changes to one often cascade to others.
- **Schedule cluster**: `schedule_generator`, `schedule_sqlite_service`, `schedule_policy_service`, and `schedule_gap_notice_service` work together.
- **Gamification cluster**: `streak_service`, `streak_badge_service`, `badge_service`, and `pattern_detection_service` form the attendance gamification subsystem.

## For AI Agents

- Services are the core business logic. Most depend on Supabase client — check `supabaseReady`.
- SQLite services handle offline-first data persistence.
- Payroll services are tightly coupled — changes cascade across the cluster.
- Pattern: static methods or singleton instances, async operations return Futures.
- When modifying payroll services, verify export (PDF + Excel) still produces correct output.
- `SharedPreferences` for session state (NOT `FlutterSecureStorage` — causes ANR).
