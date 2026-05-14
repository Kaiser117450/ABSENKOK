-- Phase 66: Server-side safety net for the attendance photo grooming pipeline.
--
-- Why this exists
--   Phase 64 wired up a client-side fire-and-forget call to the
--   `analyze-attendance-photo` Edge Function after each upload. In production
--   that call was failing silently (Edge Function had verify_jwt=true, kiosk
--   anon JWT was getting dropped, and the catch in `requestGroomingAnalysis`
--   swallowed the error). Result: 4990+ attendance_logs with selfie_url = null
--   and 0 rows in attendance_photo_analysis.
--
-- What this migration does
--   1. Enables `pg_net` so Postgres can perform outbound HTTP calls.
--   2. Adds `attendance_photo_storage_path(text)` to extract the storage
--      object path from a public selfie URL.
--   3. Adds `trigger_attendance_photo_analysis()` (SECURITY DEFINER) that
--      POSTs to the Edge Function whenever `attendance_logs.selfie_url`
--      transitions from NULL to NOT NULL or changes to a new URL.
--   4. Installs the `attendance_photo_analysis_on_selfie_url_set` trigger.
--
-- Notes
--   - The Edge Function must be deployed with `verify_jwt = false` so this
--     server-side call (and the kiosk anon call) succeeds without a user JWT.
--   - The trigger never blocks the attendance write — failures are caught
--     and logged as WARNING. QC analysis is idempotent on attendance_log_id
--     via the upsert in the Edge Function.

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.attendance_photo_storage_path(selfie_url text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT NULLIF(regexp_replace(
    selfie_url,
    '^.*/storage/v1/object/(?:public|sign|authenticated)/attendance-photos/',
    ''
  ), selfie_url)
$$;

COMMENT ON FUNCTION public.attendance_photo_storage_path(text)
IS 'Extracts the storage object path inside attendance-photos from a public selfie URL. Returns NULL if the URL does not match the bucket.';

CREATE OR REPLACE FUNCTION public.trigger_attendance_photo_analysis()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $$
DECLARE
  v_path     text;
  v_function text := 'https://tmapxdftdhxovthgbhww.supabase.co/functions/v1/analyze-attendance-photo';
  v_anon_key text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtYXB4ZGZ0ZGh4b3Z0aGdiaHd3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1MDUxNjUsImV4cCI6MjA4NzA4MTE2NX0.He46hRru1q_aie_1y6DO6msRcSACYgM3zYX_aGW3C14';
BEGIN
  IF NEW.selfie_url IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.selfie_url IS NOT DISTINCT FROM NEW.selfie_url THEN
    RETURN NEW;
  END IF;

  v_path := public.attendance_photo_storage_path(NEW.selfie_url);
  IF v_path IS NULL OR v_path = '' THEN
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url     := v_function,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', v_anon_key,
      'Authorization', 'Bearer ' || v_anon_key
    ),
    body    := jsonb_build_object(
      'attendance_log_id', NEW.id::text,
      'photo_path',        v_path,
      'photo_url',         NEW.selfie_url
    ),
    timeout_milliseconds := 5000
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trigger_attendance_photo_analysis: %', SQLERRM;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trigger_attendance_photo_analysis()
IS 'Fires analyze-attendance-photo via pg_net whenever attendance_logs.selfie_url is set or changed. Safe to fail; QC analysis is idempotent on attendance_log_id.';

DROP TRIGGER IF EXISTS attendance_photo_analysis_on_selfie_url_set ON public.attendance_logs;
CREATE TRIGGER attendance_photo_analysis_on_selfie_url_set
AFTER INSERT OR UPDATE OF selfie_url ON public.attendance_logs
FOR EACH ROW
WHEN (NEW.selfie_url IS NOT NULL)
EXECUTE FUNCTION public.trigger_attendance_photo_analysis();
