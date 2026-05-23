# Deployment Notes — analyze-attendance-photo

## Phase 67 — Grooming QC Rubric

**Required env var:** `USE_LEGACY_VISION_SCORING=true` (safe default — keeps old scoring active)

To activate new rubric scoring: set `USE_LEGACY_VISION_SCORING=false` in Supabase Edge Functions secrets.

**What changes when flipped to false:**
- Cloud Vision labels parsed through deterministic rubric (grooming_rules.ts)
- beard/mustache/stubble → face_clean_shave penalized (was getting free +2 from "person" label)
- hijab → hair_neat=not_visible → +3 score (was being penalized)
- cap/hat → classified as "cap" not "hijab"
- New columns written: face_clean_shave, uniform_compliant, hair_neat, head_covering, reasoning, model_name
- LABEL_DETECTION maxResults bumped from 15 → 30

**Rollback:** Set `USE_LEGACY_VISION_SCORING=true` to instantly revert.
