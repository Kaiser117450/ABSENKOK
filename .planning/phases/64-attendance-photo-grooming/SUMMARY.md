---
phase: 64-attendance-photo-grooming
plan: beta-foundation
subsystem: kiosk, storage, grooming-qc
tags: [flutter, supabase, camera, mlkit, grooming, beta]
provides:
  - Beta-gated MASUK/PULANG selfie capture with on-device face validation
  - Supabase Storage upload path and offline photo retry queue
  - Google Cloud Vision Edge Function for async grooming analysis
  - Flutter admin Grooming QC screen behind the same beta flag
affects: [kiosk-scan, offline-sync, admin-reporting, supabase-storage]
tech-stack:
  added:
    - camera
    - google_mlkit_face_detection
    - image
  patterns:
    - Build-time beta guard via ATTENDANCE_PHOTO_BETA
    - Fire-and-forget post-submit photo upload and analysis
    - Additive-only SQL migration
key-files:
  created:
    - lib/services/camera_service.dart
    - lib/services/face_detection_service.dart
    - lib/services/photo_compression_service.dart
    - lib/services/photo_upload_service.dart
    - lib/widgets/camera_face_preview.dart
    - lib/screens/admin/admin_grooming_report_screen.dart
    - supabase/functions/analyze-attendance-photo/index.ts
    - sql/phase_64_attendance_photo_storage.sql
  modified:
    - pubspec.yaml
    - lib/main.dart
    - lib/screens/kiosk/kiosk_scan_screen.dart
    - lib/services/kiosk_scan_authority_service.dart
    - lib/models/kiosk_scan_context.dart
    - lib/models/pending_log.dart
    - lib/services/sqlite_service.dart
    - lib/services/sync_service.dart
    - lib/core/constants.dart
    - android/app/src/main/AndroidManifest.xml
completed: 2026-05-06
---

# Phase 64: Attendance Photo Grooming Beta Summary

## Accomplishments

- Added `ATTENDANCE_PHOTO_BETA` as the rollout guard. The existing kiosk flow stays unchanged when the flag is absent.
- Added camera, face detection, compression, upload, and reusable preview services/widgets for MASUK/PULANG selfie capture.
- Wired kiosk scan flow so MASUK/PULANG require a valid captured face only in beta, while ISTIRAHAT/KEMBALI keep the legacy immediate buttons.
- Kept attendance submit fast: photo upload and grooming analysis run after success and do not block the success screen.
- Added local photo queue fields to SQLite pending logs and sync retry handling for offline captures.
- Added additive Supabase SQL for the `attendance-photos` bucket, photo metadata, analysis table, and RPC helpers.
- Added the `analyze-attendance-photo` Edge Function for Google Cloud Vision label, face, and safe-search analysis.
- Added a beta-only Flutter admin Grooming QC route/tab for scores, labels, thumbnails, and review flags.

## Verification

- `dart analyze` on changed Dart files passed.
- `flutter test` passed with 442 tests.
- `deno fmt supabase\functions\analyze-attendance-photo\index.ts --check` passed.
- `deno check supabase\functions\analyze-attendance-photo\index.ts` passed.
- `flutter build apk --debug --dart-define=ATTENDANCE_PHOTO_BETA=true` passed.
- Full `flutter analyze` still has existing unrelated warnings outside this phase.

## Open Follow-up

- Add focused regression tests for the beta photo contracts and offline sync seams.
- Harden `attach_attendance_photo` so the URL attached to a log must match the expected storage bucket/path convention.
- Document the operator rollout sequence for SQL, Edge Function secrets, and beta APK smoke testing before live rollout.
