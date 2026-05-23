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

-- apply_grooming_qc_override: admin-only score correction with required audit note.
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
