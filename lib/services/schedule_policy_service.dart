import 'package:flutter/material.dart';

import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';

class SchedulePolicyService {
  static const int fulltimeRequiredWorkMinutes = 600;
  // Part-time: 8 jam kerja wajib
  static const int parttimeRequiredWorkMinutes = 480;
  // Break: fulltime & parttime-saat-lembur = 2j, parttime-normal = 1j
  static const int fulltimeBreakAllowanceMinutes = 120;
  static const int parttimeBreakAllowanceMinutes = 60;

  static int defaultRequiredWorkMinutes(EmployeeContract contract) {
    switch (contract) {
      case EmployeeContract.fulltime:
        return fulltimeRequiredWorkMinutes;
      case EmployeeContract.parttime:
        return parttimeRequiredWorkMinutes;
    }
  }

  static TimeOfDay? lateCutoff(ShiftBand band) {
    return band.lateCutoff;
  }

  static int payrollBreakAllowanceMinutes({
    required EmployeeContract contract,
    bool isOvertime = false,
  }) {
    if (isOvertime) {
      return fulltimeBreakAllowanceMinutes;
    }

    switch (contract) {
      case EmployeeContract.fulltime:
        return fulltimeBreakAllowanceMinutes;
      case EmployeeContract.parttime:
        return parttimeBreakAllowanceMinutes;
    }
  }

  static bool isLate({
    required DateTime logicalDate,
    required DateTime scannedAt,
    required ShiftBand band,
  }) {
    final cutoff = lateCutoff(band);
    if (cutoff == null) {
      return false;
    }

    final cutoffAtMinute = DateTime(
      logicalDate.year,
      logicalDate.month,
      logicalDate.day,
      cutoff.hour,
      cutoff.minute,
    );
    final scannedAtMinute = DateTime(
      logicalDate.year,
      logicalDate.month,
      logicalDate.day,
      scannedAt.hour,
      scannedAt.minute,
    );

    return scannedAtMinute.isAfter(cutoffAtMinute);
  }

  static int scheduledSpanMinutes({
    required EmployeeContract contract,
    required int requiredWorkMinutes,
  }) {
    final defaultMinutes = defaultRequiredWorkMinutes(contract);
    return requiredWorkMinutes +
        payrollBreakAllowanceMinutes(
          contract: contract,
          isOvertime: requiredWorkMinutes > defaultMinutes,
        );
  }

  static TimeOfDay estimatedShiftEnd({
    required TimeOfDay startTime,
    required EmployeeContract contract,
    required int requiredWorkMinutes,
  }) {
    return _timeOfDayFromMinutes(
      _minutesOfDay(startTime) +
          scheduledSpanMinutes(
            contract: contract,
            requiredWorkMinutes: requiredWorkMinutes,
          ),
    );
  }

  static int _minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

  static TimeOfDay _timeOfDayFromMinutes(int minutes) {
    final normalized = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60);
    return TimeOfDay(
      hour: normalized ~/ 60,
      minute: normalized % 60,
    );
  }
}
