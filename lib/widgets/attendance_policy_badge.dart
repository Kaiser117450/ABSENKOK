import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/attendance_policy_recap_day.dart';

class AttendancePolicyBadge extends StatelessWidget {
  final AttendancePolicyStatus status;
  final LateKind lateKind;

  const AttendancePolicyBadge({
    super.key,
    required this.status,
    required this.lateKind,
  });

  static _AttendancePolicyBadgeStyle _resolveStyle({
    required AttendancePolicyStatus status,
    required LateKind lateKind,
  }) {
    if (lateKind == LateKind.breakFirstConfirmed) {
      return const _AttendancePolicyBadgeStyle(
        label: 'Break-first',
        foregroundColor: Color(0xFF9A3412),
        backgroundColor: Color(0xFFFFEDD5),
        borderColor: Color(0xFFF97316),
      );
    }

    if (lateKind == LateKind.breakFirstEligible) {
      return const _AttendancePolicyBadgeStyle(
        label: 'Kandidat break-first',
        foregroundColor: Color(0xFF92400E),
        backgroundColor: Color(0xFFFEF3C7),
        borderColor: Color(0xFFF59E0B),
      );
    }

    if (lateKind == LateKind.normal) {
      return const _AttendancePolicyBadgeStyle(
        label: 'Terlambat',
        foregroundColor: Color(0xFFB45309),
        backgroundColor: Color(0xFFFEF3C7),
        borderColor: Color(0xFFF59E0B),
      );
    }

    switch (status) {
      case AttendancePolicyStatus.belumMasuk:
        return const _AttendancePolicyBadgeStyle(
          label: 'Belum masuk',
          foregroundColor: Color(0xFF475569),
          backgroundColor: Color(0xFFF8FAFC),
          borderColor: Color(0xFFCBD5E1),
        );
      case AttendancePolicyStatus.tidakHadir:
        return const _AttendancePolicyBadgeStyle(
          label: 'Tidak hadir',
          foregroundColor: Color(0xFFB91C1C),
          backgroundColor: Color(0xFFFEE2E2),
          borderColor: Color(0xFFEF4444),
        );
      case AttendancePolicyStatus.hadirTanpaJadwal:
        return const _AttendancePolicyBadgeStyle(
          label: 'Hadir tanpa jadwal',
          foregroundColor: Color(0xFF1D4ED8),
          backgroundColor: Color(0xFFDBEAFE),
          borderColor: Color(0xFF60A5FA),
        );
      case AttendancePolicyStatus.sakit:
        return const _AttendancePolicyBadgeStyle(
          label: 'Sakit',
          foregroundColor: Color(0xFFB91C1C),
          backgroundColor: Color(0xFFFEE2E2),
          borderColor: Color(0xFFF87171),
        );
      case AttendancePolicyStatus.izin:
        return const _AttendancePolicyBadgeStyle(
          label: 'Izin',
          foregroundColor: Color(0xFF1D4ED8),
          backgroundColor: Color(0xFFDBEAFE),
          borderColor: Color(0xFF60A5FA),
        );
      case AttendancePolicyStatus.cuti:
        return const _AttendancePolicyBadgeStyle(
          label: 'Cuti',
          foregroundColor: Color(0xFF7C3AED),
          backgroundColor: Color(0xFFF3E8FF),
          borderColor: Color(0xFFC084FC),
        );
      case AttendancePolicyStatus.libur:
        return const _AttendancePolicyBadgeStyle(
          label: 'Libur',
          foregroundColor: Color(0xFF475569),
          backgroundColor: Color(0xFFF1F5F9),
          borderColor: Color(0xFFCBD5E1),
        );
      case AttendancePolicyStatus.hadir:
        return const _AttendancePolicyBadgeStyle(
          label: 'Hadir',
          foregroundColor: AppColors.success,
          backgroundColor: Color(0xFFDCFCE7),
          borderColor: Color(0xFF4ADE80),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(status: status, lateKind: lateKind);

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
}
