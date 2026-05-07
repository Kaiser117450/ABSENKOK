# Phase 64: Attendance Photo Grooming Beta

## Goal

Add beta-gated face photo capture for MASUK and PULANG attendance scans without changing the legacy kiosk flow unless the beta flag is enabled. The foundation stores compressed attendance selfies in Supabase Storage, validates one face on-device with ML Kit, queues photos offline with pending attendance logs, and prepares async server-side grooming analysis through Google Cloud Vision.

## Beta Guardrail

- Runtime flag: `--dart-define=ATTENDANCE_PHOTO_BETA=true`.
- Default: disabled, preserving the existing kiosk button flow and legacy ecosystem.
- All camera/ML Kit initialization and photo capture work must be skipped unless the flag is enabled.
- Upload and grooming analysis run asynchronously after attendance submission and must not block the success screen.

## Phase 1: Foundation - Supabase Storage + Camera Service

### 1.1 Supabase Storage Bucket Setup (SQL)

- Create `sql/phase_64_attendance_photo_storage.sql`.
- Create bucket `attendance-photos` in Supabase Storage.
- RLS policy: kiosk anon key can INSERT, admin can SELECT/DELETE.
- Path convention: `{outlet_id}/{employee_id}/{YYYY-MM-DD}/{log_id}.jpg`.
- Add additive beta fields around attendance photos:
  - `attendance_logs.selfie_url` if missing.
  - `attendance_logs.photo_required`.
  - `attendance_logs.photo_uploaded_at`.
  - `attendance_photo_analysis` table for grooming results.
- Keep the legacy `record_kiosk_scan` parameter contract intact for beta safety;
  resolve the inserted row by `local_id` through
  `resolve_attendance_log_for_local_id`, then attach the photo through
  `attach_attendance_photo`.

### 1.2 Flutter Dependencies

- Add to `pubspec.yaml`:
  - `camera: ^0.11.0` for faster kiosk camera preview.
  - `google_mlkit_face_detection: ^0.12.0` for on-device face detection.
  - `image: ^4.3.0` for compression and resize.
- Keep `supabase_flutter` as the Storage API client.

### 1.3 Camera Service

- Create `lib/services/camera_service.dart`.
- Singleton manages one `CameraController`.
- Methods:
  - `initialize()`
  - `dispose()`
  - `capturePhoto()`
  - `getPreviewWidget()`
- Use the front camera with `ResolutionPreset.medium`.
- Pre-initialize from `lib/main.dart` only when `ATTENDANCE_PHOTO_BETA=true`.

### 1.4 Face Detection Service

- Create `lib/services/face_detection_service.dart`.
- Wrap Google ML Kit Face Detection.
- Method: `processImage(InputImage) -> FaceDetectionResult`.
- `FaceDetectionResult` contains:
  - `hasFace`
  - `faceCount`
  - `boundingBox`
  - `headEulerAngleY`
  - `isValid`
- Validation:
  - face detected
  - exactly 1 face
  - face front-facing with `abs(headEulerAngleY) < 30`
  - face width and height at least 20% of frame dimensions

### 1.5 Photo Compression Service

- Create `lib/services/photo_compression_service.dart`.
- Method: `compressAndResize(Uint8List rawBytes) -> Uint8List`.
- Resize longest side to max 640px.
- JPEG quality 60%.
- Target output: 30-50KB per photo when source allows it.

### 1.6 Photo Upload Service

- Create `lib/services/photo_upload_service.dart`.
- Method: `uploadAttendancePhoto({outletId, employeeId, logDate, logId, bytes}) -> String photoUrl`.
- Upload to Supabase Storage bucket `attendance-photos`.
- Return public URL stored in `attendance_logs.selfie_url`.
- Offline behavior:
  - save photo to local filesystem
  - retry upload during sync
  - delete local file after successful upload

## Phase 2: Kiosk UI Integration - Camera Preview + Auto-capture

### 2.1 Modify `lib/screens/kiosk/kiosk_scan_screen.dart`

- Add `_ScanStep.capturingPhoto` between `selectAction` and `submitting`.
- After `_loadActionState`, resolve the next scan actions.
- If the scan flow requires MASUK or PULANG, show camera preview first.
- ISTIRAHAT and KEMBALI stay on the existing immediate button flow.

Camera preview widget:

- Create `lib/widgets/camera_face_preview.dart`.
- Show camera preview inside the kiosk content area while preserving the existing header.
- Overlay green bounding box when face is valid and red when not valid.
- Guidance text:
  - `Arahkan wajah ke kamera`
  - `Wajah terdeteksi`
- Auto-capture when face remains valid for 500ms.
- After capture, show preview for 300ms, then reveal action buttons.
- Store captured photo bytes in screen state for use during submit.

### 2.2 Modify `_submitAttendance()`

- After `recordScan()` succeeds and returns `logId`:
  1. compress captured photo
  2. upload to `attendance-photos` asynchronously
  3. update `attendance_logs.selfie_url`
  4. invoke `analyze-attendance-photo` asynchronously
- If upload fails, persist the photo locally and retry during sync.

### 2.3 Timing Budget

- Camera pre-initialized: 0ms when beta flag is enabled and warmup succeeds.
- Face detection per frame: target around 30ms with throttling.
- Auto-capture delay: 500ms stable valid face.
- Photo compression: target around 50ms after submit.
- Upload photo: async after submit, never blocks UI success.

## Phase 3: Server-side Grooming Analysis

### 3.1 Supabase Edge Function

- Create `supabase/functions/analyze-attendance-photo/index.ts`.
- Triggered asynchronously after photo upload.
- Flow:
  - download photo from Supabase Storage
  - call Google Cloud Vision API for Label Detection, Face Detection, and Safe Search
  - parse grooming indicators
  - insert/update `attendance_photo_analysis`

### 3.2 Database Schema

Create `attendance_photo_analysis`:

```sql
CREATE TABLE attendance_photo_analysis (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attendance_log_id uuid REFERENCES attendance_logs(id),
  photo_url text NOT NULL,
  face_detected boolean DEFAULT false,
  face_confidence numeric(4,2),
  face_count int DEFAULT 0,
  photo_quality text CHECK (photo_quality IN ('clear','blurry','dark','overexposed')),
  grooming_labels jsonb DEFAULT '[]',
  grooming_score numeric(3,1),
  safe_search_passed boolean DEFAULT true,
  raw_vision_response jsonb,
  analyzed_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);
```

### 3.3 Google Cloud Vision Setup

- Create a Google Cloud project and enable Vision API.
- Create a service account key.
- Store the key JSON in Supabase Edge Function secret `GOOGLE_CLOUD_VISION_KEY`.
- Free tier note: 1000 requests/month is not enough for 500 employees x 2 photos/day; production needs paid quota or nightly batch processing.

### 3.4 Grooming Score Algorithm

- Face clearly visible: +3
- Photo quality clear: +2
- Uniform detected: +2
- Neat/clean labels: +2
- Safe search passed: +1
- Max score: 10

## Phase 4: Admin Web Report - Grooming QC Dashboard

- Flutter admin report should show per employee per day:
  - MASUK and PULANG thumbnails
  - grooming score
  - flag for score < 6
  - Cloud Vision labels
- Optional Astro portal route `/portal/admin/grooming` can follow after beta data is collected.

## Phase 5: Offline Resilience

### 5.1 Local Photo Queue

- Add `local_photo_path` to the SQLite `pending_logs` table.
- Save offline photos to the app documents directory.
- During `SyncService.syncPendingLogs()`, upload the photo after the attendance log is synced.
- Delete local file after upload success.

### 5.2 Retry Logic

- Add photo upload retry after attendance sync.
- Max retry: 3 attempts per photo.
- If retries fail, leave row queued/failed so admin can review after reconciliation.

## Files

Create:

- `lib/services/camera_service.dart`
- `lib/services/face_detection_service.dart`
- `lib/services/photo_compression_service.dart`
- `lib/services/photo_upload_service.dart`
- `lib/widgets/camera_face_preview.dart`
- `supabase/functions/analyze-attendance-photo/index.ts`
- `sql/phase_64_attendance_photo_storage.sql`
- `.planning/phases/64-attendance-photo-grooming/PLAN.md`

Modify:

- `pubspec.yaml`
- `lib/main.dart`
- `lib/screens/kiosk/kiosk_scan_screen.dart`
- `lib/services/kiosk_scan_authority_service.dart`
- `lib/models/kiosk_scan_context.dart`
- `lib/models/pending_log.dart`
- `lib/services/sqlite_service.dart`
- `lib/services/sync_service.dart`
- `lib/core/constants.dart`
- `android/app/src/main/AndroidManifest.xml`

## Implementation Order

1. Phase 1 foundation services.
2. Phase 2 kiosk UI integration.
3. Phase 5 offline retry.
4. Phase 3 Cloud Vision function.
5. Phase 4 admin report after beta data exists.

## Verification

- `flutter pub get`
- `dart format` on changed Dart files
- `flutter analyze`
- targeted tests around `SyncService`
- manual beta smoke test on device with `--dart-define=ATTENDANCE_PHOTO_BETA=true`
