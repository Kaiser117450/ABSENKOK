# Attendance Photo Redesign — Bank-Style Liveness + Cloud Vision Rubric QC

**Date:** 2026-05-23
**Status:** Approved design, ready for planning
**Project:** absensi_enakko_flutter (Ayam Guling Enakko kiosk attendance)

---

## 1. Problem

Three issues with the current attendance photo system (Phases 64–66):

1. **No liveness.** `CameraFacePreview` auto-captures after a stable face holds in the oval for 500 ms. A printed photo or another phone's screen passes the check. There is no eye-blink or other liveness signal.
2. **Grooming QC is unreliable.** The `analyze-attendance-photo` Edge Function uses Cloud Vision LABEL_DETECTION with naive keyword matching (`person`, `clothing`, `shirt`, `apron`, `clean`, `neat`). Result: bearded employees get high scores because `person` matches almost any photo, while hijab-wearing employees get low scores because their face bounding box is smaller relative to the head covering and `clothing` is the only positive signal. No beard / mustache / stubble penalty exists.
3. **Admin QC UI is shallow.** `admin_grooming_report_screen.dart` shows a flat 7-day list with three vague chips (Wajah / Safe / Quality). No per-criteria breakdown, no override + audit trail, no per-employee aggregate, no filters, no export.

## 2. Goal

Replace the capture flow with a bank-style liveness check (face alignment → blink challenge), rewrite the Cloud Vision scoring as a deterministic rubric that explicitly penalises facial hair and is hijab-neutral, and redesign the admin QC dashboard around investigation / monitoring / analytics workflows.

The attendance write itself stays advisory — a bad grooming score never blocks an attendance log. Operations cannot stop if Vision API is down.

## 3. Decisions locked during brainstorming

| Decision | Choice |
|---|---|
| Grooming rubric criteria | Clean shave + hijab-neutral + uniform compliance + neat hair (all four) |
| Liveness challenge | Blink-only (after 1 s aligned hold) |
| QC enforcement | Advisory only — flag in admin UI, never block attendance |
| Admin UI shape | Tabbed dashboard: List · Per-Employee · Analytics |
| QC vendor | Stay on Cloud Vision; fix scoring code, not vendor |
| Override permission | Admin-only (`app_role = 'admin'`). Manager views only. |

## 4. Architecture overview

```
KIOSK Flutter app
  └ CameraFacePreview (state machine)
      └ ML Kit FaceDetector with classification enabled
          → emits FaceDetectionResult { alignment, eyeOpen* }
      → on capture: bytes → R2 via sign-r2-upload Edge Function
      → RPC attach_attendance_photo sets attendance_logs.selfie_url
           │
           ▼ trigger (Phase 66, kept)
POSTGRES
  └ attendance_photo_analysis_on_selfie_url_set
      → pg_net.http_post → Edge Function
           │
           ▼
EDGE FUNCTION analyze-attendance-photo (REWRITTEN)
  └ Cloud Vision LABEL + FACE + SAFE_SEARCH
  └ parseGroomingAnalysis(): deterministic rubric (new code)
  └ Upsert attendance_photo_analysis with per-criteria columns
           │
           ▼
ADMIN APP
  └ AdminGroomingReportScreen (REWRITTEN as tabs)
      → reads attendance_photo_analysis via Realtime
      → override via apply_grooming_qc_override RPC
```

Trigger (Phase 66) stays unchanged. R2 upload path (Phase 66) stays unchanged. Only the capture widget, the Edge Function body, and the admin screen change. Plus one additive SQL migration.

## 5. Capture flow design

### 5.1 ML Kit configuration

Enable classification so eye-open probability is returned per face:

```dart
FaceDetector(options: FaceDetectorOptions(
  performanceMode: FaceDetectorMode.accurate,
  enableClassification: true,   // NEW
  minFaceSize: 0.15,             // bumped from 0.10
));
```

### 5.2 `FaceDetectionResult` shape

```dart
class FaceDetectionResult {
  final bool hasFace;
  final int faceCount;
  final Rect? boundingBox;
  final double? headEulerAngleY;
  final double? leftEyeOpen;    // NEW: 0..1, null if classification unavailable
  final double? rightEyeOpen;   // NEW: 0..1
  final FaceAlignment alignment; // NEW enum
}

enum FaceAlignment { tooSmall, tooBig, offCenter, tilted, aligned }
```

The old boolean `isValid` is removed. UI computes alignment based on bbox center distance from oval center, bbox width relative to oval width, and `headEulerAngleY`.

### 5.3 State machine

```
idle
  → camera ready → searching
  searching:
    – face count != 1 OR alignment != aligned → stay
    – face count == 1 AND alignment == aligned → aligning
  aligning:
    – aligned stable for attendancePhotoStableFaceMs (1000) → promptBlink
    – alignment lost any frame → searching (reset hold timer)
  promptBlink:
    – both eyes < eyeClosedThreshold (0.30) then > eyeOpenThreshold (0.70)
      within attendancePhotoBlinkWindowMs (3000) AND alignment still aligned
      → capturing
    – window expires without blink → searching, increment attempt
    – on 3rd expired window → show "Coba lagi" button (manual reset)
  capturing:
    – takePicture() → freeze frame → onPhotoCaptured(bytes) → done
```

### 5.4 Tuning constants (`AppConstants`)

```dart
attendancePhotoStableFaceMs       = 1000   // was 500
attendancePhotoBlinkWindowMs      = 3000
attendancePhotoEyeClosedThreshold = 0.30
attendancePhotoEyeOpenThreshold   = 0.70
attendancePhotoMaxHeadEulerY      = 15     // was 30
attendancePhotoOvalFillMin        = 0.55
attendancePhotoOvalFillMax        = 0.95
attendancePhotoMaxBlinkAttempts   = 3
```

`attendancePhotoFaceThrottleMs` (140), `attendancePhotoMinFaceFrameRatio` (0.20) and `attendancePhotoPreviewMs` (300) stay as-is.

### 5.5 Visual treatment per state

| State | Oval border | Outside scrim | Bottom pill text |
|---|---|---|---|
| searching | white 3 px, dashed | black 55 % | "Posisikan wajah di dalam lingkaran" |
| aligning | white 4 px solid + progress arc | black 65 % | "Tahan posisi…" |
| promptBlink | green 5 px + soft glow | black 65 % | "Kedipkan mata sekali 👁️" |
| capturing | green 6 px filled ring | black 75 % | ✓ "Berhasil" |
| retry | amber 4 px | black 65 % | "Coba kedipkan lagi…" |

A small "Batal" link sits bottom-left so a stuck user can exit.

### 5.6 Anti-cheat

Alignment is re-checked every frame during `promptBlink` — moving the face out of the oval during the blink window cancels the capture. Closed-eye photos (sleeping or staring) cannot trigger capture because the state requires a closed→open transition, not a static closed-eye reading.

## 6. Grooming QC rewrite

### 6.1 Vendor

Stay on Cloud Vision. No new secrets, no new dependencies. Same three features used today (LABEL_DETECTION, FACE_DETECTION, SAFE_SEARCH_DETECTION). LABEL_DETECTION `maxResults` bumped from 15 → 30.

### 6.2 Label whitelists (single source of truth in TS)

```ts
const FACIAL_HAIR_LABELS = [
  'beard','moustache','mustache','facial hair','goatee','stubble','sideburns',
];
// Hijab-specific terms only. Generic terms like 'head covering' live in
// AMBIGUOUS to avoid mis-classifying male crew caps as hijab (Cloud Vision
// returns 'head covering' for many cap-shaped objects).
const HIJAB_LABELS = [
  'hijab','headscarf','veil','niqab','khimar',
];
// Caps the male crew commonly wear. chef\'s hat covers the kitchen team.
const CAP_LABELS = [
  'cap','hat','baseball cap','chef hat','chef\'s hat','beanie','bandana',
];
// Ambiguous or other coverings — still counts as head_covering != 'none' so
// hair_neat resolves to 'not_visible' (OK). UI shows 'Lainnya' chip.
const OTHER_HEAD_COVERING_LABELS = [
  'turban','head covering','head wrap','headcloth',
];
const UNIFORM_LABELS = [
  'apron','chef','chef\'s uniform','uniform','polo shirt','dress shirt',
  'service uniform','waiter','staff',
];
const MESSY_HAIR_LABELS = [
  'messy hair','disheveled','unkempt','bedhead',
];
const LONG_HAIR_LABELS = [
  'long hair',  // only flagged for laki-laki — currently we have no gender hint, so this is NOT used in MVP scoring
];
const POOR_QUALITY_LABELS = {
  blurry:      ['blur','blurry','out of focus','motion blur'],
  dark:        ['darkness','low light','night','shadow'],
  overexposed: ['overexposed','glare','lens flare','bright'],
};
```

All matches require `label.score >= 0.65`. Comparison is case-insensitive `description.toLowerCase().includes(token)`.

### 6.3 Derived attributes

```
face_clean_shave:
  – if any FACIAL_HAIR_LABEL matches → 'beard' if 'beard' or 'goatee' present,
    'mustache' if 'mustache' or 'moustache' present, 'stubble' if 'stubble' or
    'sideburns' or 'facial hair' present (precedence beard > mustache > stubble)
  – else if face_detected → 'ok'
  – else → 'unclear'

head_covering:
  – if any HIJAB_LABEL matches → 'hijab'
  – else if any CAP_LABEL matches → 'cap'
  – else if any OTHER_HEAD_COVERING_LABEL matches → 'other'
  – else → 'none'

uniform_compliant:
  – if any UNIFORM_LABEL matches → 'ok'
  – else if any of 'tank top','sleeveless','singlet','swimsuit','bikini' matches → 'wrong_attire'
  – else if face_detected → 'no_uniform'
  – else → 'unclear'

hair_neat:
  – if head_covering != 'none' → 'not_visible'
  – else if any MESSY_HAIR_LABEL matches → 'messy'
  – else → 'ok'

photo_quality:
  – first matching key in POOR_QUALITY_LABELS wins (blurry > dark > overexposed)
  – else 'clear'
```

The hijab-neutral fix in QC scoring is purely the `hair_neat = 'not_visible'` rerouting plus the score formula (Section 6.4). The Edge Function has no other implicit penalties that depend on face size, so nothing else needs unblocking server-side. The on-device alignment check during capture (Section 5) is independent of head covering.

### 6.4 Score formula

```
score = 0
  + (face_clean_shave == 'ok'              ? 3 : 0)
  + (face_clean_shave == 'unclear'         ? 1 : 0)
  + (uniform_compliant == 'ok'             ? 3 : 0)
  + (uniform_compliant == 'unclear'        ? 1 : 0)
  + (hair_neat in {'ok','not_visible'}     ? 3 : 0)
  + (photo_quality == 'clear'              ? 1 : 0)
cap at 10
```

Hijab employees gain points from `hair_neat = not_visible` instead of losing points from "no hair visible" — fixes the current bug.

### 6.5 Reasoning text

Template-generated in TypeScript, ≤200 Indonesian characters. Examples:

- `"Terdeteksi jenggot. Seragam OK. Foto jelas."`
- `"Wajah bersih. Pakai apron. Berhijab — rambut OK. Foto jelas."`
- `"Wajah bersih. Pakai apron. Pakai topi — rambut OK. Foto jelas."`
- `"Wajah tidak terdeteksi jelas. Foto buram."`

The template enumerates non-OK findings first, then OK findings. Stored in the new `reasoning` column.

### 6.6 `parseGroomingAnalysis` output

```ts
{
  faceDetected: boolean,
  faceConfidence: number,         // from Vision FACE
  faceCount: number,
  photoQuality: 'clear'|'blurry'|'dark'|'overexposed',
  faceCleanShave: 'ok'|'stubble'|'mustache'|'beard'|'unclear',
  uniformCompliant: 'ok'|'no_uniform'|'wrong_attire'|'unclear',
  hairNeat: 'ok'|'messy'|'not_visible',
  headCovering: 'none'|'hijab'|'cap'|'other',
  groomingLabels: Array<{description, score}>,  // raw labels, audit
  groomingScore: number,           // 0..10
  reasoning: string,               // ≤200 chars
  safeSearchPassed: boolean,
  modelName: 'cloud-vision-rubric-v1',
}
```

### 6.7 Rollout

Edge Function honours `USE_LEGACY_VISION_SCORING` env var. When `true`, the old keyword logic runs. Default `false` (new rubric). After 7 days in production, the flag and the legacy branch are deleted.

The DB migration is additive only — no existing data is rewritten. Old rows render in the admin UI with their original `grooming_score` and no per-criteria chips.

## 7. Database schema changes

### 7.1 New columns on `attendance_photo_analysis`

```sql
ALTER TABLE public.attendance_photo_analysis
  ADD COLUMN face_clean_shave   text,
  ADD COLUMN uniform_compliant  text,
  ADD COLUMN hair_neat          text,
  ADD COLUMN head_covering      text,
  ADD COLUMN reasoning          text,
  ADD COLUMN model_name         text,
  ADD COLUMN qc_override_score  numeric,
  ADD COLUMN qc_override_note   text,
  ADD COLUMN qc_overridden_by   uuid REFERENCES auth.users(id),
  ADD COLUMN qc_overridden_at   timestamptz;

CREATE INDEX attendance_photo_analysis_overrides_idx
  ON public.attendance_photo_analysis (qc_overridden_at DESC)
  WHERE qc_overridden_at IS NOT NULL;
```

### 7.2 New RPC `apply_grooming_qc_override`

`SECURITY DEFINER`, requires `auth.uid()`, requires `raw_app_meta_data->>'app_role' = 'admin'`. Validates score 0..10 and note length ≥10. Sets the four override columns plus `qc_overridden_at = now()`.

Manager / supervisor cannot call it. RLS on `attendance_photo_analysis` for normal SELECTs is unchanged.

### 7.3 RLS for SELECT

Existing policies stand. Admins and managers continue to read all rows in scope of their outlets.

## 8. Admin UI structure

### 8.1 Layout

```
Scaffold
  AppBar  ("Grooming QC", refresh, filter)
    └ Summary strip   (foto count · review count · override count · range)
  TabBar  (List / Per Karyawan / Analytics)
  TabBarView
    Tab 1: ListView of _GroomingReportCard
    Tab 2: ListView of _GroomingPerEmployeeCard (sorted worst first)
    Tab 3: Analytics cards (top violators, per-outlet, trend) + CSV export FAB
```

Tabs all read from the same `GroomingQcService.watchRows(filter)` stream — a Riverpod `StreamProvider` over a Supabase Realtime subscription on `attendance_photo_analysis`.

### 8.2 List card (Tab 1)

- 96 × 128 cached photo thumbnail, tap for full preview (existing `_PhotoPreviewScreen`)
- Employee name + position + outlet + attendance type + scanned time
- Score pill (green ≥7, amber 5–6.9, red <5). If override exists, shows `4.5→8.0 ✏` and tap reveals override note + admin name + timestamp
- Four per-criteria chips (`wajah_bersih`, `seragam`, `rambut`, `penutup_kepala`) each colour-coded per its own status. `penutup_kepala` chip is informational only (never red): shows "Hijab" (blue), "Topi" (grey), "Lainnya" (grey), or "Tidak ada" (muted) based on `head_covering` enum. Hijab and Topi both result in `hair_neat='not_visible'` → +3 in score (Section 6.4)
- Reasoning text below chips (italic, two lines max, ellipsis)
- "Override skor" button → override dialog

### 8.3 Per-Karyawan card (Tab 2)

- Employee avatar + name + position + outlet
- Avg score for current window (default 30 d), violation count (`grooming_score < 6`)
- Sparkline: last 30 daily-avg scores, 1 px per day
- 4 most-recent photo thumbnails
- "Detail per foto" link → switches to Tab 1 filtered to this employee
- Sorted ascending by avg score (worst first = action queue)

### 8.4 Analytics (Tab 3)

- Top violators (last 30 d) — horizontal bar chart, top 10 by violation rate
- Per-outlet compliance — bar chart, % passing per outlet
- 30 d trend — daily average score sparkline + delta vs prior 30 d
- CSV export FAB anchored bottom-right

### 8.5 Filter sheet

Modal bottom sheet from AppBar 🔍, fields:

- Time range: today / 7 d / 30 d / custom
- Outlet: multi-select chip (scoped to admin's allowed outlets)
- Employee: search field
- Needs-review-only switch (`grooming_score < 6` OR `face_detected = false` OR `face_count != 1` OR `safe_search_passed = false`)
- Overridden-only switch

Filter state lives in a Riverpod provider, persists per app session (not across restarts).

### 8.6 Override dialog

Score number stepper (0..10, 0.5 step), note text field (min 10 chars, hint "Alasan override"), Cancel / Simpan buttons. Save calls `apply_grooming_qc_override` RPC and closes; list updates via realtime.

### 8.7 CSV export

Columns: `tanggal, jam, outlet, employee_name, position, attendance_type, skor_ai, skor_override, override_note, override_by, wajah_bersih, seragam, rambut, penutup_kepala, photo_quality, reasoning, photo_url`. Generated client-side from currently-filtered rows, saved + shared via `share_plus` (existing dependency).

### 8.8 Loading / empty / error states

- Tab 1 skeleton: 5 shimmer cards
- Tab 2 skeleton: 4 shimmer cards
- Tab 3 skeleton: 3 shimmer chart boxes
- Empty after filter: `AppEmptyState` with copy "Tidak ada foto sesuai filter"
- Error: `AppEmptyState` with retry button

## 9. Files affected

### Kiosk (capture)
- `lib/services/face_detection_service.dart` — enable classification, expose eye-open + alignment
- `lib/widgets/camera_face_preview.dart` — replace hold timer with state machine
- `lib/core/constants.dart` — add liveness tuning constants
- `lib/screens/kiosk/kiosk_scan_screen.dart` — passthrough adjustments only

### Backend
- `supabase/functions/analyze-attendance-photo/index.ts` — rewrite scoring + extraction
- `sql/phase_67_grooming_qc_rubric.sql` — new migration

### Admin
- `lib/screens/admin/admin_grooming_report_screen.dart` — rewrite as tabbed dashboard
- `lib/screens/admin/widgets/grooming_card.dart` — new
- `lib/screens/admin/widgets/grooming_per_employee_card.dart` — new
- `lib/screens/admin/widgets/grooming_filter_sheet.dart` — new
- `lib/screens/admin/widgets/grooming_override_dialog.dart` — new
- `lib/screens/admin/widgets/grooming_analytics_charts.dart` — new
- `lib/services/grooming_qc_service.dart` — new

### Tests
- `test/services/face_detection_service_test.dart`
- `test/widgets/camera_face_preview_state_test.dart`
- `test/widgets/camera_face_preview_golden_test.dart`
- `test/services/grooming_qc_service_test.dart`
- `test/widgets/grooming_card_test.dart`
- `test/widgets/grooming_filter_sheet_test.dart`
- `test/widgets/grooming_override_dialog_test.dart`
- `supabase/functions/analyze-attendance-photo/index_test.ts`
- `sql/phase_67_grooming_qc_rubric_test.sql`

## 10. Testing strategy

### 10.1 Kiosk
- State machine test (pure Dart) covering all transitions including blink retry, alignment loss, cancel
- Golden tests for oval guide painter, one per state
- Widget test for camera_face_preview with fake CameraService

### 10.2 Edge Function
- Deno test feeding canned Vision API responses for: beard present, hijab present, both together, no labels, blur, dark
- Score formula tested across 8 representative permutations
- Vision API failure path returns 500 (no silent swallow)
- Optional smoke test against live Vision API with 4 anonymised fixture photos checked into `supabase/functions/analyze-attendance-photo/fixtures/`

### 10.3 SQL
- pg-tap (or sqlite-style equivalent) for `apply_grooming_qc_override`: unauthorized rejected, non-admin rejected, score out of range rejected, note too short rejected, success populates all four columns

### 10.4 Admin UI
- Widget tests for each new widget with mock row variants (hijab, beard, override applied, missing photo)
- Filter sheet state transitions
- Override dialog: Save disabled until note ≥10 chars
- CSV export builder unit test

### 10.5 Manual UAT
1. Kiosk: bad face position → "Posisikan wajah" persists
2. Kiosk: good position, hold 1 s → "Kedipkan mata" prompts
3. Kiosk: blink → captures + submits
4. Kiosk: keep eyes closed → no false capture
5. Kiosk: print a face on paper → cannot pass blink
6. Admin: new photo appears within ~2 s of capture (realtime)
7. Admin: override score with note → badge updates + audit trail visible
8. Admin: filter by outlet + 7 d + needs-review → counts match
9. Admin: export CSV → opens cleanly in Excel
10. Admin: hijab employee no longer flagged red

## 11. Rollout plan

1. Phase 67 SQL migration applied (additive)
2. Edge Function deployed with `USE_LEGACY_VISION_SCORING=false`
3. New kiosk app released with new capture widget
4. New admin screen released
5. 7 days observation in production
6. Remove legacy scoring branch + env var

If the new rubric misbehaves (e.g. hijab still penalised by surprise label), flip `USE_LEGACY_VISION_SCORING=true` to revert scoring without redeploying.

## 12. Out of scope

- Vendor change away from Cloud Vision (Gemini, Vertex AI) — considered, declined
- Blocking workflow on QC failure — declined; advisory only
- Manager / supervisor override permission — declined; admin-only
- Employee-facing visibility of own score — out of scope, not requested
- Push notifications for repeat offenders — out of scope, not requested
- Multi-language admin UI — admin is Indonesian-only
- Photo retention / TTL — current R2 setup retained as-is

## 13. Open assumptions

- "Long hair" gender-conditional penalty is dropped from MVP because attendance_logs has no reliable gender hint; can be added later if `employees.gender` becomes a usable signal.
- Cloud Vision returns the listed hijab labels reliably on Indonesian faces. The fixture smoke test in 10.2 is the gate that proves this before launch. If Vision fails to label hijab, the worst case is `hair_neat = 'ok'` (since head_covering = 'none' and no MESSY_HAIR_LABEL fires) — still a +3, so no false penalty. The bug we are fixing (low scores for hijab today) only requires that we stop letting "person" silently grant +2 and that we explicitly treat `not_visible` as OK.
- ML Kit `enableClassification` works on the kiosk device class. If it doesn't, the state machine falls back to alignment-only and shows "Kedipkan mata" as a soft prompt without enforcement — degrades gracefully to today's behaviour.
- Realtime subscription cost is acceptable at ~600 photos/day. If not, the screen falls back to pull-on-refresh.
