import 'package:absensi_enakko_flutter/services/photo_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhotoUploadService storage paths', () {
    test('uses outlet employee date and log id convention', () {
      final path = PhotoUploadService.instance.buildStoragePath(
        outletId: 'outlet-1',
        employeeId: 'employee-9',
        logDate: DateTime(2026, 5, 7, 23, 59),
        logId: '11111111-1111-1111-1111-111111111111',
      );

      expect(
        path,
        'outlet-1/employee-9/2026-05-07/'
        '11111111-1111-1111-1111-111111111111.jpg',
      );
    });

    test('sanitizes unsafe path segments', () {
      final path = PhotoUploadService.instance.buildStoragePath(
        outletId: ' Outlet A/../../x ',
        employeeId: 'emp:42',
        logDate: DateTime(2026, 5, 7),
        logId: 'log/with spaces',
      );

      expect(path, 'Outlet_A_.._.._x/emp_42/2026-05-07/log_with_spaces.jpg');
      expect(path.split('/'), hasLength(4));
    });
  });
}
