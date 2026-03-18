import 'package:absensi_enakko_flutter/screens/admin/admin_login_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canUseBiometricLogin', () {
    test('requires an active Supabase session', () {
      expect(
        canUseBiometricLogin(
          hasBiometricHardware: true,
          biometricEnabled: true,
          hasSupabaseSession: false,
        ),
        isFalse,
      );
    });

    test('returns true only when hardware, preference, and session exist', () {
      expect(
        canUseBiometricLogin(
          hasBiometricHardware: true,
          biometricEnabled: true,
          hasSupabaseSession: true,
        ),
        isTrue,
      );
    });

    test('returns false when biometric preference is disabled', () {
      expect(
        canUseBiometricLogin(
          hasBiometricHardware: true,
          biometricEnabled: false,
          hasSupabaseSession: true,
        ),
        isFalse,
      );
    });
  });
}
