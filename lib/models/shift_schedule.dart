import 'dart:convert';
import 'package:flutter/material.dart';
import 'employee.dart';
import 'time_off_request.dart';
/// Model untuk slot shift (Pagi, Siang, Sore, Libur)
class ShiftSlot {
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color;

  const ShiftSlot({
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.color,
  });

  // Shift untuk gerai buka 09:00 - 22:00
  factory ShiftSlot.pagi() => ShiftSlot(
        name: 'Pagi',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 17, minute: 0), // 09:00-17:00 (8 jam)
        color: const Color(0xFF3B82F6), // Blue
      );

  factory ShiftSlot.siang() => ShiftSlot(
        name: 'Siang',
        startTime: const TimeOfDay(hour: 12, minute: 0),
        endTime: const TimeOfDay(hour: 20, minute: 0), // 12:00-20:00 (8 jam)
        color: const Color(0xFFF59E0B), // Amber
      );

  factory ShiftSlot.sore() => ShiftSlot(
        name: 'Sore',
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 22, minute: 0), // 14:00-22:00 (8 jam)
        color: const Color(0xFFF97316), // Orange
      );

  factory ShiftSlot.libur() => ShiftSlot(
        name: 'Libur',
        startTime: const TimeOfDay(hour: 0, minute: 0),
        endTime: const TimeOfDay(hour: 0, minute: 0),
        color: const Color(0xFFDC2626), // Red
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'start_hour': startTime.hour,
        'start_minute': startTime.minute,
        'end_hour': endTime.hour,
        'end_minute': endTime.minute,
        'color': color.value,
      };

  factory ShiftSlot.fromJson(Map<String, dynamic> json) => ShiftSlot(
        name: json['name'] as String,
        startTime: TimeOfDay(
          hour: json['start_hour'] as int,
          minute: json['start_minute'] as int,
        ),
        endTime: TimeOfDay(
          hour: json['end_hour'] as int,
          minute: json['end_minute'] as int,
        ),
        color: Color(json['color'] as int),
      );
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
  });

  factory ScheduleEntry.fromEmployee({
    required String id,
    required DateTime date,
    required Employee employee,
    required ShiftSlot shift,
    bool isDayOff = false,
    ScheduleStatus status = ScheduleStatus.normal,
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
      );

  factory ScheduleEntry.customName({
    required String id,
    required DateTime date,
    required String name,
    required ShiftSlot shift,
    ScheduleStatus status = ScheduleStatus.normal,
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
      );

  factory ScheduleEntry.izin({
    required String id,
    required DateTime date,
    required Employee employee,
    required ShiftSlot shift,
    String? notes,
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
    return entries.where((e) =>
        e.date.year == date.year &&
        e.date.month == date.month &&
        e.date.day == date.day).toList();
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
        template: ShiftTemplate.fromJson(json['template'] as Map<String, dynamic>),
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

