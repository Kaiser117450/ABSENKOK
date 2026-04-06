import 'package:flutter/material.dart';

import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';
import 'package:absensi_enakko_flutter/services/schedule_policy_service.dart';

/// Model untuk slot shift (Pagi, Siang, Sore, Libur)
class ShiftSlot {
  final String name;
  final ShiftBand band;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color;
  final int requiredWorkMinutes;
  final int lateCutoffHour;
  final int lateCutoffMinute;

  const ShiftSlot({
    required this.name,
    required this.band,
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.requiredWorkMinutes,
    required this.lateCutoffHour,
    required this.lateCutoffMinute,
  });

  factory ShiftSlot.fromBand({
    required ShiftBand band,
    EmployeeContract contract = EmployeeContract.fulltime,
    int? requiredWorkMinutes,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    Color? color,
    String? name,
  }) {
    final lateCutoff = SchedulePolicyService.lateCutoff(band);

    return ShiftSlot(
      name: name ?? band.label,
      band: band,
      startTime: startTime ?? _defaultStartTimeForBand(band),
      endTime: endTime ?? _defaultEndTimeForBand(band),
      color: color ?? _defaultColorForBand(band),
      requiredWorkMinutes: requiredWorkMinutes ??
          (band.isDayOff
              ? 0
              : SchedulePolicyService.defaultRequiredWorkMinutes(contract)),
      lateCutoffHour: lateCutoff?.hour ?? 0,
      lateCutoffMinute: lateCutoff?.minute ?? 0,
    );
  }

  // Shift untuk gerai buka 09:00 - 22:00
  factory ShiftSlot.pagi({
    EmployeeContract contract = EmployeeContract.fulltime,
    int? requiredWorkMinutes,
  }) =>
      ShiftSlot.fromBand(
        band: ShiftBand.pagi,
        contract: contract,
        requiredWorkMinutes: requiredWorkMinutes,
      );

  factory ShiftSlot.siang({
    EmployeeContract contract = EmployeeContract.fulltime,
    int? requiredWorkMinutes,
  }) =>
      ShiftSlot.fromBand(
        band: ShiftBand.siang,
        contract: contract,
        requiredWorkMinutes: requiredWorkMinutes,
      );

  factory ShiftSlot.sore({
    EmployeeContract contract = EmployeeContract.fulltime,
    int? requiredWorkMinutes,
  }) =>
      ShiftSlot.fromBand(
        band: ShiftBand.sore,
        contract: contract,
        requiredWorkMinutes: requiredWorkMinutes,
      );

  factory ShiftSlot.libur() => ShiftSlot.fromBand(
        band: ShiftBand.libur,
        contract: EmployeeContract.fulltime,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'band': band.storageValue,
        'required_work_minutes': requiredWorkMinutes,
        'late_cutoff_hour': lateCutoffHour,
        'late_cutoff_minute': lateCutoffMinute,
        'start_hour': startTime.hour,
        'start_minute': startTime.minute,
        'end_hour': endTime.hour,
        'end_minute': endTime.minute,
        'color': color.toARGB32(),
      };

  factory ShiftSlot.fromJson(Map<String, dynamic> json) {
    final band = ShiftBand.tryParse(json['band']?.toString()) ??
        ShiftBand.tryParse(json['name']?.toString()) ??
        _inferBandFromLegacyTimes(json) ??
        ShiftBand.pagi;
    final lateCutoff = SchedulePolicyService.lateCutoff(band);

    return ShiftSlot(
      name: (json['name'] as String?) ?? band.label,
      band: band,
      startTime: _readTimeOfDay(
        json,
        hourKey: 'start_hour',
        minuteKey: 'start_minute',
        fallback: _defaultStartTimeForBand(band),
      ),
      endTime: _readTimeOfDay(
        json,
        hourKey: 'end_hour',
        minuteKey: 'end_minute',
        fallback: _defaultEndTimeForBand(band),
      ),
      color: Color(
        _readInt(json['color'], _defaultColorForBand(band).toARGB32()),
      ),
      requiredWorkMinutes: _readInt(
        json['required_work_minutes'],
        band.isDayOff
            ? 0
            : SchedulePolicyService.defaultRequiredWorkMinutes(
                EmployeeContract.fulltime,
              ),
      ),
      lateCutoffHour: _readInt(
        json['late_cutoff_hour'],
        lateCutoff?.hour ?? 0,
      ),
      lateCutoffMinute: _readInt(
        json['late_cutoff_minute'],
        lateCutoff?.minute ?? 0,
      ),
    );
  }

  static ShiftBand? _inferBandFromLegacyTimes(Map<String, dynamic> json) {
    final startHour = _tryReadInt(json['start_hour']);
    if (startHour == null) {
      return null;
    }

    if (startHour >= 14) {
      return ShiftBand.sore;
    }
    if (startHour >= 12) {
      return ShiftBand.siang;
    }
    if (startHour == 0 && _tryReadInt(json['end_hour']) == 0) {
      return ShiftBand.libur;
    }
    return ShiftBand.pagi;
  }

  static TimeOfDay _readTimeOfDay(
    Map<String, dynamic> json, {
    required String hourKey,
    required String minuteKey,
    required TimeOfDay fallback,
  }) {
    return TimeOfDay(
      hour: _readInt(json[hourKey], fallback.hour),
      minute: _readInt(json[minuteKey], fallback.minute),
    );
  }

  static int _readInt(Object? raw, int fallback) {
    return _tryReadInt(raw) ?? fallback;
  }

  static int? _tryReadInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  static TimeOfDay _defaultStartTimeForBand(ShiftBand band) {
    switch (band) {
      case ShiftBand.pagi:
        return const TimeOfDay(hour: 9, minute: 0);
      case ShiftBand.siang:
        return const TimeOfDay(hour: 12, minute: 0);
      case ShiftBand.sore:
        return const TimeOfDay(hour: 14, minute: 0);
      case ShiftBand.libur:
        return const TimeOfDay(hour: 0, minute: 0);
    }
  }

  static TimeOfDay _defaultEndTimeForBand(ShiftBand band) {
    switch (band) {
      case ShiftBand.pagi:
        return const TimeOfDay(hour: 17, minute: 0);
      case ShiftBand.siang:
        return const TimeOfDay(hour: 20, minute: 0);
      case ShiftBand.sore:
        return const TimeOfDay(hour: 22, minute: 0);
      case ShiftBand.libur:
        return const TimeOfDay(hour: 0, minute: 0);
    }
  }

  static Color _defaultColorForBand(ShiftBand band) {
    switch (band) {
      case ShiftBand.pagi:
        return const Color(0xFF3B82F6);
      case ShiftBand.siang:
        return const Color(0xFFF59E0B);
      case ShiftBand.sore:
        return const Color(0xFFF97316);
      case ShiftBand.libur:
        return const Color(0xFFDC2626);
    }
  }
}

/// Template shift per gerai
class ShiftTemplate {
  final String id;
  final String outletId;
  final String name;
  final List<ShiftSlot> slots;
  final bool isDefault;

  ShiftTemplate({
    required this.id,
    required this.outletId,
    required this.name,
    required this.slots,
    this.isDefault = false,
  });

  factory ShiftTemplate.standard(String outletId) => ShiftTemplate(
        id: 'template_pagi_siang_sore',
        outletId: outletId,
        name: 'Pagi, Siang & Sore',
        slots: [ShiftSlot.pagi(), ShiftSlot.siang(), ShiftSlot.sore()],
        isDefault: true,
      );

  factory ShiftTemplate.pagiSore(String outletId) => ShiftTemplate(
        id: 'template_pagi_sore',
        outletId: outletId,
        name: 'Pagi & Sore',
        slots: [ShiftSlot.pagi(), ShiftSlot.sore()],
        isDefault: false,
      );

  factory ShiftTemplate.pagiSiang(String outletId) => ShiftTemplate(
        id: 'template_pagi_siang',
        outletId: outletId,
        name: 'Pagi & Siang',
        slots: [ShiftSlot.pagi(), ShiftSlot.siang()],
        isDefault: false,
      );

  factory ShiftTemplate.siangOnly(String outletId) => ShiftTemplate(
        id: 'template_siang',
        outletId: outletId,
        name: 'Siang Only',
        slots: [ShiftSlot.siang()],
        isDefault: false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'outlet_id': outletId,
        'name': name,
        'slots': slots.map((s) => s.toJson()).toList(),
        'is_default': isDefault,
      };

  factory ShiftTemplate.fromJson(Map<String, dynamic> json) => ShiftTemplate(
        id: json['id'] as String,
        outletId: json['outlet_id'] as String,
        name: json['name'] as String,
        slots: (json['slots'] as List)
            .map((s) => ShiftSlot.fromJson(s as Map<String, dynamic>))
            .toList(),
        isDefault: json['is_default'] as bool? ?? false,
      );
}

/// Status khusus untuk entry (sakit/izin/libur)
enum ScheduleStatus { normal, sakit, izin, libur, cuti }

extension ScheduleStatusExt on ScheduleStatus {
  Color get color {
    switch (this) {
      case ScheduleStatus.normal:
        return const Color(0xFF22C55E); // Green
      case ScheduleStatus.sakit:
        return const Color(0xFFDC2626); // Red
      case ScheduleStatus.izin:
        return const Color(0xFF2563EB); // Blue
      case ScheduleStatus.libur:
        return const Color(0xFF6B7280); // Gray
      case ScheduleStatus.cuti:
        return const Color(0xFF9333EA); // Purple
    }
  }

  String get label {
    switch (this) {
      case ScheduleStatus.normal:
        return 'Masuk';
      case ScheduleStatus.sakit:
        return 'Sakit';
      case ScheduleStatus.izin:
        return 'Izin';
      case ScheduleStatus.libur:
        return 'Libur';
      case ScheduleStatus.cuti:
        return 'Cuti';
    }
  }

  IconData get icon {
    switch (this) {
      case ScheduleStatus.normal:
        return Icons.check_circle;
      case ScheduleStatus.sakit:
        return Icons.sick;
      case ScheduleStatus.izin:
        return Icons.event_note;
      case ScheduleStatus.libur:
        return Icons.weekend;
      case ScheduleStatus.cuti:
        return Icons.beach_access;
    }
  }
}

/// Entry jadwal untuk 1 karyawan di 1 tanggal & 1 shift
class ScheduleEntry {
  final String id;
  final DateTime date;
  final String? employeeId;
  final String? customName;
  final String displayName;
  final bool isCustomName;
  final ShiftSlot shift;
  final bool isDayOff;
  final ScheduleStatus status; // normal, sakit, izin, libur, cuti
  final String? notes;
  final String? role;

  ScheduleEntry({
    required this.id,
    required this.date,
    this.employeeId,
    this.customName,
    required this.displayName,
    required this.isCustomName,
    required this.shift,
    this.isDayOff = false,
    this.status = ScheduleStatus.normal,
    this.notes,
    this.role,
  });

  factory ScheduleEntry.fromEmployee({
    required String id,
    required DateTime date,
    required Employee employee,
    required ShiftSlot shift,
    bool isDayOff = false,
    ScheduleStatus status = ScheduleStatus.normal,
    String? role,
  }) =>
      ScheduleEntry(
        id: id,
        date: date,
        employeeId: employee.id,
        customName: null,
        displayName: employee.name,
        isCustomName: false,
        shift: shift,
        isDayOff: isDayOff,
        status: status,
        role: role,
      );

  factory ScheduleEntry.customName({
    required String id,
    required DateTime date,
    required String name,
    required ShiftSlot shift,
    ScheduleStatus status = ScheduleStatus.normal,
    String? role,
  }) =>
      ScheduleEntry(
        id: id,
        date: date,
        employeeId: null,
        customName: name,
        displayName: name,
        isCustomName: true,
        shift: shift,
        status: status,
        role: role,
      );

  factory ScheduleEntry.dayOff({
    required String id,
    required DateTime date,
    required ShiftSlot shift,
  }) =>
      ScheduleEntry(
        id: id,
        date: date,
        employeeId: null,
        customName: null,
        displayName: 'LIBUR',
        isCustomName: false,
        shift: shift,
        isDayOff: true,
        status: ScheduleStatus.libur,
      );

  factory ScheduleEntry.sakit({
    required String id,
    required DateTime date,
    required Employee employee,
    required ShiftSlot shift,
    String? notes,
    String? role,
  }) =>
      ScheduleEntry(
        id: id,
        date: date,
        employeeId: employee.id,
        customName: null,
        displayName: '${employee.name} (SAKIT)',
        isCustomName: false,
        shift: shift,
        isDayOff: true,
        status: ScheduleStatus.sakit,
        notes: notes,
        role: role,
      );

  factory ScheduleEntry.izin({
    required String id,
    required DateTime date,
    required Employee employee,
    required ShiftSlot shift,
    String? notes,
    String? role,
  }) =>
      ScheduleEntry(
        id: id,
        date: date,
        employeeId: employee.id,
        customName: null,
        displayName: '${employee.name} (IZIN)',
        isCustomName: false,
        shift: shift,
        isDayOff: true,
        status: ScheduleStatus.izin,
        notes: notes,
        role: role,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'employee_id': employeeId,
        'custom_name': customName,
        'display_name': displayName,
        'is_custom_name': isCustomName,
        'shift': shift.toJson(),
        'is_day_off': isDayOff,
        'status': status.name,
        'notes': notes,
        'role': role,
      };

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) => ScheduleEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        employeeId: json['employee_id'] as String?,
        customName: json['custom_name'] as String?,
        displayName: json['display_name'] as String,
        isCustomName: json['is_custom_name'] as bool,
        shift: ShiftSlot.fromJson(json['shift'] as Map<String, dynamic>),
        isDayOff: json['is_day_off'] as bool? ?? false,
        status: _parseStatus(json['status'] as String?),
        notes: json['notes'] as String?,
        role: json['role'] as String?,
      );

  static ScheduleStatus _parseStatus(String? value) {
    switch (value) {
      case 'sakit':
        return ScheduleStatus.sakit;
      case 'izin':
        return ScheduleStatus.izin;
      case 'libur':
        return ScheduleStatus.libur;
      case 'cuti':
        return ScheduleStatus.cuti;
      default:
        return ScheduleStatus.normal;
    }
  }
}

/// Jadwal lengkap untuk 1 periode (minggu/bulan)
class OutletSchedule {
  final String id;
  final String outletId;
  final DateTime startDate;
  final DateTime endDate;
  final ShiftTemplate template;
  final List<ScheduleEntry> entries;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final bool isActive;

  OutletSchedule({
    required this.id,
    required this.outletId,
    required this.startDate,
    required this.endDate,
    required this.template,
    required this.entries,
    required this.createdAt,
    this.syncedAt,
    this.isActive = true,
  });

  /// Get entries for specific date
  List<ScheduleEntry> getEntriesForDate(DateTime date) {
    return entries
        .where((e) =>
            e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day)
        .toList();
  }

  /// Check if schedule is for weekly or monthly
  bool get isWeekly => endDate.difference(startDate).inDays <= 7;

  /// Check if schedule is draft (not synced)
  bool get isDraft => syncedAt == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'outlet_id': outletId,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'template': template.toJson(),
        'entries': entries.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'synced_at': syncedAt?.toIso8601String(),
        'is_active': isActive,
      };

  factory OutletSchedule.fromJson(Map<String, dynamic> json) => OutletSchedule(
        id: json['id'] as String,
        outletId: json['outlet_id'] as String,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        template:
            ShiftTemplate.fromJson(json['template'] as Map<String, dynamic>),
        entries: (json['entries'] as List)
            .map((e) => ScheduleEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
        syncedAt: json['synced_at'] != null
            ? DateTime.parse(json['synced_at'] as String)
            : null,
        isActive: json['is_active'] as bool? ?? true,
      );
}
