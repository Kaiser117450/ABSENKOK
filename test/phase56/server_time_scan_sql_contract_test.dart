import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath = 'sql/phase_56_server_time_scan_authority_20260327.sql';

  group('Phase 56 SQL server time scan contract', () {
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
        reason:
            'Expected $migrationPath to be present for the Phase 56 rollout.',
      );
    });

    test('defines the required authority columns and unique local id index',
        () {
      for (final token in const [
        'device_captured_at',
        'capture_mode',
        'queue_order',
        'initial_scan_intent',
        'requires_admin_review',
        'idx_attendance_logs_local_id_unique',
      ]) {
        expect(
          sql.contains(token),
          isTrue,
          reason: 'Missing Phase 56 authority token: $token',
        );
      }
    });

    test('contains both kiosk RPCs and server-owned time capture', () {
      for (final token in const [
        'get_kiosk_scan_context',
        'record_kiosk_scan',
        'statement_timestamp()',
        'SECURITY DEFINER',
      ]) {
        expect(
          sql.contains(token),
          isTrue,
          reason: 'Missing kiosk RPC contract token: $token',
        );
      }
    });

    test('preserves recap truth wiring and WITA formatting', () {
      for (final token in const [
        'break_first_confirmed',
        'HH24:MI "WITA"',
        'break_first_eligible',
      ]) {
        expect(
          sql.contains(token),
          isTrue,
          reason: 'Missing recap or formatting token: $token',
        );
      }
    });
  });
}
