import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath = 'sql/phase_51_admin_session_trust_20260325.sql';
  const affectedFunctions = <String>[
    'get_attendance_rates',
    'get_weekly_trend',
    'get_outlet_comparison',
    'update_employee_streak',
    'get_overtime_flags',
    'get_missing_clockouts',
    'get_arrival_patterns',
  ];
  const functionSignatures = <String, String>{
    'get_attendance_rates':
        'get_attendance_rates(UUID, TIMESTAMPTZ, TIMESTAMPTZ)',
    'get_weekly_trend': 'get_weekly_trend(UUID, INT)',
    'get_outlet_comparison': 'get_outlet_comparison(TIMESTAMPTZ, TIMESTAMPTZ)',
    'update_employee_streak': 'update_employee_streak(UUID)',
    'get_overtime_flags': 'get_overtime_flags(UUID, DATE, NUMERIC)',
    'get_missing_clockouts': 'get_missing_clockouts(UUID, NUMERIC)',
    'get_arrival_patterns': 'get_arrival_patterns(UUID, INT)',
  };

  group('Phase 51 SQL role guard contract', () {
    late File migrationFile;
    late String sql;

    setUpAll(() {
      migrationFile = File(migrationPath);
      if (migrationFile.existsSync()) {
        sql = migrationFile.readAsStringSync();
      } else {
        sql = '';
      }
    });

    test('migration file exists', () {
      expect(
        migrationFile.existsSync(),
        isTrue,
        reason: 'Expected $migrationPath to be present for the Phase 51 rollout.',
      );
    });

    test('defines the affected functions with the expected names', () {
      final createFunctionMatches = RegExp(
        r'CREATE OR REPLACE FUNCTION\s+([a-z_]+)\s*\(',
        multiLine: true,
      ).allMatches(sql);

      final createdFunctions = createFunctionMatches
          .map((match) => match.group(1))
          .whereType<String>()
          .toList();

      expect(createdFunctions, hasLength(affectedFunctions.length));
      expect(createdFunctions, orderedEquals(affectedFunctions));
    });

    test('contains null-safe role guards', () {
      expect(
        sql.contains('IS DISTINCT FROM') || sql.contains('v_role IS NULL'),
        isTrue,
        reason: 'Phase 51 must fail closed on null or invalid role claims.',
      );
    });

    test('preserves explicit revoke and grant statements', () {
      for (final entry in functionSignatures.entries) {
        final signature = entry.value;

        expect(
          sql.contains('REVOKE ALL ON FUNCTION $signature FROM PUBLIC;'),
          isTrue,
          reason: 'Missing REVOKE ALL contract for ${entry.key}.',
        );
        expect(
          sql.contains('GRANT EXECUTE ON FUNCTION $signature TO authenticated;'),
          isTrue,
          reason: 'Missing GRANT EXECUTE contract for ${entry.key}.',
        );
      }
    });

    test('does not trust writable user metadata', () {
      expect(
        sql.toLowerCase().contains('user_metadata'),
        isFalse,
        reason: 'Phase 51 migration must rely on app_metadata only.',
      );
    });
  });
}
