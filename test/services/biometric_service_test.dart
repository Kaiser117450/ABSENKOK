import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_enakko_flutter/services/biometric_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiometricService', () {
    test('isAvailable returns false when not supported', () async {
      // local_auth uses platform channels; in test environment
      // without mock setup, it should return false (Exception)
      final result = await BiometricService.isAvailable();
      expect(result, isFalse);
    });

    test('authenticate returns false when platform throws', () async {
      final result = await BiometricService.authenticate();
      expect(result, isFalse);
    });

    test('getAvailableTypes returns empty list on error', () async {
      final result = await BiometricService.getAvailableTypes();
      expect(result, isEmpty);
    });
  });
}
