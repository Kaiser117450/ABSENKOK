import 'package:absensi_enakko_flutter/core/admin_session_claims.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminSessionClaims.fromMetadata', () {
    test('resolves admin from app metadata', () {
      final claims = AdminSessionClaims.fromMetadata(
        appMetadata: const {'app_role': 'admin'},
      );

      expect(claims, isNotNull);
      expect(claims!.isAdmin, isTrue);
      expect(claims.isKepalaGerai, isFalse);
      expect(claims.managedOutletId, isNull);
    });

    test('resolves kepala gerai only with managed outlet id', () {
      final claims = AdminSessionClaims.fromMetadata(
        appMetadata: const {
          'app_role': 'kepala_gerai',
          'managed_outlet_id': 'outlet-1',
        },
      );

      expect(claims, isNotNull);
      expect(claims!.isAdmin, isFalse);
      expect(claims.isKepalaGerai, isTrue);
      expect(claims.managedOutletId, 'outlet-1');
    });

    test('rejects kepala gerai without managed outlet id', () {
      expect(
        AdminSessionClaims.fromMetadata(
          appMetadata: const {'app_role': 'kepala_gerai'},
        ),
        isNull,
      );

      expect(
        AdminSessionClaims.fromMetadata(
          appMetadata: const {
            'app_role': 'kepala_gerai',
            'managed_outlet_id': '',
          },
        ),
        isNull,
      );
    });

    test('rejects unknown roles', () {
      expect(
        AdminSessionClaims.fromMetadata(
          appMetadata: const {'app_role': 'employee'},
        ),
        isNull,
      );
    });

    test('ignores writable user metadata entirely', () {
      final claims = AdminSessionClaims.fromMetadata(
        appMetadata: const {'app_role': 'employee'},
        userMetadata: const {
          'app_role': 'admin',
          'managed_outlet_id': 'outlet-from-user-metadata',
        },
      );

      expect(claims, isNull);
    });
  });
}
