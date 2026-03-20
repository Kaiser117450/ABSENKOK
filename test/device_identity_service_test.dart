import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_enakko_flutter/services/device_identity_service.dart'; // ignore: depend_on_referenced_packages

void main() {
  group('DeviceIdentityService', () {
    group('isValidUuidV4', () {
      test('accepts valid UUIDv4', () {
        expect(
          DeviceIdentityService.isValidUuidV4('550e8400-e29b-41d4-a716-446655440000'),
          isTrue,
        );
      });

      test('accepts lowercase UUIDv4', () {
        expect(
          DeviceIdentityService.isValidUuidV4('6ba7b810-9dad-41d3-80b4-00c04fd430c8'),
          isTrue,
        );
      });

      test('accepts uppercase UUIDv4', () {
        expect(
          DeviceIdentityService.isValidUuidV4('6BA7B810-9DAD-41D3-80B4-00C04FD430C8'),
          isTrue,
        );
      });

      test('rejects old 12-char format', () {
        expect(
          DeviceIdentityService.isValidUuidV4('abc123def456'),
          isFalse,
        );
      });

      test('rejects empty string', () {
        expect(
          DeviceIdentityService.isValidUuidV4(''),
          isFalse,
        );
      });

      test('rejects UUIDv1 (version digit != 4)', () {
        expect(
          DeviceIdentityService.isValidUuidV4('550e8400-e29b-11d4-a716-446655440000'),
          isFalse,
        );
      });

      test('rejects UUID with invalid variant bits', () {
        // variant bits must be 8, 9, a, or b in position 19
        expect(
          DeviceIdentityService.isValidUuidV4('550e8400-e29b-41d4-c716-446655440000'),
          isFalse,
        );
      });

      test('rejects string with wrong length', () {
        expect(
          DeviceIdentityService.isValidUuidV4('550e8400-e29b-41d4-a716'),
          isFalse,
        );
      });
    });
  });
}
