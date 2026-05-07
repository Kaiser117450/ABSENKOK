-- Phase 64 hotfix: attendance photo Storage policy folder count.
--
-- Supabase storage.foldername(name) returns folders only, excluding the file.
-- For the path convention {outlet_id}/{employee_id}/{YYYY-MM-DD}/{log_id}.jpg,
-- the folder count is 3, not 4. The original policy blocked kiosk uploads.

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
