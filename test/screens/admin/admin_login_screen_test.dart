import 'package:absensi_enakko_flutter/screens/admin/admin_login_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canUseBiometricLogin', () {
    test('requires a trusted privileged session', () {
      expect(
        canUseBiometricLogin(
          hasBiometricHardware: true,
          biometricEnabled: true,
          hasTrustedAdminSession: false,
        ),
        isFalse,
      );
    });

    test(
        'returns true only when hardware, preference, and trusted claims exist',
        () {
      expect(
        canUseBiometricLogin(
          hasBiometricHardware: true,
          biometricEnabled: true,
          hasTrustedAdminSession: true,
        ),
        isTrue,
      );
    });

    test('returns false when biometric preference is disabled', () {
      expect(
        canUseBiometricLogin(
          hasBiometricHardware: true,
          biometricEnabled: false,
          hasTrustedAdminSession: true,
        ),
        isFalse,
      );
    });

    test('returns false when biometric hardware is unavailable', () {
      expect(
        canUseBiometricLogin(
          hasBiometricHardware: false,
          biometricEnabled: true,
          hasTrustedAdminSession: true,
        ),
        isFalse,
      );
    });
  });
}
