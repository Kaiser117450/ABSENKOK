import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath = 'sql/phase_57_strict_recap_evaluation_engine_20260327.sql';

  group('Phase 57 strict recap SQL contract', () {
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
        reason: 'Expected $migrationPath to exist for the Phase 57 rollout.',
      );
    });

    test('defines strict recap helper functions', () {
      for (final token in const [
        'is_strict_recap_manager_exempt',
        'resolve_strict_recap_break_allowance_minutes',
        'resolve_strict_recap_primary_status',
      ]) {
        expect(
          sql.contains(token),
          isTrue,
          reason: 'Missing strict recap helper: $token',
        );
      }
    });

    test('widens the recap payload with strict fields', () {
      for (final token in const [
        'primary_status',
        'primary_severity',
        'detail_signals',
        'detail_notes',
        'is_manager_exempt',
        'logical_day_complete',
        'net_work_minutes',
        'total_break_minutes',
        'overtime_minutes',
        'short_work_minutes',
        'excess_break_minutes',
        'paired_break_count',
      ]) {
        expect(
          sql.contains(token),
          isTrue,
          reason: 'Missing widened recap token: $token',
        );
      }
    });

    test('contains overnight grouping and exemption keywords', () {
      for (final token in const [
        'operating_mode',
        'TWENTY_FOUR_HOUR',
        'belum_absen_pulang',
        'kepala toko',
        'kepala gerai',
      ]) {
        expect(
          sql.contains(token),
          isTrue,
          reason: 'Missing overnight or exemption token: $token',
        );
      }
    });
  });
}
