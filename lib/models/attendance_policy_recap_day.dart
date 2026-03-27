import 'shift_band.dart';

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
        return 'Belum Masuk';
      case AttendancePolicyStatus.tidakHadir:
        return 'Tidak Hadir';
      case AttendancePolicyStatus.sakit:
        return 'Sakit';
      case AttendancePolicyStatus.izin:
        return 'Izin';
      case AttendancePolicyStatus.cuti:
        return 'Cuti';
      case AttendancePolicyStatus.libur:
        return 'Libur';
      case AttendancePolicyStatus.hadirTanpaJadwal:
        return 'Hadir Tanpa Jadwal';
    }
  }

  static AttendancePolicyStatus parse(String? raw) {
    return tryParse(raw) ?? AttendancePolicyStatus.hadir;
  }

  static AttendancePolicyStatus? tryParse(String? raw) {
    if (raw == null) return null;
    final normalized =
        raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (normalized.isEmpty) return null;

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
    if (raw == null) return null;
    final normalized =
        raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (normalized.isEmpty) return null;

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
  });

  factory AttendancePolicyRecapDay.fromJson(Map<String, dynamic> json) {
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
      attendanceStatus:
          AttendancePolicyStatus.parse(json['attendance_status']?.toString()),
      lateKind: LateKind.parse(json['late_kind']?.toString()),
      isLate: _readBool(json['is_late']),
      breakFirstEligible: _readBool(json['break_first_eligible']),
      breakFirstConfirmed: _readBool(json['break_first_confirmed']),
      firstScanLocal: _readDateTime(json['first_scan_local']),
      firstBreakLocal: _readDateTime(json['first_break_local']),
      lastPulangLocal: _readDateTime(json['last_pulang_local']),
      notes: json['notes']?.toString(),
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
    };
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
    if (raw is String && raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.toString());
  }

  static int? _readInt(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  static bool _readBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      return normalized == 'true' || normalized == 't' || normalized == '1';
    }
    return false;
  }

  static String _readRequiredString(Object? raw, String fieldName) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) {
      throw StateError('$fieldName is required');
    }
    return value;
  }
}
