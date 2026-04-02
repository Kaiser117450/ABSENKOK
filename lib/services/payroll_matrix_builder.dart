import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';
import 'package:absensi_enakko_flutter/services/payroll_matrix_semantics.dart';

PayrollMatrixDataset buildPayrollMatrix({
  required DateTime startDate,
  required DateTime endDate,
  required Iterable<Employee> employees,
  required Iterable<AttendancePolicyRecapDay> recapRows,
  PayrollMatrixSemantics semantics = const PayrollMatrixSemantics(),
}) {
  final start = _dateOnly(startDate);
  final end = _dateOnly(endDate);
  if (end.isBefore(start)) {
    throw ArgumentError.value(
      endDate,
      'endDate',
      'End date must not be before start date',
    );
  }

  final dates = _buildDateRange(start, end);
  final lookup = <String, AttendancePolicyRecapDay>{};

  for (final recap in recapRows) {
    final logicalDate = _dateOnly(recap.logicalDate);
    if (logicalDate.isBefore(start) || logicalDate.isAfter(end)) {
      continue;
    }
    lookup[_cellKey(recap.employeeId, logicalDate)] = recap;
  }

  final activeEmployees = employees
      .where((employee) => employee.isActive)
      .where((employee) => employee.archivedAt == null)
      .toList(growable: false)
    ..sort(_compareEmployees);

  final rows = activeEmployees.map((employee) {
    var summary = const PayrollMatrixSummaryCounts.zero();
    final cells = dates.map((date) {
      final recap = lookup[_cellKey(employee.id, date)];
      if (recap != null) {
        summary = summary.add(semantics.countsForRecap(recap));
      }
      return semantics.buildDayCell(
        date: date,
        recap: recap,
      );
    }).toList(growable: false);

    return PayrollMatrixRow(
      employeeId: employee.id,
      employeeName: employee.name,
      employmentContract: employee.employmentContract,
      cells: cells,
      lateCount: summary.lateCount,
      shortWorkCount: summary.shortWorkCount,
      excessBreakCount: summary.excessBreakCount,
      absenceCount: summary.absenceCount,
      overtimeCount: summary.overtimeCount,
    );
  }).toList(growable: false);

  return PayrollMatrixDataset(
    dates: dates,
    rows: rows,
  );
}

int _compareEmployees(Employee left, Employee right) {
  final contractComparison = _contractSortOrder(left.employmentContract)
      .compareTo(_contractSortOrder(right.employmentContract));
  if (contractComparison != 0) {
    return contractComparison;
  }

  final nameComparison =
      left.name.toLowerCase().compareTo(right.name.toLowerCase());
  if (nameComparison != 0) {
    return nameComparison;
  }

  return left.id.compareTo(right.id);
}

int _contractSortOrder(EmployeeContract contract) {
  switch (contract) {
    case EmployeeContract.fulltime:
      return 0;
    case EmployeeContract.parttime:
      return 1;
  }
}

List<DateTime> _buildDateRange(DateTime start, DateTime end) {
  final dates = <DateTime>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    dates.add(cursor);
    cursor = cursor.add(const Duration(days: 1));
  }
  return dates;
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _cellKey(String employeeId, DateTime logicalDate) {
  final date = _dateOnly(logicalDate);
  return '$employeeId|'
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
