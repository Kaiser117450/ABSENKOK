# Attendance Photo QC v2 — Design Spec

Date: 2026-06-03 · Branch: `codex/attendance-photo-beta`

## Goal
Improve the attendance-selfie pipeline end to end: nicer capture UI, a clearer QC
review tab, a **transparent + admin-tunable** Google Cloud Vision scoring system,
an admin screen to reassign a kepala gerai to a different outlet, and a final
cleanup of the test photos taken on employee **Akmal Marzukii**.

## Decisions (confirmed with user)
1. Rules config = **single active JSONB row** (`grooming_rules_config`), read by the
   edge function at runtime with a hardcoded fallback. Versioned for rollback.
2. Capture work is a **visual redesign** ("UI jelek") + include the low-risk **EXIF
   orientation fix**.
3. Kepala-gerai "ganti wilayah" = **reassign the manager login's outlet scope**
   (`auth.users` app_metadata) — no new region column.
4. Long-hair rule = **best-effort, applies to everyone, admin-overridable** (no gender
   column). Detected from Cloud Vision labels (`long hair`/`ponytail`/`bun` minus
   `crew cut`/`buzz cut`).
5. Admin corrections become real **improvement**: stored as feedback rows AND the
   admin can edit the rules config that the edge function reads.
6. Final deliverable: **beta APK uploaded to a GitHub release**.

## Grounding facts
- Vision = Google Cloud Vision API (LABEL + FACE + SAFE_SEARCH). Env `GOOGLE_CLOUD_VISION_KEY`.
- Real label vocab is messy/outlet-specific: uniform shows as "Active Shirt"/"Dress shirt",
  caps as "Baseball/Cricket cap", hijab as "Scarf/Shawl/Abaya/Wrap", facial hair as
  "Beard/Moustache/Facial hair", short hair as "Crew cut". → config-driven mapping is justified.
- `attendance_photo_analysis` already has rubric + override columns incl. `qc_corrections`.
- **Security regression**: two `apply_grooming_qc_override` overloads exist; the 4-arg one
  (called by the app) lost the admin check. Consolidate to one admin-only version.
- Akmal Marzukii `8d41a644-8649-481f-8fb9-8581ebeffd3b`: 77 logs, **39 selfies + 39 analysis rows**
  on R2 `pub-00c05d1539fd41c8ae543132a606bb61.r2.dev/{outlet}/{employee}/{date}/{log}.jpg`.

## Phases

### Phase 1 — Scoring v2 + rules config (DB + edge function)
- Migration `phase_72_grooming_rules_config.sql`:
  - `grooming_rules_config(id, version, is_active, config jsonb, note, updated_by, created_at)`
    with partial-unique index `WHERE is_active` (one active row). Seed v1 from current rules.
  - `grooming_feedback(id, attendance_log_id, criterion, ai_verdict, admin_verdict,
    ai_score, admin_score, labels jsonb, note, created_by, created_at)`.
  - `attendance_photo_analysis`: add `hair_length text`, `score_breakdown jsonb`.
  - Drop the unsafe 3-arg override; recreate one admin-only
    `apply_grooming_qc_override(uuid, numeric, text, jsonb)` that also inserts a
    `grooming_feedback` row per corrected criterion.
  - RPC `get_active_grooming_rules()` (read) + `save_grooming_rules(config jsonb, note)` (admin write, bumps version, flips active).
- `grooming_rules.ts`: make all functions take a `GroomingConfig`; export
  `DEFAULT_GROOMING_CONFIG` (= today's constants). Add `hair_length` criterion + emit
  `score_breakdown`. Apply `flagged_labels` overlay. Keep deno tests green; add tests for
  config override + long-hair.
- `index.ts`: fetch active config (cached ~60s) → pass to parser; write `hair_length` +
  `score_breakdown`.

### Phase 2 — QC tab overhaul + rules editor (Flutter admin)
- `grooming_card`: show raw **AI score + effective score**, per-criterion chips with
  corrected-state styling (strikethrough/check), expandable full reasoning, new
  "Rambut panjang" chip, score-math breakdown row.
- Override dialog: add long-hair criterion + "Tandai AI salah → jadikan rule" that writes
  feedback and offers to add a label to the config.
- New screen **Aturan AI (Grooming Rules)**: edit label sets / thresholds / weights /
  flagged labels via `get_active_grooming_rules` + `save_grooming_rules`.
- Service/provider: extend `grooming_qc_service.dart` + add a rules-config service.

### Phase 3 — Capture UI redesign (Flutter)
- Redesign `camera_face_preview.dart` + capture step in `kiosk_scan_screen.dart`: clean
  oval guide, animated status ring, clear step text, success animation, theme colors.
- Fix: apply EXIF/orientation to captured bytes before compression/upload.

### Phase 4 — Reassign kepala gerai (DB + Flutter admin)
- Migration `phase_73_outlet_manager_reassign.sql`: admin-only
  `admin_list_outlet_managers()` + `admin_reassign_outlet_manager(p_user_id, p_outlet_ids uuid[])`
  (updates `managed_outlet_id` + `managed_outlet_ids` in app_metadata).
- New admin screen: list managers + current outlet → pick new outlet → save.

### Phase 5 — Akmal cleanup (LAST, after user confirms "sempurna")
- Edge function `delete-r2-object` (admin/service) to remove the 39 R2 objects, then
  delete 39 `attendance_photo_analysis` rows + null 39 `selfie_url` (keep logs).

## Verification
- `flutter analyze` (treat only `error` lines as blocking), edge `deno test`,
  migrations applied additively via Supabase MCP. Visual UI verified by user on device
  (Flutter mobile — no web preview). Then build beta APK + GitHub release.
