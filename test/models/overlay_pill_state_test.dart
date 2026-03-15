import 'dart:convert';

import 'package:absensi_enakko_flutter/models/overlay_pill_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OverlayPillState.fromRaw', () {
    test('parses v1 idle JSON payload into typed state', () {
      final raw = jsonEncode({
        'v': 1,
        'mode': 'idle',
        'outlet': 'Gerai Cihampelas',
        'time': '08:30',
        'attendanceType': 'masuk',
        'accentHex': '#22C55E',
        'eventUntilEpochMs': 0,
        'expanded': true,
      });

      final state = OverlayPillState.fromRaw(raw);

      expect(state.mode, OverlayPillMode.idle);
      expect(state.outlet, 'Gerai Cihampelas');
      expect(state.time, '08:30');
      expect(state.attendanceType, 'masuk');
      expect(state.accentHex, '#22C55E');
      expect(state.eventUntilEpochMs, 0);
      expect(state.expanded, isTrue);
    });

    test('parses v1 event JSON payload into typed state', () {
      final raw = jsonEncode({
        'v': 1,
        'mode': 'event',
        'outlet': 'Gerai Sudirman',
        'time': '11:45',
        'attendanceType': 'pulang',
        'accentHex': '#6B7280',
        'eventUntilEpochMs': 1710000000000,
        'expanded': false,
      });

      final state = OverlayPillState.fromRaw(raw);

      expect(state.mode, OverlayPillMode.event);
      expect(state.outlet, 'Gerai Sudirman');
      expect(state.time, '11:45');
      expect(state.attendanceType, 'pulang');
      expect(state.accentHex, '#6B7280');
      expect(state.eventUntilEpochMs, 1710000000000);
      expect(state.expanded, isFalse);
    });

    test('parses legacy outlet|HH:mm payload as safe idle fallback', () {
      final state = OverlayPillState.fromRaw('Gerai Dipatiukur|09:15');

      expect(state.mode, OverlayPillMode.idle);
      expect(state.outlet, 'Gerai Dipatiukur');
      expect(state.time, '09:15');
      expect(state.attendanceType, 'masuk');
      expect(state.accentHex, '#22C55E');
    });

    test('handles malformed JSON without throwing and returns defaults', () {
      final state = OverlayPillState.fromRaw('{this-is-not-valid-json');

      expect(state.mode, OverlayPillMode.idle);
      expect(state.outlet, 'Absensi Enakko');
      expect(state.time, '--:--');
      expect(state.attendanceType, 'masuk');
      expect(state.accentHex, '#22C55E');
      expect(state.eventUntilEpochMs, 0);
      expect(state.expanded, isTrue);
    });
  });

  group('OverlayPillState serialization', () {
    test('toWirePayload serializes v1 schema fields', () {
      final state = OverlayPillState(
        mode: OverlayPillMode.event,
        outlet: 'Gerai Riau',
        time: '13:00',
        attendanceType: 'kembali',
        accentHex: '#3B82F6',
        eventUntilEpochMs: 1700000000000,
        expanded: false,
      );

      final payload = state.toWirePayload();
      final decoded = jsonDecode(payload) as Map<String, dynamic>;

      expect(decoded['v'], 1);
      expect(decoded['mode'], 'event');
      expect(decoded['outlet'], 'Gerai Riau');
      expect(decoded['time'], '13:00');
      expect(decoded['attendanceType'], 'kembali');
      expect(decoded['accentHex'], '#3B82F6');
      expect(decoded['eventUntilEpochMs'], 1700000000000);
      expect(decoded['expanded'], isFalse);
    });
  });

  group('OverlayPillState event expiry helper', () {
    test('returns true when eventUntilEpochMs is in the past for event mode', () {
      final state = OverlayPillState(
        mode: OverlayPillMode.event,
        outlet: 'Gerai Setiabudi',
        time: '15:00',
        attendanceType: 'break',
        accentHex: '#F59E0B',
        eventUntilEpochMs: 1000,
      );

      expect(
        state.isEventExpiredAt(DateTime.fromMillisecondsSinceEpoch(1001)),
        isTrue,
      );
    });

    test('returns false when event is still active', () {
      final state = OverlayPillState(
        mode: OverlayPillMode.event,
        outlet: 'Gerai Setiabudi',
        time: '15:00',
        attendanceType: 'break',
        accentHex: '#F59E0B',
        eventUntilEpochMs: 2000,
      );

      expect(
        state.isEventExpiredAt(DateTime.fromMillisecondsSinceEpoch(1500)),
        isFalse,
      );
    });

    test('returns false for idle mode', () {
      final state = OverlayPillState(
        mode: OverlayPillMode.idle,
        outlet: 'Gerai Setiabudi',
        time: '15:00',
        attendanceType: 'masuk',
        accentHex: '#22C55E',
        eventUntilEpochMs: 1000,
      );

      expect(
        state.isEventExpiredAt(DateTime.fromMillisecondsSinceEpoch(999999)),
        isFalse,
      );
    });
  });

  group('OverlayPillState displayLabel', () {
    test('v1 JSON with displayLabel field parses displayLabel correctly', () {
      final raw = jsonEncode({
        'v': 1,
        'mode': 'idle',
        'outlet': 'Gerai Cihampelas',
        'time': '08:30',
        'attendanceType': 'masuk',
        'accentHex': '#22C55E',
        'eventUntilEpochMs': 0,
        'expanded': true,
        'displayLabel': '🍽️ Budi istirahat',
      });

      final state = OverlayPillState.fromRaw(raw);

      expect(state.displayLabel, '🍽️ Budi istirahat');
    });

    test('v1 JSON WITHOUT displayLabel defaults to empty string (backward compat)', () {
      final raw = jsonEncode({
        'v': 1,
        'mode': 'idle',
        'outlet': 'Gerai Cihampelas',
        'time': '08:30',
        'attendanceType': 'masuk',
        'accentHex': '#22C55E',
        'eventUntilEpochMs': 0,
        'expanded': true,
      });

      final state = OverlayPillState.fromRaw(raw);

      expect(state.displayLabel, '');
    });

    test('toWirePayload includes displayLabel in output map', () {
      final state = OverlayPillState(
        mode: OverlayPillMode.event,
        outlet: 'Gerai Riau',
        time: '13:00',
        attendanceType: 'kembali',
        accentHex: '#3B82F6',
        eventUntilEpochMs: 1700000000000,
        expanded: false,
        displayLabel: 'Hari ini 12/14 hadir 🎉',
      );

      final payload = state.toWirePayload();
      final decoded = jsonDecode(payload) as Map<String, dynamic>;

      expect(decoded['displayLabel'], 'Hari ini 12/14 hadir 🎉');
    });

    test('displayLabel round-trip: construct → toWirePayload → fromRaw → matches', () {
      final original = OverlayPillState(
        mode: OverlayPillMode.idle,
        outlet: 'Gerai Bandung',
        time: '10:00',
        attendanceType: 'masuk',
        accentHex: '#22C55E',
        displayLabel: '🍽️ Sari istirahat',
      );

      final payload = original.toWirePayload();
      final restored = OverlayPillState.fromRaw(payload);

      expect(restored.displayLabel, '🍽️ Sari istirahat');
      expect(restored.outlet, 'Gerai Bandung');
      expect(restored.time, '10:00');
    });

    test('legacy delimiter payload → displayLabel is empty string', () {
      final state = OverlayPillState.fromRaw('Gerai Dipatiukur|09:15');

      expect(state.displayLabel, '');
    });

    test('defaults() → displayLabel is empty string', () {
      final state = OverlayPillState.defaults();

      expect(state.displayLabel, '');
    });
  });
}
