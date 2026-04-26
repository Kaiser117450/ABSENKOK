import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/kiosk_scan_context.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';
import 'package:absensi_enakko_flutter/services/kiosk_scan_authority_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KioskScanAuthorityService', () {
    test('unwraps nested data payloads for context responses', () {
      final context = KioskScanAuthorityService.parseContext({
        'data': {
          'data': {
            'server_now_utc': '2026-03-27T02:15:00Z',
            'server_now_wita_label': '10:15 WITA',
            'logical_date': '2026-03-27',
            'last_authoritative_type': 'break',
            'last_authoritative_scanned_at': '2026-03-27T01:55:00Z',
            'shift_band': 'SIANG',
            'employment_contract': 'PARTTIME',
            'late_cutoff_local': '10:00',
            'break_first_deadline_local': '11:00',
            'break_first_eligible': true,
          },
        },
      });

      expect(context.serverNowWitaLabel, '10:15 WITA');
      expect(context.logicalDate, DateTime(2026, 3, 27));
      expect(context.lastAuthoritativeType, AttendanceType.breakTime);
      expect(
        context.lastAuthoritativeScannedAt,
        DateTime.parse('2026-03-27T01:55:00Z'),
      );
      expect(context.shiftBand, ShiftBand.siang);
      expect(context.employmentContract, EmployeeContract.parttime);
      expect(context.lateCutoffLocal, '10:00');
    });

    test('maps record results with authority state and review flags', () {
      final result = KioskScanAuthorityService.parseRecordResult({
        'data': {
          'data': {
            'authority_state': 'live_confirmed',
            'scanned_at_utc': '2026-03-27T03:05:00Z',
            'scanned_at_wita_label': '11:05 WITA',
            'recorded_type': 'masuk',
            'initial_scan_intent': 'break_first',
            'requires_admin_review': true,
          },
        },
      });

      expect(result.authorityState, KioskScanAuthorityState.liveConfirmed);
      expect(result.scannedAtUtc, DateTime.parse('2026-03-27T03:05:00Z'));
      expect(result.scannedAtWitaLabel, '11:05 WITA');
      expect(result.recordedType, AttendanceType.masuk);
      expect(result.initialScanIntent, InitialScanIntent.none);
      expect(result.requiresAdminReview, isTrue);
    });

    test('missing optional result columns degrade safely', () {
      final result = KioskScanAuthorityService.parseRecordResult({
        'authority_state': 'duplicate_local_id',
        'recorded_type': 'break',
      });

      expect(result.authorityState, KioskScanAuthorityState.duplicateLocalId);
      expect(result.scannedAtUtc, isNull);
      expect(result.scannedAtWitaLabel, isEmpty);
      expect(result.recordedType, AttendanceType.breakTime);
      expect(result.initialScanIntent, InitialScanIntent.none);
      expect(result.requiresAdminReview, isFalse);
    });

    test('attendance logs default new authority fields when columns are absent',
        () {
      final log = AttendanceLog.fromJson({
        'id': 'log-1',
        'employee_id': 'employee-1',
        'scan_outlet_id': 'outlet-1',
        'type': 'masuk',
        'scanned_at': '2026-03-27T01:00:00Z',
        'created_at': '2026-03-27T01:00:00Z',
      });

      expect(log.deviceCapturedAt, isNull);
      expect(log.captureMode, AttendanceCaptureMode.live);
      expect(log.queueOrder, isNull);
      expect(log.initialScanIntent, InitialScanIntent.none);
      expect(log.requiresAdminReview, isFalse);
    });
  });
}
