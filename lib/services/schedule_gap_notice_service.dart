import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/outlet_operating_mode.dart';
import 'package:absensi_enakko_flutter/models/schedule_gap_notice.dart';
import 'package:absensi_enakko_flutter/services/admin_policy_recap_dataset_service.dart';

const String kScheduleGapNoticeStatusLabel = 'Hadir tanpa jadwal';
const String kScheduleGapNoticeHelperText =
    'Jadwal untuk tanggal ini belum terisi. Isi jadwal agar tindak lanjut operasional tetap jelas.';

class ScheduleGapNoticeService {
  const ScheduleGapNoticeService({
    this.datasetService = const AdminPolicyRecapDatasetService(),
  });

  final AdminPolicyRecapDatasetService datasetService;

  ScheduleGapNoticeResult build({
    required Iterable<Employee> employees,
    required Iterable<AttendancePolicyRecapDay> strictRows,
    required Iterable<AttendanceLog> attendanceLogs,
    required String outletId,
    required String outletName,
    required OutletOperatingMode outletOperatingMode,
    DateTime? now,
  }) {
    final recapDataset = datasetService.build(
      employees: employees,
      strictRows: strictRows,
      attendanceLogs: attendanceLogs,
      outletId: outletId,
      outletName: outletName,
      outletOperatingMode: outletOperatingMode,
      now: now,
    );

    final entriesByKey = <String, ScheduleGapNoticeEntry>{};

    for (final row in recapDataset.fallbackRows) {
      if (row.outletId != outletId) {
        continue;
      }

      final logicalDate = _dateOnly(row.logicalDate);
      final entryKey = _buildEntryKey(row.employeeId, logicalDate);
      entriesByKey.putIfAbsent(
        entryKey,
        () => ScheduleGapNoticeEntry(
          employeeId: row.employeeId,
          employeeName: row.employeeName,
          outletId: outletId,
          outletName: outletName,
          logicalDate: logicalDate,
          statusLabel: kScheduleGapNoticeStatusLabel,
          helperText: kScheduleGapNoticeHelperText,
        ),
      );
    }

    final entries = entriesByKey.values.toList(growable: false)
      ..sort(_compareNoticeEntries);

    return ScheduleGapNoticeResult(entries: entries);
  }
}

String _buildEntryKey(String employeeId, DateTime logicalDate) {
  final dateOnly = _dateOnly(logicalDate);
  return '$employeeId|'
      '${dateOnly.year.toString().padLeft(4, '0')}-'
      '${dateOnly.month.toString().padLeft(2, '0')}-'
      '${dateOnly.day.toString().padLeft(2, '0')}';
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

int _compareNoticeEntries(
  ScheduleGapNoticeEntry left,
  ScheduleGapNoticeEntry right,
) {
  final dateComparison = _dateOnly(
    right.logicalDate,
  ).compareTo(_dateOnly(left.logicalDate));
  if (dateComparison != 0) {
    return dateComparison;
  }

  final nameComparison = left.employeeName.toLowerCase().compareTo(
        right.employeeName.toLowerCase(),
      );
  if (nameComparison != 0) {
    return nameComparison;
  }

  return left.employeeId.compareTo(right.employeeId);
}
