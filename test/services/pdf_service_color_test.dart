import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:absensi_enakko_flutter/services/pdf_service.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/shift_schedule.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';
import 'package:flutter/material.dart';

/// Phase 8.1 — PDF Export Validation Tests
/// Tests status/type color mapping and label correctness
/// that ensure PDF output matches UI badge colors.

void main() {
  group('PdfService._statusTextColor — Rekap Harian PDF status colors', () {
    test('Sakit maps to red (#DC2626)', () {
      final color = PdfService.statusTextColorForTest('Sakit');
      expect(color, PdfColor.fromHex('DC2626'));
    });

    test('Izin maps to blue (#2563EB)', () {
      final color = PdfService.statusTextColorForTest('Izin');
      expect(color, PdfColor.fromHex('2563EB'));
    });

    test('Belum Pulang maps to amber (#D97706)', () {
      final color = PdfService.statusTextColorForTest('Belum Pulang');
      expect(color, PdfColor.fromHex('D97706'));
    });

    test('Hadir (default) maps to green (#16A34A)', () {
      final color = PdfService.statusTextColorForTest('Hadir');
      expect(color, PdfColor.fromHex('16A34A'));
    });

    test('unknown status falls through to green (default)', () {
      final color = PdfService.statusTextColorForTest('UnknownStatus');
      expect(color, PdfColor.fromHex('16A34A'));
    });

    test('empty string falls through to green (default)', () {
      final color = PdfService.statusTextColorForTest('');
      expect(color, PdfColor.fromHex('16A34A'));
    });
  });

  group('PdfService._typeTextColor — Per Scan PDF jenis colors', () {
    test('Masuk maps to green (#16A34A)', () {
      final color = PdfService.typeTextColorForTest('Masuk');
      expect(color, PdfColor.fromHex('16A34A'));
    });

    test('Istirahat maps to amber (#D97706)', () {
      final color = PdfService.typeTextColorForTest('Istirahat');
      expect(color, PdfColor.fromHex('D97706'));
    });

    test('Pulang maps to gray (#6B7280)', () {
      final color = PdfService.typeTextColorForTest('Pulang');
      expect(color, PdfColor.fromHex('6B7280'));
    });

    test('Kembali maps to cyan (#0891B2)', () {
      final color = PdfService.typeTextColorForTest('Kembali');
      expect(color, PdfColor.fromHex('0891B2'));
    });

    test('Sakit maps to red (#DC2626)', () {
      final color = PdfService.typeTextColorForTest('Sakit');
      expect(color, PdfColor.fromHex('DC2626'));
    });

    test('Izin maps to blue (#2563EB)', () {
      final color = PdfService.typeTextColorForTest('Izin');
      expect(color, PdfColor.fromHex('2563EB'));
    });

    test('unknown jenis falls through to dark gray (#374151)', () {
      final color = PdfService.typeTextColorForTest('Lembur');
      expect(color, PdfColor.fromHex('374151'));
    });
  });

  group('Status/Type color uniqueness', () {
    test('all 4 status colors are distinct', () {
      final colors = [
        PdfService.statusTextColorForTest('Sakit'),
        PdfService.statusTextColorForTest('Izin'),
        PdfService.statusTextColorForTest('Belum Pulang'),
        PdfService.statusTextColorForTest('Hadir'),
      ];
      expect(colors.toSet().length, 4);
    });

    test('all 6 type colors are distinct', () {
      final colors = [
        PdfService.typeTextColorForTest('Masuk'),
        PdfService.typeTextColorForTest('Istirahat'),
        PdfService.typeTextColorForTest('Pulang'),
        PdfService.typeTextColorForTest('Kembali'),
        PdfService.typeTextColorForTest('Sakit'),
        PdfService.typeTextColorForTest('Izin'),
      ];
      expect(colors.toSet().length, 6);
    });
  });

  group('AttendanceDailyPdfStats DTO', () {
    test('can construct with all fields', () {
      final stats = AttendanceDailyPdfStats(
        totalKaryawan: 10,
        totalMasuk: 8,
        totalTidakHadir: 1,
        totalBelumPulang: 1,
        totalScan: 24,
        employeeRows: [
          const AttendanceDailyPdfEmployeeRow(
            nama: 'Alice',
            masukCount: 5,
            tidakHadirCount: 0,
            belumPulangCount: 1,
            avgMasukStr: '08:30',
            avgPulangStr: '17:15',
            totalKerjaStr: '40j 0m',
          ),
        ],
      );

      expect(stats.totalKaryawan, 10);
      expect(stats.totalMasuk, 8);
      expect(stats.totalTidakHadir, 1);
      expect(stats.totalBelumPulang, 1);
      expect(stats.totalScan, 24);
      expect(stats.employeeRows.length, 1);
      expect(stats.employeeRows.first.nama, 'Alice');
      expect(stats.employeeRows.first.masukCount, 5);
    });

    test('empty employeeRows is valid (no crash)', () {
      final stats = AttendanceDailyPdfStats(
        totalKaryawan: 0,
        totalMasuk: 0,
        totalTidakHadir: 0,
        totalBelumPulang: 0,
        totalScan: 0,
        employeeRows: [],
      );

      expect(stats.employeeRows, isEmpty);
      expect(stats.totalMasuk, 0);
      expect(stats.totalTidakHadir, 0);
      expect(stats.totalBelumPulang, 0);
    });
  });

  group('PdfService._getMostCommonRole — Role detection for schedule PDF', () {
    // Helper to create a shift slot for testing
    ShiftSlot createTestShift() => ShiftSlot(
          name: 'Pagi',
          band: ShiftBand.pagi,
          startTime: const TimeOfDay(hour: 7, minute: 0),
          endTime: const TimeOfDay(hour: 19, minute: 0),
          color: Colors.blue,
          requiredWorkMinutes: 600,
          lateCutoffHour: 7,
          lateCutoffMinute: 0,
          breakFirstDeadlineHour: 9,
          breakFirstDeadlineMinute: 0,
        );

    test('builds estimated window from contract and shift span', () {
      final shift = ShiftSlot.sore(contract: EmployeeContract.parttime);
      final label = PdfService.estimatedScheduleWindowForTest(
        shift: shift,
        contract: EmployeeContract.parttime,
      );

      expect(label, '13:00-22:00');
    });

    test('returns null for empty entries', () {
      final result = PdfService.getMostCommonRoleForTest([]);
      expect(result, isNull);
    });

    test('returns null when no entries have roles', () {
      final entries = [
        ScheduleEntry(
          id: '1',
          date: DateTime(2024, 1, 1),
          employeeId: 'emp1',
          displayName: 'John',
          isCustomName: false,
          shift: createTestShift(),
          role: null,
        ),
        ScheduleEntry(
          id: '2',
          date: DateTime(2024, 1, 2),
          employeeId: 'emp1',
          displayName: 'John',
          isCustomName: false,
          shift: createTestShift(),
          role: '',
        ),
      ];

      final result = PdfService.getMostCommonRoleForTest(entries);
      expect(result, isNull);
    });

    test('returns single role when all entries have same role', () {
      final entries = [
        ScheduleEntry(
          id: '1',
          date: DateTime(2024, 1, 1),
          employeeId: 'emp1',
          displayName: 'John',
          isCustomName: false,
          shift: createTestShift(),
          role: 'Kasir',
        ),
        ScheduleEntry(
          id: '2',
          date: DateTime(2024, 1, 2),
          employeeId: 'emp1',
          displayName: 'John',
          isCustomName: false,
          shift: createTestShift(),
          role: 'Kasir',
        ),
      ];

      final result = PdfService.getMostCommonRoleForTest(entries);
      expect(result, 'Kasir');
    });

    test('returns most common role when entries have different roles', () {
      final entries = [
        ScheduleEntry(
          id: '1',
          date: DateTime(2024, 1, 1),
          employeeId: 'emp1',
          displayName: 'John',
          isCustomName: false,
          shift: createTestShift(),
          role: 'Kasir',
        ),
        ScheduleEntry(
          id: '2',
          date: DateTime(2024, 1, 2),
          employeeId: 'emp1',
          displayName: 'John',
          isCustomName: false,
          shift: createTestShift(),
          role: 'Kasir',
        ),
        ScheduleEntry(
          id: '3',
          date: DateTime(2024, 1, 3),
          employeeId: 'emp1',
          displayName: 'John',
          isCustomName: false,
          shift: createTestShift(),
          role: 'Manager',
        ),
      ];

      final result = PdfService.getMostCommonRoleForTest(entries);
      expect(result, 'Kasir'); // 2 occurrences vs 1
    });

    test('returns first role when frequencies are tied', () {
      final entries = [
        ScheduleEntry(
          id: '1',
          date: DateTime(2024, 1, 1),
          employeeId: 'emp1',
          displayName: 'John',
          isCustomName: false,
          shift: createTestShift(),
          role: 'Kasir',
        ),
        ScheduleEntry(
          id: '2',
          date: DateTime(2024, 1, 2),
          employeeId: 'emp1',
          displayName: 'John',
          isCustomName: false,
          shift: createTestShift(),
          role: 'Manager',
        ),
      ];

      final result = PdfService.getMostCommonRoleForTest(entries);
      expect(result, isNotNull);
      expect(['Kasir', 'Manager'], contains(result)); // Either is valid for tie
    });

    test('ignores null and empty roles in frequency calculation', () {
      final entries = [
        ScheduleEntry(
          id: '1',
          date: DateTime(2024, 1, 1),
          employeeId: 'emp1',
          displayName: 'John',
          isCustomName: false,
          shift: createTestShift(),
          role: 'Kasir',
        ),
        ScheduleEntry(
          id: '2',
          date: DateTime(2024, 1, 2),
          employeeId: 'emp1',
          displayName: 'John',
          isCustomName: false,
          shift: createTestShift(),
          role: null,
        ),
        ScheduleEntry(
          id: '3',
          date: DateTime(2024, 1, 3),
          employeeId: 'emp1',
          displayName: 'John',
          isCustomName: false,
          shift: createTestShift(),
          role: '',
        ),
        ScheduleEntry(
          id: '4',
          date: DateTime(2024, 1, 4),
          employeeId: 'emp1',
          displayName: 'John',
          isCustomName: false,
          shift: createTestShift(),
          role: 'Kasir',
        ),
      ];

      final result = PdfService.getMostCommonRoleForTest(entries);
      expect(result, 'Kasir'); // Should ignore null and empty entries
    });
  });
}
