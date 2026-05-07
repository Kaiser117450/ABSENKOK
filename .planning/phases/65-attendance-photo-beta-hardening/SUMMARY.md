---
phase: 65-attendance-photo-beta-hardening
subsystem: kiosk, offline-sync, storage-security, testing
tags: [flutter, supabase, sql, tests, beta-hardening]
provides:
  - Focused regression coverage for attendance photo beta contracts
  - Testable offline photo retry seam in SyncService
  - Fail-closed SQL guardrails for attaching attendance photo URLs
affects: [offline-sync, photo-upload, supabase-sql, test-suite]
key-files:
  created:
    - .planning/phases/65-attendance-photo-beta-hardening/PLAN.md
    - test/models/kiosk_scan_photo_contract_test.dart
    - test/services/photo_upload_service_test.dart
    - test/services/photo_compression_service_test.dart
    - test/phase64/attendance_photo_sql_contract_test.dart
  modified:
    - .planning/phases/64-attendance-photo-grooming/SUMMARY.md
    - lib/services/sync_service.dart
    - lib/services/photo_compression_service.dart
    - sql/phase_64_attendance_photo_storage.sql
    - test/services/sync_service_order_test.dart
completed: 2026-05-07
---

# Phase 65: Attendance Photo Beta Hardening Summary

## Accomplishments

- Captured the Phase 64 completion summary so the beta implementation has a planning handoff.
- Added a Phase 65 hardening plan focused on tests, sync retry seams, and SQL guardrails.
- Made `SyncService.syncPendingLogs()` accept injectable beta/photo retry hooks, preserving production defaults while allowing offline photo behavior to be tested without real Supabase calls.
- Hardened `PhotoCompressionService` against decoder exceptions from malformed bytes; invalid captures now safely return original bytes instead of crashing compression.
- Tightened `attach_attendance_photo` in `sql/phase_64_attendance_photo_storage.sql` so it rejects blank URLs, URLs outside the public `attendance-photos` path, URLs whose `{log_id}.jpg` does not match the target attendance log, and missing log rows.
- Added regression tests for legacy RPC photo-param compatibility, pending photo queue fields, recorded log reference parsing, storage path sanitization, compression resize behavior, beta sync photo upload, duplicate local-id photo resolution for both typed results and Postgrest unique-violation exceptions, empty-queue saved-photo retry, and SQL contract tokens.

## Verification

- `dart format lib\services\sync_service.dart lib\services\photo_compression_service.dart test\models\kiosk_scan_photo_contract_test.dart test\services\photo_upload_service_test.dart test\services\photo_compression_service_test.dart test\services\sync_service_order_test.dart test\phase64\attendance_photo_sql_contract_test.dart`
- `flutter test test\models\kiosk_scan_photo_contract_test.dart test\services\photo_upload_service_test.dart test\services\photo_compression_service_test.dart test\services\sync_service_order_test.dart test\phase64\attendance_photo_sql_contract_test.dart` passed.
- `dart analyze lib\services\sync_service.dart lib\services\photo_compression_service.dart test\models\kiosk_scan_photo_contract_test.dart test\services\photo_upload_service_test.dart test\services\photo_compression_service_test.dart test\services\sync_service_order_test.dart test\phase64\attendance_photo_sql_contract_test.dart` passed.
- `flutter test` passed with 457 tests.
- `flutter build apk --debug --dart-define=ATTENDANCE_PHOTO_BETA=true` passed and produced `build\app\outputs\flutter-apk\app-debug.apk`.

## Notes

- Full `flutter analyze` still reports the repo's existing 26 info/warning items outside this phase's focused surface.
- The Flutter test/build commands required a temporary `C:\tmp\flutter_sdk` junction because the SDK path contains spaces and native-assets hook compilation still breaks on that path. The junction was removed after verification.
- The beta APK build emitted only the known Kotlin 1.9.25 future-deprecation warning; the project intentionally remains pinned because Kotlin 2.x breaks `nfc_manager`.
- Production Supabase migration `phase_64_attendance_photo_grooming_beta_20260507` was applied after explicit user approval on 2026-05-07.
- Supabase Edge Function `analyze-attendance-photo` was deployed on 2026-05-07 with `GOOGLE_CLOUD_VISION_KEY` stored as an Edge Function secret. The function now supports either a Google Vision API key or a service-account JSON value in that secret.
