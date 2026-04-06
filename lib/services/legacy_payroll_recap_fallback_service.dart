import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/outlet_operating_mode.dart';
import 'package:absensi_enakko_flutter/services/schedule_policy_service.dart';

class LegacyPayrollSourceDay {
  const LegacyPayrollSourceDay({
    required this.logicalDate,
    required this.employee,
    required this.outletId,
    required this.outletName,
    required this.outletOperatingMode,
    required this.logs,
  });

  final DateTime logicalDate;
  final Employee employee;
  final String outletId;
  final String outletName;
  final OutletOperatingMode outletOperatingMode;
  final List<AttendanceLog> logs;
}

class LegacyPayrollRecapFallbackService {
  const LegacyPayrollRecapFallbackService();

  List<LegacyPayrollSourceDay> buildSourceDays({
    required Iterable<AttendanceLog> logs,
    required Map<String, Employee> employeesById,
    required String outletId,
    required String outletName,
    required OutletOperatingMode outletOperatingMode,
  }) {
    final resolvedLogs = logs
        .map((log) => _ResolvedLog.fromLog(log))
        .whereType<_ResolvedLog>()
        .where((log) => employeesById.containsKey(log.log.employeeId))
        .toList(growable: false)
      ..sort(_compareResolvedLogs);

    final grouped = <String, _MutableSourceDay>{};
    final openLogicalDateByEmployee = <String, DateTime>{};

    for (final resolved in resolvedLogs) {
      final employee = employeesById[resolved.log.employeeId];
      if (employee == null) {
        continue;
      }

      final logicalDate = _resolveLogicalDate(
        log: resolved.log,
        scannedAtLocal: resolved.scannedAtLocal,
        outletOperatingMode: outletOperatingMode,
        openLogicalDate: openLogicalDateByEmployee[employee.id],
      );
      final key = _rowKey(employee.id, logicalDate);
      final bucket = grouped.putIfAbsent(
        key,
        () => _MutableSourceDay(
          logicalDate: logicalDate,
          employee: employee,
        ),
      );
      bucket.logs.add(resolved.log);

      switch (resolved.log.type) {
        case AttendanceType.masuk:
          openLogicalDateByEmployee[employee.id] = logicalDate;
          break;
        case AttendanceType.pulang:
          final openLogicalDate = openLogicalDateByEmployee[employee.id];
          if (openLogicalDate != null &&
              _isSameDate(openLogicalDate, logicalDate)) {
            openLogicalDateByEmployee.remove(employee.id);
          }
          break;
        case AttendanceType.breakTime:
        case AttendanceType.kembali:
        case AttendanceType.sakit:
        case AttendanceType.izin:
          break;
      }
    }

    return grouped.values
        .map(
          (bucket) => LegacyPayrollSourceDay(
            logicalDate: bucket.logicalDate,
            employee: bucket.employee,
            outletId: outletId,
            outletName: outletName,
            outletOperatingMode: outletOperatingMode,
            logs: bucket.logs
              ..sort(
                (left, right) => _parseLocalDateTime(left.scannedAt)!.compareTo(
                  _parseLocalDateTime(right.scannedAt)!,
                ),
              ),
          ),
        )
        .toList(growable: false)
      ..sort(
        (left, right) {
          final dateComparison = left.logicalDate.compareTo(right.logicalDate);
          if (dateComparison != 0) {
            return dateComparison;
          }
          return left.employee.name
              .toLowerCase()
              .compareTo(right.employee.name.toLowerCase());
        },
      );
  }

  List<AttendancePolicyRecapDay> synthesizeMissingRows({
    required Iterable<LegacyPayrollSourceDay> sourceDays,
    required Iterable<AttendancePolicyRecapDay> strictRows,
    DateTime? now,
  }) {
    final strictKeys = strictRows
        .map((row) => _rowKey(row.employeeId, row.logicalDate))
        .toSet();
    final referenceNow = (now ?? DateTime.now()).toLocal();

    return sourceDays
        .where((sourceDay) => sourceDay.logs.isNotEmpty)
        .where(
          (sourceDay) => !strictKeys
              .contains(_rowKey(sourceDay.employee.id, sourceDay.logicalDate)),
        )
        .map((sourceDay) => _buildFallbackRow(sourceDay, referenceNow))
        .toList(growable: false);
  }

  AttendancePolicyRecapDay _buildFallbackRow(
    LegacyPayrollSourceDay sourceDay,
    DateTime referenceNow,
  ) {
    final sortedLogs = sourceDay.logs
        .map((log) => _ResolvedLog.fromLog(log))
        .whereType<_ResolvedLog>()
        .toList(growable: false)
      ..sort(_compareResolvedLogs);

    final contract = sourceDay.employee.employmentContract;
    final requiredWorkMinutes =
        SchedulePolicyService.defaultRequiredWorkMinutes(contract);
    final notes = sortedLogs
        .map((log) => log.log.notes?.trim())
        .whereType<String>()
        .firstWhere(
          (note) => note.isNotEmpty,
          orElse: () => '',
        );

    final onlySakit =
        sortedLogs.every((log) => log.log.type == AttendanceType.sakit);
    if (onlySakit) {
      return _buildSpecialStatusRow(
        sourceDay: sourceDay,
        requiredWorkMinutes: requiredWorkMinutes,
        status: AttendancePolicyStatus.sakit,
        primaryStatus: AttendancePolicyPrimaryStatus.sakit,
        notes: notes.isEmpty ? null : notes,
      );
    }

    final onlyIzin =
        sortedLogs.every((log) => log.log.type == AttendanceType.izin);
    if (onlyIzin) {
      return _buildSpecialStatusRow(
        sourceDay: sourceDay,
        requiredWorkMinutes: requiredWorkMinutes,
        status: AttendancePolicyStatus.izin,
        primaryStatus: AttendancePolicyPrimaryStatus.izin,
        notes: notes.isEmpty ? null : notes,
      );
    }

    final presenceLogs = sortedLogs
        .where(
          (log) =>
              log.log.type != AttendanceType.sakit &&
              log.log.type != AttendanceType.izin,
        )
        .toList(growable: false);

    final firstObserved =
        presenceLogs.isEmpty ? null : presenceLogs.first.scannedAtLocal;
    final masukLogs = presenceLogs
        .where((log) => log.log.type == AttendanceType.masuk)
        .toList(growable: false);
    final pulangLogs = presenceLogs
        .where((log) => log.log.type == AttendanceType.pulang)
        .toList(growable: false);
    final firstMasuk =
        masukLogs.isEmpty ? null : masukLogs.first.scannedAtLocal;
    final lastPulang =
        pulangLogs.isEmpty ? null : pulangLogs.last.scannedAtLocal;
    final breakSummary = _computeBreakSummary(presenceLogs);
    final firstScanLocal = firstMasuk ?? firstObserved;
    final isToday = _isActiveLogicalDay(
      logicalDate: sourceDay.logicalDate,
      outletOperatingMode: sourceDay.outletOperatingMode,
      referenceNow: referenceNow,
    );

    if (firstScanLocal != null && lastPulang == null) {
      final primaryStatus = isToday
          ? AttendancePolicyPrimaryStatus.activeIncomplete
          : AttendancePolicyPrimaryStatus.belumAbsenPulang;
      final signals = <AttendancePolicySignal>[
        AttendancePolicySignal.hadirTanpaJadwal,
        isToday
            ? AttendancePolicySignal.activeIncomplete
            : AttendancePolicySignal.belumAbsenPulang,
      ];
      return AttendancePolicyRecapDay(
        logicalDate: sourceDay.logicalDate,
        employeeId: sourceDay.employee.id,
        employeeName: sourceDay.employee.name,
        outletId: sourceDay.outletId,
        outletName: sourceDay.outletName,
        shiftBand: null,
        requiredWorkMinutes: requiredWorkMinutes,
        lateCutoffLocal: null,
        attendanceStatus: AttendancePolicyStatus.hadirTanpaJadwal,
        lateKind: LateKind.none,
        isLate: false,
        firstScanLocal: firstScanLocal,
        firstBreakLocal: breakSummary.firstBreakLocal,
        lastPulangLocal: null,
        notes: notes.isEmpty ? null : notes,
        primaryStatus: primaryStatus,
        primarySeverity: _primarySeverity(primaryStatus),
        detailSignals: signals,
        detailNotes: const <String>[],
        isManagerExempt: false,
        managerPosition: null,
        logicalDayComplete: false,
        incompleteReason: 'missing_pulang',
        netWorkMinutes: null,
        totalBreakMinutes: breakSummary.totalBreakMinutes,
        overtimeMinutes: 0,
        shortWorkMinutes: 0,
        excessBreakMinutes: 0,
        pairedBreakCount: breakSummary.pairedBreakCount,
      );
    }

    final workStart = firstScanLocal ?? firstObserved;
    final netWorkMinutes = workStart == null || lastPulang == null
        ? 0
        : _computeNetWorkMinutes(
            start: workStart,
            end: lastPulang,
            breakMinutes: breakSummary.totalBreakMinutes,
          );
    final overtimeMinutes = netWorkMinutes > requiredWorkMinutes
        ? netWorkMinutes - requiredWorkMinutes
        : 0;
    final allowedBreakMinutes =
        SchedulePolicyService.payrollBreakAllowanceMinutes(
      contract: contract,
      isOvertime: overtimeMinutes > 0,
    );
    final excessBreakMinutes =
        breakSummary.totalBreakMinutes > allowedBreakMinutes
            ? breakSummary.totalBreakMinutes - allowedBreakMinutes
            : 0;
    final shortWorkMinutes = netWorkMinutes < requiredWorkMinutes
        ? requiredWorkMinutes - netWorkMinutes
        : 0;
    final primaryStatus = _presencePrimaryStatus(
      shortWorkMinutes: shortWorkMinutes,
      excessBreakMinutes: excessBreakMinutes,
      overtimeMinutes: overtimeMinutes,
    );
    final detailSignals = <AttendancePolicySignal>[
      AttendancePolicySignal.hadirTanpaJadwal,
      if (shortWorkMinutes > 0) AttendancePolicySignal.shortWork,
      if (excessBreakMinutes > 0) AttendancePolicySignal.excessBreak,
      if (overtimeMinutes > 0) AttendancePolicySignal.overtime,
    ];

    return AttendancePolicyRecapDay(
      logicalDate: sourceDay.logicalDate,
      employeeId: sourceDay.employee.id,
      employeeName: sourceDay.employee.name,
      outletId: sourceDay.outletId,
      outletName: sourceDay.outletName,
      shiftBand: null,
      requiredWorkMinutes: requiredWorkMinutes,
      lateCutoffLocal: null,
      attendanceStatus: AttendancePolicyStatus.hadirTanpaJadwal,
      lateKind: LateKind.none,
      isLate: false,
      firstScanLocal: workStart,
      firstBreakLocal: breakSummary.firstBreakLocal,
      lastPulangLocal: lastPulang,
      notes: notes.isEmpty ? null : notes,
      primaryStatus: primaryStatus,
      primarySeverity: _primarySeverity(primaryStatus),
      detailSignals: detailSignals,
      detailNotes: const <String>[],
      isManagerExempt: false,
      managerPosition: null,
      logicalDayComplete: true,
      incompleteReason: null,
      netWorkMinutes: netWorkMinutes,
      totalBreakMinutes: breakSummary.totalBreakMinutes,
      overtimeMinutes: overtimeMinutes,
      shortWorkMinutes: shortWorkMinutes,
      excessBreakMinutes: excessBreakMinutes,
      pairedBreakCount: breakSummary.pairedBreakCount,
    );
  }

  AttendancePolicyRecapDay _buildSpecialStatusRow({
    required LegacyPayrollSourceDay sourceDay,
    required int requiredWorkMinutes,
    required AttendancePolicyStatus status,
    required AttendancePolicyPrimaryStatus primaryStatus,
    required String? notes,
  }) {
    return AttendancePolicyRecapDay(
      logicalDate: sourceDay.logicalDate,
      employeeId: sourceDay.employee.id,
      employeeName: sourceDay.employee.name,
      outletId: sourceDay.outletId,
      outletName: sourceDay.outletName,
      shiftBand: null,
      requiredWorkMinutes: requiredWorkMinutes,
      lateCutoffLocal: null,
      attendanceStatus: status,
      lateKind: LateKind.none,
      isLate: false,
      firstScanLocal: null,
      firstBreakLocal: null,
      lastPulangLocal: null,
      notes: notes,
      primaryStatus: primaryStatus,
      primarySeverity: _primarySeverity(primaryStatus),
      detailSignals: const <AttendancePolicySignal>[],
      detailNotes: const <String>[],
      isManagerExempt: false,
      managerPosition: null,
      logicalDayComplete: true,
      incompleteReason: null,
      netWorkMinutes: 0,
      totalBreakMinutes: 0,
      overtimeMinutes: 0,
      shortWorkMinutes: 0,
      excessBreakMinutes: 0,
      pairedBreakCount: 0,
    );
  }
}

class _MutableSourceDay {
  _MutableSourceDay({
    required this.logicalDate,
    required this.employee,
  });

  final DateTime logicalDate;
  final Employee employee;
  final List<AttendanceLog> logs = <AttendanceLog>[];
}

class _ResolvedLog {
  const _ResolvedLog({
    required this.log,
    required this.scannedAtLocal,
  });

  final AttendanceLog log;
  final DateTime scannedAtLocal;

  static _ResolvedLog? fromLog(AttendanceLog log) {
    final scannedAtLocal = _parseLocalDateTime(log.scannedAt);
    if (scannedAtLocal == null) {
      return null;
    }
    return _ResolvedLog(
      log: log,
      scannedAtLocal: scannedAtLocal,
    );
  }
}

class _BreakSummary {
  const _BreakSummary({
    required this.totalBreakMinutes,
    required this.pairedBreakCount,
    required this.firstBreakLocal,
  });

  final int totalBreakMinutes;
  final int pairedBreakCount;
  final DateTime? firstBreakLocal;
}

int _compareResolvedLogs(_ResolvedLog left, _ResolvedLog right) {
  final timeComparison = left.scannedAtLocal.compareTo(right.scannedAtLocal);
  if (timeComparison != 0) {
    return timeComparison;
  }
  return left.log.id.compareTo(right.log.id);
}

DateTime _resolveLogicalDate({
  required AttendanceLog log,
  required DateTime scannedAtLocal,
  required OutletOperatingMode outletOperatingMode,
  required DateTime? openLogicalDate,
}) {
  final localDate = DateTime(
    scannedAtLocal.year,
    scannedAtLocal.month,
    scannedAtLocal.day,
  );
  if (outletOperatingMode != OutletOperatingMode.twentyFourHour ||
      log.type == AttendanceType.masuk ||
      openLogicalDate == null) {
    return localDate;
  }

  final nextDay = openLogicalDate.add(const Duration(days: 1));
  final isNextCalendarDay = _isSameDate(nextDay, localDate);
  if (isNextCalendarDay && scannedAtLocal.hour < 12) {
    return openLogicalDate;
  }

  return localDate;
}

_BreakSummary _computeBreakSummary(List<_ResolvedLog> logs) {
  var totalBreakMinutes = 0;
  var pairedBreakCount = 0;
  DateTime? firstBreakLocal;
  DateTime? breakStart;

  for (final log in logs) {
    switch (log.log.type) {
      case AttendanceType.breakTime:
        breakStart ??= log.scannedAtLocal;
        firstBreakLocal ??= log.scannedAtLocal;
        break;
      case AttendanceType.kembali:
      case AttendanceType.pulang:
        if (breakStart != null && log.scannedAtLocal.isAfter(breakStart)) {
          totalBreakMinutes +=
              log.scannedAtLocal.difference(breakStart).inMinutes;
          pairedBreakCount += 1;
          breakStart = null;
        }
        break;
      case AttendanceType.masuk:
      case AttendanceType.sakit:
      case AttendanceType.izin:
        break;
    }
  }

  return _BreakSummary(
    totalBreakMinutes: totalBreakMinutes,
    pairedBreakCount: pairedBreakCount,
    firstBreakLocal: firstBreakLocal,
  );
}

int _computeNetWorkMinutes({
  required DateTime start,
  required DateTime end,
  required int breakMinutes,
}) {
  final grossMinutes = end.difference(start).inMinutes;
  return grossMinutes > breakMinutes ? grossMinutes - breakMinutes : 0;
}

AttendancePolicyPrimaryStatus _presencePrimaryStatus({
  required int shortWorkMinutes,
  required int excessBreakMinutes,
  required int overtimeMinutes,
}) {
  if (shortWorkMinutes > 0) {
    return AttendancePolicyPrimaryStatus.shortWork;
  }
  if (excessBreakMinutes > 0) {
    return AttendancePolicyPrimaryStatus.excessBreak;
  }
  if (overtimeMinutes > 0) {
    return AttendancePolicyPrimaryStatus.overtime;
  }
  return AttendancePolicyPrimaryStatus.hadirTanpaJadwal;
}

AttendancePolicySeverity _primarySeverity(
  AttendancePolicyPrimaryStatus primaryStatus,
) {
  switch (primaryStatus) {
    case AttendancePolicyPrimaryStatus.shortWork:
    case AttendancePolicyPrimaryStatus.excessBreak:
    case AttendancePolicyPrimaryStatus.belumAbsenPulang:
      return AttendancePolicySeverity.red;
    case AttendancePolicyPrimaryStatus.overtime:
      return AttendancePolicySeverity.yellow;
    case AttendancePolicyPrimaryStatus.activeIncomplete:
    case AttendancePolicyPrimaryStatus.hadirTanpaJadwal:
    case AttendancePolicyPrimaryStatus.sakit:
    case AttendancePolicyPrimaryStatus.izin:
    case AttendancePolicyPrimaryStatus.hadir:
    case AttendancePolicyPrimaryStatus.late:
    case AttendancePolicyPrimaryStatus.absence:
    case AttendancePolicyPrimaryStatus.exemptManager:
    case AttendancePolicyPrimaryStatus.belumMasuk:
    case AttendancePolicyPrimaryStatus.cuti:
    case AttendancePolicyPrimaryStatus.libur:
      return AttendancePolicySeverity.info;
  }
}

bool _isActiveLogicalDay({
  required DateTime logicalDate,
  required OutletOperatingMode outletOperatingMode,
  required DateTime referenceNow,
}) {
  final today =
      DateTime(referenceNow.year, referenceNow.month, referenceNow.day);
  if (_isSameDate(logicalDate, today)) {
    return true;
  }
  if (outletOperatingMode != OutletOperatingMode.twentyFourHour) {
    return false;
  }

  final overnightCarryDay = logicalDate.add(const Duration(days: 1));
  return _isSameDate(overnightCarryDay, today) && referenceNow.hour < 12;
}

String _rowKey(String employeeId, DateTime logicalDate) {
  final dateOnly =
      DateTime(logicalDate.year, logicalDate.month, logicalDate.day);
  return '$employeeId|'
      '${dateOnly.year.toString().padLeft(4, '0')}-'
      '${dateOnly.month.toString().padLeft(2, '0')}-'
      '${dateOnly.day.toString().padLeft(2, '0')}';
}

DateTime? _parseLocalDateTime(String raw) {
  final parsed = DateTime.tryParse(raw);
  return parsed?.toLocal();
}

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
