import 'package:flutter/material.dart';

import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';

class SchedulePolicyService {
  static const int fulltimeRequiredWorkMinutes = 600;
  static const int parttimeRequiredWorkMinutes = 540;
  static const int fulltimeBreakFirstExtensionMinutes = 120;
  static const int parttimeBreakFirstExtensionMinutes = 60;

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

  static TimeOfDay? breakFirstDeadline({
    required ShiftBand band,
    required EmployeeContract contract,
  }) {
    final cutoff = lateCutoff(band);
    if (cutoff == null) {
      return null;
    }

    return _timeOfDayFromMinutes(
      _minutesOfDay(cutoff) + breakFirstExtensionMinutes(contract),
    );
  }

  static int breakFirstExtensionMinutes(EmployeeContract contract) {
    switch (contract) {
      case EmployeeContract.fulltime:
        return fulltimeBreakFirstExtensionMinutes;
      case EmployeeContract.parttime:
        return parttimeBreakFirstExtensionMinutes;
    }
  }

  static int payrollBreakAllowanceMinutes({
    required EmployeeContract contract,
    bool isOvertime = false,
  }) {
    if (isOvertime) {
      return fulltimeBreakFirstExtensionMinutes;
    }

    return breakFirstExtensionMinutes(contract);
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

  static int _minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

  static TimeOfDay _timeOfDayFromMinutes(int minutes) {
    final normalized = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60);
    return TimeOfDay(
      hour: normalized ~/ 60,
      minute: normalized % 60,
    );
  }
}
