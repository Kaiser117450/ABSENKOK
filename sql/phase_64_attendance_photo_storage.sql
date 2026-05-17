-- Phase 64: Attendance Photo Grooming Beta
-- Additive-only migration for beta photo capture, storage, and analysis.
--
-- Apply manually in Supabase SQL Editor after reviewing storage exposure.
-- The Flutter beta is disabled by default until ATTENDANCE_PHOTO_BETA=true.

-- 1. Storage bucket ---------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'attendance-photos',
  'attendance-photos',
  true,
  262144,
  ARRAY['image/jpeg']
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "attendance_photos_kiosk_insert" ON storage.objects;
CREATE POLICY "attendance_photos_kiosk_insert"
  ON storage.objects
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    bucket_id = 'attendance-photos'
    AND lower(right(name, 4)) = '.jpg'
    AND array_length(storage.foldername(name), 1) = 3
  );

DROP POLICY IF EXISTS "attendance_photos_admin_select" ON storage.objects;
CREATE POLICY "attendance_photos_admin_select"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'attendance-photos'
    AND public.get_app_role() = 'admin'
  );

DROP POLICY IF EXISTS "attendance_photos_admin_delete" ON storage.objects;
CREATE POLICY "attendance_photos_admin_delete"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'attendance-photos'
    AND public.get_app_role() = 'admin'
  );

-- 2. Attendance log beta metadata ------------------------------------------

ALTER TABLE public.attendance_logs
  ADD COLUMN IF NOT EXISTS selfie_url text;

ALTER TABLE public.attendance_logs
  ADD COLUMN IF NOT EXISTS photo_required boolean NOT NULL DEFAULT false;

ALTER TABLE public.attendance_logs
  ADD COLUMN IF NOT EXISTS photo_uploaded_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_attendance_logs_photo_required
  ON public.attendance_logs (scan_outlet_id, scanned_at DESC)
  WHERE photo_required = true;

-- 3. Grooming analysis table ------------------------------------------------

CREATE TABLE IF NOT EXISTS public.attendance_photo_analysis (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attendance_log_id uuid REFERENCES public.attendance_logs(id) ON DELETE CASCADE,
  photo_url text NOT NULL,
  face_detected boolean DEFAULT false,
  face_confidence numeric(4,2),
  face_count int DEFAULT 0,
  photo_quality text CHECK (
    photo_quality IN ('clear', 'blurry', 'dark', 'overexposed')
  ),
  grooming_labels jsonb DEFAULT '[]'::jsonb,
  grooming_score numeric(3,1),
  safe_search_passed boolean DEFAULT true,
  raw_vision_response jsonb,
  analyzed_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

-- Phase 66: full unique index (no WHERE clause) so analyze-attendance-photo's
-- upsert with ON CONFLICT (attendance_log_id) can resolve against this index.
-- Postgres still treats multiple NULLs as distinct in unique indexes, so the
-- semantic of allowing NULL attendance_log_id rows is preserved.
CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_photo_analysis_log_unique
  ON public.attendance_photo_analysis (attendance_log_id);

CREATE INDEX IF NOT EXISTS idx_attendance_photo_analysis_score
  ON public.attendance_photo_analysis (grooming_score, analyzed_at DESC);

ALTER TABLE public.attendance_photo_analysis ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "attendance_photo_analysis_admin_select" ON public.attendance_photo_analysis;
CREATE POLICY "attendance_photo_analysis_admin_select"
  ON public.attendance_photo_analysis
  FOR SELECT
  TO authenticated
  USING (public.get_app_role() = 'admin');

DROP POLICY IF EXISTS "attendance_photo_analysis_service_insert" ON public.attendance_photo_analysis;
CREATE POLICY "attendance_photo_analysis_service_insert"
  ON public.attendance_photo_analysis
  FOR INSERT
  TO authenticated
  WITH CHECK (false);

DROP POLICY IF EXISTS "attendance_photo_analysis_service_update" ON public.attendance_photo_analysis;
CREATE POLICY "attendance_photo_analysis_service_update"
  ON public.attendance_photo_analysis
  FOR UPDATE
  TO authenticated
  USING (false)
  WITH CHECK (false);

-- 4. RPC helpers ------------------------------------------------------------
-- These helpers avoid giving kiosk clients broad attendance_logs UPDATE
-- privileges. Live photo beta scans should send a local_id so the client can
-- resolve the inserted UUID without changing the legacy record_kiosk_scan flow.

CREATE OR REPLACE FUNCTION public.resolve_attendance_log_for_local_id(
  p_local_id text
)
RETURNS TABLE (
  log_id uuid,
  scanned_at_utc timestamptz,
  logical_date date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF COALESCE(BTRIM(p_local_id), '') = '' THEN
    RAISE EXCEPTION 'local_id is required';
  END IF;

  RETURN QUERY
  SELECT
    al.id,
    al.scanned_at,
    (al.scanned_at AT TIME ZONE 'Asia/Makassar')::date
  FROM public.attendance_logs al
  WHERE al.local_id = p_local_id
  ORDER BY al.scanned_at DESC, al.id DESC
  LIMIT 1;
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_attendance_log_for_local_id(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_attendance_log_for_local_id(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.attach_attendance_photo(
  p_attendance_log_id uuid,
  p_selfie_url text,
  p_photo_required boolean DEFAULT true
)
RETURNS TABLE (
  log_id uuid,
  selfie_url text,
  photo_uploaded_at timestamptz
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_selfie_url text;
  v_updated_count int;
BEGIN
  IF p_attendance_log_id IS NULL THEN
    RAISE EXCEPTION 'attendance log id is required';
  END IF;

  v_selfie_url := BTRIM(p_selfie_url);

  IF COALESCE(v_selfie_url, '') = '' THEN
    RAISE EXCEPTION 'selfie_url is required';
  END IF;

  -- Phase 66: Photos now live on Cloudflare R2. Accept either the r2.dev
  -- public domain or the S3-compatible endpoint, and require the URL to
  -- end with the attendance log id so a kiosk anon key cannot point
  -- selfie_url at an unrelated object. Update the host LIKE patterns if
  -- the deployment migrates to a custom R2 domain.
  IF v_selfie_url NOT LIKE 'https://%'
     OR (
       v_selfie_url NOT LIKE '%.r2.dev/%'
       AND v_selfie_url NOT LIKE '%.r2.cloudflarestorage.com/%'
     )
     OR v_selfie_url NOT LIKE ('%/' || p_attendance_log_id::text || '.jpg') THEN
    RAISE EXCEPTION 'selfie_url does not match attendance photo R2 path';
  END IF;

  UPDATE public.attendance_logs al
  SET
    selfie_url = v_selfie_url,
    photo_required = COALESCE(p_photo_required, true),
    photo_uploaded_at = statement_timestamp()
  WHERE al.id = p_attendance_log_id;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count = 0 THEN
    RAISE EXCEPTION 'attendance log not found';
  END IF;

  RETURN QUERY
  SELECT
    al.id,
    al.selfie_url,
    al.photo_uploaded_at
  FROM public.attendance_logs al
  WHERE al.id = p_attendance_log_id;
END;
$$;

REVOKE ALL ON FUNCTION public.attach_attendance_photo(uuid, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.attach_attendance_photo(uuid, text, boolean) TO anon, authenticated;
