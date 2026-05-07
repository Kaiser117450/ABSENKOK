import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath = 'sql/phase_64_attendance_photo_storage.sql';

  group('Phase 64 attendance photo SQL contract', () {
    late File migrationFile;
    late String sql;

    setUpAll(() {
      migrationFile = File(migrationPath);
      sql = migrationFile.existsSync() ? migrationFile.readAsStringSync() : '';
    });

    test('migration file exists', () {
      expect(
        migrationFile.existsSync(),
        isTrue,
        reason: 'Expected $migrationPath to be present for beta rollout.',
      );
    });

    test('defines storage bucket and scoped object policies', () {
      for (final token in const [
        "'attendance-photos'",
        'attendance_photos_kiosk_insert',
        'attendance_photos_admin_select',
        'attendance_photos_admin_delete',
        'array_length(storage.foldername(name), 1) = 4',
      ]) {
        expect(sql.contains(token), isTrue, reason: 'Missing token: $token');
      }
    });

    test('defines additive attendance photo metadata and analysis table', () {
      for (final token in const [
        'ADD COLUMN IF NOT EXISTS selfie_url',
        'ADD COLUMN IF NOT EXISTS photo_required',
        'ADD COLUMN IF NOT EXISTS photo_uploaded_at',
        'CREATE TABLE IF NOT EXISTS public.attendance_photo_analysis',
        'grooming_score numeric(3,1)',
        'safe_search_passed boolean DEFAULT true',
      ]) {
        expect(sql.contains(token), isTrue, reason: 'Missing token: $token');
      }
    });

    test('keeps kiosk photo helpers explicit and fail-closed', () {
      for (final token in const [
        'resolve_attendance_log_for_local_id',
        'attach_attendance_photo',
        'SECURITY DEFINER',
        "REVOKE ALL ON FUNCTION public.attach_attendance_photo(uuid, text, boolean) FROM PUBLIC;",
        'GRANT EXECUTE ON FUNCTION public.attach_attendance_photo(uuid, text, boolean) TO anon, authenticated;',
        "v_selfie_url NOT LIKE '%/storage/v1/object/public/attendance-photos/%'",
        "p_attendance_log_id::text || '.jpg%'",
        'GET DIAGNOSTICS v_updated_count = ROW_COUNT',
        "RAISE EXCEPTION 'attendance log not found'",
      ]) {
        expect(sql.contains(token), isTrue, reason: 'Missing token: $token');
      }
    });
  });
}
