import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/outlet_operating_mode.dart';
import 'package:absensi_enakko_flutter/services/legacy_payroll_recap_fallback_service.dart';

class AdminPolicyRecapDatasetResult {
  const AdminPolicyRecapDatasetResult({
    required this.mergedRows,
    required this.strictRows,
    required this.fallbackRows,
  });

  final List<AttendancePolicyRecapDay> mergedRows;
  final List<AttendancePolicyRecapDay> strictRows;
  final List<AttendancePolicyRecapDay> fallbackRows;
}

class AdminPolicyRecapDatasetService {
  const AdminPolicyRecapDatasetService({
    this.fallbackService = const LegacyPayrollRecapFallbackService(),
  });

  final LegacyPayrollRecapFallbackService fallbackService;

  AdminPolicyRecapDatasetResult build({
    required Iterable<Employee> employees,
    required Iterable<AttendancePolicyRecapDay> strictRows,
    required Iterable<AttendanceLog> attendanceLogs,
    required String outletId,
    required String outletName,
    required OutletOperatingMode outletOperatingMode,
    DateTime? now,
  }) {
    final employeeList = employees.toList(growable: false);
    final strictRowList = strictRows.toList(growable: false)
      ..sort(_compareRecapRows);
    final employeesById = <String, Employee>{
      for (final employee in employeeList) employee.id: employee,
    };
    final filteredLogs = attendanceLogs
        .where((log) => log.scanOutletId == outletId)
        .toList(growable: false);
    final sourceDays = fallbackService.buildSourceDays(
      logs: filteredLogs,
      employeesById: employeesById,
      outletId: outletId,
      outletName: outletName,
      outletOperatingMode: outletOperatingMode,
    );
    final fallbackRows = fallbackService.synthesizeMissingRows(
      sourceDays: sourceDays,
      strictRows: strictRowList,
      now: now,
    )..sort(_compareRecapRows);

    final mergedByKey = <String, AttendancePolicyRecapDay>{
      for (final row in strictRowList)
        _buildRowKey(row.employeeId, row.logicalDate): row,
    };

    for (final row in fallbackRows) {
      mergedByKey.putIfAbsent(
        _buildRowKey(row.employeeId, row.logicalDate),
        () => row,
      );
    }

    final mergedRows = mergedByKey.values.toList(growable: false)
      ..sort(_compareRecapRows);

    return AdminPolicyRecapDatasetResult(
      mergedRows: mergedRows,
      strictRows: strictRowList,
      fallbackRows: fallbackRows,
    );
  }
}

String _buildRowKey(String employeeId, DateTime logicalDate) {
  final dateOnly =
      DateTime(logicalDate.year, logicalDate.month, logicalDate.day);
  return '$employeeId|'
      '${dateOnly.year.toString().padLeft(4, '0')}-'
      '${dateOnly.month.toString().padLeft(2, '0')}-'
      '${dateOnly.day.toString().padLeft(2, '0')}';
}

int _compareRecapRows(
  AttendancePolicyRecapDay left,
  AttendancePolicyRecapDay right,
) {
  final dateComparison = _dateOnly(left.logicalDate).compareTo(
    _dateOnly(right.logicalDate),
  );
  if (dateComparison != 0) {
    return dateComparison;
  }

  final nameComparison = left.employeeName
      .toLowerCase()
      .compareTo(right.employeeName.toLowerCase());
  if (nameComparison != 0) {
    return nameComparison;
  }

  return left.employeeId.compareTo(right.employeeId);
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
