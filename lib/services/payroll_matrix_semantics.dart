import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_day_cell.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';

class PayrollMatrixSummaryCounts {
  final int lateCount;
  final int shortWorkCount;
  final int excessBreakCount;
  final int absenceCount;
  final int overtimeCount;

  const PayrollMatrixSummaryCounts({
    required this.lateCount,
    required this.shortWorkCount,
    required this.excessBreakCount,
    required this.absenceCount,
    required this.overtimeCount,
  });

  const PayrollMatrixSummaryCounts.zero()
      : lateCount = 0,
        shortWorkCount = 0,
        excessBreakCount = 0,
        absenceCount = 0,
        overtimeCount = 0;

  PayrollMatrixSummaryCounts add(PayrollMatrixSummaryCounts other) {
    return PayrollMatrixSummaryCounts(
      lateCount: lateCount + other.lateCount,
      shortWorkCount: shortWorkCount + other.shortWorkCount,
      excessBreakCount: excessBreakCount + other.excessBreakCount,
      absenceCount: absenceCount + other.absenceCount,
      overtimeCount: overtimeCount + other.overtimeCount,
    );
  }
}

class PayrollMatrixSummaryMetric {
  final String tag;
  final String label;
  final String fillColorHex;
  final String textColorHex;

  const PayrollMatrixSummaryMetric({
    required this.tag,
    required this.label,
    required this.fillColorHex,
    required this.textColorHex,
  });
}

class PayrollMatrixSummaryMetricValue {
  final String tag;
  final String label;
  final int value;
  final String fillColorHex;
  final String textColorHex;

  const PayrollMatrixSummaryMetricValue({
    required this.tag,
    required this.label,
    required this.value,
    required this.fillColorHex,
    required this.textColorHex,
  });
}

class PayrollMatrixSemantics {
  static const String lateTag = 'TLT';
  static const String shortWorkTag = 'KJG';
  static const String excessBreakTag = 'BRK';
  static const String absenceTag = 'ABS';
  static const String overtimeTag = 'OT';
  static const String managerExemptTag = 'ME';

  const PayrollMatrixSemantics();

  static const Map<AttendancePolicySignal, String> _signalTags =
      <AttendancePolicySignal, String>{
    AttendancePolicySignal.late: lateTag,
    AttendancePolicySignal.shortWork: shortWorkTag,
    AttendancePolicySignal.excessBreak: excessBreakTag,
    AttendancePolicySignal.absence: absenceTag,
    AttendancePolicySignal.overtime: overtimeTag,
    AttendancePolicySignal.exemptManager: managerExemptTag,
  };

  static const List<String> _tagOrder = <String>[
    lateTag,
    shortWorkTag,
    excessBreakTag,
    absenceTag,
    overtimeTag,
    managerExemptTag,
  ];

  static const Map<AttendancePolicyPrimaryStatus, _PayrollCellPalette>
      _statusPalettes = <AttendancePolicyPrimaryStatus, _PayrollCellPalette>{
    AttendancePolicyPrimaryStatus.hadir:
        _PayrollCellPalette('#FFFFFF', '#111827'),
    AttendancePolicyPrimaryStatus.late:
        _PayrollCellPalette('#FEF3C7', '#92400E'),
    AttendancePolicyPrimaryStatus.shortWork:
        _PayrollCellPalette('#FEE2E2', '#B91C1C'),
    AttendancePolicyPrimaryStatus.excessBreak:
        _PayrollCellPalette('#FEE2E2', '#B91C1C'),
    AttendancePolicyPrimaryStatus.overtime:
        _PayrollCellPalette('#FEF3C7', '#92400E'),
    AttendancePolicyPrimaryStatus.absence:
        _PayrollCellPalette('#FEE2E2', '#B91C1C'),
    AttendancePolicyPrimaryStatus.exemptManager:
        _PayrollCellPalette('#F8FAFC', '#334155'),
    AttendancePolicyPrimaryStatus.hadirTanpaJadwal:
        _PayrollCellPalette('#ECFEFF', '#0F766E'),
    AttendancePolicyPrimaryStatus.belumAbsenPulang:
        _PayrollCellPalette('#FEE2E2', '#B91C1C'),
    AttendancePolicyPrimaryStatus.activeIncomplete:
        _PayrollCellPalette('#DBEAFE', '#1E40AF'),
    AttendancePolicyPrimaryStatus.belumMasuk:
        _PayrollCellPalette('#F3F4F6', '#6B7280'),
    AttendancePolicyPrimaryStatus.sakit:
        _PayrollCellPalette('#FEF3C7', '#92400E'),
    AttendancePolicyPrimaryStatus.izin:
        _PayrollCellPalette('#DBEAFE', '#1E40AF'),
    AttendancePolicyPrimaryStatus.cuti:
        _PayrollCellPalette('#F3E8FF', '#7C3AED'),
    AttendancePolicyPrimaryStatus.libur:
        _PayrollCellPalette('#F3F4F6', '#6B7280'),
  };

  static const List<PayrollMatrixSummaryMetric> _summaryMetrics =
      <PayrollMatrixSummaryMetric>[
    PayrollMatrixSummaryMetric(
      tag: lateTag,
      label: 'Terlambat',
      fillColorHex: '#FEF3C7',
      textColorHex: '#92400E',
    ),
    PayrollMatrixSummaryMetric(
      tag: shortWorkTag,
      label: 'Kurang Jam',
      fillColorHex: '#FEE2E2',
      textColorHex: '#B91C1C',
    ),
    PayrollMatrixSummaryMetric(
      tag: excessBreakTag,
      label: 'Break Lebih',
      fillColorHex: '#FEE2E2',
      textColorHex: '#B91C1C',
    ),
    PayrollMatrixSummaryMetric(
      tag: absenceTag,
      label: 'Tidak Hadir',
      fillColorHex: '#FEE2E2',
      textColorHex: '#B91C1C',
    ),
    PayrollMatrixSummaryMetric(
      tag: overtimeTag,
      label: 'Lembur',
      fillColorHex: '#FEF3C7',
      textColorHex: '#92400E',
    ),
  ];

  String? tagForSignal(AttendancePolicySignal signal) => _signalTags[signal];

  List<String> get legendTags => List<String>.unmodifiable(_tagOrder);

  List<PayrollMatrixSummaryMetric> get summaryMetrics =>
      List<PayrollMatrixSummaryMetric>.unmodifiable(_summaryMetrics);

  PayrollMatrixDayCell buildDayCell({
    required DateTime date,
    required AttendancePolicyRecapDay? recap,
  }) {
    if (recap == null) {
      return PayrollMatrixDayCell.placeholder(date);
    }

    final palette = _paletteFor(recap);
    final tags = secondaryTagsFor(recap);
    return PayrollMatrixDayCell(
      date: DateTime(date.year, date.month, date.day),
      primaryLabel: _primaryLabelFor(recap),
      secondaryTags: tags,
      secondaryDescriptions: _buildDescriptions(tags, recap),
      fillColorHex: palette.fillColorHex,
      textColorHex: palette.textColorHex,
      primaryStatus: recap.primaryStatus,
      hasData: true,
    );
  }

  /// Builds human-readable descriptions for each tag with duration info.
  /// E.g. "OT" → "Lembur 45m", "TLT" → "Terlambat 15m".
  List<String> _buildDescriptions(
    List<String> tags,
    AttendancePolicyRecapDay recap,
  ) {
    return tags.map((tag) {
      switch (tag) {
        case lateTag:
          return _descWithDuration('Terlambat', _estimateLateMinutes(recap));
        case shortWorkTag:
          return _descWithDuration('Kurang Jam', recap.shortWorkMinutes);
        case excessBreakTag:
          return _descWithDuration('Break Lebih', recap.excessBreakMinutes);
        case absenceTag:
          return 'Tidak Hadir';
        case overtimeTag:
          return _descWithDuration('Lembur', recap.overtimeMinutes);
        case managerExemptTag:
          return 'Manager Exempt';
        default:
          return tag;
      }
    }).toList(growable: false);
  }

  /// Formats a description with duration in minutes/hours.
  /// E.g. "Lembur 45m", "Kurang Jam 1j 30m".
  static String _descWithDuration(String label, int? minutes) {
    if (minutes == null || minutes == 0) return label;
    final absMinutes = minutes.abs();
    if (absMinutes < 60) return '$label ${absMinutes}m';
    final hours = absMinutes ~/ 60;
    final remainder = absMinutes % 60;
    if (remainder == 0) return '$label ${hours}j';
    return '$label ${hours}j ${remainder}m';
  }

  /// Estimate late minutes from recap data.
  /// The recap model doesn't have a direct `lateMinutes` field, so we
  /// derive it from the difference between scheduled start and actual scan.
  static int? _estimateLateMinutes(AttendancePolicyRecapDay recap) {
    if (recap.firstScanLocal == null || recap.lateCutoffLocal == null) {
      return null;
    }
    final cutoff = DateTime.tryParse(recap.lateCutoffLocal!);
    if (cutoff == null) return null;
    final diff = recap.firstScanLocal!.difference(cutoff).inMinutes;
    return diff > 0 ? diff : null;
  }

  List<String> secondaryTagsFor(AttendancePolicyRecapDay recap) {
    final seen = <String>{};
    final orderedTags = <String>[];

    final primaryTag = _tagForPrimaryStatus(recap.primaryStatus);
    if (primaryTag != null && seen.add(primaryTag)) {
      orderedTags.add(primaryTag);
    }

    for (final signal in recap.detailSignals) {
      final tag = _signalTags[signal];
      if (tag == null || !seen.add(tag)) {
        continue;
      }
      orderedTags.add(tag);
    }

    orderedTags.sort(
      (left, right) =>
          _tagOrder.indexOf(left).compareTo(_tagOrder.indexOf(right)),
    );
    return orderedTags;
  }

  PayrollMatrixSummaryCounts countsForRecap(AttendancePolicyRecapDay recap) {
    return PayrollMatrixSummaryCounts(
      lateCount: _hasLate(recap) ? 1 : 0,
      shortWorkCount: _hasShortWork(recap) ? 1 : 0,
      excessBreakCount: _hasExcessBreak(recap) ? 1 : 0,
      absenceCount: _hasAbsence(recap) ? 1 : 0,
      overtimeCount: _hasOvertime(recap) ? 1 : 0,
    );
  }

  PayrollMatrixSummaryCounts summarizeDataset(PayrollMatrixDataset dataset) {
    var summary = const PayrollMatrixSummaryCounts.zero();
    for (final row in dataset.rows) {
      summary = summary.add(
        PayrollMatrixSummaryCounts(
          lateCount: row.lateCount,
          shortWorkCount: row.shortWorkCount,
          excessBreakCount: row.excessBreakCount,
          absenceCount: row.absenceCount,
          overtimeCount: row.overtimeCount,
        ),
      );
    }
    return summary;
  }

  List<PayrollMatrixSummaryMetricValue> summaryMetricValuesForDataset(
    PayrollMatrixDataset dataset,
  ) {
    final summary = summarizeDataset(dataset);
    return _summaryMetrics
        .map(
          (metric) => PayrollMatrixSummaryMetricValue(
            tag: metric.tag,
            label: metric.label,
            value: _summaryValueForTag(metric.tag, summary),
            fillColorHex: metric.fillColorHex,
            textColorHex: metric.textColorHex,
          ),
        )
        .toList(growable: false);
  }

  String _primaryLabelFor(AttendancePolicyRecapDay recap) {
    if (recap.primaryStatus == AttendancePolicyPrimaryStatus.hadirTanpaJadwal) {
      return _explicitPrimaryLabels[
          AttendancePolicyPrimaryStatus.hadirTanpaJadwal]!;
    }
    if (recap.primaryStatus == null &&
        recap.attendanceStatus == AttendancePolicyStatus.hadirTanpaJadwal) {
      return _explicitStatusLabels[AttendancePolicyStatus.hadirTanpaJadwal]!;
    }

    if (recap.firstScanLocal != null && recap.lastPulangLocal != null) {
      return '${_formatTime(recap.firstScanLocal!)} / ${_formatTime(recap.lastPulangLocal!)}';
    }

    final primaryStatus = recap.primaryStatus;
    if (primaryStatus != null) {
      final explicitPrimary = _explicitPrimaryLabels[primaryStatus];
      if (explicitPrimary != null) {
        return explicitPrimary;
      }
    }

    final explicitStatus = _explicitStatusLabels[recap.attendanceStatus];
    if (explicitStatus != null) {
      return explicitStatus;
    }

    if (recap.firstScanLocal != null && recap.lastPulangLocal == null) {
      return 'Belum Absen Pulang';
    }
    if (recap.firstScanLocal == null && recap.lastPulangLocal != null) {
      return 'Belum Masuk';
    }

    final note = recap.notes?.trim();
    if (note != null && note.isNotEmpty) {
      return note;
    }

    return 'Hadir';
  }

  _PayrollCellPalette _paletteFor(AttendancePolicyRecapDay recap) {
    final primaryStatus = recap.primaryStatus;
    if (primaryStatus != null) {
      return _statusPalettes[primaryStatus] ??
          const _PayrollCellPalette(
            '#FFFFFF',
            '#111827',
          );
    }

    switch (recap.attendanceStatus) {
      case AttendancePolicyStatus.sakit:
        return _statusPalettes[AttendancePolicyPrimaryStatus.sakit]!;
      case AttendancePolicyStatus.izin:
        return _statusPalettes[AttendancePolicyPrimaryStatus.izin]!;
      case AttendancePolicyStatus.cuti:
        return _statusPalettes[AttendancePolicyPrimaryStatus.cuti]!;
      case AttendancePolicyStatus.libur:
        return _statusPalettes[AttendancePolicyPrimaryStatus.libur]!;
      case AttendancePolicyStatus.hadirTanpaJadwal:
        return _statusPalettes[AttendancePolicyPrimaryStatus.hadirTanpaJadwal]!;
      case AttendancePolicyStatus.tidakHadir:
        return _statusPalettes[AttendancePolicyPrimaryStatus.absence]!;
      case AttendancePolicyStatus.belumMasuk:
        return _statusPalettes[AttendancePolicyPrimaryStatus.belumMasuk]!;
      case AttendancePolicyStatus.hadir:
        return _statusPalettes[AttendancePolicyPrimaryStatus.hadir]!;
    }
  }

  String? _tagForPrimaryStatus(AttendancePolicyPrimaryStatus? status) {
    switch (status) {
      case AttendancePolicyPrimaryStatus.late:
        return lateTag;
      case AttendancePolicyPrimaryStatus.shortWork:
        return shortWorkTag;
      case AttendancePolicyPrimaryStatus.excessBreak:
        return excessBreakTag;
      case AttendancePolicyPrimaryStatus.absence:
        return absenceTag;
      case AttendancePolicyPrimaryStatus.overtime:
        return overtimeTag;
      case AttendancePolicyPrimaryStatus.exemptManager:
        return managerExemptTag;
      case null:
      case AttendancePolicyPrimaryStatus.hadir:
      case AttendancePolicyPrimaryStatus.hadirTanpaJadwal:
      case AttendancePolicyPrimaryStatus.belumAbsenPulang:
      case AttendancePolicyPrimaryStatus.activeIncomplete:
      case AttendancePolicyPrimaryStatus.belumMasuk:
      case AttendancePolicyPrimaryStatus.sakit:
      case AttendancePolicyPrimaryStatus.izin:
      case AttendancePolicyPrimaryStatus.cuti:
      case AttendancePolicyPrimaryStatus.libur:
        return null;
    }
  }

  bool _hasLate(AttendancePolicyRecapDay recap) {
    return recap.hasSignal(AttendancePolicySignal.late) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.late ||
        recap.isLate ||
        recap.lateKind != LateKind.none;
  }

  bool _hasShortWork(AttendancePolicyRecapDay recap) {
    return recap.hasSignal(AttendancePolicySignal.shortWork) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.shortWork;
  }

  bool _hasExcessBreak(AttendancePolicyRecapDay recap) {
    return recap.hasSignal(AttendancePolicySignal.excessBreak) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.excessBreak;
  }

  bool _hasAbsence(AttendancePolicyRecapDay recap) {
    return recap.hasSignal(AttendancePolicySignal.absence) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.absence ||
        recap.attendanceStatus == AttendancePolicyStatus.tidakHadir;
  }

  bool _hasOvertime(AttendancePolicyRecapDay recap) {
    return recap.hasSignal(AttendancePolicySignal.overtime) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.overtime;
  }

  int _summaryValueForTag(
    String tag,
    PayrollMatrixSummaryCounts summary,
  ) {
    switch (tag) {
      case lateTag:
        return summary.lateCount;
      case shortWorkTag:
        return summary.shortWorkCount;
      case excessBreakTag:
        return summary.excessBreakCount;
      case absenceTag:
        return summary.absenceCount;
      case overtimeTag:
        return summary.overtimeCount;
      case managerExemptTag:
        return 0;
    }
    return 0;
  }

  String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  static const Map<AttendancePolicyPrimaryStatus, String>
      _explicitPrimaryLabels = <AttendancePolicyPrimaryStatus, String>{
    AttendancePolicyPrimaryStatus.libur: 'Libur',
    AttendancePolicyPrimaryStatus.izin: 'Izin',
    AttendancePolicyPrimaryStatus.sakit: 'Sakit',
    AttendancePolicyPrimaryStatus.cuti: 'Cuti',
    AttendancePolicyPrimaryStatus.absence: 'Tidak Hadir',
    AttendancePolicyPrimaryStatus.hadirTanpaJadwal: 'Hadir tanpa jadwal',
    AttendancePolicyPrimaryStatus.belumAbsenPulang: 'Belum Absen Pulang',
    AttendancePolicyPrimaryStatus.belumMasuk: 'Belum Masuk',
    AttendancePolicyPrimaryStatus.activeIncomplete: 'Masih Bekerja',
  };

  static const Map<AttendancePolicyStatus, String> _explicitStatusLabels =
      <AttendancePolicyStatus, String>{
    AttendancePolicyStatus.libur: 'Libur',
    AttendancePolicyStatus.izin: 'Izin',
    AttendancePolicyStatus.sakit: 'Sakit',
    AttendancePolicyStatus.cuti: 'Cuti',
    AttendancePolicyStatus.tidakHadir: 'Tidak Hadir',
    AttendancePolicyStatus.hadirTanpaJadwal: 'Hadir tanpa jadwal',
    AttendancePolicyStatus.belumMasuk: 'Belum Masuk',
  };
}

class _PayrollCellPalette {
  final String fillColorHex;
  final String textColorHex;

  const _PayrollCellPalette(this.fillColorHex, this.textColorHex);
}
