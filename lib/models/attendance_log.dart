import 'package:flutter/material.dart';
import 'employee.dart';
import 'outlet.dart';

enum AttendanceType { masuk, breakTime, pulang, kembali, sakit, izin }

extension AttendanceTypeExt on AttendanceType {
  Color get color {
    switch (this) {
      case AttendanceType.masuk:
        return const Color(0xFF22C55E); // Green
      case AttendanceType.breakTime:
        return const Color(0xFFF59E0B); // Amber
      case AttendanceType.pulang:
        return const Color(0xFF6B7280); // Gray
      case AttendanceType.kembali:
        return const Color(0xFF3B82F6); // Blue
      case AttendanceType.sakit:
        return const Color(0xFFDC2626); // Red
      case AttendanceType.izin:
        return const Color(0xFF2563EB); // Blue
    }
  }

  String get value {
    switch (this) {
      case AttendanceType.masuk:
        return 'masuk';
      case AttendanceType.breakTime:
        return 'break';
      case AttendanceType.pulang:
        return 'pulang';
      case AttendanceType.kembali:
        return 'kembali';
      case AttendanceType.sakit:
        return 'sakit';
      case AttendanceType.izin:
        return 'izin';
    }
  }

  String get label {
    switch (this) {
      case AttendanceType.masuk:
        return 'Masuk';
      case AttendanceType.breakTime:
        return 'Istirahat';
      case AttendanceType.pulang:
        return 'Pulang';
      case AttendanceType.kembali:
        return 'Kembali';
      case AttendanceType.sakit:
        return 'Sakit';
      case AttendanceType.izin:
        return 'Izin';
    }
  }

  String get emoji {
    switch (this) {
      case AttendanceType.masuk:
        return '✅';
      case AttendanceType.breakTime:
        return '☕';
      case AttendanceType.pulang:
        return '🏠';
      case AttendanceType.kembali:
        return '🔄';
      case AttendanceType.sakit:
        return '🤒';
      case AttendanceType.izin:
        return '📋';
    }
  }

  static AttendanceType fromString(String s) {
    switch (s) {
      case 'masuk':
        return AttendanceType.masuk;
      case 'break':
        return AttendanceType.breakTime;
      case 'pulang':
        return AttendanceType.pulang;
      case 'kembali':
        return AttendanceType.kembali;
      case 'sakit':
        return AttendanceType.sakit;
      case 'izin':
        return AttendanceType.izin;
      default:
        return AttendanceType.masuk;
    }
  }
}

class AttendanceLog {
  final String id;
  final String employeeId;
  final String scanOutletId;
  final AttendanceType type;
  final double? lat;
  final double? lng;
  final String? selfieUrl;
  final String? deviceId;
  final String scannedAt;
  final String? syncedAt;
  final String? localId;
  final String createdAt;
  final bool isBackup; // true jika karyawan backup di gerai lain
  final String? notes; // keterangan backup

  // Joined fields (from Supabase select with joins)
  final Employee? employee;
  final Outlet? outlet;

  const AttendanceLog({
    required this.id,
    required this.employeeId,
    required this.scanOutletId,
    required this.type,
    this.lat,
    this.lng,
    this.selfieUrl,
    this.deviceId,
    required this.scannedAt,
    this.syncedAt,
    this.localId,
    required this.createdAt,
    this.isBackup = false,
    this.notes,
    this.employee,
    this.outlet,
  });

  factory AttendanceLog.fromJson(Map<String, dynamic> json) {
    // Joined employee may be a Map or null
    Employee? emp;
    if (json['employee'] is Map<String, dynamic>) {
      emp = Employee.fromJson(json['employee'] as Map<String, dynamic>);
    }

    Outlet? outl;
    if (json['outlet'] is Map<String, dynamic>) {
      outl = Outlet.fromJson(json['outlet'] as Map<String, dynamic>);
    }

    return AttendanceLog(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      scanOutletId: json['scan_outlet_id'] as String,
      type: AttendanceTypeExt.fromString(json['type'] as String? ?? 'masuk'),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      selfieUrl: json['selfie_url'] as String?,
      deviceId: json['device_id'] as String?,
      scannedAt: json['scanned_at'] as String? ?? '',
      syncedAt: json['synced_at'] as String?,
      localId: json['local_id'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      isBackup: json['is_backup'] as bool? ?? false,
      notes: json['notes'] as String?,
      employee: emp,
      outlet: outl,
    );
  }
}
