import 'package:absensi_enakko_flutter/models/daily_summary.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/services/pdf_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to build a minimal DailySummary for testing.
DailySummary _makeSummary({
  required String dateLabel,
  required DailySummaryStatus status,
  DateTime? firstMasuk,
  DateTime? lastPulang,
  Duration? workDuration,
  String? employeeId,
  String? employeeName,
  int scanCount = 1,
}) {
  final employee = employeeId != null
      ? Employee(
          id: employeeId,
          name: employeeName ?? 'Emp $employeeId',
          isActive: true,
          createdAt: '',
          updatedAt: '',
        )
      : null;

  return DailySummary(
    dateLabel: dateLabel,
    employee: employee,
    outlet: null,
    firstMasuk: firstMasuk,
    lastPulang: lastPulang,
    workDuration: workDuration,
    totalBreak: Duration.zero,
    scanCount: scanCount,
    status: status,
  );
}

void main() {
  group('PdfReportService._computeStats', () {
    test('empty list returns zeroed stats', () {
      final stats = PdfReportService.computeStatsForTest([]);

      expect(stats.totalHadir, 0);
      expect(stats.attendanceRate, 0.0);
      expect(stats.totalSakit, 0);
      expect(stats.totalScan, 0);
      expect(stats.employeeRows, isEmpty);
    });

    test('2 employees x 2 days all normal hadir → totalHadir=4, rate=100%', () {
      final summaries = [
        _makeSummary(
          dateLabel: '2024-01-01',
          status: DailySummaryStatus.normal,
          firstMasuk: DateTime(2024, 1, 1, 8, 0),
          lastPulang: DateTime(2024, 1, 1, 17, 0),
          workDuration: const Duration(hours: 8),
          employeeId: 'emp1',
          employeeName: 'Alice',
          scanCount: 2,
        ),
        _makeSummary(
          dateLabel: '2024-01-02',
          status: DailySummaryStatus.normal,
          firstMasuk: DateTime(2024, 1, 2, 8, 0),
          lastPulang: DateTime(2024, 1, 2, 17, 0),
          workDuration: const Duration(hours: 8),
          employeeId: 'emp1',
          employeeName: 'Alice',
          scanCount: 2,
        ),
        _makeSummary(
          dateLabel: '2024-01-01',
          status: DailySummaryStatus.normal,
          firstMasuk: DateTime(2024, 1, 1, 9, 0),
          lastPulang: DateTime(2024, 1, 1, 18, 0),
          workDuration: const Duration(hours: 8),
          employeeId: 'emp2',
          employeeName: 'Bob',
          scanCount: 2,
        ),
        _makeSummary(
          dateLabel: '2024-01-02',
          status: DailySummaryStatus.normal,
          firstMasuk: DateTime(2024, 1, 2, 9, 0),
          lastPulang: DateTime(2024, 1, 2, 18, 0),
          workDuration: const Duration(hours: 8),
          employeeId: 'emp2',
          employeeName: 'Bob',
          scanCount: 2,
        ),
      ];

      final stats = PdfReportService.computeStatsForTest(summaries);

      expect(stats.totalHadir, 4);
      expect(stats.attendanceRate, closeTo(100.0, 0.01));
      expect(stats.employeeRows.length, 2);
    });

    test('1 sakit row → totalSakit=1, totalHadir=0, attendanceRate=0', () {
      final summaries = [
        _makeSummary(
          dateLabel: '2024-01-01',
          status: DailySummaryStatus.sakit,
          firstMasuk: null,
          employeeId: 'emp1',
        ),
      ];

      final stats = PdfReportService.computeStatsForTest(summaries);

      expect(stats.totalSakit, 1);
      expect(stats.totalHadir, 0);
      expect(stats.attendanceRate, 0.0);
    });

    test('employee rows sorted alphabetically by name', () {
      final summaries = [
        _makeSummary(
          dateLabel: '2024-01-01',
          status: DailySummaryStatus.normal,
          firstMasuk: DateTime(2024, 1, 1, 8, 0),
          workDuration: const Duration(hours: 8),
          employeeId: 'emp_z',
          employeeName: 'Zara',
        ),
        _makeSummary(
          dateLabel: '2024-01-01',
          status: DailySummaryStatus.normal,
          firstMasuk: DateTime(2024, 1, 1, 8, 0),
          workDuration: const Duration(hours: 8),
          employeeId: 'emp_a',
          employeeName: 'Alice',
        ),
        _makeSummary(
          dateLabel: '2024-01-01',
          status: DailySummaryStatus.normal,
          firstMasuk: DateTime(2024, 1, 1, 8, 0),
          workDuration: const Duration(hours: 8),
          employeeId: 'emp_m',
          employeeName: 'Mira',
        ),
      ];

      final stats = PdfReportService.computeStatsForTest(summaries);
      final names = stats.employeeRows.map((r) => r.name).toList();

      expect(names, ['Alice', 'Mira', 'Zara']);
    });
  });

  group('PdfReportService._avgTimeOfDayStr', () {
    test('empty list returns --:--', () {
      expect(PdfReportService.avgTimeOfDayStrForTest([]), '--:--');
    });

    test('averages two different times correctly (time-of-day minutes only)',
        () {
      // 08:30 = 510 min, 09:30 = 570 min → avg = 540 min = 09:00
      final times = [
        DateTime(2024, 1, 1, 8, 30),
        DateTime(2024, 1, 2, 9, 30), // different date, same time-of-day avg
      ];
      expect(PdfReportService.avgTimeOfDayStrForTest(times), '09:00');
    });

    test('single time returns formatted time', () {
      final times = [DateTime(2024, 1, 1, 7, 5)];
      expect(PdfReportService.avgTimeOfDayStrForTest(times), '07:05');
    });
  });

  group('PdfReportService._chunkEmployeeRows', () {
    test('empty list returns empty chunks', () {
      final chunks = PdfReportService.chunkEmployeeRowsForTest([], 25);
      expect(chunks, isEmpty);
    });

    test('26 rows split into chunks of [25, 1]', () {
      // We can't construct _EmployeeRow directly (private typedef),
      // so we use the computeStatsForTest approach with 26 employees
      final summaries = List.generate(
        26,
        (i) => _makeSummary(
          dateLabel: '2024-01-01',
          status: DailySummaryStatus.normal,
          firstMasuk: DateTime(2024, 1, 1, 8, 0),
          workDuration: const Duration(hours: 8),
          employeeId: 'emp_$i',
          employeeName: 'Employee $i',
        ),
      );

      final stats = PdfReportService.computeStatsForTest(summaries);
      // stats.employeeRows has 26 entries
      final chunks =
          PdfReportService.chunkEmployeeRowsForTest(stats.employeeRows, 25);

      expect(chunks.length, 2);
      expect(chunks[0].length, 25);
      expect(chunks[1].length, 1);
    });

    test('25 rows stays as single chunk', () {
      final summaries = List.generate(
        25,
        (i) => _makeSummary(
          dateLabel: '2024-01-01',
          status: DailySummaryStatus.normal,
          firstMasuk: DateTime(2024, 1, 1, 8, 0),
          workDuration: const Duration(hours: 8),
          employeeId: 'emp_$i',
          employeeName: 'Employee $i',
        ),
      );

      final stats = PdfReportService.computeStatsForTest(summaries);
      final chunks =
          PdfReportService.chunkEmployeeRowsForTest(stats.employeeRows, 25);

      expect(chunks.length, 1);
      expect(chunks[0].length, 25);
    });
  });
}
