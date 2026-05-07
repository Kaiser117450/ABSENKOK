import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/kiosk_scan_context.dart';
import 'package:absensi_enakko_flutter/models/pending_log.dart';
import 'package:absensi_enakko_flutter/services/kiosk_scan_authority_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiosk scan photo beta model contract', () {
    test(
        'record request keeps legacy RPC params unless photo params are opted in',
        () {
      const request = KioskScanRecordRequest(
        employeeId: 'employee-1',
        outletId: 'outlet-1',
        deviceId: 'device-1',
        type: AttendanceType.masuk,
        localId: 'local-1',
        photoRequired: true,
        selfieUrl:
            'https://example.supabase.co/storage/v1/object/public/attendance-photos/outlet-1/employee-1/2026-05-07/log-1.jpg',
      );

      expect(request.toRpcParams(), isNot(contains('p_photo_required')));
      expect(request.toRpcParams(), isNot(contains('p_selfie_url')));

      final betaParams = request.toRpcParams(includePhotoParams: true);
      expect(betaParams['p_photo_required'], isTrue);
      expect(
        betaParams['p_selfie_url'],
        endsWith('/attendance-photos/outlet-1/employee-1/2026-05-07/log-1.jpg'),
      );
    });

    test('pending log maps local photo queue fields', () {
      final log = PendingLog.fromMap({
        'local_id': 'local-1',
        'employee_id': 'employee-1',
        'scan_outlet_id': 'outlet-1',
        'type': 'masuk',
        'lat': null,
        'lng': null,
        'device_id': 'device-1',
        'scanned_at': '2026-05-07T00:30:00Z',
        'device_captured_at': '2026-05-07T00:30:00Z',
        'capture_mode': 'queued',
        'queue_order': 7,
        'initial_scan_intent': 'none',
        'sync_status': 'pending',
        'retry_count': 1,
        'created_at': '2026-05-07T00:30:00Z',
        'is_backup': 0,
        'notes': null,
        'local_photo_path': 'attendance_photo_queue/outlet-1/photo.jpg',
        'photo_retry_count': 2,
      });

      expect(log.localPhotoPath, 'attendance_photo_queue/outlet-1/photo.jpg');
      expect(log.photoRetryCount, 2);
      expect(log.toMap()['local_photo_path'], log.localPhotoPath);
      expect(log.toMap()['photo_retry_count'], 2);
    });

    test('recorded log ref parser unwraps nested RPC rows', () {
      final ref = KioskScanAuthorityService.parseRecordedLogRef({
        'data': {
          'data': [
            {
              'log_id': '11111111-1111-1111-1111-111111111111',
              'scanned_at_utc': '2026-05-07T00:30:00Z',
              'logical_date': '2026-05-07',
            },
          ],
        },
      });

      expect(ref.logId, '11111111-1111-1111-1111-111111111111');
      expect(ref.scannedAtUtc, DateTime.parse('2026-05-07T00:30:00Z'));
      expect(ref.logicalDate, DateTime(2026, 5, 7));
    });
  });
}
