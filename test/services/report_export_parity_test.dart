import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_day_cell.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';
import 'package:absensi_enakko_flutter/services/admin_policy_recap_dataset_service.dart';
import 'package:absensi_enakko_flutter/services/payroll_matrix_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/report_export_parity_fixture.dart';

void main() {
  group('report export parity', () {
    const service = AdminPolicyRecapDatasetService();

    test('keeps the canonical merged-row payroll semantics locked', () {
      final bundle = buildReportExportParityFixtureBundle();

      final recapDataset = service.build(
        employees: bundle.employees,
        strictRows: bundle.strictRows,
        attendanceLogs: bundle.attendanceLogs,
        outletId: bundle.outletId,
        outletName: bundle.outletName,
        outletOperatingMode: bundle.outletOperatingMode,
        now: DateTime(2026, 3, 29, 10),
      );

      final payrollDataset = buildPayrollMatrix(
        startDate: bundle.startDate,
        endDate: bundle.endDate,
        employees: bundle.employees,
        recapRows: recapDataset.mergedRows,
      );

      final recapByKey = <String, AttendancePolicyRecapDay>{
        for (final row in recapDataset.mergedRows)
          reportExportParityKey(row.employeeId, row.logicalDate): row,
      };
      final cellsByKey = <String, PayrollMatrixDayCell>{};
      for (final row in payrollDataset.rows) {
        for (final cell in row.cells.where((candidate) => candidate.hasData)) {
          cellsByKey[reportExportParityKey(row.employeeId, cell.date)] = cell;
        }
      }

      expect(bundle.scenarioIds, reportExportParityScenarioIds);
      expect(cellsByKey.keys, containsAll(bundle.expectationsByKey.keys));

      final overnightKey = reportExportParityKey(
        'emp-outlet-24-jam',
        DateTime(2026, 3, 18),
      );
      final overtimeKey = reportExportParityKey(
        'emp-overtime',
        DateTime(2026, 3, 25),
      );
      final noShowKey = reportExportParityKey(
        'emp-no-show',
        DateTime(2026, 3, 28),
      );
      final legacyFallbackKey = reportExportParityKey(
        'emp-legacy-fallback-no-schedule',
        DateTime(2026, 3, 21),
      );

      expect(cellsByKey[overnightKey]?.secondaryTags, contains('TLT'));
      expect(cellsByKey[overtimeKey]?.secondaryTags, contains('OT'));
      expect(cellsByKey[noShowKey]?.secondaryTags, contains('ABS'));

      expect(recapDataset.isCompatibilityMode, isTrue);
      expect(recapDataset.fallbackRows, hasLength(1));
      expect(
        recapByKey[legacyFallbackKey]?.attendanceStatus.label,
        bundle.expectationsByKey[legacyFallbackKey]?.primaryLabel,
      );
      expect(
        recapByKey[legacyFallbackKey]?.attendanceStatus.label,
        'Hadir tanpa jadwal',
      );

      final orderedSummary = <String, int>{
        for (var index = 0;
            index < PayrollMatrixRow.summaryLabels.length;
            index++)
          PayrollMatrixRow.summaryLabels[index]: payrollDataset.rows.fold<int>(
            0,
            (sum, row) => sum + row.summaryValuesInOrder[index],
          ),
      };
      expect(orderedSummary.keys.toList(), PayrollMatrixRow.summaryLabels);
      expect(orderedSummary.values.toList(), <int>[2, 0, 0, 1, 1]);
    });

    test('only turns on compatibility mode when fallback rows are present', () {
      final bundle = buildReportExportParityFixtureBundle();

      final withoutFallback = service.build(
        employees: bundle.employees,
        strictRows: bundle.strictRows,
        attendanceLogs: const [],
        outletId: bundle.outletId,
        outletName: bundle.outletName,
        outletOperatingMode: bundle.outletOperatingMode,
        now: DateTime(2026, 3, 29, 10),
      );

      expect(withoutFallback.fallbackRows, isEmpty);
      expect(withoutFallback.isCompatibilityMode, isFalse);
    });
  });
}
