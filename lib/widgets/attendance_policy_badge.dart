import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/attendance_policy_recap_day.dart';
import '../models/attendance_policy_signal.dart';

class AttendancePolicyBadge extends StatelessWidget {
  final AttendancePolicyPrimaryStatus? primaryStatus;
  final AttendancePolicySeverity? primarySeverity;
  final AttendancePolicyStatus? status;
  final LateKind? lateKind;

  const AttendancePolicyBadge({
    super.key,
    this.primaryStatus,
    this.primarySeverity,
    this.status,
    this.lateKind,
  }) : assert(primaryStatus != null || status != null);

  static _AttendancePolicyBadgeStyle _resolveStyle({
    AttendancePolicyPrimaryStatus? primaryStatus,
    AttendancePolicySeverity? primarySeverity,
    AttendancePolicyStatus? status,
    LateKind? lateKind,
  }) {
    if (primaryStatus != null) {
      switch (primaryStatus) {
        case AttendancePolicyPrimaryStatus.late:
          return _strictStyle('Terlambat', AttendancePolicySeverity.red);
        case AttendancePolicyPrimaryStatus.shortWork:
          return _strictStyle('Kurang jam kerja', AttendancePolicySeverity.red);
        case AttendancePolicyPrimaryStatus.excessBreak:
          return _strictStyle(
              'Istirahat berlebih', AttendancePolicySeverity.red);
        case AttendancePolicyPrimaryStatus.overtime:
          return _strictStyle('Lembur', AttendancePolicySeverity.yellow);
        case AttendancePolicyPrimaryStatus.absence:
          return _strictStyle('Tidak hadir', AttendancePolicySeverity.red);
        case AttendancePolicyPrimaryStatus.exemptManager:
          return _strictStyle('Manager exempt', AttendancePolicySeverity.info);
        case AttendancePolicyPrimaryStatus.hadirTanpaJadwal:
          return _strictStyle(
              'Hadir tanpa jadwal', AttendancePolicySeverity.info);
        case AttendancePolicyPrimaryStatus.belumAbsenPulang:
          return _strictStyle(
              'Belum absen pulang', AttendancePolicySeverity.red);
        case AttendancePolicyPrimaryStatus.activeIncomplete:
          return _strictStyle(
            'Hari masih berjalan',
            primarySeverity ?? AttendancePolicySeverity.info,
          );
        case AttendancePolicyPrimaryStatus.belumMasuk:
          return _strictStyle('Belum masuk', AttendancePolicySeverity.info);
        case AttendancePolicyPrimaryStatus.sakit:
          return _strictStyle('Sakit', AttendancePolicySeverity.info);
        case AttendancePolicyPrimaryStatus.izin:
          return _strictStyle('Izin', AttendancePolicySeverity.info);
        case AttendancePolicyPrimaryStatus.cuti:
          return _strictStyle('Cuti', AttendancePolicySeverity.info);
        case AttendancePolicyPrimaryStatus.libur:
          return _strictStyle('Libur', AttendancePolicySeverity.info);
        case AttendancePolicyPrimaryStatus.hadir:
          return _strictStyle('Hadir', AttendancePolicySeverity.info);
      }
    }

    final resolvedStatus = status ?? AttendancePolicyStatus.hadir;
    final resolvedLateKind = lateKind ?? LateKind.none;

    if (resolvedLateKind == LateKind.breakFirstConfirmed) {
      return const _AttendancePolicyBadgeStyle(
        label: 'Break-first',
        foregroundColor: Color(0xFF9A3412),
        backgroundColor: Color(0xFFFFEDD5),
        borderColor: Color(0xFFF97316),
      );
    }

    if (resolvedLateKind == LateKind.breakFirstEligible) {
      return const _AttendancePolicyBadgeStyle(
        label: 'Kandidat break-first',
        foregroundColor: Color(0xFF92400E),
        backgroundColor: Color(0xFFFEF3C7),
        borderColor: Color(0xFFF59E0B),
      );
    }

    if (resolvedLateKind == LateKind.normal) {
      return _strictStyle('Terlambat', AttendancePolicySeverity.red);
    }

    switch (resolvedStatus) {
      case AttendancePolicyStatus.belumMasuk:
        return _strictStyle('Belum masuk', AttendancePolicySeverity.info);
      case AttendancePolicyStatus.tidakHadir:
        return _strictStyle('Tidak hadir', AttendancePolicySeverity.red);
      case AttendancePolicyStatus.hadirTanpaJadwal:
        return _strictStyle(
            'Hadir tanpa jadwal', AttendancePolicySeverity.info);
      case AttendancePolicyStatus.sakit:
        return _strictStyle('Sakit', AttendancePolicySeverity.info);
      case AttendancePolicyStatus.izin:
        return _strictStyle('Izin', AttendancePolicySeverity.info);
      case AttendancePolicyStatus.cuti:
        return _strictStyle('Cuti', AttendancePolicySeverity.info);
      case AttendancePolicyStatus.libur:
        return _strictStyle('Libur', AttendancePolicySeverity.info);
      case AttendancePolicyStatus.hadir:
        return _strictStyle('Hadir', AttendancePolicySeverity.info);
    }
  }

  static _AttendancePolicyBadgeStyle _strictStyle(
    String label,
    AttendancePolicySeverity severity,
  ) {
    switch (severity) {
      case AttendancePolicySeverity.red:
        return const _AttendancePolicyBadgeStyle(
          label: '',
          foregroundColor: AppColors.danger,
          backgroundColor: AppColors.dangerLight,
          borderColor: Color(0xFFF87171),
        ).copyWith(label: label);
      case AttendancePolicySeverity.yellow:
        return const _AttendancePolicyBadgeStyle(
          label: '',
          foregroundColor: Color(0xFF92400E),
          backgroundColor: Color(0xFFFEF3C7),
          borderColor: Color(0xFFF59E0B),
        ).copyWith(label: label);
      case AttendancePolicySeverity.info:
        if (label == 'Hadir') {
          return const _AttendancePolicyBadgeStyle(
            label: 'Hadir',
            foregroundColor: AppColors.success,
            backgroundColor: Color(0xFFDCFCE7),
            borderColor: Color(0xFF4ADE80),
          );
        }
        if (label == 'Hadir tanpa jadwal') {
          return const _AttendancePolicyBadgeStyle(
            label: 'Hadir tanpa jadwal',
            foregroundColor: Color(0xFF1D4ED8),
            backgroundColor: Color(0xFFDBEAFE),
            borderColor: Color(0xFF60A5FA),
          );
        }
        if (label == 'Izin') {
          return const _AttendancePolicyBadgeStyle(
            label: 'Izin',
            foregroundColor: Color(0xFF1D4ED8),
            backgroundColor: Color(0xFFDBEAFE),
            borderColor: Color(0xFF60A5FA),
          );
        }
        if (label == 'Cuti') {
          return const _AttendancePolicyBadgeStyle(
            label: 'Cuti',
            foregroundColor: Color(0xFF7C3AED),
            backgroundColor: Color(0xFFF3E8FF),
            borderColor: Color(0xFFC084FC),
          );
        }
        return _AttendancePolicyBadgeStyle(
          label: label,
          foregroundColor: const Color(0xFF475569),
          backgroundColor: const Color(0xFFF8FAFC),
          borderColor: const Color(0xFFCBD5E1),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(
      primaryStatus: primaryStatus,
      primarySeverity: primarySeverity,
      status: status,
      lateKind: lateKind,
    );

    return Container(
      key: const Key('attendance-policy-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.borderColor),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: style.foregroundColor,
        ),
      ),
    );
  }
}

class _AttendancePolicyBadgeStyle {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  const _AttendancePolicyBadgeStyle({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  _AttendancePolicyBadgeStyle copyWith({
    String? label,
    Color? foregroundColor,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return _AttendancePolicyBadgeStyle(
      label: label ?? this.label,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
    );
  }
}
