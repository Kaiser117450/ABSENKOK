import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';

enum AttendancePolicyStatus {
  hadir,
  belumMasuk,
  tidakHadir,
  sakit,
  izin,
  cuti,
  libur,
  hadirTanpaJadwal;

  String get storageValue {
    switch (this) {
      case AttendancePolicyStatus.hadir:
        return 'hadir';
      case AttendancePolicyStatus.belumMasuk:
        return 'belum_masuk';
      case AttendancePolicyStatus.tidakHadir:
        return 'tidak_hadir';
      case AttendancePolicyStatus.sakit:
        return 'sakit';
      case AttendancePolicyStatus.izin:
        return 'izin';
      case AttendancePolicyStatus.cuti:
        return 'cuti';
      case AttendancePolicyStatus.libur:
        return 'libur';
      case AttendancePolicyStatus.hadirTanpaJadwal:
        return 'hadir_tanpa_jadwal';
    }
  }

  String get label {
    switch (this) {
      case AttendancePolicyStatus.hadir:
        return 'Hadir';
      case AttendancePolicyStatus.belumMasuk:
        return 'Belum masuk';
      case AttendancePolicyStatus.tidakHadir:
        return 'Tidak hadir';
      case AttendancePolicyStatus.sakit:
        return 'Sakit';
      case AttendancePolicyStatus.izin:
        return 'Izin';
      case AttendancePolicyStatus.cuti:
        return 'Cuti';
      case AttendancePolicyStatus.libur:
        return 'Libur';
      case AttendancePolicyStatus.hadirTanpaJadwal:
        return 'Hadir tanpa jadwal';
    }
  }

  static AttendancePolicyStatus parse(String? raw) {
    return tryParse(raw) ?? AttendancePolicyStatus.hadir;
  }

  static AttendancePolicyStatus? tryParse(String? raw) {
    final normalized =
        raw?.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '') ?? '';
    switch (normalized) {
      case 'hadir':
        return AttendancePolicyStatus.hadir;
      case 'belummasuk':
        return AttendancePolicyStatus.belumMasuk;
      case 'tidakhadir':
        return AttendancePolicyStatus.tidakHadir;
      case 'sakit':
        return AttendancePolicyStatus.sakit;
      case 'izin':
        return AttendancePolicyStatus.izin;
      case 'cuti':
        return AttendancePolicyStatus.cuti;
      case 'libur':
        return AttendancePolicyStatus.libur;
      case 'hadirtanpajadwal':
        return AttendancePolicyStatus.hadirTanpaJadwal;
      default:
        return null;
    }
  }
}

enum LateKind {
  none,
  normal,
  breakFirstEligible,
  breakFirstConfirmed;

  String get storageValue {
    switch (this) {
      case LateKind.none:
        return 'none';
      case LateKind.normal:
        return 'normal';
      case LateKind.breakFirstEligible:
        return 'break_first_eligible';
      case LateKind.breakFirstConfirmed:
        return 'break_first_confirmed';
    }
  }

  String get label {
    switch (this) {
      case LateKind.none:
        return '-';
      case LateKind.normal:
        return 'Terlambat';
      case LateKind.breakFirstEligible:
        return 'Break-first eligible';
      case LateKind.breakFirstConfirmed:
        return 'Break-first confirmed';
    }
  }

  static LateKind parse(String? raw) {
    return tryParse(raw) ?? LateKind.none;
  }

  static LateKind? tryParse(String? raw) {
    final normalized =
        raw?.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '') ?? '';
    switch (normalized) {
      case 'none':
        return LateKind.none;
      case 'normal':
        return LateKind.normal;
      case 'breakfirsteligible':
        return LateKind.breakFirstEligible;
      case 'breakfirstconfirmed':
        return LateKind.breakFirstConfirmed;
      default:
        return null;
    }
  }
}

class AttendancePolicyRecapDay {
  final DateTime logicalDate;
  final String employeeId;
  final String employeeName;
  final String outletId;
  final String outletName;
  final ShiftBand? shiftBand;
  final int? requiredWorkMinutes;
  final String? lateCutoffLocal;
  final String? breakFirstDeadlineLocal;
  final AttendancePolicyStatus attendanceStatus;
  final LateKind lateKind;
  final bool isLate;
  final bool breakFirstEligible;
  final bool breakFirstConfirmed;
  final DateTime? firstScanLocal;
  final DateTime? firstBreakLocal;
  final DateTime? lastPulangLocal;
  final String? notes;
  final AttendancePolicyPrimaryStatus? primaryStatus;
  final AttendancePolicySeverity? primarySeverity;
  final List<AttendancePolicySignal> detailSignals;
  final List<String> detailNotes;
  final bool isManagerExempt;
  final String? managerPosition;
  final bool logicalDayComplete;
  final String? incompleteReason;
  final int? netWorkMinutes;
  final int? totalBreakMinutes;
  final int? overtimeMinutes;
  final int? shortWorkMinutes;
  final int? excessBreakMinutes;
  final int? pairedBreakCount;

  const AttendancePolicyRecapDay({
    required this.logicalDate,
    required this.employeeId,
    required this.employeeName,
    required this.outletId,
    required this.outletName,
    required this.shiftBand,
    required this.requiredWorkMinutes,
    required this.lateCutoffLocal,
    required this.breakFirstDeadlineLocal,
    required this.attendanceStatus,
    required this.lateKind,
    required this.isLate,
    required this.breakFirstEligible,
    required this.breakFirstConfirmed,
    required this.firstScanLocal,
    required this.firstBreakLocal,
    required this.lastPulangLocal,
    required this.notes,
    this.primaryStatus,
    this.primarySeverity,
    this.detailSignals = const [],
    this.detailNotes = const [],
    this.isManagerExempt = false,
    this.managerPosition,
    this.logicalDayComplete = true,
    this.incompleteReason,
    this.netWorkMinutes,
    this.totalBreakMinutes,
    this.overtimeMinutes,
    this.shortWorkMinutes,
    this.excessBreakMinutes,
    this.pairedBreakCount,
  });

  factory AttendancePolicyRecapDay.fromJson(Map<String, dynamic> json) {
    final detailSignals = _readSignalList(json['detail_signals']);
    final detailNotes = _readStringList(json['detail_notes']);
    final primaryStatus = AttendancePolicyPrimaryStatus.tryParse(
            json['primary_status']?.toString()) ??
        _derivePrimaryStatus(json, detailSignals);
    final primarySeverity = AttendancePolicySeverity.tryParse(
            json['primary_severity']?.toString()) ??
        _derivePrimarySeverity(primaryStatus);
    final breakFirstConfirmed =
        _readOptionalBool(json['break_first_confirmed']) ??
            detailSignals.contains(AttendancePolicySignal.breakFirstConfirmed);
    final breakFirstEligible =
        _readOptionalBool(json['break_first_eligible']) ?? false;
    final isLate = _readOptionalBool(json['is_late']) ??
        detailSignals.contains(AttendancePolicySignal.late) ||
            primaryStatus == AttendancePolicyPrimaryStatus.late;
    final attendanceStatus = AttendancePolicyStatus.tryParse(
            json['attendance_status']?.toString()) ??
        _deriveAttendanceStatus(primaryStatus, detailSignals);
    final lateKind = LateKind.tryParse(json['late_kind']?.toString()) ??
        _deriveLateKind(
          detailSignals: detailSignals,
          primaryStatus: primaryStatus,
          breakFirstEligible: breakFirstEligible,
          breakFirstConfirmed: breakFirstConfirmed,
        );
    final fallbackNotes = detailNotes.isEmpty && json['notes'] != null
        ? <String>[json['notes'].toString()]
        : detailNotes;

    return AttendancePolicyRecapDay(
      logicalDate: _readDate(json['logical_date']),
      employeeId: _readRequiredString(json['employee_id'], 'employee_id'),
      employeeName: _readRequiredString(json['employee_name'], 'employee_name'),
      outletId: _readRequiredString(json['outlet_id'], 'outlet_id'),
      outletName: _readRequiredString(json['outlet_name'], 'outlet_name'),
      shiftBand: ShiftBand.tryParse(json['shift_band']?.toString()),
      requiredWorkMinutes: _readInt(json['required_work_minutes']),
      lateCutoffLocal: json['late_cutoff_local']?.toString(),
      breakFirstDeadlineLocal: json['break_first_deadline_local']?.toString(),
      attendanceStatus: attendanceStatus,
      lateKind: lateKind,
      isLate: isLate,
      breakFirstEligible: breakFirstEligible,
      breakFirstConfirmed: breakFirstConfirmed,
      firstScanLocal: _readDateTime(json['first_scan_local']),
      firstBreakLocal: _readDateTime(json['first_break_local']),
      lastPulangLocal: _readDateTime(json['last_pulang_local']),
      notes: json['notes']?.toString(),
      primaryStatus: primaryStatus,
      primarySeverity: primarySeverity,
      detailSignals: detailSignals,
      detailNotes: fallbackNotes,
      isManagerExempt: _readOptionalBool(json['is_manager_exempt']) ??
          detailSignals.contains(AttendancePolicySignal.exemptManager) ||
              primaryStatus == AttendancePolicyPrimaryStatus.exemptManager,
      managerPosition: json['manager_position']?.toString(),
      logicalDayComplete: _readOptionalBool(json['logical_day_complete']) ??
          primaryStatus != AttendancePolicyPrimaryStatus.activeIncomplete,
      incompleteReason: json['incomplete_reason']?.toString(),
      netWorkMinutes: _readInt(json['net_work_minutes']),
      totalBreakMinutes: _readInt(json['total_break_minutes']),
      overtimeMinutes: _readInt(json['overtime_minutes']),
      shortWorkMinutes: _readInt(json['short_work_minutes']),
      excessBreakMinutes: _readInt(json['excess_break_minutes']),
      pairedBreakCount: _readInt(json['paired_break_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'logical_date': logicalDate.toIso8601String(),
      'employee_id': employeeId,
      'employee_name': employeeName,
      'outlet_id': outletId,
      'outlet_name': outletName,
      'shift_band': shiftBand?.storageValue,
      'required_work_minutes': requiredWorkMinutes,
      'late_cutoff_local': lateCutoffLocal,
      'break_first_deadline_local': breakFirstDeadlineLocal,
      'attendance_status': attendanceStatus.storageValue,
      'late_kind': lateKind.storageValue,
      'is_late': isLate,
      'break_first_eligible': breakFirstEligible,
      'break_first_confirmed': breakFirstConfirmed,
      'first_scan_local': firstScanLocal?.toIso8601String(),
      'first_break_local': firstBreakLocal?.toIso8601String(),
      'last_pulang_local': lastPulangLocal?.toIso8601String(),
      'notes': notes,
      'primary_status': primaryStatus?.storageValue,
      'primary_severity': primarySeverity?.storageValue,
      'detail_signals':
          detailSignals.map((signal) => signal.storageValue).toList(),
      'detail_notes': detailNotes,
      'is_manager_exempt': isManagerExempt,
      'manager_position': managerPosition,
      'logical_day_complete': logicalDayComplete,
      'incomplete_reason': incompleteReason,
      'net_work_minutes': netWorkMinutes,
      'total_break_minutes': totalBreakMinutes,
      'overtime_minutes': overtimeMinutes,
      'short_work_minutes': shortWorkMinutes,
      'excess_break_minutes': excessBreakMinutes,
      'paired_break_count': pairedBreakCount,
    };
  }

  bool hasSignal(AttendancePolicySignal signal) {
    return detailSignals.contains(signal);
  }

  bool get isRedPrimary => primarySeverity == AttendancePolicySeverity.red;

  bool get isYellowPrimary =>
      primarySeverity == AttendancePolicySeverity.yellow;

  bool get hasAnyPenaltySignals {
    const penaltySignals = {
      AttendancePolicySignal.late,
      AttendancePolicySignal.shortWork,
      AttendancePolicySignal.excessBreak,
      AttendancePolicySignal.absence,
      AttendancePolicySignal.belumAbsenPulang,
    };
    return detailSignals.any(penaltySignals.contains);
  }

  static AttendancePolicyPrimaryStatus? _derivePrimaryStatus(
    Map<String, dynamic> json,
    List<AttendancePolicySignal> detailSignals,
  ) {
    final attendanceStatus =
        AttendancePolicyStatus.tryParse(json['attendance_status']?.toString());
    if (attendanceStatus != null) {
      switch (attendanceStatus) {
        case AttendancePolicyStatus.belumMasuk:
          return AttendancePolicyPrimaryStatus.belumMasuk;
        case AttendancePolicyStatus.tidakHadir:
          return AttendancePolicyPrimaryStatus.absence;
        case AttendancePolicyStatus.sakit:
          return AttendancePolicyPrimaryStatus.sakit;
        case AttendancePolicyStatus.izin:
          return AttendancePolicyPrimaryStatus.izin;
        case AttendancePolicyStatus.cuti:
          return AttendancePolicyPrimaryStatus.cuti;
        case AttendancePolicyStatus.libur:
          return AttendancePolicyPrimaryStatus.libur;
        case AttendancePolicyStatus.hadirTanpaJadwal:
          return AttendancePolicyPrimaryStatus.hadirTanpaJadwal;
        case AttendancePolicyStatus.hadir:
          break;
      }
    }

    final lateKind = LateKind.tryParse(json['late_kind']?.toString());
    if (lateKind == LateKind.normal ||
        lateKind == LateKind.breakFirstConfirmed) {
      return AttendancePolicyPrimaryStatus.late;
    }

    if (detailSignals.contains(AttendancePolicySignal.overtime)) {
      return AttendancePolicyPrimaryStatus.overtime;
    }
    if (detailSignals.contains(AttendancePolicySignal.exemptManager)) {
      return AttendancePolicyPrimaryStatus.exemptManager;
    }
    if (detailSignals.contains(AttendancePolicySignal.hadirTanpaJadwal)) {
      return AttendancePolicyPrimaryStatus.hadirTanpaJadwal;
    }
    if (detailSignals.contains(AttendancePolicySignal.absence)) {
      return AttendancePolicyPrimaryStatus.absence;
    }

    return AttendancePolicyPrimaryStatus.hadir;
  }

  static AttendancePolicySeverity? _derivePrimarySeverity(
    AttendancePolicyPrimaryStatus? primaryStatus,
  ) {
    switch (primaryStatus) {
      case AttendancePolicyPrimaryStatus.late:
      case AttendancePolicyPrimaryStatus.shortWork:
      case AttendancePolicyPrimaryStatus.excessBreak:
      case AttendancePolicyPrimaryStatus.absence:
      case AttendancePolicyPrimaryStatus.belumAbsenPulang:
        return AttendancePolicySeverity.red;
      case AttendancePolicyPrimaryStatus.overtime:
        return AttendancePolicySeverity.yellow;
      case null:
        return null;
      default:
        return AttendancePolicySeverity.info;
    }
  }

  static AttendancePolicyStatus _deriveAttendanceStatus(
    AttendancePolicyPrimaryStatus? primaryStatus,
    List<AttendancePolicySignal> detailSignals,
  ) {
    if (detailSignals.contains(AttendancePolicySignal.hadirTanpaJadwal)) {
      return AttendancePolicyStatus.hadirTanpaJadwal;
    }

    switch (primaryStatus) {
      case AttendancePolicyPrimaryStatus.belumMasuk:
        return AttendancePolicyStatus.belumMasuk;
      case AttendancePolicyPrimaryStatus.absence:
        return AttendancePolicyStatus.tidakHadir;
      case AttendancePolicyPrimaryStatus.sakit:
        return AttendancePolicyStatus.sakit;
      case AttendancePolicyPrimaryStatus.izin:
        return AttendancePolicyStatus.izin;
      case AttendancePolicyPrimaryStatus.cuti:
        return AttendancePolicyStatus.cuti;
      case AttendancePolicyPrimaryStatus.libur:
        return AttendancePolicyStatus.libur;
      case AttendancePolicyPrimaryStatus.hadirTanpaJadwal:
        return AttendancePolicyStatus.hadirTanpaJadwal;
      case null:
      case AttendancePolicyPrimaryStatus.hadir:
      case AttendancePolicyPrimaryStatus.late:
      case AttendancePolicyPrimaryStatus.shortWork:
      case AttendancePolicyPrimaryStatus.excessBreak:
      case AttendancePolicyPrimaryStatus.overtime:
      case AttendancePolicyPrimaryStatus.exemptManager:
      case AttendancePolicyPrimaryStatus.belumAbsenPulang:
      case AttendancePolicyPrimaryStatus.activeIncomplete:
        return AttendancePolicyStatus.hadir;
    }
  }

  static LateKind _deriveLateKind({
    required List<AttendancePolicySignal> detailSignals,
    required AttendancePolicyPrimaryStatus? primaryStatus,
    required bool breakFirstEligible,
    required bool breakFirstConfirmed,
  }) {
    if (breakFirstConfirmed ||
        detailSignals.contains(AttendancePolicySignal.breakFirstConfirmed)) {
      return LateKind.breakFirstConfirmed;
    }
    if (breakFirstEligible) {
      return LateKind.breakFirstEligible;
    }
    if (detailSignals.contains(AttendancePolicySignal.late) ||
        primaryStatus == AttendancePolicyPrimaryStatus.late) {
      return LateKind.normal;
    }
    return LateKind.none;
  }

  static DateTime _readDate(Object? raw) {
    final parsed = _readDateTime(raw);
    if (parsed == null) {
      throw StateError('logical_date is required');
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime? _readDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final stringValue = raw.toString().trim();
    if (stringValue.isEmpty) return null;
    return DateTime.tryParse(stringValue);
  }

  static int? _readInt(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  static bool? _readOptionalBool(Object? raw) {
    if (raw == null) return null;
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      return normalized == 'true' ||
          normalized == 't' ||
          normalized == '1' ||
          normalized == 'yes';
    }
    return null;
  }

  static List<AttendancePolicySignal> _readSignalList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((value) => AttendancePolicySignal.tryParse(value?.toString()))
        .whereType<AttendancePolicySignal>()
        .toList(growable: false);
  }

  static List<String> _readStringList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((value) => value?.toString().trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  static String _readRequiredString(Object? raw, String fieldName) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) {
      throw StateError('$fieldName is required');
    }
    return value;
  }
}
