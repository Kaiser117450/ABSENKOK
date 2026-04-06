import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_day_cell.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PayrollMatrixRow', () {
    test('summary values stay in payroll order', () {
      final row = PayrollMatrixRow(
        employeeId: 'emp-1',
        employeeName: 'Ayu',
        employmentContract: EmployeeContract.fulltime,
        employeeRole: '',
        cells: <PayrollMatrixDayCell>[
          PayrollMatrixDayCell.placeholder(DateTime(2026, 3, 27)),
        ],
        lateCount: 2,
        shortWorkCount: 1,
        excessBreakCount: 3,
        absenceCount: 4,
        overtimeCount: 5,
      );

      expect(PayrollMatrixRow.summaryLabels, const <String>[
        'Terlambat',
        'Kurang Jam',
        'Break Lebih',
        'Tidak Hadir',
        'Lembur',
      ]);
      expect(row.summaryValuesInOrder, const <int>[2, 1, 3, 4, 5]);
    });

    test('dataset isEmpty reflects missing rows or dates', () {
      const emptyDataset = PayrollMatrixDataset(
        dates: <DateTime>[],
        rows: <PayrollMatrixRow>[],
      );

      expect(emptyDataset.isEmpty, isTrue);
    });
  });
}
