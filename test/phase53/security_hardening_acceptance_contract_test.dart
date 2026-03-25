import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const helperPath = 'tool/security_hardening_acceptance.ps1';

  const requiredFlutterCommands = <String>[
    'test/phase50/kiosk_device_model_test.dart',
    'test/phase51/admin_session_claims_test.dart',
    'test/phase51/sql_role_guard_contract_test.dart',
    'test/phase52/portal_recovery_contract_test.dart',
  ];

  const requiredAstroCommands = <String>[
    'npm run check',
    'npm run build',
  ];

  group('Phase 53 security hardening acceptance contract', () {
    late File helperFile;
    late String script;

    setUpAll(() {
      helperFile = File(helperPath);
      if (helperFile.existsSync()) {
        script = helperFile.readAsStringSync();
      } else {
        script = '';
      }
    });

    test('helper script exists at tool/security_hardening_acceptance.ps1', () {
      expect(
        helperFile.existsSync(),
        isTrue,
        reason: 'Expected $helperPath to be present as the Phase 53 acceptance helper.',
      );
    });

    test('helper script contains all four focused Flutter test commands', () {
      for (final testPath in requiredFlutterCommands) {
        expect(
          script.contains(testPath),
          isTrue,
          reason: 'Missing Flutter test command for: $testPath',
        );
      }
    });

    test('helper script contains npm run check and npm run build Astro commands', () {
      for (final cmd in requiredAstroCommands) {
        // The script stores 'npm' and args separately; check key tokens
        final parts = cmd.split(' ');
        final lastPart = parts.last; // 'check' or 'build'
        expect(
          script.contains("'run', '$lastPart'") ||
              script.contains('"run", "$lastPart"') ||
              script.contains("'run $lastPart'") ||
              script.contains(cmd),
          isTrue,
          reason: 'Missing Astro command: $cmd',
        );
      }
    });

    test('helper script exposes -CheckOnly parameter', () {
      expect(
        script.contains('CheckOnly'),
        isTrue,
        reason: 'Helper must expose a -CheckOnly parameter to preview without executing.',
      );
    });

    test(
        'helper script does not treat repair_employee_portal_accounts_20260325.sql as an executable rollout step',
        () {
      // The recovery SQL filename may appear in comments or reminder text, but
      // must not appear as an argument to a command (Cmd/Args invocation block).
      // We check that it is not inside a command Args array.
      final sqlFile = 'repair_employee_portal_accounts_20260325.sql';

      // Acceptable: appears in a Write-Host string (documentation/reminder).
      // Not acceptable: appears inside an @{ ... Args = @(...) } command block.
      final commandBlockPattern = RegExp(
        r"@\{[^}]*Args\s*=\s*@\([^)]*repair_employee_portal_accounts_20260325\.sql[^)]*\)",
        dotAll: true,
      );

      expect(
        commandBlockPattern.hasMatch(script),
        isFalse,
        reason:
            'The recovery SQL file must not be part of the executable acceptance command surface.',
      );
    });
  });
}
