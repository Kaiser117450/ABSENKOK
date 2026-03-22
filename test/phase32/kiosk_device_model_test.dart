import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_enakko_flutter/models/kiosk_device.dart';

void main() {
  group('KioskDevice model', () {
    final fullJson = {
      'id': 'abc123',
      'device_uuid': 'uuid-1234-5678-abcd',
      'outlet_id': 'outlet-001',
      'last_heartbeat_at': '2026-03-22T10:00:00.000Z',
      'battery_level': 85,
      'is_charging': true,
      'pending_sync_count': 3,
      'app_version': '6.0.0+100',
      'nickname': 'Kiosk Depan',
      'is_active': true,
    };

    test('fromJson parses all fields correctly', () {
      final device = KioskDevice.fromJson(fullJson);
      expect(device.id, 'abc123');
      expect(device.deviceUuid, 'uuid-1234-5678-abcd');
      expect(device.outletId, 'outlet-001');
      expect(device.lastHeartbeatAt, isNotNull);
      expect(device.batteryLevel, 85);
      expect(device.isCharging, true);
      expect(device.pendingSyncCount, 3);
      expect(device.appVersion, '6.0.0+100');
      expect(device.nickname, 'Kiosk Depan');
      expect(device.isActive, true);
    });

    test('fromJson handles null optional fields', () {
      final minimalJson = {
        'id': 'abc123',
        'device_uuid': 'uuid-1234-5678-abcd',
        'outlet_id': null,
        'last_heartbeat_at': null,
        'battery_level': null,
        'is_charging': null,
        'pending_sync_count': null,
        'app_version': null,
        'nickname': null,
        'is_active': null,
      };
      final device = KioskDevice.fromJson(minimalJson);
      expect(device.outletId, isNull);
      expect(device.lastHeartbeatAt, isNull);
      expect(device.batteryLevel, isNull);
      expect(device.isCharging, isNull);
      expect(device.pendingSyncCount, isNull);
      expect(device.appVersion, isNull);
      expect(device.nickname, isNull);
      expect(device.isActive, true); // default
    });

    test('isOnline returns true when heartbeat within 30 minutes', () {
      final recentJson = {
        ...fullJson,
        'last_heartbeat_at': DateTime.now()
            .subtract(const Duration(minutes: 5))
            .toUtc()
            .toIso8601String(),
      };
      final device = KioskDevice.fromJson(recentJson);
      expect(device.isOnline, true);
    });

    test('isOnline returns false when lastHeartbeatAt is null', () {
      final device = KioskDevice.fromJson({...fullJson, 'last_heartbeat_at': null});
      expect(device.isOnline, false);
    });

    test('isOnline returns false when heartbeat is 31+ minutes ago', () {
      final staleJson = {
        ...fullJson,
        'last_heartbeat_at': DateTime.now()
            .subtract(const Duration(minutes: 31))
            .toUtc()
            .toIso8601String(),
      };
      final device = KioskDevice.fromJson(staleJson);
      expect(device.isOnline, false);
    });

    test('copyWith overrides nickname', () {
      final device = KioskDevice.fromJson(fullJson);
      final updated = device.copyWith(nickname: 'Kiosk Belakang');
      expect(updated.nickname, 'Kiosk Belakang');
      expect(updated.id, device.id); // unchanged fields
    });

    test('displayName returns nickname when set', () {
      final device = KioskDevice.fromJson(fullJson);
      expect(device.displayName, 'Kiosk Depan');
    });

    test('displayName returns "Kiosk {uuid[0:8]}" when no nickname', () {
      final device = KioskDevice.fromJson({...fullJson, 'nickname': null});
      expect(device.displayName, 'Kiosk uuid-123');
    });
  });
}
