import 'package:absensi_enakko_flutter/models/kiosk_device.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KioskDevice Phase 50 safety', () {
    Map<String, dynamic> buildJson({
      Object? deviceUuid = '123e4567-e89b-12d3-a456-426614174000',
      Object? lastHeartbeatAt = '2026-03-22T10:00:00.000Z',
      Object? nickname,
    }) {
      return {
        'id': 'device-1',
        'device_uuid': deviceUuid,
        'outlet_id': 'outlet-1',
        'last_heartbeat_at': lastHeartbeatAt,
        'battery_level': 82,
        'is_charging': true,
        'pending_sync_count': 2,
        'app_version': '7.0.0+8013',
        'nickname': nickname,
        'is_active': true,
      };
    }

    test('null device_uuid does not throw and falls back safely', () {
      final device = KioskDevice.fromJson(buildJson(deviceUuid: null));

      expect(device.deviceUuid, '');
      expect(device.displayName, 'Kiosk');
    });

    test('empty device_uuid does not throw and falls back safely', () {
      final device = KioskDevice.fromJson(buildJson(deviceUuid: ''));

      expect(device.displayName, 'Kiosk');
    });

    test('short device_uuid does not throw or slice out of range', () {
      final device = KioskDevice.fromJson(buildJson(deviceUuid: 'abc'));

      expect(device.displayName, 'Kiosk');
    });

    test('malformed last_heartbeat_at becomes null instead of crashing', () {
      final device =
          KioskDevice.fromJson(buildJson(lastHeartbeatAt: 'not-a-timestamp'));

      expect(device.lastHeartbeatAt, isNull);
    });

    test('trimmed nickname wins over the UUID fallback', () {
      final device =
          KioskDevice.fromJson(buildJson(nickname: '  Kiosk Pintu Depan  '));

      expect(device.displayName, 'Kiosk Pintu Depan');
    });

    test('long device_uuid keeps the familiar short label', () {
      final device = KioskDevice.fromJson(buildJson(nickname: null));

      expect(device.displayName, 'Kiosk 123e4567');
    });
  });
}
