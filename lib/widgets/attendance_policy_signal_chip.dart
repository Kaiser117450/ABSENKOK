import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/attendance_policy_signal.dart';

class AttendancePolicySignalChip extends StatelessWidget {
  final AttendancePolicySignal signal;

  const AttendancePolicySignalChip({
    super.key,
    required this.signal,
  });

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(signal);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.borderColor),
      ),
      child: Text(
        signal.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: style.foregroundColor,
        ),
      ),
    );
  }

  static _SignalChipStyle _resolveStyle(AttendancePolicySignal signal) {
    switch (signal) {
      case AttendancePolicySignal.late:
      case AttendancePolicySignal.shortWork:
      case AttendancePolicySignal.excessBreak:
      case AttendancePolicySignal.absence:
      case AttendancePolicySignal.belumAbsenPulang:
        return const _SignalChipStyle(
          foregroundColor: AppColors.danger,
          backgroundColor: AppColors.dangerLight,
          borderColor: Color(0xFFFCA5A5),
        );
      case AttendancePolicySignal.overtime:
      case AttendancePolicySignal.breakFirstConfirmed:
        return const _SignalChipStyle(
          foregroundColor: Color(0xFF92400E),
          backgroundColor: Color(0xFFFEF3C7),
          borderColor: Color(0xFFF59E0B),
        );
      case AttendancePolicySignal.exemptManager:
      case AttendancePolicySignal.hadirTanpaJadwal:
      case AttendancePolicySignal.activeIncomplete:
        return const _SignalChipStyle(
          foregroundColor: Color(0xFF334155),
          backgroundColor: Color(0xFFF8FAFC),
          borderColor: Color(0xFFCBD5E1),
        );
    }
  }
}

class _SignalChipStyle {
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  const _SignalChipStyle({
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });
}
