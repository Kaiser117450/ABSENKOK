import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_day_cell.dart';

class PayrollMatrixRow {
  static const List<String> summaryLabels = <String>[
    'Terlambat',
    'Kurang Jam',
    'Break Lebih',
    'Tidak Hadir',
    'Lembur',
  ];

  final String employeeId;
  final String employeeName;
  final EmployeeContract employmentContract;
  final List<PayrollMatrixDayCell> cells;
  final int lateCount;
  final int shortWorkCount;
  final int excessBreakCount;
  final int absenceCount;
  final int overtimeCount;

  const PayrollMatrixRow({
    required this.employeeId,
    required this.employeeName,
    required this.employmentContract,
    required this.cells,
    required this.lateCount,
    required this.shortWorkCount,
    required this.excessBreakCount,
    required this.absenceCount,
    required this.overtimeCount,
  });

  List<int> get summaryValuesInOrder => <int>[
        lateCount,
        shortWorkCount,
        excessBreakCount,
        absenceCount,
        overtimeCount,
      ];
}

class PayrollMatrixDataset {
  final List<DateTime> dates;
  final List<PayrollMatrixRow> rows;

  const PayrollMatrixDataset({
    required this.dates,
    required this.rows,
  });

  bool get isEmpty => rows.isEmpty || dates.isEmpty;
}
