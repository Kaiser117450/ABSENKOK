-- sql/phase_72_grooming_rules_config.sql
-- Phase 72: Admin-editable grooming rule config + feedback loop + scoring v2.
--
-- 1. grooming_rules_config: one active JSONB row the Edge Function reads at
--    runtime (label vocab, thresholds, weights, custom flagged labels). The
--    admin "Aturan AI" screen edits this, so corrections change future scoring.
-- 2. grooming_feedback: every admin correction is logged as training/feedback
--    data ("AI salah" → masukan/improvement).
-- 3. attendance_photo_analysis: + hair_length, + score_breakdown (transparency).
-- 4. apply_grooming_qc_override: consolidated to ONE admin-only function (the
--    previous 4-arg overload had lost its admin check) that also writes feedback.
-- 5. get_active_grooming_rules / save_grooming_rules RPCs for the admin UI.
--
-- Purely additive to existing rows. Safe to re-run (idempotent).

BEGIN;

-- 1. Rule config -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.grooming_rules_config (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version     integer NOT NULL,
  is_active   boolean NOT NULL DEFAULT false,
  config      jsonb   NOT NULL,
  note        text,
  updated_by  uuid REFERENCES auth.users(id),
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- At most one active config row.
CREATE UNIQUE INDEX IF NOT EXISTS grooming_rules_config_single_active
  ON public.grooming_rules_config ((is_active)) WHERE is_active;

ALTER TABLE public.grooming_rules_config ENABLE ROW LEVEL SECURITY;
-- No direct table policies: reads/writes go through SECURITY DEFINER RPCs;
-- the Edge Function uses the service role which bypasses RLS.

-- Seed v1 from the historical hardcoded defaults (only if table is empty).
INSERT INTO public.grooming_rules_config (version, is_active, config, note)
SELECT 1, true, $json$
{
  "thresholds": { "min_label_score": 0.65, "min_uniform_label_score": 0.55, "min_face_confidence": 0.5 },
  "weights": { "face": 3, "uniform": 3, "hair": 3, "photo": 1 },
  "label_sets": {
    "hijab": ["hijab","headscarf","veil","niqab","khimar","shawl","abaya"],
    "cap": ["cap","hat","baseball cap","cricket cap","chef hat","chef's hat","beanie","bandana","headgear"],
    "other_head_covering": ["turban","head covering","head wrap","headcloth"],
    "beard": ["beard","goatee"],
    "mustache": ["moustache","mustache"],
    "stubble": ["stubble","sideburns","facial hair"],
    "uniform": ["apron","uniform","workwear","work wear","work clothing","shirt","t-shirt","tshirt","t shirt","polo shirt","polo","polo neck","dress shirt","button-up","button up","buttoned","blouse","tunic","top","collar","sleeve","neckline","crew neck","v-neck","active shirt","sportswear","athletic wear","jersey","outerwear","knitwear","vest","waistcoat","chef","restaurant"],
    "wrong_attire": ["tank top","sleeveless","singlet","swimwear","bikini","swimsuit","underwear","lingerie","bare chest","shirtless"],
    "messy_hair": ["messy hair","disheveled","unkempt","tousled"],
    "long_hair": ["long hair","ponytail","bun","pigtail","dreadlocks","hair bun"],
    "short_hair_ok": ["crew cut","buzz cut","short hair","fade","undercut","high and tight","caesar cut","comb over"],
    "blurry": ["blur","blurry","out of focus","motion blur"],
    "dark": ["darkness","dark","underexposed","low light"],
    "overexposed": ["overexposed","overexposure","glare","blown out"]
  },
  "flagged_labels": []
}
$json$::jsonb, 'Phase 72 seed (defaults from grooming_rules.ts)'
WHERE NOT EXISTS (SELECT 1 FROM public.grooming_rules_config);

-- 2. Feedback log ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.grooming_feedback (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attendance_log_id uuid REFERENCES public.attendance_logs(id) ON DELETE SET NULL,
  criterion         text NOT NULL,
  ai_verdict        text,
  admin_verdict     text,
  ai_score          numeric,
  admin_score       numeric,
  labels            jsonb,
  note              text,
  created_by        uuid REFERENCES auth.users(id),
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS grooming_feedback_created_at_idx
  ON public.grooming_feedback (created_at DESC);
CREATE INDEX IF NOT EXISTS grooming_feedback_criterion_idx
  ON public.grooming_feedback (criterion);

ALTER TABLE public.grooming_feedback ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.grooming_feedback TO authenticated;
DROP POLICY IF EXISTS grooming_feedback_admin_read ON public.grooming_feedback;
CREATE POLICY grooming_feedback_admin_read ON public.grooming_feedback
  FOR SELECT TO authenticated
  USING ((auth.jwt() -> 'app_metadata' ->> 'app_role') = 'admin');

-- 3. New analysis columns --------------------------------------------------
ALTER TABLE public.attendance_photo_analysis
  ADD COLUMN IF NOT EXISTS hair_length     text,
  ADD COLUMN IF NOT EXISTS score_breakdown jsonb;

COMMENT ON COLUMN public.attendance_photo_analysis.hair_length     IS 'enum: ok | long | not_visible | unclear (best-effort, admin-overridable)';
COMMENT ON COLUMN public.attendance_photo_analysis.score_breakdown IS 'jsonb {face,uniform,hair,photo,total,max} for transparent scoring';

COMMIT;

-- 4. Override RPC: ONE admin-only version + feedback logging ----------------
BEGIN;

-- Remove the redundant 3-arg overload so only the 4-arg admin-checked one exists.
DROP FUNCTION IF EXISTS public.apply_grooming_qc_override(uuid, numeric, text);

CREATE OR REPLACE FUNCTION public.apply_grooming_qc_override(
  p_attendance_log_id uuid,
  p_score             numeric,
  p_note              text,
  p_corrections       jsonb DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid  uuid;
  v_role text;
  v_row  public.attendance_photo_analysis%ROWTYPE;
  v_key  text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '28000';
  END IF;

  SELECT raw_app_meta_data->>'app_role' INTO v_role
    FROM auth.users WHERE id = v_uid;
  IF v_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'forbidden: admin only' USING ERRCODE = '42501';
  END IF;

  IF p_score IS NOT NULL AND (p_score < 0 OR p_score > 10) THEN
    RAISE EXCEPTION 'score must be between 0 and 10' USING ERRCODE = '22023';
  END IF;
  IF p_note IS NULL OR length(trim(p_note)) < 10 THEN
    RAISE EXCEPTION 'note must be at least 10 characters' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_row FROM public.attendance_photo_analysis
   WHERE attendance_log_id = p_attendance_log_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'attendance_photo_analysis row not found' USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.attendance_photo_analysis
     SET qc_override_score = p_score,
         qc_override_note  = trim(p_note),
         qc_overridden_by  = v_uid,
         qc_overridden_at  = now(),
         qc_corrections    = COALESCE(p_corrections, qc_corrections)
   WHERE attendance_log_id = p_attendance_log_id;

  -- Log one feedback row per corrected criterion (admin marks AI wrong → OK).
  IF p_corrections IS NOT NULL THEN
    FOR v_key IN
      SELECT key FROM jsonb_each_text(p_corrections) WHERE value = 'true'
    LOOP
      INSERT INTO public.grooming_feedback (
        attendance_log_id, criterion, ai_verdict, admin_verdict,
        ai_score, admin_score, labels, note, created_by
      ) VALUES (
        p_attendance_log_id, v_key,
        CASE v_key
          WHEN 'face_clean_shave'  THEN v_row.face_clean_shave
          WHEN 'uniform_compliant' THEN v_row.uniform_compliant
          WHEN 'hair_neat'         THEN v_row.hair_neat
          WHEN 'hair_length'       THEN v_row.hair_length
          WHEN 'head_covering'     THEN v_row.head_covering
          ELSE NULL
        END,
        'ok', v_row.grooming_score, p_score, v_row.grooming_labels,
        trim(p_note), v_uid
      );
    END LOOP;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.apply_grooming_qc_override(uuid, numeric, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.apply_grooming_qc_override(uuid, numeric, text, jsonb) TO authenticated;

COMMENT ON FUNCTION public.apply_grooming_qc_override(uuid, numeric, text, jsonb)
IS 'Admin-only grooming QC override: writes audit columns + corrections, logs grooming_feedback rows. Rejects non-admin.';

COMMIT;

-- 5. Rule config read/write RPCs -------------------------------------------
BEGIN;

CREATE OR REPLACE FUNCTION public.get_active_grooming_rules()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid  uuid;
  v_role text;
  v_out  jsonb;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '28000';
  END IF;
  SELECT raw_app_meta_data->>'app_role' INTO v_role
    FROM auth.users WHERE id = v_uid;
  IF v_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'forbidden: admin only' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
           'id', id, 'version', version, 'config', config,
           'note', note, 'updated_at', created_at)
    INTO v_out
    FROM public.grooming_rules_config
   WHERE is_active = true
   ORDER BY version DESC
   LIMIT 1;

  RETURN v_out;  -- null if none active
END;
$$;

CREATE OR REPLACE FUNCTION public.save_grooming_rules(
  p_config jsonb,
  p_note   text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     uuid;
  v_role    text;
  v_version integer;
  v_id      uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '28000';
  END IF;
  SELECT raw_app_meta_data->>'app_role' INTO v_role
    FROM auth.users WHERE id = v_uid;
  IF v_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'forbidden: admin only' USING ERRCODE = '42501';
  END IF;
  IF p_config IS NULL OR jsonb_typeof(p_config) <> 'object' THEN
    RAISE EXCEPTION 'config must be a json object' USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(MAX(version), 0) + 1 INTO v_version
    FROM public.grooming_rules_config;

  UPDATE public.grooming_rules_config SET is_active = false WHERE is_active;

  INSERT INTO public.grooming_rules_config (version, is_active, config, note, updated_by)
  VALUES (v_version, true, p_config, p_note, v_uid)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('id', v_id, 'version', v_version);
END;
$$;

REVOKE ALL ON FUNCTION public.get_active_grooming_rules() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.save_grooming_rules(jsonb, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_active_grooming_rules() TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_grooming_rules(jsonb, text) TO authenticated;

COMMENT ON FUNCTION public.get_active_grooming_rules() IS 'Admin-only: returns active grooming rule config {id,version,config,note,updated_at}.';
COMMENT ON FUNCTION public.save_grooming_rules(jsonb, text) IS 'Admin-only: stores a new active grooming rule config version (deactivates the previous one).';

COMMIT;
