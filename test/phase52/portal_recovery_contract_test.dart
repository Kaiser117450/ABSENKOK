import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const scriptPath = 'sql/repair_employee_portal_accounts_20260325.sql';

  group('Phase 52 portal recovery contract', () {
    late File recoveryScriptFile;
    late String sql;

    setUpAll(() {
      recoveryScriptFile = File(scriptPath);
      if (recoveryScriptFile.existsSync()) {
        sql = recoveryScriptFile.readAsStringSync();
      } else {
        sql = '';
      }
    });

    test('recovery script exists', () {
      expect(
        recoveryScriptFile.existsSync(),
        isTrue,
        reason: 'Expected $scriptPath to exist for Phase 52 portal recovery hardening.',
      );
    });

    test('requires confirmed portal auth users', () {
      expect(
        sql.contains('u.email_confirmed_at IS NOT NULL'),
        isTrue,
        reason: 'Recovery must require confirmed hidden portal identities.',
      );
    });

    test('requires employee_portal role metadata', () {
      expect(
        sql.contains('employee_portal'),
        isTrue,
        reason: 'Recovery must only restore employee_portal auth users.',
      );
    });

    test('requires explicit employee_id binding metadata', () {
      expect(
        sql.contains('employee_id'),
        isTrue,
        reason: 'Recovery must require explicit employee_id metadata.',
      );
    });

    test('does not unconditionally overwrite employee mapping auth_user_id', () {
      expect(
        sql.contains('auth_user_id = EXCLUDED.auth_user_id'),
        isFalse,
        reason: 'Recovery must not opportunistically repoint employee mappings.',
      );
    });
  });
}
