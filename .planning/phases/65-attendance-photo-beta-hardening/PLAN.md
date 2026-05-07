---
phase: 65-attendance-photo-beta-hardening
type: execute
depends_on:
  - 64-attendance-photo-grooming
files_modified:
  - .planning/phases/64-attendance-photo-grooming/SUMMARY.md
  - .planning/phases/65-attendance-photo-beta-hardening/PLAN.md
  - sql/phase_64_attendance_photo_storage.sql
  - lib/services/sync_service.dart
  - test/models/kiosk_scan_photo_contract_test.dart
  - test/services/photo_compression_service_test.dart
  - test/services/photo_upload_service_test.dart
  - test/services/sync_service_order_test.dart
  - test/phase64/attendance_photo_sql_contract_test.dart
autonomous: true
requirements: ["PHOTO-BETA-ROLLBACK", "PHOTO-OFFLINE-RETRY", "PHOTO-SQL-GUARD"]
---

# Phase 65: Attendance Photo Beta Hardening

## Objective

Close the highest-risk beta gaps from Phase 64 before operator device testing: lock photo contracts with regression tests, make offline photo retry testable without real Supabase calls, and fail closed when attaching photo URLs to attendance logs.

## Scope

- Add Phase 64 completion summary.
- Add focused Dart tests for:
  - legacy RPC parameter compatibility
  - pending log photo queue fields
  - recorded log reference parsing
  - photo path sanitization
  - compression resize/quality behavior
  - sync photo upload retry behavior
- Add SQL contract tests for the Phase 64 migration.
- Harden `attach_attendance_photo`:
  - reject blank photo URLs
  - reject URLs outside the public `attendance-photos` bucket path
  - reject URLs whose final `{log_id}.jpg` does not match the attendance log being updated
  - raise when no log row was updated

## Locked Decisions

- Keep `record_kiosk_scan` unchanged. Beta photo attachment remains a post-submit helper so old APKs and non-beta builds are unaffected.
- Do not apply production SQL from the agent. The user must approve any Supabase migration application.
- Do not add new runtime dependencies in this hardening phase.
- Keep beta disabled by default.

## Verification

- `dart format` on changed Dart test/service files.
- `flutter test` for new and affected focused tests.
- `dart analyze` on changed Dart files.
- Re-run existing `deno check` for the Edge Function if it is touched.
