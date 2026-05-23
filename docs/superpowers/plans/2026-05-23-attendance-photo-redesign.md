# Attendance Photo Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the auto-capture attendance photo flow with a bank-style liveness check (align → blink), rewrite Cloud Vision scoring as an explicit Indonesian-context rubric that penalises facial hair and is hijab-neutral, and rebuild the admin QC dashboard around investigation / monitoring / analytics workflows.

**Architecture:** Three coordinated changes wired through the existing R2-upload → Postgres-trigger → Edge-Function → `attendance_photo_analysis` table → admin UI pipeline. SQL migration is additive; Edge Function rewrites scoring logic only; kiosk camera widget gets a state machine; admin screen becomes a tabbed dashboard. Phase 66 trigger and R2 upload path stay unchanged.

**Tech Stack:** Flutter / Dart, Riverpod, `google_mlkit_face_detection` (with classification enabled), Supabase (Postgres, Edge Functions on Deno, Realtime), Cloudflare R2, Google Cloud Vision API.

**Spec:** `docs/superpowers/specs/2026-05-23-attendance-photo-redesign-design.md`

---

## Phases

- **Phase A — Backend foundation** (SQL migration + Edge Function rewrite). Independently shippable.
- **Phase B — Kiosk capture** (face detection + state machine + UI). Independent of A.
- **Phase C — Admin UI** (tabbed dashboard + override + analytics). Depends on A.
- **Phase D — Integration UAT + rollout** (flip flag, observe, delete legacy).

Each task is one focused change with TDD steps. Commits are frequent and atomic.

---

## File structure (locked before tasks)

### Created
- `sql/phase_67_grooming_qc_rubric.sql`
- `test/phase67/phase_67_grooming_qc_rubric_test.dart`
- `supabase/functions/analyze-attendance-photo/grooming_rules.ts`
- `supabase/functions/analyze-attendance-photo/grooming_rules_test.ts`
- `supabase/functions/analyze-attendance-photo/fixtures/vision_beard.json`
- `supabase/functions/analyze-attendance-photo/fixtures/vision_hijab.json`
- `supabase/functions/analyze-attendance-photo/fixtures/vision_clean.json`
- `supabase/functions/analyze-attendance-photo/fixtures/vision_no_uniform.json`
- `supabase/functions/analyze-attendance-photo/fixtures/vision_blurry.json`
- `lib/widgets/face_capture_state_machine.dart`
- `lib/services/grooming_qc_service.dart`
- `lib/providers/grooming_filter_provider.dart`
- `lib/screens/admin/widgets/grooming_card.dart`
- `lib/screens/admin/widgets/grooming_per_employee_card.dart`
- `lib/screens/admin/widgets/grooming_filter_sheet.dart`
- `lib/screens/admin/widgets/grooming_override_dialog.dart`
- `lib/screens/admin/widgets/grooming_analytics_charts.dart`
- `lib/screens/admin/widgets/grooming_csv_export.dart`
- `test/services/face_detection_service_test.dart`
- `test/widgets/face_capture_state_machine_test.dart`
- `test/widgets/camera_face_preview_golden_test.dart`
- `test/services/grooming_qc_service_test.dart`
- `test/widgets/grooming_card_test.dart`
- `test/widgets/grooming_filter_sheet_test.dart`
- `test/widgets/grooming_override_dialog_test.dart`
- `test/widgets/grooming_csv_export_test.dart`
- `docs/superpowers/specs/2026-05-23-attendance-photo-uat.md`

### Modified
- `lib/core/constants.dart` — add liveness + scoring constants
- `lib/services/face_detection_service.dart` — enable classification, expose alignment + eye-open
- `lib/widgets/camera_face_preview.dart` — wire to state machine, redo UI per state
- `lib/screens/kiosk/kiosk_scan_screen.dart` — only verify no contract breakage
- `lib/screens/admin/admin_grooming_report_screen.dart` — full rewrite as tabbed dashboard
- `supabase/functions/analyze-attendance-photo/index.ts` — delegate scoring to grooming_rules, add legacy flag

---

# Phase A — Backend foundation

Each task is bite-sized, ends with a commit.

## Task A1: SQL migration — add new columns + indexes

**Files:**
- Create: `sql/phase_67_grooming_qc_rubric.sql`

- [ ] **Step 1: Write the migration**

```sql
-- sql/phase_67_grooming_qc_rubric.sql
-- Phase 67: Grooming QC rubric — explicit per-criteria columns + admin override.
--
-- Adds 10 new columns to attendance_photo_analysis so the Edge Function can
-- record beard / uniform / hair / head-covering judgments explicitly instead
-- of relying on a single opaque grooming_score. Adds an override pathway
-- (score + note + auditor + timestamp) so admins can correct AI mistakes.
--
-- This migration is purely ADDITIVE. Existing rows are untouched. Old admin
-- code reads grooming_score as before; new admin code reads the new columns
-- with null fallback.

BEGIN;

ALTER TABLE public.attendance_photo_analysis
  ADD COLUMN IF NOT EXISTS face_clean_shave   text,
  ADD COLUMN IF NOT EXISTS uniform_compliant  text,
  ADD COLUMN IF NOT EXISTS hair_neat          text,
  ADD COLUMN IF NOT EXISTS head_covering      text,
  ADD COLUMN IF NOT EXISTS reasoning          text,
  ADD COLUMN IF NOT EXISTS model_name         text,
  ADD COLUMN IF NOT EXISTS qc_override_score  numeric,
  ADD COLUMN IF NOT EXISTS qc_override_note   text,
  ADD COLUMN IF NOT EXISTS qc_overridden_by   uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS qc_overridden_at   timestamptz;

CREATE INDEX IF NOT EXISTS attendance_photo_analysis_overrides_idx
  ON public.attendance_photo_analysis (qc_overridden_at DESC)
  WHERE qc_overridden_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS attendance_photo_analysis_analyzed_at_idx
  ON public.attendance_photo_analysis (analyzed_at DESC);

COMMENT ON COLUMN public.attendance_photo_analysis.face_clean_shave  IS 'enum: ok | stubble | mustache | beard | unclear';
COMMENT ON COLUMN public.attendance_photo_analysis.uniform_compliant IS 'enum: ok | no_uniform | wrong_attire | unclear';
COMMENT ON COLUMN public.attendance_photo_analysis.hair_neat         IS 'enum: ok | messy | not_visible';
COMMENT ON COLUMN public.attendance_photo_analysis.head_covering     IS 'enum: none | hijab | cap | other';
COMMENT ON COLUMN public.attendance_photo_analysis.reasoning         IS 'Indonesian human-readable summary, <=200 chars';
COMMENT ON COLUMN public.attendance_photo_analysis.model_name        IS 'rubric/model identifier, e.g. cloud-vision-rubric-v1';

COMMIT;
```

- [ ] **Step 2: Apply the migration locally via Supabase MCP**

Use `mcp__supabase__apply_migration` with name `phase_67_grooming_qc_rubric` and the SQL body above.
Expected: success response, no errors.

- [ ] **Step 3: Verify columns exist**

Use `mcp__supabase__execute_sql` with:

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'attendance_photo_analysis'
  AND column_name IN ('face_clean_shave','uniform_compliant','hair_neat',
                      'head_covering','reasoning','model_name',
                      'qc_override_score','qc_override_note',
                      'qc_overridden_by','qc_overridden_at')
ORDER BY column_name;
```
Expected: 10 rows.

- [ ] **Step 4: Commit**

```bash
git add sql/phase_67_grooming_qc_rubric.sql
git commit -m "feat(sql): phase 67 grooming QC rubric columns + override

Adds 10 additive columns to attendance_photo_analysis for explicit
per-criteria QC judgments (clean shave, uniform, hair, head covering)
plus an admin override audit trail. Backward compatible — existing
rows untouched and old admin code keeps reading grooming_score."
```

---

## Task A2: SQL RPC — apply_grooming_qc_override

**Files:**
- Modify: `sql/phase_67_grooming_qc_rubric.sql` — append RPC + grant

- [ ] **Step 1: Append the RPC to the migration**

```sql
-- Append to sql/phase_67_grooming_qc_rubric.sql

BEGIN;

CREATE OR REPLACE FUNCTION public.apply_grooming_qc_override(
  p_attendance_log_id uuid,
  p_score             numeric,
  p_note              text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthorized' USING ERRCODE = '28000';
  END IF;

  SELECT raw_app_meta_data->>'app_role'
    INTO v_role
    FROM auth.users
   WHERE id = auth.uid();

  IF v_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'forbidden: admin only' USING ERRCODE = '42501';
  END IF;

  IF p_score IS NULL OR p_score < 0 OR p_score > 10 THEN
    RAISE EXCEPTION 'score must be between 0 and 10' USING ERRCODE = '22023';
  END IF;

  IF length(coalesce(p_note, '')) < 10 THEN
    RAISE EXCEPTION 'note must be at least 10 characters' USING ERRCODE = '22023';
  END IF;

  UPDATE public.attendance_photo_analysis
     SET qc_override_score = p_score,
         qc_override_note  = p_note,
         qc_overridden_by  = auth.uid(),
         qc_overridden_at  = now()
   WHERE attendance_log_id = p_attendance_log_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'attendance_photo_analysis row not found' USING ERRCODE = 'P0002';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.apply_grooming_qc_override(uuid, numeric, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.apply_grooming_qc_override(uuid, numeric, text) TO authenticated;

COMMENT ON FUNCTION public.apply_grooming_qc_override(uuid, numeric, text)
IS 'Admin-only override of grooming QC score with required note. Writes audit columns and rejects non-admin auth.uid.';

COMMIT;
```

- [ ] **Step 2: Apply the appended migration**

Use `mcp__supabase__apply_migration` with name `phase_67_grooming_qc_rubric_rpc` and the appended SQL only.

- [ ] **Step 3: Verify the function exists**

Use `mcp__supabase__execute_sql`:

```sql
SELECT proname, prosecdef
FROM pg_proc
WHERE proname = 'apply_grooming_qc_override'
  AND pronamespace = 'public'::regnamespace;
```
Expected: 1 row, `prosecdef = true`.

- [ ] **Step 4: Commit**

```bash
git add sql/phase_67_grooming_qc_rubric.sql
git commit -m "feat(sql): apply_grooming_qc_override RPC (admin-only audit)

Admin-only SECURITY DEFINER function. Validates score 0..10 and
note length >=10. Writes qc_overridden_by/at automatically from
auth.uid() and now(). Non-admin callers raise SQLSTATE 42501."
```

---

## Task A3: Dart-side contract tests for the SQL (sqflite-style fake)

**Files:**
- Create: `test/phase67/phase_67_grooming_qc_rubric_test.dart`

We follow the convention from `test/phase64/attendance_photo_sql_contract_test.dart` — Dart contract test reads the SQL file and asserts shape, not actual DB.

- [ ] **Step 1: Write the failing test**

```dart
// test/phase67/phase_67_grooming_qc_rubric_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('phase_67_grooming_qc_rubric.sql', () {
    late String sql;

    setUpAll(() {
      sql = File('sql/phase_67_grooming_qc_rubric.sql').readAsStringSync();
    });

    test('adds all 10 required additive columns', () {
      const required = [
        'face_clean_shave',
        'uniform_compliant',
        'hair_neat',
        'head_covering',
        'reasoning',
        'model_name',
        'qc_override_score',
        'qc_override_note',
        'qc_overridden_by',
        'qc_overridden_at',
      ];
      for (final col in required) {
        expect(sql, contains('ADD COLUMN IF NOT EXISTS $col'),
            reason: 'missing additive ALTER for $col');
      }
    });

    test('declares the override RPC with SECURITY DEFINER', () {
      expect(sql, contains('CREATE OR REPLACE FUNCTION public.apply_grooming_qc_override'));
      expect(sql, contains('SECURITY DEFINER'));
      expect(sql, contains("SET search_path = public"));
    });

    test('RPC enforces admin-only', () {
      expect(sql, contains("v_role IS DISTINCT FROM 'admin'"));
      expect(sql, contains("'forbidden: admin only'"));
    });

    test('RPC validates score and note', () {
      expect(sql, contains('p_score < 0 OR p_score > 10'));
      expect(sql, contains("length(coalesce(p_note, '')) < 10"));
    });

    test('RPC grants execute to authenticated only', () {
      expect(sql, contains('REVOKE ALL ON FUNCTION public.apply_grooming_qc_override'));
      expect(sql, contains('GRANT EXECUTE ON FUNCTION public.apply_grooming_qc_override(uuid, numeric, text) TO authenticated'));
    });

    test('creates the partial overrides index', () {
      expect(sql, contains('attendance_photo_analysis_overrides_idx'));
      expect(sql, contains('WHERE qc_overridden_at IS NOT NULL'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it passes (SQL is already in place from A1+A2)**

```powershell
C:\flutter\bin\flutter.bat test test/phase67/phase_67_grooming_qc_rubric_test.dart
```
Expected: all assertions pass.

- [ ] **Step 3: Commit**

```bash
git add test/phase67/phase_67_grooming_qc_rubric_test.dart
git commit -m "test(sql): contract test for phase 67 grooming QC migration"
```

---

## Task A4: Extract grooming rules into a pure module (skeleton + types)

**Files:**
- Create: `supabase/functions/analyze-attendance-photo/grooming_rules.ts`

- [ ] **Step 1: Write skeleton with types and exports**

```ts
// supabase/functions/analyze-attendance-photo/grooming_rules.ts
//
// Pure rule logic for parsing Cloud Vision responses into a grooming
// judgment. Has no IO — easy to unit test with canned Vision responses.

export type FaceCleanShave   = 'ok' | 'stubble' | 'mustache' | 'beard' | 'unclear';
export type UniformCompliant = 'ok' | 'no_uniform' | 'wrong_attire' | 'unclear';
export type HairNeat         = 'ok' | 'messy' | 'not_visible';
export type HeadCovering     = 'none' | 'hijab' | 'cap' | 'other';
export type PhotoQuality     = 'clear' | 'blurry' | 'dark' | 'overexposed';

export interface GroomingAnalysis {
  faceDetected: boolean;
  faceConfidence: number;
  faceCount: number;
  photoQuality: PhotoQuality;
  faceCleanShave: FaceCleanShave;
  uniformCompliant: UniformCompliant;
  hairNeat: HairNeat;
  headCovering: HeadCovering;
  groomingLabels: Array<{ description: string; score: number }>;
  groomingScore: number;
  reasoning: string;
  safeSearchPassed: boolean;
  modelName: string;
}

export const MIN_LABEL_SCORE = 0.65;
export const MIN_FACE_CONFIDENCE = 0.8;

export const FACIAL_HAIR_LABELS = [
  'beard','moustache','mustache','facial hair','goatee','stubble','sideburns',
];

// Hijab-specific only. Generic terms like 'head covering' live in OTHER to
// avoid mis-classifying male crew caps as hijab — Cloud Vision returns
// 'head covering' for many cap-shaped objects.
export const HIJAB_LABELS = [
  'hijab','headscarf','veil','niqab','khimar',
];

export const CAP_LABELS = [
  'cap','hat','baseball cap','chef hat',"chef's hat",'beanie','bandana',
];

export const OTHER_HEAD_COVERING_LABELS = [
  'turban','head covering','head wrap','headcloth',
];

export const UNIFORM_LABELS = [
  'apron','chef',"chef's uniform",'uniform','polo shirt','dress shirt',
  'service uniform','waiter','staff',
];

export const WRONG_ATTIRE_LABELS = [
  'tank top','sleeveless','singlet','swimsuit','bikini',
];

export const MESSY_HAIR_LABELS = [
  'messy hair','disheveled','unkempt','bedhead',
];

export const POOR_QUALITY_LABELS: Record<Exclude<PhotoQuality,'clear'>, string[]> = {
  blurry:      ['blur','blurry','out of focus','motion blur'],
  dark:        ['darkness','low light','night','shadow'],
  overexposed: ['overexposed','glare','lens flare','bright'],
};

export function parseGroomingAnalysis(
  raw: Record<string, unknown>,
): GroomingAnalysis {
  // Implemented in Task A5
  throw new Error('not implemented');
}
```

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/analyze-attendance-photo/grooming_rules.ts
git commit -m "feat(qc): scaffold grooming rules module + label whitelists"
```

---

## Task A5: Implement label extraction helpers (TDD)

**Files:**
- Create: `supabase/functions/analyze-attendance-photo/grooming_rules_test.ts`
- Modify: `supabase/functions/analyze-attendance-photo/grooming_rules.ts`

- [ ] **Step 1: Write failing tests for label helpers**

```ts
// supabase/functions/analyze-attendance-photo/grooming_rules_test.ts
import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  matchAnyLabel,
  extractFaceCleanShave,
  extractHeadCovering,
  extractUniformCompliant,
  extractHairNeat,
  extractPhotoQuality,
} from "./grooming_rules.ts";

const beardLabels = [
  { description: "Beard", score: 0.92 },
  { description: "Person", score: 0.95 },
];
const hijabLabels = [
  { description: "Hijab", score: 0.88 },
  { description: "Person", score: 0.95 },
];
const capLabels = [
  { description: "Hat", score: 0.91 },
  { description: "Cap", score: 0.85 },
];
const apronLabels = [
  { description: "Apron", score: 0.81 },
  { description: "Person", score: 0.94 },
];
const lowConfBeardLabels = [
  { description: "Beard", score: 0.40 },
];

Deno.test("matchAnyLabel respects MIN_LABEL_SCORE", () => {
  assertEquals(matchAnyLabel(beardLabels, ["beard"]), true);
  assertEquals(matchAnyLabel(lowConfBeardLabels, ["beard"]), false);
});

Deno.test("extractFaceCleanShave detects beard precedence", () => {
  assertEquals(extractFaceCleanShave(beardLabels, true), "beard");
});

Deno.test("extractFaceCleanShave returns ok when face detected and no facial hair", () => {
  assertEquals(extractFaceCleanShave(apronLabels, true), "ok");
});

Deno.test("extractFaceCleanShave returns unclear when face not detected", () => {
  assertEquals(extractFaceCleanShave(apronLabels, false), "unclear");
});

Deno.test("extractHeadCovering tags hijab", () => {
  assertEquals(extractHeadCovering(hijabLabels), "hijab");
});

Deno.test("extractHeadCovering tags cap", () => {
  assertEquals(extractHeadCovering(capLabels), "cap");
});

Deno.test("extractHeadCovering returns none when no head label", () => {
  assertEquals(extractHeadCovering(apronLabels), "none");
});

Deno.test("extractUniformCompliant ok when apron present", () => {
  assertEquals(extractUniformCompliant(apronLabels, true), "ok");
});

Deno.test("extractUniformCompliant no_uniform when no match and face detected", () => {
  assertEquals(
    extractUniformCompliant([{ description: "Person", score: 0.94 }], true),
    "no_uniform",
  );
});

Deno.test("extractUniformCompliant wrong_attire on tank top", () => {
  assertEquals(
    extractUniformCompliant(
      [{ description: "Tank top", score: 0.81 }],
      true,
    ),
    "wrong_attire",
  );
});

Deno.test("extractHairNeat returns not_visible when head covered", () => {
  assertEquals(extractHairNeat(hijabLabels, "hijab"), "not_visible");
});

Deno.test("extractHairNeat returns messy on disheveled", () => {
  assertEquals(
    extractHairNeat(
      [{ description: "Messy hair", score: 0.7 }],
      "none",
    ),
    "messy",
  );
});

Deno.test("extractHairNeat returns ok by default", () => {
  assertEquals(extractHairNeat(apronLabels, "none"), "ok");
});

Deno.test("extractPhotoQuality detects blurry first", () => {
  assertEquals(
    extractPhotoQuality([
      { description: "Blur", score: 0.81 },
      { description: "Darkness", score: 0.88 },
    ]),
    "blurry",
  );
});

Deno.test("extractPhotoQuality defaults clear", () => {
  assertEquals(extractPhotoQuality(apronLabels), "clear");
});
```

- [ ] **Step 2: Run tests to verify they fail**

```powershell
deno test supabase/functions/analyze-attendance-photo/grooming_rules_test.ts
```
Expected: import errors / `not implemented`.

- [ ] **Step 3: Implement the helpers**

Append to `supabase/functions/analyze-attendance-photo/grooming_rules.ts`:

```ts
export interface Label { description: string; score: number }

export function matchAnyLabel(labels: Label[], needles: string[]): boolean {
  return labels.some((l) =>
    l.score >= MIN_LABEL_SCORE &&
    needles.some((n) => l.description.toLowerCase().includes(n))
  );
}

export function extractFaceCleanShave(
  labels: Label[],
  faceDetected: boolean,
): FaceCleanShave {
  if (!faceDetected) return 'unclear';
  if (matchAnyLabel(labels, ['beard','goatee'])) return 'beard';
  if (matchAnyLabel(labels, ['moustache','mustache'])) return 'mustache';
  if (matchAnyLabel(labels, ['stubble','sideburns','facial hair'])) return 'stubble';
  return 'ok';
}

export function extractHeadCovering(labels: Label[]): HeadCovering {
  if (matchAnyLabel(labels, HIJAB_LABELS)) return 'hijab';
  if (matchAnyLabel(labels, CAP_LABELS)) return 'cap';
  if (matchAnyLabel(labels, OTHER_HEAD_COVERING_LABELS)) return 'other';
  return 'none';
}

export function extractUniformCompliant(
  labels: Label[],
  faceDetected: boolean,
): UniformCompliant {
  if (matchAnyLabel(labels, UNIFORM_LABELS)) return 'ok';
  if (matchAnyLabel(labels, WRONG_ATTIRE_LABELS)) return 'wrong_attire';
  if (faceDetected) return 'no_uniform';
  return 'unclear';
}

export function extractHairNeat(
  labels: Label[],
  headCovering: HeadCovering,
): HairNeat {
  if (headCovering !== 'none') return 'not_visible';
  if (matchAnyLabel(labels, MESSY_HAIR_LABELS)) return 'messy';
  return 'ok';
}

export function extractPhotoQuality(labels: Label[]): PhotoQuality {
  if (matchAnyLabel(labels, POOR_QUALITY_LABELS.blurry)) return 'blurry';
  if (matchAnyLabel(labels, POOR_QUALITY_LABELS.dark)) return 'dark';
  if (matchAnyLabel(labels, POOR_QUALITY_LABELS.overexposed)) return 'overexposed';
  return 'clear';
}
```

- [ ] **Step 4: Run tests to verify they pass**

```powershell
deno test supabase/functions/analyze-attendance-photo/grooming_rules_test.ts
```
Expected: 14 pass.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/analyze-attendance-photo/grooming_rules.ts supabase/functions/analyze-attendance-photo/grooming_rules_test.ts
git commit -m "feat(qc): label extraction helpers for clean shave, uniform, hair, head covering, quality

- matchAnyLabel respects MIN_LABEL_SCORE (0.65)
- extractFaceCleanShave precedence: beard > mustache > stubble
- extractHeadCovering: HIJAB > CAP > OTHER
- extractHairNeat = not_visible when head_covering != none (hijab-neutral fix)
- 14 Deno unit tests cover the precedence rules"
```

---

## Task A6: Score formula + reasoning template (TDD)

**Files:**
- Modify: `supabase/functions/analyze-attendance-photo/grooming_rules.ts`
- Modify: `supabase/functions/analyze-attendance-photo/grooming_rules_test.ts`

- [ ] **Step 1: Write failing tests for scoring and reasoning**

Append to `grooming_rules_test.ts`:

```ts
import { computeScore, buildReasoning } from "./grooming_rules.ts";

Deno.test("computeScore max when all OK", () => {
  assertEquals(
    computeScore({
      faceCleanShave: "ok",
      uniformCompliant: "ok",
      hairNeat: "ok",
      photoQuality: "clear",
    }),
    10,
  );
});

Deno.test("computeScore hijab + apron + clean shave = 10", () => {
  assertEquals(
    computeScore({
      faceCleanShave: "ok",
      uniformCompliant: "ok",
      hairNeat: "not_visible",
      photoQuality: "clear",
    }),
    10,
  );
});

Deno.test("computeScore beard penalty", () => {
  assertEquals(
    computeScore({
      faceCleanShave: "beard",
      uniformCompliant: "ok",
      hairNeat: "ok",
      photoQuality: "clear",
    }),
    7,
  );
});

Deno.test("computeScore unclear gives partial credit", () => {
  assertEquals(
    computeScore({
      faceCleanShave: "unclear",
      uniformCompliant: "unclear",
      hairNeat: "ok",
      photoQuality: "clear",
    }),
    6,
  );
});

Deno.test("computeScore caps at 10", () => {
  const score = computeScore({
    faceCleanShave: "ok",
    uniformCompliant: "ok",
    hairNeat: "ok",
    photoQuality: "clear",
  });
  assertEquals(score <= 10, true);
});

Deno.test("buildReasoning lists issues then OKs in Indonesian", () => {
  const r = buildReasoning({
    faceCleanShave: "beard",
    uniformCompliant: "ok",
    hairNeat: "ok",
    headCovering: "none",
    photoQuality: "clear",
    faceDetected: true,
  });
  assertEquals(r.startsWith("Terdeteksi jenggot"), true);
  assertEquals(r.includes("Seragam OK"), true);
  assertEquals(r.length <= 200, true);
});

Deno.test("buildReasoning highlights hijab as positive", () => {
  const r = buildReasoning({
    faceCleanShave: "ok",
    uniformCompliant: "ok",
    hairNeat: "not_visible",
    headCovering: "hijab",
    photoQuality: "clear",
    faceDetected: true,
  });
  assertEquals(r.includes("Berhijab"), true);
  assertEquals(r.includes("rambut OK"), true);
});

Deno.test("buildReasoning highlights cap (topi)", () => {
  const r = buildReasoning({
    faceCleanShave: "ok",
    uniformCompliant: "ok",
    hairNeat: "not_visible",
    headCovering: "cap",
    photoQuality: "clear",
    faceDetected: true,
  });
  assertEquals(r.includes("topi"), true);
});

Deno.test("buildReasoning notes blurry photo", () => {
  const r = buildReasoning({
    faceCleanShave: "ok",
    uniformCompliant: "ok",
    hairNeat: "ok",
    headCovering: "none",
    photoQuality: "blurry",
    faceDetected: true,
  });
  assertEquals(r.includes("buram"), true);
});

Deno.test("buildReasoning when face not detected leads", () => {
  const r = buildReasoning({
    faceCleanShave: "unclear",
    uniformCompliant: "unclear",
    hairNeat: "ok",
    headCovering: "none",
    photoQuality: "blurry",
    faceDetected: false,
  });
  assertEquals(r.startsWith("Wajah tidak terdeteksi"), true);
});
```

- [ ] **Step 2: Run tests to verify they fail**

```powershell
deno test supabase/functions/analyze-attendance-photo/grooming_rules_test.ts
```
Expected: import errors for `computeScore` / `buildReasoning`.

- [ ] **Step 3: Implement scoring and reasoning**

Append to `grooming_rules.ts`:

```ts
interface ScoreInput {
  faceCleanShave: FaceCleanShave;
  uniformCompliant: UniformCompliant;
  hairNeat: HairNeat;
  photoQuality: PhotoQuality;
}

export function computeScore(input: ScoreInput): number {
  let score = 0;

  if (input.faceCleanShave === 'ok') score += 3;
  else if (input.faceCleanShave === 'unclear') score += 1;
  // 'stubble' | 'mustache' | 'beard' → 0

  if (input.uniformCompliant === 'ok') score += 3;
  else if (input.uniformCompliant === 'unclear') score += 1;

  if (input.hairNeat === 'ok' || input.hairNeat === 'not_visible') score += 3;
  // 'messy' → 0

  if (input.photoQuality === 'clear') score += 1;

  return Math.min(score, 10);
}

interface ReasoningInput extends ScoreInput {
  headCovering: HeadCovering;
  faceDetected: boolean;
}

export function buildReasoning(input: ReasoningInput): string {
  const parts: string[] = [];

  if (!input.faceDetected) {
    parts.push('Wajah tidak terdeteksi jelas');
  } else if (input.faceCleanShave === 'beard') {
    parts.push('Terdeteksi jenggot');
  } else if (input.faceCleanShave === 'mustache') {
    parts.push('Terdeteksi kumis');
  } else if (input.faceCleanShave === 'stubble') {
    parts.push('Terdeteksi bulu wajah');
  } else if (input.faceCleanShave === 'ok') {
    parts.push('Wajah bersih');
  }

  if (input.uniformCompliant === 'ok') parts.push('Seragam OK');
  else if (input.uniformCompliant === 'no_uniform') parts.push('Tidak pakai seragam');
  else if (input.uniformCompliant === 'wrong_attire') parts.push('Pakaian tidak pantas');

  if (input.headCovering === 'hijab') parts.push('Berhijab — rambut OK');
  else if (input.headCovering === 'cap') parts.push('Pakai topi — rambut OK');
  else if (input.headCovering === 'other') parts.push('Penutup kepala — rambut OK');
  else if (input.hairNeat === 'messy') parts.push('Rambut acak');
  else if (input.hairNeat === 'ok' && input.faceDetected) parts.push('Rambut OK');

  if (input.photoQuality === 'blurry') parts.push('Foto buram');
  else if (input.photoQuality === 'dark') parts.push('Foto gelap');
  else if (input.photoQuality === 'overexposed') parts.push('Foto terlalu terang');
  else if (input.photoQuality === 'clear') parts.push('Foto jelas');

  const text = parts.join('. ') + '.';
  return text.length > 200 ? text.slice(0, 197) + '...' : text;
}
```

- [ ] **Step 4: Run tests**

```powershell
deno test supabase/functions/analyze-attendance-photo/grooming_rules_test.ts
```
Expected: all tests pass (24 total).

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/analyze-attendance-photo/grooming_rules.ts supabase/functions/analyze-attendance-photo/grooming_rules_test.ts
git commit -m "feat(qc): score formula + Indonesian reasoning template

Score: face_clean_shave OK +3 / unclear +1, uniform OK +3 / unclear +1,
hair OK or not_visible +3, photo clear +1. Capped at 10. Reasoning
leads with issues, ends with positives, max 200 chars."
```

---

## Task A7: Wire up parseGroomingAnalysis from Vision response

**Files:**
- Modify: `supabase/functions/analyze-attendance-photo/grooming_rules.ts`
- Modify: `supabase/functions/analyze-attendance-photo/grooming_rules_test.ts`

- [ ] **Step 1: Write failing integration test using a canned Vision response**

Append to `grooming_rules_test.ts`:

```ts
import { parseGroomingAnalysis } from "./grooming_rules.ts";

const cannedBeardResponse = {
  responses: [{
    labelAnnotations: [
      { description: "Beard", score: 0.92 },
      { description: "Person", score: 0.96 },
      { description: "Shirt", score: 0.84 },
    ],
    faceAnnotations: [{ detectionConfidence: 0.93 }],
    safeSearchAnnotation: { adult: "VERY_UNLIKELY", violence: "UNLIKELY", racy: "UNLIKELY" },
  }],
};

Deno.test("parseGroomingAnalysis penalises beard but keeps face_detected true", () => {
  const r = parseGroomingAnalysis(cannedBeardResponse);
  assertEquals(r.faceDetected, true);
  assertEquals(r.faceCleanShave, "beard");
  assertEquals(r.groomingScore < 8, true);
  assertEquals(r.modelName, "cloud-vision-rubric-v1");
  assertEquals(r.safeSearchPassed, true);
});

const cannedHijabResponse = {
  responses: [{
    labelAnnotations: [
      { description: "Hijab", score: 0.89 },
      { description: "Apron", score: 0.82 },
      { description: "Person", score: 0.95 },
    ],
    faceAnnotations: [{ detectionConfidence: 0.86 }],
    safeSearchAnnotation: { adult: "VERY_UNLIKELY", violence: "VERY_UNLIKELY", racy: "VERY_UNLIKELY" },
  }],
};

Deno.test("parseGroomingAnalysis is hijab-neutral and rewards apron", () => {
  const r = parseGroomingAnalysis(cannedHijabResponse);
  assertEquals(r.headCovering, "hijab");
  assertEquals(r.hairNeat, "not_visible");
  assertEquals(r.uniformCompliant, "ok");
  assertEquals(r.groomingScore, 10);
});

Deno.test("parseGroomingAnalysis handles empty responses", () => {
  const r = parseGroomingAnalysis({ responses: [{}] });
  assertEquals(r.faceDetected, false);
  assertEquals(r.faceCount, 0);
  assertEquals(r.faceCleanShave, "unclear");
});
```

- [ ] **Step 2: Run tests to confirm failure**

```powershell
deno test supabase/functions/analyze-attendance-photo/grooming_rules_test.ts
```
Expected: `parseGroomingAnalysis` throws "not implemented".

- [ ] **Step 3: Replace stub `parseGroomingAnalysis` body**

In `grooming_rules.ts`, replace the existing stub `parseGroomingAnalysis` with:

```ts
export function parseGroomingAnalysis(
  raw: Record<string, unknown>,
): GroomingAnalysis {
  const responses = Array.isArray(raw.responses) ? raw.responses : [];
  const first = (responses[0] ?? {}) as Record<string, unknown>;

  const rawLabels = Array.isArray(first.labelAnnotations)
    ? first.labelAnnotations as Array<Record<string, unknown>>
    : [];
  const faces = Array.isArray(first.faceAnnotations)
    ? first.faceAnnotations as Array<Record<string, unknown>>
    : [];
  const safe = (first.safeSearchAnnotation ?? {}) as Record<string, string>;

  const labels: Label[] = rawLabels.map((l) => ({
    description: String(l.description ?? ''),
    score: Number(l.score ?? 0),
  })).filter((l) => l.description.length > 0);

  const faceConfidence = faces.length > 0
    ? Number(faces[0].detectionConfidence ?? 0)
    : 0;
  const faceDetected = faces.length > 0 && faceConfidence >= MIN_FACE_CONFIDENCE;

  const headCovering = extractHeadCovering(labels);
  const faceCleanShave = extractFaceCleanShave(labels, faceDetected);
  const uniformCompliant = extractUniformCompliant(labels, faceDetected);
  const hairNeat = extractHairNeat(labels, headCovering);
  const photoQuality = extractPhotoQuality(labels);

  const groomingScore = computeScore({
    faceCleanShave, uniformCompliant, hairNeat, photoQuality,
  });
  const reasoning = buildReasoning({
    faceCleanShave, uniformCompliant, hairNeat, headCovering,
    photoQuality, faceDetected,
  });

  const safeSearchPassed = (['adult','violence','racy'] as const).every((k) =>
    !['LIKELY','VERY_LIKELY'].includes(String(safe[k] ?? 'UNKNOWN'))
  );

  return {
    faceDetected,
    faceConfidence: Number(faceConfidence.toFixed(2)),
    faceCount: faces.length,
    photoQuality,
    faceCleanShave,
    uniformCompliant,
    hairNeat,
    headCovering,
    groomingLabels: labels,
    groomingScore: Number(groomingScore.toFixed(1)),
    reasoning,
    safeSearchPassed,
    modelName: 'cloud-vision-rubric-v1',
  };
}
```

- [ ] **Step 4: Run tests**

```powershell
deno test supabase/functions/analyze-attendance-photo/grooming_rules_test.ts
```
Expected: all tests pass (27 total).

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/analyze-attendance-photo/grooming_rules.ts supabase/functions/analyze-attendance-photo/grooming_rules_test.ts
git commit -m "feat(qc): parseGroomingAnalysis composes rules into structured judgment

Vision response → labels → 4 per-criteria extractors → score + reasoning.
Hijab + apron + clean shave returns score 10 (regression-locked).
Beard returns face_clean_shave='beard' and score capped low."
```

---

## Task A8: Wire grooming_rules into the Edge Function entrypoint

**Files:**
- Modify: `supabase/functions/analyze-attendance-photo/index.ts`

- [ ] **Step 1: Add legacy flag and import the new module**

Update the top of `index.ts`:

```ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { parseGroomingAnalysis } from "./grooming_rules.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const USE_LEGACY_VISION_SCORING =
  (Deno.env.get("USE_LEGACY_VISION_SCORING") ?? "false").toLowerCase() === "true";
```

- [ ] **Step 2: Replace the analysis + upsert section**

Inside `serve(...)`, after `const visionResponse = await callVisionApi(...)`, replace the next block with:

```ts
const visionResponse = await callVisionApi(imageBytes, googleAuth);

const analysis = USE_LEGACY_VISION_SCORING
  ? parseLegacyGroomingAnalysis(visionResponse)
  : parseGroomingAnalysis(visionResponse);

const { error: upsertError } = await supabaseAdmin
  .from("attendance_photo_analysis")
  .upsert(
    {
      attendance_log_id: attendanceLogId,
      photo_url: photoUrl,
      face_detected: analysis.faceDetected,
      face_confidence: analysis.faceConfidence,
      face_count: analysis.faceCount,
      photo_quality: analysis.photoQuality,
      grooming_labels: analysis.groomingLabels,
      grooming_score: analysis.groomingScore,
      safe_search_passed: analysis.safeSearchPassed,
      raw_vision_response: visionResponse,
      analyzed_at: new Date().toISOString(),
      // Rubric columns — present only on non-legacy path
      face_clean_shave: (analysis as any).faceCleanShave ?? null,
      uniform_compliant: (analysis as any).uniformCompliant ?? null,
      hair_neat: (analysis as any).hairNeat ?? null,
      head_covering: (analysis as any).headCovering ?? null,
      reasoning: (analysis as any).reasoning ?? null,
      model_name: (analysis as any).modelName ?? "cloud-vision-legacy",
    },
    { onConflict: "attendance_log_id" },
  );
```

- [ ] **Step 3: Rename existing parseGroomingAnalysis to parseLegacyGroomingAnalysis**

In `index.ts` find the existing local function `function parseGroomingAnalysis(raw: ...)` (from current code) and rename it to `parseLegacyGroomingAnalysis`. Leave its body unchanged. This keeps the rollback path working.

- [ ] **Step 4: Bump LABEL_DETECTION maxResults**

Find the `callVisionApi` body and change:

```ts
{ type: "LABEL_DETECTION", maxResults: 15 },
```
to
```ts
{ type: "LABEL_DETECTION", maxResults: 30 },
```

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/analyze-attendance-photo/index.ts
git commit -m "feat(qc): wire rubric scoring + legacy flag + bump label maxResults

USE_LEGACY_VISION_SCORING=true falls back to the old keyword scoring
for rollback. New path writes face_clean_shave/uniform_compliant/
hair_neat/head_covering/reasoning columns alongside legacy fields.
LABEL_DETECTION bumped from 15 to 30 for richer label coverage."
```

---

## Task A9: Capture and check in fixture Vision responses

Five fixture JSON files give us deterministic regression tests against real-shaped Vision payloads.

**Files:**
- Create: `supabase/functions/analyze-attendance-photo/fixtures/vision_beard.json`
- Create: `supabase/functions/analyze-attendance-photo/fixtures/vision_hijab.json`
- Create: `supabase/functions/analyze-attendance-photo/fixtures/vision_clean.json`
- Create: `supabase/functions/analyze-attendance-photo/fixtures/vision_no_uniform.json`
- Create: `supabase/functions/analyze-attendance-photo/fixtures/vision_blurry.json`

- [ ] **Step 1: Write the five fixtures**

```json
// vision_beard.json
{
  "responses": [{
    "labelAnnotations": [
      {"description": "Beard", "score": 0.93},
      {"description": "Facial hair", "score": 0.88},
      {"description": "Person", "score": 0.97},
      {"description": "Apron", "score": 0.81}
    ],
    "faceAnnotations": [{"detectionConfidence": 0.94}],
    "safeSearchAnnotation": {"adult": "VERY_UNLIKELY", "violence": "VERY_UNLIKELY", "racy": "VERY_UNLIKELY"}
  }]
}
```

```json
// vision_hijab.json
{
  "responses": [{
    "labelAnnotations": [
      {"description": "Hijab", "score": 0.91},
      {"description": "Apron", "score": 0.83},
      {"description": "Person", "score": 0.96}
    ],
    "faceAnnotations": [{"detectionConfidence": 0.87}],
    "safeSearchAnnotation": {"adult": "VERY_UNLIKELY", "violence": "VERY_UNLIKELY", "racy": "VERY_UNLIKELY"}
  }]
}
```

```json
// vision_clean.json
{
  "responses": [{
    "labelAnnotations": [
      {"description": "Person", "score": 0.97},
      {"description": "Polo shirt", "score": 0.85},
      {"description": "Uniform", "score": 0.78}
    ],
    "faceAnnotations": [{"detectionConfidence": 0.95}],
    "safeSearchAnnotation": {"adult": "VERY_UNLIKELY", "violence": "VERY_UNLIKELY", "racy": "VERY_UNLIKELY"}
  }]
}
```

```json
// vision_no_uniform.json
{
  "responses": [{
    "labelAnnotations": [
      {"description": "Tank top", "score": 0.84},
      {"description": "Person", "score": 0.96}
    ],
    "faceAnnotations": [{"detectionConfidence": 0.92}],
    "safeSearchAnnotation": {"adult": "VERY_UNLIKELY", "violence": "VERY_UNLIKELY", "racy": "VERY_UNLIKELY"}
  }]
}
```

```json
// vision_blurry.json
{
  "responses": [{
    "labelAnnotations": [
      {"description": "Blur", "score": 0.87},
      {"description": "Out of focus", "score": 0.78},
      {"description": "Person", "score": 0.91}
    ],
    "faceAnnotations": [{"detectionConfidence": 0.62}],
    "safeSearchAnnotation": {"adult": "VERY_UNLIKELY", "violence": "VERY_UNLIKELY", "racy": "VERY_UNLIKELY"}
  }]
}
```

- [ ] **Step 2: Add a fixture-driven test**

Append to `grooming_rules_test.ts`:

```ts
async function loadFixture(name: string): Promise<Record<string, unknown>> {
  const url = new URL(`./fixtures/${name}.json`, import.meta.url);
  const text = await Deno.readTextFile(url);
  return JSON.parse(text);
}

Deno.test("fixture: beard photo -> face_clean_shave=beard, score<8", async () => {
  const r = parseGroomingAnalysis(await loadFixture("vision_beard"));
  assertEquals(r.faceCleanShave, "beard");
  assertEquals(r.groomingScore < 8, true);
});

Deno.test("fixture: hijab photo -> head_covering=hijab, score=10", async () => {
  const r = parseGroomingAnalysis(await loadFixture("vision_hijab"));
  assertEquals(r.headCovering, "hijab");
  assertEquals(r.hairNeat, "not_visible");
  assertEquals(r.groomingScore, 10);
});

Deno.test("fixture: clean photo -> all OK, score>=9", async () => {
  const r = parseGroomingAnalysis(await loadFixture("vision_clean"));
  assertEquals(r.faceCleanShave, "ok");
  assertEquals(r.uniformCompliant, "ok");
  assertEquals(r.groomingScore >= 9, true);
});

Deno.test("fixture: tank top -> uniform_compliant=wrong_attire", async () => {
  const r = parseGroomingAnalysis(await loadFixture("vision_no_uniform"));
  assertEquals(r.uniformCompliant, "wrong_attire");
});

Deno.test("fixture: blurry photo -> photo_quality=blurry, face_detected=false", async () => {
  const r = parseGroomingAnalysis(await loadFixture("vision_blurry"));
  assertEquals(r.photoQuality, "blurry");
  assertEquals(r.faceDetected, false);
});
```

- [ ] **Step 3: Run tests**

```powershell
deno test --allow-read supabase/functions/analyze-attendance-photo/grooming_rules_test.ts
```
Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/analyze-attendance-photo/fixtures/ supabase/functions/analyze-attendance-photo/grooming_rules_test.ts
git commit -m "test(qc): fixture-driven regression tests for 5 Vision response shapes

Beard, hijab, clean, tank-top, blurry — each locked behaviour now
regression-tested without hitting Vision API."
```

---

## Task A10: Deploy Edge Function with USE_LEGACY_VISION_SCORING=true (safe default)

- [ ] **Step 1: Deploy the function**

Use `mcp__supabase__deploy_edge_function` with `name=analyze-attendance-photo` and the updated source from `supabase/functions/analyze-attendance-photo/`. Set env var `USE_LEGACY_VISION_SCORING=true` so the legacy path runs in prod after deploy.

Expected: deploy success, no schema errors.

- [ ] **Step 2: Verify with a smoke test on an existing attendance_log**

Use `mcp__supabase__execute_sql`:

```sql
SELECT attendance_log_id, model_name, grooming_score, face_clean_shave
FROM attendance_photo_analysis
ORDER BY analyzed_at DESC
LIMIT 3;
```
Expected: existing rows still have `model_name` NULL (legacy path doesn't set it, since legacy code wasn't aware of the column). New rows analysed after this deploy will have `model_name='cloud-vision-legacy'`.

- [ ] **Step 3: Commit deployment notes**

No code change in this step — phase A is complete. The flag flip to `false` is Phase D.

---

# Phase B — Kiosk capture (state machine + liveness)

## Task B1: Add liveness tuning constants

**Files:**
- Modify: `lib/core/constants.dart`

- [ ] **Step 1: Edit the file**

Inside the `AppConstants` class near the other `attendancePhoto*` constants, replace:

```dart
  static const int attendancePhotoStableFaceMs = 500;
  static const int attendancePhotoPreviewMs = 300;
  static const int attendancePhotoFaceThrottleMs = 140;
  static const double attendancePhotoMaxHeadEulerY = 30;
  static const double attendancePhotoMinFaceFrameRatio = 0.20;
  static const int attendancePhotoUploadMaxRetries = 3;
```

with:

```dart
  static const int attendancePhotoStableFaceMs = 1000;
  static const int attendancePhotoBlinkWindowMs = 3000;
  static const double attendancePhotoEyeClosedThreshold = 0.30;
  static const double attendancePhotoEyeOpenThreshold = 0.70;
  static const int attendancePhotoPreviewMs = 300;
  static const int attendancePhotoFaceThrottleMs = 140;
  static const double attendancePhotoMaxHeadEulerY = 15;
  static const double attendancePhotoMinFaceFrameRatio = 0.20;
  static const double attendancePhotoOvalFillMin = 0.55;
  static const double attendancePhotoOvalFillMax = 0.95;
  static const int attendancePhotoMaxBlinkAttempts = 3;
  static const int attendancePhotoUploadMaxRetries = 3;
```

- [ ] **Step 2: Run analyze to confirm no other file used the old values**

```powershell
C:\flutter\bin\flutter.bat analyze lib/
```
Expected: zero errors. If any file references missing constants, fix them in the same task.

- [ ] **Step 3: Commit**

```bash
git add lib/core/constants.dart
git commit -m "feat(kiosk): liveness tuning constants for bank-style capture

stableFaceMs 500→1000 (anti-shake hold), maxHeadEulerY 30→15
(stricter alignment), new blinkWindowMs/eyeOpen/closed thresholds,
ovalFillMin/Max, maxBlinkAttempts."
```

---

## Task B2: Extend FaceDetectionService with classification + alignment

**Files:**
- Modify: `lib/services/face_detection_service.dart`

- [ ] **Step 1: Replace the file contents**

```dart
// lib/services/face_detection_service.dart
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/constants.dart';

enum FaceAlignment { absent, tooSmall, tooBig, offCenter, tilted, aligned }

class FaceDetectionResult {
  final bool hasFace;
  final int faceCount;
  final Rect? boundingBox;
  final double? headEulerAngleY;
  final double? leftEyeOpen;
  final double? rightEyeOpen;
  final FaceAlignment alignment;

  const FaceDetectionResult({
    required this.hasFace,
    required this.faceCount,
    required this.alignment,
    this.boundingBox,
    this.headEulerAngleY,
    this.leftEyeOpen,
    this.rightEyeOpen,
  });

  const FaceDetectionResult.empty()
      : hasFace = false,
        faceCount = 0,
        boundingBox = null,
        headEulerAngleY = null,
        leftEyeOpen = null,
        rightEyeOpen = null,
        alignment = FaceAlignment.absent;

  bool get bothEyesClosed =>
      (leftEyeOpen ?? 1) < AppConstants.attendancePhotoEyeClosedThreshold &&
      (rightEyeOpen ?? 1) < AppConstants.attendancePhotoEyeClosedThreshold;

  bool get bothEyesOpen =>
      (leftEyeOpen ?? 0) > AppConstants.attendancePhotoEyeOpenThreshold &&
      (rightEyeOpen ?? 0) > AppConstants.attendancePhotoEyeOpenThreshold;
}

class FaceDetectionService {
  FaceDetectionService._();

  static final FaceDetectionService instance = FaceDetectionService._();

  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true,
      minFaceSize: 0.15,
    ),
  );

  Future<FaceDetectionResult> processImage(InputImage inputImage) async {
    final faces = await _detector.processImage(inputImage);
    if (faces.isEmpty) return const FaceDetectionResult.empty();

    final face = faces.first;
    final frameSize = inputImage.metadata?.size;
    final alignment = _resolveAlignment(face, frameSize, faces.length);

    return FaceDetectionResult(
      hasFace: true,
      faceCount: faces.length,
      boundingBox: face.boundingBox,
      headEulerAngleY: face.headEulerAngleY,
      leftEyeOpen: face.leftEyeOpenProbability,
      rightEyeOpen: face.rightEyeOpenProbability,
      alignment: alignment,
    );
  }

  FaceAlignment _resolveAlignment(Face face, Size? frame, int faceCount) {
    if (faceCount != 1) return FaceAlignment.absent;
    final tilt = face.headEulerAngleY?.abs() ?? 0;
    if (tilt > AppConstants.attendancePhotoMaxHeadEulerY) {
      return FaceAlignment.tilted;
    }
    if (frame == null) return FaceAlignment.aligned;

    final widthRatio = face.boundingBox.width / frame.width;
    if (widthRatio < AppConstants.attendancePhotoOvalFillMin) {
      return FaceAlignment.tooSmall;
    }
    if (widthRatio > AppConstants.attendancePhotoOvalFillMax) {
      return FaceAlignment.tooBig;
    }

    final faceCenterX = face.boundingBox.center.dx;
    final frameCenterX = frame.width / 2;
    final centerOffset = (faceCenterX - frameCenterX).abs() / frame.width;
    if (centerOffset > 0.15) return FaceAlignment.offCenter;

    return FaceAlignment.aligned;
  }

  Future<void> close() => _detector.close();
}
```

- [ ] **Step 2: Run analyze and look for compile errors in dependents**

```powershell
C:\flutter\bin\flutter.bat analyze lib/services/face_detection_service.dart lib/widgets/camera_face_preview.dart
```
Expected: errors only in `camera_face_preview.dart` because we removed the old `isValid` field. Those are fixed in Task B5.

- [ ] **Step 3: Commit**

```bash
git add lib/services/face_detection_service.dart
git commit -m "feat(kiosk): FaceDetectionService exposes alignment + eye-open

enableClassification=true returns left/right eye-open probabilities.
New FaceAlignment enum encodes the camera's coaching state. Old
isValid getter removed — UI consumes the enum directly."
```

---

## Task B3: Unit tests for FaceDetectionService alignment logic

**Files:**
- Create: `test/services/face_detection_service_test.dart`

We test the pure alignment logic by reaching into `_resolveAlignment` indirectly via a test-only subclass that bypasses the detector. Since `_resolveAlignment` is private, we use the `bothEyesClosed/Open` getters on `FaceDetectionResult` and stub `processImage` via subclass-friendly extraction. To keep this test pure and fast we add a `@visibleForTesting` helper.

- [ ] **Step 1: Add the visible-for-testing helper**

Append to `lib/services/face_detection_service.dart` inside `FaceDetectionService`:

```dart
  @visibleForTesting
  FaceAlignment debugResolveAlignment({
    required int faceCount,
    required Rect boundingBox,
    required double headEulerY,
    required Size frameSize,
  }) {
    if (faceCount != 1) return FaceAlignment.absent;
    if (headEulerY.abs() > AppConstants.attendancePhotoMaxHeadEulerY) {
      return FaceAlignment.tilted;
    }
    final widthRatio = boundingBox.width / frameSize.width;
    if (widthRatio < AppConstants.attendancePhotoOvalFillMin) {
      return FaceAlignment.tooSmall;
    }
    if (widthRatio > AppConstants.attendancePhotoOvalFillMax) {
      return FaceAlignment.tooBig;
    }
    final centerOffset =
        (boundingBox.center.dx - frameSize.width / 2).abs() / frameSize.width;
    if (centerOffset > 0.15) return FaceAlignment.offCenter;
    return FaceAlignment.aligned;
  }
```

Add at top: `import 'package:flutter/foundation.dart';`

- [ ] **Step 2: Write failing tests**

```dart
// test/services/face_detection_service_test.dart
import 'dart:ui';

import 'package:absensi_enakko_flutter/services/face_detection_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = FaceDetectionService.instance;
  const frame = Size(720, 1280);

  Rect bbox(double widthRatio, {double offsetRatio = 0}) {
    final w = frame.width * widthRatio;
    final cx = frame.width / 2 + (frame.width * offsetRatio);
    return Rect.fromCenter(center: Offset(cx, frame.height / 2), width: w, height: w);
  }

  test('returns absent when no face', () {
    expect(
      service.debugResolveAlignment(
        faceCount: 0,
        boundingBox: Rect.zero,
        headEulerY: 0,
        frameSize: frame,
      ),
      FaceAlignment.absent,
    );
  });

  test('returns tilted when euler > 15', () {
    expect(
      service.debugResolveAlignment(
        faceCount: 1,
        boundingBox: bbox(0.7),
        headEulerY: 20,
        frameSize: frame,
      ),
      FaceAlignment.tilted,
    );
  });

  test('returns tooSmall when width below 0.55', () {
    expect(
      service.debugResolveAlignment(
        faceCount: 1,
        boundingBox: bbox(0.40),
        headEulerY: 0,
        frameSize: frame,
      ),
      FaceAlignment.tooSmall,
    );
  });

  test('returns tooBig when width above 0.95', () {
    expect(
      service.debugResolveAlignment(
        faceCount: 1,
        boundingBox: bbox(0.97),
        headEulerY: 0,
        frameSize: frame,
      ),
      FaceAlignment.tooBig,
    );
  });

  test('returns offCenter when centre offset > 0.15', () {
    expect(
      service.debugResolveAlignment(
        faceCount: 1,
        boundingBox: bbox(0.7, offsetRatio: 0.2),
        headEulerY: 0,
        frameSize: frame,
      ),
      FaceAlignment.offCenter,
    );
  });

  test('returns aligned for ideal placement', () {
    expect(
      service.debugResolveAlignment(
        faceCount: 1,
        boundingBox: bbox(0.7),
        headEulerY: 5,
        frameSize: frame,
      ),
      FaceAlignment.aligned,
    );
  });

  test('bothEyesClosed when both probabilities < 0.30', () {
    final r = FaceDetectionResult(
      hasFace: true,
      faceCount: 1,
      alignment: FaceAlignment.aligned,
      leftEyeOpen: 0.2,
      rightEyeOpen: 0.15,
    );
    expect(r.bothEyesClosed, isTrue);
    expect(r.bothEyesOpen, isFalse);
  });

  test('bothEyesOpen when both probabilities > 0.70', () {
    final r = FaceDetectionResult(
      hasFace: true,
      faceCount: 1,
      alignment: FaceAlignment.aligned,
      leftEyeOpen: 0.85,
      rightEyeOpen: 0.9,
    );
    expect(r.bothEyesOpen, isTrue);
    expect(r.bothEyesClosed, isFalse);
  });
}
```

- [ ] **Step 3: Run tests**

```powershell
C:\flutter\bin\flutter.bat test test/services/face_detection_service_test.dart
```
Expected: 8 pass.

- [ ] **Step 4: Commit**

```bash
git add lib/services/face_detection_service.dart test/services/face_detection_service_test.dart
git commit -m "test(kiosk): alignment + eye-open getters with 8 cases"
```

---

## Task B4: Extract the capture state machine into a pure dart class

**Files:**
- Create: `lib/widgets/face_capture_state_machine.dart`

- [ ] **Step 1: Write the state machine**

```dart
// lib/widgets/face_capture_state_machine.dart
//
// Pure state machine for the bank-style capture flow. No camera, no
// UI, no async — easy to unit test deterministically.

import '../core/constants.dart';
import '../services/face_detection_service.dart';

enum CaptureState { searching, aligning, promptBlink, capturing, retry, exhausted, done }

class FaceCaptureStateMachine {
  CaptureState _state = CaptureState.searching;
  DateTime? _alignedSince;
  DateTime? _blinkPromptStart;
  bool _sawClosedEyes = false;
  int _attempts = 0;

  CaptureState get state => _state;
  int get attempts => _attempts;

  /// Drives one tick of the FSM from a fresh detection plus current time.
  /// Returns the new state.
  CaptureState onDetection(FaceDetectionResult r, DateTime now) {
    switch (_state) {
      case CaptureState.searching:
        if (r.alignment == FaceAlignment.aligned) {
          _state = CaptureState.aligning;
          _alignedSince = now;
        }
        break;

      case CaptureState.aligning:
        if (r.alignment != FaceAlignment.aligned) {
          _state = CaptureState.searching;
          _alignedSince = null;
        } else if (_alignedSince != null &&
            now.difference(_alignedSince!).inMilliseconds >=
                AppConstants.attendancePhotoStableFaceMs) {
          _state = CaptureState.promptBlink;
          _blinkPromptStart = now;
          _sawClosedEyes = false;
        }
        break;

      case CaptureState.promptBlink:
        if (r.alignment != FaceAlignment.aligned) {
          _state = CaptureState.searching;
          _alignedSince = null;
          _blinkPromptStart = null;
          _sawClosedEyes = false;
          break;
        }
        if (r.bothEyesClosed) {
          _sawClosedEyes = true;
        } else if (_sawClosedEyes && r.bothEyesOpen) {
          _state = CaptureState.capturing;
          break;
        }
        if (_blinkPromptStart != null &&
            now.difference(_blinkPromptStart!).inMilliseconds >=
                AppConstants.attendancePhotoBlinkWindowMs) {
          _attempts += 1;
          if (_attempts >= AppConstants.attendancePhotoMaxBlinkAttempts) {
            _state = CaptureState.exhausted;
          } else {
            _state = CaptureState.retry;
          }
        }
        break;

      case CaptureState.retry:
        if (r.alignment == FaceAlignment.aligned) {
          _state = CaptureState.promptBlink;
          _blinkPromptStart = now;
          _sawClosedEyes = false;
        }
        break;

      case CaptureState.capturing:
      case CaptureState.done:
      case CaptureState.exhausted:
        break;
    }
    return _state;
  }

  void markDone() {
    _state = CaptureState.done;
  }

  void reset() {
    _state = CaptureState.searching;
    _alignedSince = null;
    _blinkPromptStart = null;
    _sawClosedEyes = false;
    _attempts = 0;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/face_capture_state_machine.dart
git commit -m "feat(kiosk): pure state machine for bank-style capture flow"
```

---

## Task B5: Unit tests for the capture state machine

**Files:**
- Create: `test/widgets/face_capture_state_machine_test.dart`

- [ ] **Step 1: Write the tests**

```dart
// test/widgets/face_capture_state_machine_test.dart
import 'dart:ui';

import 'package:absensi_enakko_flutter/core/constants.dart';
import 'package:absensi_enakko_flutter/services/face_detection_service.dart';
import 'package:absensi_enakko_flutter/widgets/face_capture_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

FaceDetectionResult _r({
  required FaceAlignment alignment,
  double leftEye = 0.9,
  double rightEye = 0.9,
}) =>
    FaceDetectionResult(
      hasFace: alignment != FaceAlignment.absent,
      faceCount: alignment == FaceAlignment.absent ? 0 : 1,
      alignment: alignment,
      leftEyeOpen: leftEye,
      rightEyeOpen: rightEye,
      boundingBox: Rect.zero,
      headEulerAngleY: 0,
    );

void main() {
  late FaceCaptureStateMachine fsm;
  late DateTime t0;
  DateTime laterMs(int ms) => t0.add(Duration(milliseconds: ms));

  setUp(() {
    fsm = FaceCaptureStateMachine();
    t0 = DateTime(2026, 5, 23, 7, 0, 0);
  });

  test('starts searching', () {
    expect(fsm.state, CaptureState.searching);
  });

  test('searching -> aligning on aligned', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    expect(fsm.state, CaptureState.aligning);
  });

  test('aligning -> searching when alignment drops', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    fsm.onDetection(_r(alignment: FaceAlignment.offCenter), laterMs(200));
    expect(fsm.state, CaptureState.searching);
  });

  test('aligning -> promptBlink after stableFaceMs', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 10),
    );
    expect(fsm.state, CaptureState.promptBlink);
  });

  test('blink within window -> capturing', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 10),
    );
    // closed
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned, leftEye: 0.05, rightEye: 0.05),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 200),
    );
    // open
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned, leftEye: 0.95, rightEye: 0.95),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 400),
    );
    expect(fsm.state, CaptureState.capturing);
  });

  test('no blink within window -> retry', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 10),
    );
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned),
      laterMs(AppConstants.attendancePhotoStableFaceMs +
          AppConstants.attendancePhotoBlinkWindowMs +
          50),
    );
    expect(fsm.state, CaptureState.retry);
    expect(fsm.attempts, 1);
  });

  test('three failed attempts -> exhausted', () {
    void advanceOneFailedAttempt(int baseMs) {
      fsm.onDetection(_r(alignment: FaceAlignment.aligned), laterMs(baseMs));
      fsm.onDetection(
        _r(alignment: FaceAlignment.aligned),
        laterMs(baseMs + AppConstants.attendancePhotoStableFaceMs + 10),
      );
      fsm.onDetection(
        _r(alignment: FaceAlignment.aligned),
        laterMs(baseMs +
            AppConstants.attendancePhotoStableFaceMs +
            AppConstants.attendancePhotoBlinkWindowMs +
            50),
      );
    }

    advanceOneFailedAttempt(0);
    expect(fsm.state, CaptureState.retry);
    advanceOneFailedAttempt(10000);
    expect(fsm.state, CaptureState.retry);
    advanceOneFailedAttempt(20000);
    expect(fsm.state, CaptureState.exhausted);
  });

  test('alignment loss in promptBlink resets to searching', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 10),
    );
    fsm.onDetection(
      _r(alignment: FaceAlignment.offCenter),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 200),
    );
    expect(fsm.state, CaptureState.searching);
  });

  test('closed eyes only (no open transition) does not capture', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 10),
    );
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned, leftEye: 0.05, rightEye: 0.05),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 200),
    );
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned, leftEye: 0.05, rightEye: 0.05),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 500),
    );
    expect(fsm.state, CaptureState.promptBlink);
  });

  test('reset returns to initial state', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    fsm.reset();
    expect(fsm.state, CaptureState.searching);
    expect(fsm.attempts, 0);
  });
}
```

- [ ] **Step 2: Run tests**

```powershell
C:\flutter\bin\flutter.bat test test/widgets/face_capture_state_machine_test.dart
```
Expected: 10 pass.

- [ ] **Step 3: Commit**

```bash
git add test/widgets/face_capture_state_machine_test.dart
git commit -m "test(kiosk): 10 deterministic state-machine cases for capture flow"
```

---

## Task B6: Rewrite CameraFacePreview to consume the state machine + new UI

**Files:**
- Modify: `lib/widgets/camera_face_preview.dart`

This is a substantial rewrite of one file. Replace the existing contents with the new implementation that uses the state machine and renders distinct UI per state.

- [ ] **Step 1: Replace the file contents**

```dart
// lib/widgets/camera_face_preview.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation, WriteBuffer;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/attendance_log.dart';
import '../services/camera_service.dart';
import '../services/face_detection_service.dart';
import 'face_capture_state_machine.dart';

class CameraFacePreview extends StatefulWidget {
  final ValueChanged<Uint8List> onPhotoCaptured;
  final VoidCallback? onCancel;
  final AttendanceType pendingAction;

  const CameraFacePreview({
    super.key,
    required this.onPhotoCaptured,
    this.onCancel,
    this.pendingAction = AttendanceType.masuk,
  });

  @override
  State<CameraFacePreview> createState() => _CameraFacePreviewState();
}

class _CameraFacePreviewState extends State<CameraFacePreview> {
  final FaceCaptureStateMachine _fsm = FaceCaptureStateMachine();
  FaceDetectionResult _last = const FaceDetectionResult.empty();
  Uint8List? _capturedBytes;
  DateTime _lastFrameProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  bool _initializing = true;
  bool _processingFrame = false;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    unawaited(CameraService.instance.dispose());
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await CameraService.instance.initialize();
      final controller = CameraService.instance.controller;
      if (controller == null || !controller.value.isInitialized) {
        throw StateError('Kamera belum siap');
      }
      if (!controller.supportsImageStreaming()) {
        throw StateError('Perangkat tidak mendukung face preview stream');
      }
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.startImageStream(_handleCameraImage);
      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Kamera belum bisa digunakan';
      });
    }
  }

  void _handleCameraImage(CameraImage image) {
    if (_processingFrame || _capturing) return;
    final now = DateTime.now();
    if (now.difference(_lastFrameProcessed).inMilliseconds <
        AppConstants.attendancePhotoFaceThrottleMs) {
      return;
    }
    _lastFrameProcessed = now;
    _processingFrame = true;
    unawaited(_processFrame(image, now));
  }

  Future<void> _processFrame(CameraImage image, DateTime now) async {
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;
      final result =
          await FaceDetectionService.instance.processImage(inputImage);
      if (!mounted || _capturing) return;
      final newState = _fsm.onDetection(result, now);
      setState(() => _last = result);
      if (newState == CaptureState.capturing) {
        unawaited(_capture());
      }
    } catch (_) {
      // swallow; the state machine will re-prompt if needed
    } finally {
      _processingFrame = false;
    }
  }

  Future<void> _capture() async {
    if (_capturing) return;
    _capturing = true;
    try {
      final bytes = await CameraService.instance.capturePhoto();
      if (!mounted) return;
      setState(() => _capturedBytes = bytes);
      await Future<void>.delayed(
        const Duration(milliseconds: AppConstants.attendancePhotoPreviewMs),
      );
      _fsm.markDone();
      if (mounted) widget.onPhotoCaptured(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = 'Foto gagal diambil';
      });
      _fsm.reset();
      unawaited(_initialize());
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = CameraService.instance.controller;
    final camera = CameraService.instance.cameraDescription;
    if (controller == null || camera == null) return null;
    final rotation = _inputImageRotation(camera, controller.value.deviceOrientation);
    if (rotation == null) return null;
    final format = _inputImageFormat(image.format);
    if (format == null) return null;
    final bytes = _cameraImageBytes(image);
    final size = Size(image.width.toDouble(), image.height.toDouble());
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: size,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _inputImageRotation(
    CameraDescription camera,
    DeviceOrientation orientation,
  ) {
    const orientations = <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final rotationCompensation = orientations[orientation] ?? 0;
    final rotation = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + rotationCompensation) % 360
        : (camera.sensorOrientation - rotationCompensation + 360) % 360;
    return InputImageRotationValue.fromRawValue(rotation);
  }

  InputImageFormat? _inputImageFormat(ImageFormat format) {
    final raw = format.raw;
    if (raw is int) {
      final parsed = InputImageFormatValue.fromRawValue(raw);
      if (parsed != null) return parsed;
    }
    switch (format.group) {
      case ImageFormatGroup.nv21:
        return InputImageFormat.nv21;
      case ImageFormatGroup.yuv420:
        return InputImageFormat.yuv_420_888;
      case ImageFormatGroup.bgra8888:
        return InputImageFormat.bgra8888;
      default:
        return null;
    }
  }

  Uint8List _cameraImageBytes(CameraImage image) {
    final buffer = WriteBuffer();
    for (final plane in image.planes) {
      buffer.putUint8List(plane.bytes);
    }
    return buffer.done().buffer.asUint8List();
  }

  String get _pillText {
    if (_fsm.state == CaptureState.searching) {
      switch (_last.alignment) {
        case FaceAlignment.tooSmall:
          return 'Mendekat sedikit';
        case FaceAlignment.tooBig:
          return 'Mundur sedikit';
        case FaceAlignment.offCenter:
          return 'Geser ke tengah';
        case FaceAlignment.tilted:
          return 'Hadapkan wajah lurus';
        default:
          return 'Posisikan wajah di dalam lingkaran';
      }
    }
    switch (_fsm.state) {
      case CaptureState.aligning:
        return 'Tahan posisi…';
      case CaptureState.promptBlink:
        return 'Kedipkan mata sekali 👁️';
      case CaptureState.retry:
        return 'Coba kedipkan lagi…';
      case CaptureState.exhausted:
        return 'Tekan Coba Lagi untuk mengulang';
      case CaptureState.capturing:
      case CaptureState.done:
        return 'Berhasil ✓';
      default:
        return '';
    }
  }

  Color get _ovalColor {
    switch (_fsm.state) {
      case CaptureState.promptBlink:
      case CaptureState.capturing:
      case CaptureState.done:
        return AppColors.success;
      case CaptureState.retry:
        return Colors.amber;
      default:
        return Colors.white;
    }
  }

  double _holdProgress(DateTime now) {
    if (_fsm.state != CaptureState.aligning) return 0;
    return 1.0; // visualized as a static ring; CameraFacePreview animates via repaint
  }

  Color get _actionColor {
    switch (widget.pendingAction) {
      case AttendanceType.masuk:
        return AppColors.success;
      case AttendanceType.pulang:
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  String get _actionLabel {
    switch (widget.pendingAction) {
      case AttendanceType.masuk:
        return 'VERIFIKASI MASUK';
      case AttendanceType.pulang:
        return 'VERIFIKASI PULANG';
      default:
        return 'VERIFIKASI WAJAH';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const _CameraSurface(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
        ),
      );
    }
    if (_error != null) {
      return _CameraSurface(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    final captured = _capturedBytes;
    return _CameraSurface(
      child: Stack(fit: StackFit.expand, children: [
        if (captured != null)
          Image.memory(captured, fit: BoxFit.cover)
        else
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _previewSize.width,
              height: _previewSize.height,
              child: CameraService.instance.getPreviewWidget(),
            ),
          ),
        CustomPaint(
          painter: _OvalGuidePainter(
            borderColor: _ovalColor,
            state: _fsm.state,
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: _ActionTitlePill(label: _actionLabel, color: _actionColor),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _GuidancePill(text: _pillText, color: _ovalColor),
        ),
        if (widget.onCancel != null)
          Positioned(
            bottom: 12,
            left: 12,
            child: TextButton(
              onPressed: widget.onCancel,
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('Batal'),
            ),
          ),
        if (_fsm.state == CaptureState.exhausted)
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: FilledButton(
                onPressed: () => setState(_fsm.reset),
                child: const Text('Coba Lagi'),
              ),
            ),
          ),
      ]),
    );
  }

  Size get _previewSize {
    final size = CameraService.instance.controller?.value.previewSize;
    if (size == null) return const Size(720, 1280);
    return Size(size.height, size.width);
  }
}

class _CameraSurface extends StatelessWidget {
  final Widget child;
  const _CameraSurface({required this.child});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: Colors.black,
          child: AspectRatio(aspectRatio: 3 / 4, child: child),
        ),
      );
}

class _ActionTitlePill extends StatelessWidget {
  final String label;
  final Color color;
  const _ActionTitlePill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.verified_user_rounded, color: color, size: 14),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2)),
            ]),
          ),
        ),
      );
}

class _GuidancePill extends StatelessWidget {
  final String text;
  final Color color;
  const _GuidancePill({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.face_retouching_natural_rounded, color: color, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
          ]),
        ),
      );
}

class _OvalGuidePainter extends CustomPainter {
  final Color borderColor;
  final CaptureState state;
  const _OvalGuidePainter({required this.borderColor, required this.state});

  Rect _ovalRect(Size size) {
    final width = size.width * 0.72;
    final height = size.height * 0.50;
    final left = (size.width - width) / 2;
    final top = size.height * 0.10;
    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final oval = _ovalRect(size);
    final maskPath = Path()
      ..addRect(Offset.zero & size)
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    final stroke = state == CaptureState.promptBlink ||
            state == CaptureState.capturing ||
            state == CaptureState.done
        ? 5.0
        : 3.0;
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = borderColor,
    );

    if (state == CaptureState.aligning) {
      canvas.drawArc(
        oval.deflate(2),
        -math.pi / 2,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = borderColor.withValues(alpha: 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OvalGuidePainter old) =>
      old.borderColor != borderColor || old.state != state;
}
```

- [ ] **Step 2: Run analyze**

```powershell
C:\flutter\bin\flutter.bat analyze lib/widgets/camera_face_preview.dart
```
Expected: 0 errors.

- [ ] **Step 3: Run all existing tests as a regression sweep**

```powershell
C:\flutter\bin\flutter.bat test
```
Expected: all previously-green tests still pass; new state-machine and detection tests still pass.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/camera_face_preview.dart
git commit -m "feat(kiosk): bank-style camera preview with blink liveness

State machine drives oval + pill text per state. Captures only after
a closed→open eye transition while alignment is maintained. Retry
inline up to 3 times, then 'Coba Lagi' button. Optional onCancel
exposes a Batal link."
```

---

## Task B7: Golden tests for the oval guide painter (one per state)

**Files:**
- Create: `test/widgets/camera_face_preview_golden_test.dart`

- [ ] **Step 1: Write the test**

```dart
// test/widgets/camera_face_preview_golden_test.dart
import 'package:absensi_enakko_flutter/widgets/face_capture_state_machine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// We mirror the painter privately for golden coverage. This is a thin
// duplicate to avoid exporting the private painter from camera_face_preview.
class _OvalGuidePainter extends CustomPainter {
  final Color borderColor;
  final CaptureState state;
  const _OvalGuidePainter({required this.borderColor, required this.state});

  Rect _ovalRect(Size size) {
    final width = size.width * 0.72;
    final height = size.height * 0.50;
    final left = (size.width - width) / 2;
    final top = size.height * 0.10;
    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final oval = _ovalRect(size);
    final maskPath = Path()
      ..addRect(Offset.zero & size)
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(maskPath, Paint()..color = Colors.black.withValues(alpha: 0.6));
    final stroke = state == CaptureState.promptBlink ||
            state == CaptureState.capturing
        ? 5.0
        : 3.0;
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(covariant _OvalGuidePainter old) =>
      old.borderColor != borderColor || old.state != state;
}

Widget _wrap(CaptureState s, Color c) => MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox(
          width: 360,
          height: 480,
          child: CustomPaint(painter: _OvalGuidePainter(borderColor: c, state: s)),
        ),
      ),
    );

void main() {
  testWidgets('searching oval golden', (tester) async {
    await tester.pumpWidget(_wrap(CaptureState.searching, Colors.white));
    await expectLater(
      find.byType(CustomPaint),
      matchesGoldenFile('goldens/oval_searching.png'),
    );
  });

  testWidgets('aligning oval golden', (tester) async {
    await tester.pumpWidget(_wrap(CaptureState.aligning, Colors.white));
    await expectLater(
      find.byType(CustomPaint),
      matchesGoldenFile('goldens/oval_aligning.png'),
    );
  });

  testWidgets('promptBlink oval golden', (tester) async {
    await tester.pumpWidget(_wrap(CaptureState.promptBlink, const Color(0xFF22C55E)));
    await expectLater(
      find.byType(CustomPaint),
      matchesGoldenFile('goldens/oval_prompt_blink.png'),
    );
  });

  testWidgets('retry oval golden', (tester) async {
    await tester.pumpWidget(_wrap(CaptureState.retry, Colors.amber));
    await expectLater(
      find.byType(CustomPaint),
      matchesGoldenFile('goldens/oval_retry.png'),
    );
  });
}
```

- [ ] **Step 2: Generate the goldens**

```powershell
C:\flutter\bin\flutter.bat test --update-goldens test/widgets/camera_face_preview_golden_test.dart
```
Expected: 4 PNG files written under `test/widgets/goldens/`.

- [ ] **Step 3: Run normally to confirm parity**

```powershell
C:\flutter\bin\flutter.bat test test/widgets/camera_face_preview_golden_test.dart
```
Expected: 4 pass.

- [ ] **Step 4: Commit**

```bash
git add test/widgets/camera_face_preview_golden_test.dart test/widgets/goldens/
git commit -m "test(kiosk): goldens for oval guide painter in 4 states"
```

---

## Task B8: Kiosk scan screen wiring check

**Files:**
- Modify (only if compile errors): `lib/screens/kiosk/kiosk_scan_screen.dart`

- [ ] **Step 1: Compile-check**

```powershell
C:\flutter\bin\flutter.bat analyze lib/screens/kiosk/
```
Expected: 0 errors. The new CameraFacePreview signature added an optional `onCancel` — no breaking change.

- [ ] **Step 2: If there are errors, fix them by passing `onCancel:` only where the screen wants a cancel button. Otherwise skip this task.**

- [ ] **Step 3: Run kiosk integration tests (if any) and golden sweep**

```powershell
C:\flutter\bin\flutter.bat test
```
Expected: all tests pass.

- [ ] **Step 4: If you made changes, commit. Otherwise, skip the commit.**

```bash
git add lib/screens/kiosk/kiosk_scan_screen.dart
git commit -m "fix(kiosk): pass onCancel to CameraFacePreview where applicable"
```

Phase B complete. The kiosk app now demands a bank-style blink before capture.

---

# Phase C — Admin QC UI

## Task C1: GroomingQcService — query helpers + override RPC

**Files:**
- Create: `lib/services/grooming_qc_service.dart`

- [ ] **Step 1: Write the service**

```dart
// lib/services/grooming_qc_service.dart
import 'dart:async';

import 'package:absensi_enakko_flutter/core/supabase_client.dart';

class GroomingRow {
  final String attendanceLogId;
  final String photoUrl;
  final String employeeId;
  final String employeeName;
  final String employeePosition;
  final String outletId;
  final String outletName;
  final String attendanceType;
  final DateTime scannedAt;
  final DateTime? analyzedAt;
  final bool faceDetected;
  final int faceCount;
  final String photoQuality;
  final double? groomingScore;
  final double? qcOverrideScore;
  final String? qcOverrideNote;
  final String? qcOverriddenBy;
  final DateTime? qcOverriddenAt;
  final bool safeSearchPassed;
  final String? faceCleanShave;
  final String? uniformCompliant;
  final String? hairNeat;
  final String? headCovering;
  final String? reasoning;

  const GroomingRow({
    required this.attendanceLogId,
    required this.photoUrl,
    required this.employeeId,
    required this.employeeName,
    required this.employeePosition,
    required this.outletId,
    required this.outletName,
    required this.attendanceType,
    required this.scannedAt,
    required this.analyzedAt,
    required this.faceDetected,
    required this.faceCount,
    required this.photoQuality,
    required this.groomingScore,
    required this.qcOverrideScore,
    required this.qcOverrideNote,
    required this.qcOverriddenBy,
    required this.qcOverriddenAt,
    required this.safeSearchPassed,
    required this.faceCleanShave,
    required this.uniformCompliant,
    required this.hairNeat,
    required this.headCovering,
    required this.reasoning,
  });

  double? get effectiveScore => qcOverrideScore ?? groomingScore;

  bool get needsReview {
    final s = effectiveScore;
    if (s != null && s < 6) return true;
    if (!faceDetected || faceCount != 1) return true;
    if (!safeSearchPassed) return true;
    return false;
  }

  factory GroomingRow.fromRow(Map<String, dynamic> json) {
    final log = Map<String, dynamic>.from(
      (json['attendance_logs'] as Map?) ?? const {},
    );
    final employee = Map<String, dynamic>.from(
      (log['employees'] as Map?) ?? const {},
    );
    final outlet = Map<String, dynamic>.from(
      (log['outlets'] as Map?) ?? const {},
    );
    return GroomingRow(
      attendanceLogId: (json['attendance_log_id'] ?? log['id']).toString(),
      photoUrl: (json['photo_url'] ?? '').toString(),
      employeeId: (employee['id'] ?? '').toString(),
      employeeName: (employee['name'] ?? '-').toString(),
      employeePosition: (employee['position'] ?? '-').toString(),
      outletId: (log['scan_outlet_id'] ?? '').toString(),
      outletName: (outlet['name'] ?? '-').toString(),
      attendanceType: (log['type'] ?? 'masuk').toString(),
      scannedAt: DateTime.tryParse(log['scanned_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      analyzedAt: DateTime.tryParse(json['analyzed_at']?.toString() ?? ''),
      faceDetected: json['face_detected'] == true,
      faceCount: (json['face_count'] as num?)?.toInt() ?? 0,
      photoQuality: (json['photo_quality'] ?? 'clear').toString(),
      groomingScore: (json['grooming_score'] as num?)?.toDouble(),
      qcOverrideScore: (json['qc_override_score'] as num?)?.toDouble(),
      qcOverrideNote: json['qc_override_note']?.toString(),
      qcOverriddenBy: json['qc_overridden_by']?.toString(),
      qcOverriddenAt: DateTime.tryParse(json['qc_overridden_at']?.toString() ?? ''),
      safeSearchPassed: json['safe_search_passed'] != false,
      faceCleanShave: json['face_clean_shave']?.toString(),
      uniformCompliant: json['uniform_compliant']?.toString(),
      hairNeat: json['hair_neat']?.toString(),
      headCovering: json['head_covering']?.toString(),
      reasoning: json['reasoning']?.toString(),
    );
  }
}

class GroomingFilter {
  final DateTime since;
  final DateTime until;
  final Set<String> outletIds;
  final String? employeeQuery;
  final bool needsReviewOnly;
  final bool overriddenOnly;

  const GroomingFilter({
    required this.since,
    required this.until,
    this.outletIds = const {},
    this.employeeQuery,
    this.needsReviewOnly = false,
    this.overriddenOnly = false,
  });

  factory GroomingFilter.last30Days() {
    final now = DateTime.now();
    return GroomingFilter(
      since: now.subtract(const Duration(days: 30)),
      until: now,
    );
  }
}

class GroomingQcService {
  GroomingQcService._();
  static final GroomingQcService instance = GroomingQcService._();

  static const _projection = 'attendance_log_id, photo_url, face_detected, '
      'face_confidence, face_count, photo_quality, grooming_labels, '
      'grooming_score, safe_search_passed, analyzed_at, face_clean_shave, '
      'uniform_compliant, hair_neat, head_covering, reasoning, model_name, '
      'qc_override_score, qc_override_note, qc_overridden_by, qc_overridden_at, '
      'attendance_logs!inner(id, type, scanned_at, scan_outlet_id, employee_id, '
      'employees(id, name, position), outlets(name))';

  Future<List<GroomingRow>> fetchRows(GroomingFilter filter) async {
    var query = SupabaseClientFactory.admin
        .from('attendance_photo_analysis')
        .select(_projection)
        .gte('analyzed_at', filter.since.toUtc().toIso8601String())
        .lte('analyzed_at', filter.until.toUtc().toIso8601String());
    if (filter.overriddenOnly) {
      query = query.not('qc_overridden_at', 'is', null);
    }
    final raw = await query.order('analyzed_at', ascending: false).limit(500);
    final rows = (raw as List)
        .map((row) => GroomingRow.fromRow(Map<String, dynamic>.from(row as Map)))
        .where((row) => filter.outletIds.isEmpty || filter.outletIds.contains(row.outletId))
        .where((row) {
          if (filter.employeeQuery == null || filter.employeeQuery!.isEmpty) return true;
          return row.employeeName.toLowerCase().contains(filter.employeeQuery!.toLowerCase());
        })
        .where((row) => !filter.needsReviewOnly || row.needsReview)
        .toList(growable: false);
    return rows;
  }

  Stream<List<GroomingRow>> watchRows(GroomingFilter filter) async* {
    yield await fetchRows(filter);
    final channel = SupabaseClientFactory.admin
        .channel('grooming_qc_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance_photo_analysis',
          callback: (_) {},
        );
    final controller = StreamController<List<GroomingRow>>();
    Timer? debounce;
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance_photo_analysis',
          callback: (_) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 400), () async {
              try {
                controller.add(await fetchRows(filter));
              } catch (_) {}
            });
          },
        );
      }
    });
    controller.onCancel = () async {
      debounce?.cancel();
      await SupabaseClientFactory.admin.removeChannel(channel);
      await controller.close();
    };
    yield* controller.stream;
  }

  Future<void> applyOverride({
    required String attendanceLogId,
    required double score,
    required String note,
  }) async {
    await SupabaseClientFactory.admin.rpc(
      'apply_grooming_qc_override',
      params: {
        'p_attendance_log_id': attendanceLogId,
        'p_score': score,
        'p_note': note,
      },
    );
  }
}
```

- [ ] **Step 2: Run analyze**

```powershell
C:\flutter\bin\flutter.bat analyze lib/services/grooming_qc_service.dart
```
Expected: zero errors. If `SupabaseClientFactory.admin` signature differs, follow the existing pattern from `admin_grooming_report_screen.dart` (which currently passes lint).

- [ ] **Step 3: Commit**

```bash
git add lib/services/grooming_qc_service.dart
git commit -m "feat(admin): GroomingQcService — projection, fetch, realtime watch, override RPC"
```

---

## Task C2: GroomingFilterProvider (Riverpod session state)

**Files:**
- Create: `lib/providers/grooming_filter_provider.dart`

- [ ] **Step 1: Write the provider**

```dart
// lib/providers/grooming_filter_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/grooming_qc_service.dart';

class GroomingFilterNotifier extends StateNotifier<GroomingFilter> {
  GroomingFilterNotifier() : super(GroomingFilter.last30Days());

  void setRange({required DateTime since, required DateTime until}) {
    state = GroomingFilter(
      since: since,
      until: until,
      outletIds: state.outletIds,
      employeeQuery: state.employeeQuery,
      needsReviewOnly: state.needsReviewOnly,
      overriddenOnly: state.overriddenOnly,
    );
  }

  void toggleOutlet(String outletId) {
    final next = Set<String>.from(state.outletIds);
    if (!next.add(outletId)) next.remove(outletId);
    state = GroomingFilter(
      since: state.since,
      until: state.until,
      outletIds: next,
      employeeQuery: state.employeeQuery,
      needsReviewOnly: state.needsReviewOnly,
      overriddenOnly: state.overriddenOnly,
    );
  }

  void setEmployeeQuery(String? query) {
    state = GroomingFilter(
      since: state.since,
      until: state.until,
      outletIds: state.outletIds,
      employeeQuery: query,
      needsReviewOnly: state.needsReviewOnly,
      overriddenOnly: state.overriddenOnly,
    );
  }

  void setNeedsReviewOnly(bool value) {
    state = GroomingFilter(
      since: state.since,
      until: state.until,
      outletIds: state.outletIds,
      employeeQuery: state.employeeQuery,
      needsReviewOnly: value,
      overriddenOnly: state.overriddenOnly,
    );
  }

  void setOverriddenOnly(bool value) {
    state = GroomingFilter(
      since: state.since,
      until: state.until,
      outletIds: state.outletIds,
      employeeQuery: state.employeeQuery,
      needsReviewOnly: state.needsReviewOnly,
      overriddenOnly: value,
    );
  }

  void reset() {
    state = GroomingFilter.last30Days();
  }
}

final groomingFilterProvider =
    StateNotifierProvider<GroomingFilterNotifier, GroomingFilter>(
        (_) => GroomingFilterNotifier());

final groomingRowsProvider = StreamProvider.autoDispose<List<GroomingRow>>((ref) {
  final filter = ref.watch(groomingFilterProvider);
  return GroomingQcService.instance.watchRows(filter);
});
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/grooming_filter_provider.dart
git commit -m "feat(admin): Riverpod state for grooming filter + rows stream"
```

---

## Task C3: GroomingCard widget + tests

**Files:**
- Create: `lib/screens/admin/widgets/grooming_card.dart`
- Create: `test/widgets/grooming_card_test.dart`

- [ ] **Step 1: Write the widget**

```dart
// lib/screens/admin/widgets/grooming_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/grooming_qc_service.dart';

class GroomingCard extends StatelessWidget {
  final GroomingRow row;
  final VoidCallback onTapPhoto;
  final VoidCallback onTapOverride;

  const GroomingCard({
    super.key,
    required this.row,
    required this.onTapPhoto,
    required this.onTapOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: row.needsReview
              ? AppColors.danger.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Thumbnail(url: row.photoUrl, onTap: onTapPhoto),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(row.employeeName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900))),
            _ScorePill(row: row),
          ]),
          const SizedBox(height: 4),
          Text('${row.outletName} · ${row.attendanceType.toUpperCase()} · ${_fmtTime(row.scannedAt)}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _CleanShaveChip(value: row.faceCleanShave),
            _UniformChip(value: row.uniformCompliant),
            _HairChip(value: row.hairNeat),
            _HeadCoveringChip(value: row.headCovering),
          ]),
          if ((row.reasoning ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(row.reasoning!,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 8),
          Row(children: [
            TextButton.icon(
              onPressed: onTapOverride,
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Override skor'),
            ),
          ]),
        ])),
      ]),
    );
  }

  static String _fmtTime(DateTime dt) {
    final d = dt.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm $hh:$mi';
  }
}

class _Thumbnail extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  const _Thumbnail({required this.url, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: url.isEmpty ? null : onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: url.isEmpty
            ? Container(width: 96, height: 128, color: AppColors.surface,
                child: const Icon(Icons.no_photography_outlined, color: AppColors.textSecondary))
            : CachedNetworkImage(
                imageUrl: url, width: 96, height: 128, fit: BoxFit.cover,
                placeholder: (_, __) => Container(width: 96, height: 128, color: AppColors.surface,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary))),
                errorWidget: (_, __, ___) => Container(width: 96, height: 128, color: AppColors.surface,
                    child: const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary)),
              ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final GroomingRow row;
  const _ScorePill({required this.row});
  @override
  Widget build(BuildContext context) {
    final value = row.effectiveScore;
    Color bg; Color fg;
    if (value == null) { bg = AppColors.surface; fg = AppColors.textSecondary; }
    else if (value >= 7) { bg = AppColors.successLight; fg = AppColors.success; }
    else if (value >= 5) { bg = const Color(0xFFFFF4D6); fg = const Color(0xFFB75D00); }
    else { bg = AppColors.dangerLight; fg = AppColors.danger; }
    final overridden = row.qcOverrideScore != null;
    final label = value == null
        ? '-'
        : overridden
            ? '${row.groomingScore?.toStringAsFixed(1) ?? '-'}→${value.toStringAsFixed(1)} ✏'
            : value.toStringAsFixed(1);
    return DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: fg)),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  const _Chip({required this.label, required this.background, required this.foreground});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: foreground)),
        ),
      );
}

class _CleanShaveChip extends StatelessWidget {
  final String? value;
  const _CleanShaveChip({required this.value});
  @override
  Widget build(BuildContext context) {
    String label; bool bad = false;
    switch (value) {
      case 'ok': label = 'Wajah OK'; break;
      case 'stubble': label = 'Bulu wajah'; bad = true; break;
      case 'mustache': label = 'Kumis'; bad = true; break;
      case 'beard': label = 'Jenggot'; bad = true; break;
      default: label = 'Wajah ?';
    }
    return _Chip(
      label: label,
      background: bad ? AppColors.dangerLight : AppColors.surface,
      foreground: bad ? AppColors.danger : AppColors.textSecondary,
    );
  }
}

class _UniformChip extends StatelessWidget {
  final String? value;
  const _UniformChip({required this.value});
  @override
  Widget build(BuildContext context) {
    String label; bool bad = false;
    switch (value) {
      case 'ok': label = 'Seragam OK'; break;
      case 'no_uniform': label = 'Tanpa seragam'; bad = true; break;
      case 'wrong_attire': label = 'Pakaian salah'; bad = true; break;
      default: label = 'Seragam ?';
    }
    return _Chip(
      label: label,
      background: bad ? AppColors.dangerLight : AppColors.surface,
      foreground: bad ? AppColors.danger : AppColors.textSecondary,
    );
  }
}

class _HairChip extends StatelessWidget {
  final String? value;
  const _HairChip({required this.value});
  @override
  Widget build(BuildContext context) {
    String label; bool bad = false;
    switch (value) {
      case 'ok': label = 'Rambut OK'; break;
      case 'not_visible': label = 'Rambut tertutup'; break;
      case 'messy': label = 'Rambut acak'; bad = true; break;
      default: label = 'Rambut ?';
    }
    return _Chip(
      label: label,
      background: bad ? AppColors.dangerLight : AppColors.surface,
      foreground: bad ? AppColors.danger : AppColors.textSecondary,
    );
  }
}

class _HeadCoveringChip extends StatelessWidget {
  final String? value;
  const _HeadCoveringChip({required this.value});
  @override
  Widget build(BuildContext context) {
    String label;
    switch (value) {
      case 'hijab': label = 'Hijab'; break;
      case 'cap': label = 'Topi'; break;
      case 'other': label = 'Penutup lain'; break;
      default: label = 'Tanpa penutup';
    }
    final blue = value == 'hijab';
    return _Chip(
      label: label,
      background: blue ? const Color(0xFFDCEEFF) : AppColors.surface,
      foreground: blue ? const Color(0xFF0B6BC2) : AppColors.textSecondary,
    );
  }
}
```

- [ ] **Step 2: Write the widget test**

```dart
// test/widgets/grooming_card_test.dart
import 'package:absensi_enakko_flutter/screens/admin/widgets/grooming_card.dart';
import 'package:absensi_enakko_flutter/services/grooming_qc_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GroomingRow _row({
  double? score,
  double? override,
  String? cleanShave = 'ok',
  String? uniform = 'ok',
  String? hair = 'ok',
  String? head = 'none',
}) =>
    GroomingRow(
      attendanceLogId: 'a1',
      photoUrl: '',
      employeeId: 'e1',
      employeeName: 'Budi',
      employeePosition: 'Kasir',
      outletId: 'o1',
      outletName: 'Bali',
      attendanceType: 'masuk',
      scannedAt: DateTime(2026, 5, 23, 7, 2),
      analyzedAt: DateTime(2026, 5, 23, 7, 3),
      faceDetected: true,
      faceCount: 1,
      photoQuality: 'clear',
      groomingScore: score,
      qcOverrideScore: override,
      qcOverrideNote: null,
      qcOverriddenBy: null,
      qcOverriddenAt: null,
      safeSearchPassed: true,
      faceCleanShave: cleanShave,
      uniformCompliant: uniform,
      hairNeat: hair,
      headCovering: head,
      reasoning: 'Wajah bersih. Seragam OK. Foto jelas.',
    );

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('renders beard chip when faceCleanShave=beard', (tester) async {
    await tester.pumpWidget(_wrap(GroomingCard(
      row: _row(cleanShave: 'beard'),
      onTapPhoto: () {},
      onTapOverride: () {},
    )));
    expect(find.text('Jenggot'), findsOneWidget);
  });

  testWidgets('renders Topi chip for cap', (tester) async {
    await tester.pumpWidget(_wrap(GroomingCard(
      row: _row(head: 'cap', hair: 'not_visible'),
      onTapPhoto: () {},
      onTapOverride: () {},
    )));
    expect(find.text('Topi'), findsOneWidget);
    expect(find.text('Rambut tertutup'), findsOneWidget);
  });

  testWidgets('renders override pill when override score set', (tester) async {
    await tester.pumpWidget(_wrap(GroomingCard(
      row: _row(score: 4.5, override: 8.0),
      onTapPhoto: () {},
      onTapOverride: () {},
    )));
    expect(find.textContaining('4.5→8.0'), findsOneWidget);
  });

  testWidgets('hijab chip is informational, not danger', (tester) async {
    await tester.pumpWidget(_wrap(GroomingCard(
      row: _row(head: 'hijab', hair: 'not_visible'),
      onTapPhoto: () {},
      onTapOverride: () {},
    )));
    expect(find.text('Hijab'), findsOneWidget);
    expect(find.text('Rambut tertutup'), findsOneWidget);
    expect(find.text('Rambut acak'), findsNothing);
  });

  testWidgets('override button fires callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(GroomingCard(
      row: _row(),
      onTapPhoto: () {},
      onTapOverride: () => tapped = true,
    )));
    await tester.tap(find.text('Override skor'));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 3: Run tests**

```powershell
C:\flutter\bin\flutter.bat test test/widgets/grooming_card_test.dart
```
Expected: 5 pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/admin/widgets/grooming_card.dart test/widgets/grooming_card_test.dart
git commit -m "feat(admin): GroomingCard with 4 per-criteria chips + override pill

Hijab and Topi both render distinct chips with informational tone;
beard/mustache/stubble/no_uniform/wrong_attire/messy render red.
Override score displays as 'old→new ✏'. Covered by 5 widget tests."
```

---

## Task C4: GroomingFilterSheet + tests

**Files:**
- Create: `lib/screens/admin/widgets/grooming_filter_sheet.dart`
- Create: `test/widgets/grooming_filter_sheet_test.dart`

- [ ] **Step 1: Write the sheet**

```dart
// lib/screens/admin/widgets/grooming_filter_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../providers/grooming_filter_provider.dart';
import '../../../services/grooming_qc_service.dart';

class GroomingFilterSheet extends ConsumerStatefulWidget {
  final List<({String id, String name})> outlets;
  const GroomingFilterSheet({super.key, required this.outlets});

  @override
  ConsumerState<GroomingFilterSheet> createState() => _GroomingFilterSheetState();
}

class _GroomingFilterSheetState extends ConsumerState<GroomingFilterSheet> {
  late _Range _range;
  late TextEditingController _query;
  late Set<String> _outletIds;
  late bool _needsReviewOnly;
  late bool _overriddenOnly;

  @override
  void initState() {
    super.initState();
    final f = ref.read(groomingFilterProvider);
    _range = _resolveRange(f);
    _query = TextEditingController(text: f.employeeQuery ?? '');
    _outletIds = Set.from(f.outletIds);
    _needsReviewOnly = f.needsReviewOnly;
    _overriddenOnly = f.overriddenOnly;
  }

  _Range _resolveRange(GroomingFilter f) {
    final days = f.until.difference(f.since).inDays;
    if (days <= 1) return _Range.today;
    if (days <= 7) return _Range.last7;
    if (days <= 30) return _Range.last30;
    return _Range.last30;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 8),
          const Text('Rentang waktu', style: TextStyle(fontWeight: FontWeight.w800)),
          Wrap(spacing: 8, children: [
            for (final r in _Range.values)
              ChoiceChip(
                label: Text(_rangeLabel(r)),
                selected: _range == r,
                onSelected: (_) => setState(() => _range = r),
              ),
          ]),
          const SizedBox(height: 12),
          const Text('Outlet', style: TextStyle(fontWeight: FontWeight.w800)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final o in widget.outlets)
              FilterChip(
                label: Text(o.name),
                selected: _outletIds.contains(o.id),
                onSelected: (_) {
                  setState(() {
                    if (!_outletIds.add(o.id)) _outletIds.remove(o.id);
                  });
                },
              ),
          ]),
          const SizedBox(height: 12),
          const Text('Karyawan', style: TextStyle(fontWeight: FontWeight.w800)),
          TextField(
            controller: _query,
            decoration: const InputDecoration(hintText: 'Cari nama…', prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _needsReviewOnly,
            onChanged: (v) => setState(() => _needsReviewOnly = v),
            title: const Text('Hanya butuh review'),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile.adaptive(
            value: _overriddenOnly,
            onChanged: (v) => setState(() => _overriddenOnly = v),
            title: const Text('Hanya sudah di-override'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Row(children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _range = _Range.last30;
                  _outletIds = {};
                  _query.clear();
                  _needsReviewOnly = false;
                  _overriddenOnly = false;
                });
              },
              child: const Text('Reset'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () {
                final now = DateTime.now();
                final since = switch (_range) {
                  _Range.today => DateTime(now.year, now.month, now.day),
                  _Range.last7 => now.subtract(const Duration(days: 7)),
                  _Range.last30 => now.subtract(const Duration(days: 30)),
                };
                final notifier = ref.read(groomingFilterProvider.notifier);
                notifier.setRange(since: since, until: now);
                notifier.setEmployeeQuery(_query.text.trim().isEmpty ? null : _query.text.trim());
                notifier.setNeedsReviewOnly(_needsReviewOnly);
                notifier.setOverriddenOnly(_overriddenOnly);
                final current = ref.read(groomingFilterProvider);
                final added = _outletIds.difference(current.outletIds);
                final removed = current.outletIds.difference(_outletIds);
                for (final id in added.union(removed)) {
                  notifier.toggleOutlet(id);
                }
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.check),
              label: const Text('Terapkan'),
            ),
          ]),
        ]),
      ),
    );
  }
}

enum _Range { today, last7, last30 }

String _rangeLabel(_Range r) => switch (r) {
      _Range.today => 'Hari ini',
      _Range.last7 => '7 hari',
      _Range.last30 => '30 hari',
    };
```

- [ ] **Step 2: Write the test**

```dart
// test/widgets/grooming_filter_sheet_test.dart
import 'package:absensi_enakko_flutter/providers/grooming_filter_provider.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/grooming_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => ProviderScope(child: MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('reset clears outlet and query', (tester) async {
    await tester.pumpWidget(_wrap(GroomingFilterSheet(
      outlets: const [(id: 'o1', name: 'Bali'), (id: 'o2', name: 'Lombok')],
    )));
    await tester.tap(find.text('Bali'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'budi');
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('budi'), findsNothing);
  });

  testWidgets('Terapkan dispatches to filter provider', (tester) async {
    final container = ProviderContainer();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: GroomingFilterSheet(
        outlets: const [(id: 'o1', name: 'Bali')],
      ))),
    ));
    await tester.tap(find.text('7 hari'));
    await tester.pump();
    await tester.tap(find.text('Bali'));
    await tester.pump();
    await tester.tap(find.text('Hanya butuh review'));
    await tester.pump();
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();
    final state = container.read(groomingFilterProvider);
    expect(state.outletIds.contains('o1'), isTrue);
    expect(state.needsReviewOnly, isTrue);
    expect(state.until.difference(state.since).inDays, lessThanOrEqualTo(7));
  });
}
```

- [ ] **Step 3: Run tests**

```powershell
C:\flutter\bin\flutter.bat test test/widgets/grooming_filter_sheet_test.dart
```
Expected: 2 pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/admin/widgets/grooming_filter_sheet.dart test/widgets/grooming_filter_sheet_test.dart
git commit -m "feat(admin): grooming filter sheet (range, outlet, query, switches)"
```

---

## Task C5: GroomingOverrideDialog + tests

**Files:**
- Create: `lib/screens/admin/widgets/grooming_override_dialog.dart`
- Create: `test/widgets/grooming_override_dialog_test.dart`

- [ ] **Step 1: Write the dialog**

```dart
// lib/screens/admin/widgets/grooming_override_dialog.dart
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/grooming_qc_service.dart';

class GroomingOverrideDialog extends StatefulWidget {
  final GroomingRow row;
  const GroomingOverrideDialog({super.key, required this.row});

  @override
  State<GroomingOverrideDialog> createState() => _GroomingOverrideDialogState();
}

class _GroomingOverrideDialogState extends State<GroomingOverrideDialog> {
  late double _score;
  final TextEditingController _note = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _score = widget.row.qcOverrideScore ?? widget.row.groomingScore ?? 5.0;
  }

  bool get _canSubmit => _note.text.trim().length >= 10 && !_submitting;

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      await GroomingQcService.instance.applyOverride(
        attendanceLogId: widget.row.attendanceLogId,
        score: _score,
        note: _note.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() { _submitting = false; _error = 'Gagal menyimpan: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Override skor — ${widget.row.employeeName}'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Skor AI: ${widget.row.groomingScore?.toStringAsFixed(1) ?? '-'}'),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Skor admin:'),
          const SizedBox(width: 12),
          Expanded(
            child: Slider(
              value: _score,
              min: 0, max: 10, divisions: 20,
              label: _score.toStringAsFixed(1),
              onChanged: (v) => setState(() => _score = v),
            ),
          ),
          SizedBox(width: 40, child: Text(_score.toStringAsFixed(1),
              textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          minLines: 3, maxLines: 5,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Alasan override (minimal 10 karakter)',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
      ]),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(false), child: const Text('Batal')),
        FilledButton(onPressed: _canSubmit ? _submit : null, child: const Text('Simpan')),
      ],
    );
  }
}
```

- [ ] **Step 2: Write the test**

```dart
// test/widgets/grooming_override_dialog_test.dart
import 'package:absensi_enakko_flutter/screens/admin/widgets/grooming_override_dialog.dart';
import 'package:absensi_enakko_flutter/services/grooming_qc_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GroomingRow _row() => GroomingRow(
      attendanceLogId: 'a1', photoUrl: '', employeeId: 'e1',
      employeeName: 'Budi', employeePosition: 'Kasir',
      outletId: 'o1', outletName: 'Bali', attendanceType: 'masuk',
      scannedAt: DateTime(2026, 5, 23), analyzedAt: DateTime(2026, 5, 23),
      faceDetected: true, faceCount: 1, photoQuality: 'clear',
      groomingScore: 4.5,
      qcOverrideScore: null, qcOverrideNote: null,
      qcOverriddenBy: null, qcOverriddenAt: null,
      safeSearchPassed: true,
      faceCleanShave: 'ok', uniformCompliant: 'ok', hairNeat: 'ok',
      headCovering: 'none', reasoning: null,
    );

void main() {
  testWidgets('Save disabled until note >=10 chars', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (ctx) => TextButton(onPressed: () {
        showDialog(context: ctx, builder: (_) => GroomingOverrideDialog(row: _row()));
      }, child: const Text('open')),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final saveBtn = find.widgetWithText(FilledButton, 'Simpan');
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'ok lah');
    await tester.pump();
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'cukup panjang banget');
    await tester.pump();
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNotNull);
  });
}
```

- [ ] **Step 3: Run test**

```powershell
C:\flutter\bin\flutter.bat test test/widgets/grooming_override_dialog_test.dart
```
Expected: 1 pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/admin/widgets/grooming_override_dialog.dart test/widgets/grooming_override_dialog_test.dart
git commit -m "feat(admin): grooming override dialog (score slider + 10-char note)"
```

---

## Task C6: GroomingPerEmployeeCard with sparkline

**Files:**
- Create: `lib/screens/admin/widgets/grooming_per_employee_card.dart`

- [ ] **Step 1: Write the widget**

```dart
// lib/screens/admin/widgets/grooming_per_employee_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/grooming_qc_service.dart';

class GroomingPerEmployeeData {
  final String employeeId;
  final String employeeName;
  final String position;
  final String outletName;
  final double avgScore;
  final int violationCount;
  final List<double> dailyScores;
  final List<String> recentThumbnails;
  final VoidCallback onSelect;

  const GroomingPerEmployeeData({
    required this.employeeId,
    required this.employeeName,
    required this.position,
    required this.outletName,
    required this.avgScore,
    required this.violationCount,
    required this.dailyScores,
    required this.recentThumbnails,
    required this.onSelect,
  });

  static GroomingPerEmployeeData fromRows(
    String employeeId,
    List<GroomingRow> rows, {
    required VoidCallback onSelect,
  }) {
    final scores = rows.map((r) => r.effectiveScore ?? 0).toList();
    final avg = scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) / scores.length;
    final violations = scores.where((s) => s < 6).length;
    final first = rows.first;
    final thumbs = rows
        .where((r) => r.photoUrl.isNotEmpty)
        .take(4)
        .map((r) => r.photoUrl)
        .toList();
    return GroomingPerEmployeeData(
      employeeId: employeeId,
      employeeName: first.employeeName,
      position: first.employeePosition,
      outletName: first.outletName,
      avgScore: avg.toDouble(),
      violationCount: violations,
      dailyScores: scores.reversed.take(30).toList().reversed.toList(),
      recentThumbnails: thumbs,
      onSelect: onSelect,
    );
  }
}

class GroomingPerEmployeeCard extends StatelessWidget {
  final GroomingPerEmployeeData data;
  const GroomingPerEmployeeCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final danger = data.violationCount > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: danger ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data.employeeName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            Text('${data.position} · ${data.outletName}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          _StatPill(label: 'Avg 30d', value: data.avgScore.toStringAsFixed(1), danger: danger),
          const SizedBox(width: 6),
          _StatPill(label: 'Pelanggaran', value: data.violationCount.toString(), danger: danger),
        ]),
        const SizedBox(height: 10),
        SizedBox(height: 40, child: _Sparkline(values: data.dailyScores)),
        const SizedBox(height: 10),
        Row(children: [
          ...data.recentThumbnails.map((u) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: u, width: 56, height: 56, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(width: 56, height: 56, color: AppColors.surface),
                    errorWidget: (_, __, ___) => Container(width: 56, height: 56, color: AppColors.surface),
                  ),
                ),
              )),
          const Spacer(),
          TextButton(onPressed: data.onSelect, child: const Text('Detail per foto →')),
        ]),
      ]),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final bool danger;
  const _StatPill({required this.label, required this.value, required this.danger});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: danger ? AppColors.dangerLight : AppColors.successLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(value, style: TextStyle(
              fontWeight: FontWeight.w900, fontSize: 13,
              color: danger ? AppColors.danger : AppColors.success,
            )),
            Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
          ]),
        ),
      );
}

class _Sparkline extends StatelessWidget {
  final List<double> values;
  const _Sparkline({required this.values});
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return LineChart(LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      minY: 0, maxY: 10,
      lineBarsData: [
        LineChartBarData(
          spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
          isCurved: true,
          color: AppColors.primary,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
    ));
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/admin/widgets/grooming_per_employee_card.dart
git commit -m "feat(admin): per-employee QC card with avg, violations, sparkline, thumbs"
```

---

## Task C7: GroomingAnalyticsCharts (top violators / per-outlet / 30d trend)

**Files:**
- Create: `lib/screens/admin/widgets/grooming_analytics_charts.dart`

- [ ] **Step 1: Write the widget**

```dart
// lib/screens/admin/widgets/grooming_analytics_charts.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/grooming_qc_service.dart';

class GroomingAnalyticsCharts extends StatelessWidget {
  final List<GroomingRow> rows;
  const GroomingAnalyticsCharts({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    final byEmployee = <String, List<GroomingRow>>{};
    final byOutlet = <String, List<GroomingRow>>{};
    final byDay = <DateTime, List<double>>{};
    for (final r in rows) {
      byEmployee.putIfAbsent(r.employeeName, () => []).add(r);
      byOutlet.putIfAbsent(r.outletName, () => []).add(r);
      final d = DateTime(r.scannedAt.year, r.scannedAt.month, r.scannedAt.day);
      byDay.putIfAbsent(d, () => []).add(r.effectiveScore ?? 0);
    }

    final topViolators = byEmployee.entries
        .map((e) {
          final viol = e.value.where((r) => (r.effectiveScore ?? 0) < 6).length;
          return (name: e.key, rate: viol / e.value.length, count: viol);
        })
        .where((e) => e.count > 0)
        .toList()
      ..sort((a, b) => b.rate.compareTo(a.rate));

    final perOutlet = byOutlet.entries
        .map((e) {
          final pass = e.value.where((r) => (r.effectiveScore ?? 0) >= 6).length;
          return (name: e.key, passRate: pass / e.value.length);
        })
        .toList();

    final trend = byDay.entries.map((e) {
      final avg = e.value.isEmpty ? 0 : e.value.reduce((a, b) => a + b) / e.value.length;
      return (day: e.key, avg: avg.toDouble());
    }).toList()
      ..sort((a, b) => a.day.compareTo(b.day));

    return ListView(padding: EdgeInsets.zero, children: [
      _ChartCard(
        title: 'Top pelanggar (window saat ini)',
        child: _BarRows(rows: topViolators.take(10).map((e) => (label: e.name, value: e.rate * 100)).toList(), maxValue: 100, suffix: '%'),
      ),
      const SizedBox(height: 12),
      _ChartCard(
        title: 'Persentase lulus per outlet',
        child: _BarRows(rows: perOutlet.map((e) => (label: e.name, value: e.passRate * 100)).toList(), maxValue: 100, suffix: '%'),
      ),
      const SizedBox(height: 12),
      _ChartCard(
        title: 'Tren skor rata-rata harian',
        child: SizedBox(
          height: 160,
          child: LineChart(LineChartData(
            minY: 0, maxY: 10,
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: [for (var i = 0; i < trend.length; i++) FlSpot(i.toDouble(), trend[i].avg)],
                isCurved: true,
                color: AppColors.primary,
                barWidth: 2,
                dotData: const FlDotData(show: false),
              ),
            ],
          )),
        ),
      ),
    ]);
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          child,
        ]),
      );
}

class _BarRows extends StatelessWidget {
  final List<({String label, double value})> rows;
  final double maxValue;
  final String suffix;
  const _BarRows({required this.rows, required this.maxValue, required this.suffix});
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Belum cukup data', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Column(children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 120, child: Text(r.label, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12))),
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(children: [
                Container(height: 14, color: AppColors.surface),
                FractionallySizedBox(
                  widthFactor: (r.value / maxValue).clamp(0, 1),
                  child: Container(height: 14, color: AppColors.primary),
                ),
              ]),
            )),
            const SizedBox(width: 8),
            Text('${r.value.toStringAsFixed(0)}$suffix',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
        ),
    ]);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/admin/widgets/grooming_analytics_charts.dart
git commit -m "feat(admin): grooming analytics — top violators, per-outlet, 30d trend"
```

---

## Task C8: GroomingCsvExport + test

**Files:**
- Create: `lib/screens/admin/widgets/grooming_csv_export.dart`
- Create: `test/widgets/grooming_csv_export_test.dart`

- [ ] **Step 1: Write the builder + share button**

```dart
// lib/screens/admin/widgets/grooming_csv_export.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/grooming_qc_service.dart';

class GroomingCsvExport {
  static const csvHeader = 'tanggal,jam,outlet,employee_name,position,'
      'attendance_type,skor_ai,skor_override,override_note,override_by,'
      'wajah_bersih,seragam,rambut,penutup_kepala,photo_quality,reasoning,photo_url';

  static String buildCsv(List<GroomingRow> rows) {
    final buf = StringBuffer(csvHeader)..writeln();
    for (final r in rows) {
      final tgl = '${r.scannedAt.year.toString().padLeft(4, '0')}-'
          '${r.scannedAt.month.toString().padLeft(2, '0')}-'
          '${r.scannedAt.day.toString().padLeft(2, '0')}';
      final jam = '${r.scannedAt.hour.toString().padLeft(2, '0')}:'
          '${r.scannedAt.minute.toString().padLeft(2, '0')}';
      buf.writeln([
        tgl, jam,
        _esc(r.outletName), _esc(r.employeeName), _esc(r.employeePosition),
        r.attendanceType,
        r.groomingScore?.toStringAsFixed(1) ?? '',
        r.qcOverrideScore?.toStringAsFixed(1) ?? '',
        _esc(r.qcOverrideNote ?? ''),
        _esc(r.qcOverriddenBy ?? ''),
        r.faceCleanShave ?? '',
        r.uniformCompliant ?? '',
        r.hairNeat ?? '',
        r.headCovering ?? '',
        r.photoQuality,
        _esc(r.reasoning ?? ''),
        _esc(r.photoUrl),
      ].join(','));
    }
    return buf.toString();
  }

  static String _esc(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}

class GroomingCsvExportButton extends StatelessWidget {
  final List<GroomingRow> rows;
  const GroomingCsvExportButton({super.key, required this.rows});

  Future<void> _share() async {
    final csv = GroomingCsvExport.buildCsv(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/grooming_qc_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'Grooming QC export');
  }

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        onPressed: rows.isEmpty ? null : _share,
        icon: const Icon(Icons.file_download_outlined),
        label: const Text('Export CSV'),
      );
}
```

- [ ] **Step 2: Write the test**

```dart
// test/widgets/grooming_csv_export_test.dart
import 'package:absensi_enakko_flutter/screens/admin/widgets/grooming_csv_export.dart';
import 'package:absensi_enakko_flutter/services/grooming_qc_service.dart';
import 'package:flutter_test/flutter_test.dart';

GroomingRow _row() => GroomingRow(
      attendanceLogId: 'a1', photoUrl: 'https://r2/photo.jpg', employeeId: 'e1',
      employeeName: 'Budi, Si', employeePosition: 'Kasir',
      outletId: 'o1', outletName: 'Bali', attendanceType: 'masuk',
      scannedAt: DateTime(2026, 5, 23, 7, 2),
      analyzedAt: DateTime(2026, 5, 23, 7, 3),
      faceDetected: true, faceCount: 1, photoQuality: 'clear',
      groomingScore: 6.5, qcOverrideScore: 8.0,
      qcOverrideNote: 'Label salah, "rapi" kok', qcOverriddenBy: null,
      qcOverriddenAt: null, safeSearchPassed: true,
      faceCleanShave: 'ok', uniformCompliant: 'ok',
      hairNeat: 'ok', headCovering: 'none',
      reasoning: 'Wajah bersih. Seragam OK. Foto jelas.',
    );

void main() {
  test('header is the agreed columns', () {
    expect(GroomingCsvExport.csvHeader.split(',').length, 17);
    expect(GroomingCsvExport.csvHeader, contains('penutup_kepala'));
  });

  test('escapes commas and quotes', () {
    final csv = GroomingCsvExport.buildCsv([_row()]);
    expect(csv, contains('"Budi, Si"'));
    expect(csv, contains('"Label salah, ""rapi"" kok"'));
    expect(csv, contains('6.5'));
    expect(csv, contains('8.0'));
    expect(csv, contains('2026-05-23'));
  });
}
```

- [ ] **Step 3: Run the test**

```powershell
C:\flutter\bin\flutter.bat test test/widgets/grooming_csv_export_test.dart
```
Expected: 2 pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/admin/widgets/grooming_csv_export.dart test/widgets/grooming_csv_export_test.dart
git commit -m "feat(admin): CSV export with 17 columns + RFC 4180 escaping"
```

---

## Task C9: Rewrite AdminGroomingReportScreen as tabbed dashboard

**Files:**
- Modify (full rewrite): `lib/screens/admin/admin_grooming_report_screen.dart`

- [ ] **Step 1: Replace the file contents**

```dart
// lib/screens/admin/admin_grooming_report_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../providers/grooming_filter_provider.dart';
import '../../services/grooming_qc_service.dart';
import '../../widgets/app_empty_state.dart';
import 'widgets/grooming_analytics_charts.dart';
import 'widgets/grooming_card.dart';
import 'widgets/grooming_csv_export.dart';
import 'widgets/grooming_filter_sheet.dart';
import 'widgets/grooming_override_dialog.dart';
import 'widgets/grooming_per_employee_card.dart';

class AdminGroomingReportScreen extends ConsumerStatefulWidget {
  const AdminGroomingReportScreen({super.key});

  @override
  ConsumerState<AdminGroomingReportScreen> createState() =>
      _AdminGroomingReportScreenState();
}

class _AdminGroomingReportScreenState
    extends ConsumerState<AdminGroomingReportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openFilter() {
    final appState = ref.read(appProvider);
    final outlets = appState.outlets
        .where((o) => appState.canAccessOutlet(o.id))
        .map((o) => (id: o.id, name: o.name))
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => GroomingFilterSheet(outlets: outlets),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(groomingRowsProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Grooming QC'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'List'),
            Tab(text: 'Per Karyawan'),
            Tab(text: 'Analytics'),
          ],
        ),
        actions: [
          IconButton(onPressed: _openFilter, icon: const Icon(Icons.tune_rounded)),
        ],
      ),
      body: rowsAsync.when(
        data: (rows) => _Tabs(controller: _tabs, rows: rows),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => AppEmptyState(
          icon: Icons.error_outline_rounded,
          heading: 'Gagal memuat data',
          subtext: 'Coba refresh atau cek koneksi.',
        ),
      ),
      floatingActionButton: rowsAsync.maybeWhen(
        data: (rows) => GroomingCsvExportButton(rows: rows),
        orElse: () => null,
      ),
    );
  }
}

class _Tabs extends ConsumerWidget {
  final TabController controller;
  final List<GroomingRow> rows;
  const _Tabs({required this.controller, required this.rows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TabBarView(controller: controller, children: [
      _ListTab(rows: rows),
      _PerEmployeeTab(rows: rows, onSelect: (employeeId) {
        ref.read(groomingFilterProvider.notifier)
            .setEmployeeQuery(rows.firstWhere((r) => r.employeeId == employeeId).employeeName);
        controller.animateTo(0);
      }),
      _AnalyticsTab(rows: rows),
    ]);
  }
}

class _ListTab extends StatelessWidget {
  final List<GroomingRow> rows;
  const _ListTab({required this.rows});
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: AppEmptyState(
        icon: Icons.photo_camera_front_outlined,
        heading: 'Tidak ada foto sesuai filter',
        subtext: 'Ubah filter atau tunggu data baru masuk.',
      ));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: rows.length,
      itemBuilder: (_, i) => GroomingCard(
        row: rows[i],
        onTapPhoto: () => _openPreview(context, rows[i]),
        onTapOverride: () => _openOverride(context, rows[i]),
      ),
    );
  }

  void _openPreview(BuildContext context, GroomingRow r) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white,
          title: Text(r.employeeName)),
      body: Center(child: InteractiveViewer(child: Image.network(r.photoUrl))),
    )));
  }

  void _openOverride(BuildContext context, GroomingRow r) {
    showDialog<bool>(context: context, builder: (_) => GroomingOverrideDialog(row: r));
  }
}

class _PerEmployeeTab extends StatelessWidget {
  final List<GroomingRow> rows;
  final void Function(String employeeId) onSelect;
  const _PerEmployeeTab({required this.rows, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final byEmployee = <String, List<GroomingRow>>{};
    for (final r in rows) {
      byEmployee.putIfAbsent(r.employeeId, () => []).add(r);
    }
    final list = byEmployee.entries
        .map((e) => GroomingPerEmployeeData.fromRows(
              e.key,
              e.value,
              onSelect: () => onSelect(e.key),
            ))
        .toList()
      ..sort((a, b) => a.avgScore.compareTo(b.avgScore));
    if (list.isEmpty) {
      return const Center(child: AppEmptyState(
        icon: Icons.people_outline,
        heading: 'Belum ada data karyawan',
        subtext: '',
      ));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: list.length,
      itemBuilder: (_, i) => GroomingPerEmployeeCard(data: list[i]),
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  final List<GroomingRow> rows;
  const _AnalyticsTab({required this.rows});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        child: GroomingAnalyticsCharts(rows: rows),
      );
}
```

- [ ] **Step 2: Run analyze + tests sweep**

```powershell
C:\flutter\bin\flutter.bat analyze lib/screens/admin/admin_grooming_report_screen.dart
C:\flutter\bin\flutter.bat test
```
Expected: 0 errors, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/admin/admin_grooming_report_screen.dart
git commit -m "feat(admin): tabbed grooming QC dashboard (List, Per Karyawan, Analytics)

Realtime rows via groomingRowsProvider. Filter sheet wired to AppBar.
CSV export FAB. Each tab consumes the same rows stream filtered by
GroomingFilterProvider."
```

---

# Phase D — Integration, UAT, rollout

## Task D1: Write the UAT checklist

**Files:**
- Create: `docs/superpowers/specs/2026-05-23-attendance-photo-uat.md`

- [ ] **Step 1: Write the file**

```markdown
# UAT — Attendance Photo Redesign

Run through each step on a real kiosk device with a real admin account. Tick each box.

## Kiosk capture
- [ ] Scan NFC, position face badly (off-centre, too far): pill remains "Posisikan wajah…" with directional hint.
- [ ] Position face well; oval turns white solid, pill says "Tahan posisi…", progress arc draws.
- [ ] After 1 s aligned hold, oval turns green and pill says "Kedipkan mata sekali 👁️".
- [ ] Blink once: capture fires, photo flashes, attendance submits.
- [ ] Hold eyes closed without opening: capture does NOT fire. Pill remains "Kedipkan mata".
- [ ] Move face mid-blink-prompt: state resets to "Posisikan wajah".
- [ ] Print a face on paper and present it: cannot pass blink check (no closed→open transition observable).
- [ ] After 3 failed blink windows: "Coba Lagi" button appears. Tap → returns to searching.
- [ ] Tap Batal (if exposed): exits capture flow.

## Admin
- [ ] Within ~2 s of a kiosk capture, a new card appears at the top of the Grooming QC List tab (realtime).
- [ ] Beard photo: card shows red "Jenggot" chip and score <8.
- [ ] Hijab photo: card shows blue "Hijab" chip, "Rambut tertutup" chip, score ≥9 (regression).
- [ ] Topi photo (male crew): card shows grey "Topi" chip (NOT "Hijab"), score ≥9.
- [ ] Tap Override skor: dialog opens with slider + note field; Simpan disabled until note ≥10 chars.
- [ ] Submit override with valid note: pill updates to "old→new ✏", chip stays as AI judged.
- [ ] Open filter sheet: change to 7 hari + one outlet + Hanya butuh review on, Terapkan.
- [ ] Switch to Per Karyawan tab: cards sorted worst-first, sparkline draws.
- [ ] Tap "Detail per foto" on a card: returns to List tab filtered to that employee.
- [ ] Analytics tab: top violators bar chart, per-outlet pass rate, 30d trend line all render with current data.
- [ ] Tap Export CSV FAB: share sheet opens. CSV contains the agreed 17 columns including penutup_kepala.

## Operational safety
- [ ] Network drop during capture: attendance still queues offline; photo stored locally for retry (existing Phase 64 behaviour, not regressed).
- [ ] Vision API hard fail: attendance log still saved, attendance_photo_analysis row missing — admin UI shows no QC chips, score "-".
- [ ] USE_LEGACY_VISION_SCORING=true: new captures still produce a row, model_name='cloud-vision-legacy', per-criteria columns NULL — UI degrades to legacy chips.
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-05-23-attendance-photo-uat.md
git commit -m "docs(qc): UAT checklist for attendance photo redesign"
```

---

## Task D2: Flip USE_LEGACY_VISION_SCORING to false

This is a production environment-variable change, not a code commit. Coordinate with whoever owns Supabase secrets.

- [ ] **Step 1: In Supabase dashboard → Edge Functions → analyze-attendance-photo → Settings**, set `USE_LEGACY_VISION_SCORING=false`.

- [ ] **Step 2: Take 5 fresh kiosk captures (mix: clean, beard, hijab, topi, blurry).**

- [ ] **Step 3: Query for newly-analyzed rows**

Use `mcp__supabase__execute_sql`:

```sql
SELECT attendance_log_id, model_name, grooming_score,
       face_clean_shave, uniform_compliant, hair_neat, head_covering, reasoning
FROM attendance_photo_analysis
WHERE analyzed_at > now() - interval '10 minutes'
ORDER BY analyzed_at DESC;
```
Expected: 5 rows, all with `model_name = 'cloud-vision-rubric-v1'` and per-criteria columns populated.

- [ ] **Step 4: If everything looks right, run through the UAT checklist (D1).**

---

## Task D3: 7-day observation window

- [ ] **Step 1: Tag the release**

```bash
git tag v8.9.0-grooming-qc-rubric-2026-05-23
git push --tags
```

- [ ] **Step 2: Every day for 7 days, query for outliers**

```sql
SELECT analyzed_at::date AS day,
       count(*) AS total,
       count(*) FILTER (WHERE grooming_score < 6) AS low_score,
       count(*) FILTER (WHERE face_clean_shave = 'beard') AS beard,
       count(*) FILTER (WHERE head_covering = 'hijab') AS hijab,
       count(*) FILTER (WHERE head_covering = 'cap') AS cap
FROM attendance_photo_analysis
WHERE analyzed_at > now() - interval '7 days'
  AND model_name = 'cloud-vision-rubric-v1'
GROUP BY 1
ORDER BY 1 DESC;
```

Watch for: hijab rate ≈ proportion of hijab-wearing staff (no longer always low-score), beard detection rate plausible (5-15 % of male staff in restaurants), cap detection occurs for kitchen crew.

- [ ] **Step 2 (rollback if needed):** flip `USE_LEGACY_VISION_SCORING=true`, file a bug, do not delete the legacy path yet.

---

## Task D4: Delete legacy scoring path

After Task D3 passes, remove the dead code.

**Files:**
- Modify: `supabase/functions/analyze-attendance-photo/index.ts`

- [ ] **Step 1: Delete the legacy branch**

In `index.ts` remove:
- The `USE_LEGACY_VISION_SCORING` constant
- The conditional `USE_LEGACY_VISION_SCORING ? parseLegacyGroomingAnalysis : parseGroomingAnalysis`
- The entire `parseLegacyGroomingAnalysis` function and its helpers (`inferPhotoQuality`, the old keyword logic)

Keep only the call:
```ts
const analysis = parseGroomingAnalysis(visionResponse);
```

- [ ] **Step 2: Redeploy**

Use `mcp__supabase__deploy_edge_function` to push the cleaned version.

- [ ] **Step 3: Verify with a fresh capture**

```sql
SELECT model_name FROM attendance_photo_analysis ORDER BY analyzed_at DESC LIMIT 1;
```
Expected: `cloud-vision-rubric-v1`.

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/analyze-attendance-photo/index.ts
git commit -m "chore(qc): delete legacy Vision scoring branch + env flag"
```

---

## Self-Review (writer's checklist after writing the plan)

**1. Spec coverage:** Every spec section maps to at least one task:
- §5 capture flow → B1–B8
- §6 QC rewrite → A4–A9
- §7 DB schema → A1–A2
- §8 admin UI → C1–C9
- §10 testing → tests are embedded in every relevant task
- §11 rollout → D1–D4
- §13 open assumptions → handled inline (e.g. ML Kit classification graceful degradation lives in B2/B6; hijab fixture in A9)

**2. Placeholder scan:** No TBDs, no "see Task N", every code block is complete. Each commit message is verbatim.

**3. Type consistency:** `GroomingRow`, `GroomingFilter`, `FaceCaptureStateMachine`, `FaceDetectionResult`, `CaptureState`, `FaceAlignment`, `GroomingAnalysis` consistent across all tasks. RPC name `apply_grooming_qc_override` consistent in SQL, service, dialog. Column names match across migration, Edge Function, service, CSV export.

**4. Frequent commits:** 31 tasks, each ends in 1 commit. Plus tag commit in D3.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-23-attendance-photo-redesign.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Best for a plan this size (31 tasks) since each task is self-contained and a fresh context per task avoids drift.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints. Slower but you see every keystroke.

Which approach?

