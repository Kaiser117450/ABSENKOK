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
