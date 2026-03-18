import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_enakko_flutter/services/missing_clockout_service.dart';

void main() {
  group('MissingClockoutService', () {
    group('formatNotificationBody', () {
      test('returns correct body for count=3 and outlet name', () {
        final result = MissingClockoutService.formatNotificationBody(
          3,
          'Outlet Dago',
        );
        expect(result, '3 karyawan belum scan pulang di Outlet Dago');
      });

      test('returns correct body for count=1 and different outlet name', () {
        final result = MissingClockoutService.formatNotificationBody(
          1,
          'Outlet Cipaganti',
        );
        expect(result, '1 karyawan belum scan pulang di Outlet Cipaganti');
      });
    });

    group('shouldNotify', () {
      test('returns false when missing list is empty', () {
        expect(MissingClockoutService.shouldNotify([]), isFalse);
      });

      test('returns true when missing list has 1 entry', () {
        expect(
          MissingClockoutService.shouldNotify([
            {'employee_id': 'x'},
          ]),
          isTrue,
        );
      });

      test('returns true when missing list has multiple entries', () {
        expect(
          MissingClockoutService.shouldNotify([
            {'a': 1},
            {'b': 2},
            {'c': 3},
          ]),
          isTrue,
        );
      });
    });

    group('groupByOutlet', () {
      test('correctly groups MissingClockout entries by outletId', () {
        final entries = [
          MissingClockoutEntry(
            employeeId: 'emp-1',
            employeeName: 'Andi',
            outletId: 'outlet-a',
            masukTime: DateTime(2026, 3, 18, 8, 0),
          ),
          MissingClockoutEntry(
            employeeId: 'emp-2',
            employeeName: 'Budi',
            outletId: 'outlet-b',
            masukTime: DateTime(2026, 3, 18, 9, 0),
          ),
          MissingClockoutEntry(
            employeeId: 'emp-3',
            employeeName: 'Citra',
            outletId: 'outlet-a',
            masukTime: DateTime(2026, 3, 18, 7, 30),
          ),
        ];

        final grouped = MissingClockoutService.groupByOutlet(entries);

        expect(grouped.keys.length, 2);
        expect(grouped['outlet-a']?.length, 2);
        expect(grouped['outlet-b']?.length, 1);
        expect(
          grouped['outlet-a']?.map((e) => e.employeeId).toList(),
          containsAll(['emp-1', 'emp-3']),
        );
        expect(grouped['outlet-b']?.first.employeeId, 'emp-2');
      });
    });
  });
}
