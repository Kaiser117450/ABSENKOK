import 'attendance_policy_signal.dart';

class PayrollMatrixDayCell {
  final DateTime date;
  final String primaryLabel;
  final List<String> secondaryTags;
  final List<String> secondaryDescriptions;
  final String fillColorHex;
  final String textColorHex;
  final AttendancePolicyPrimaryStatus? primaryStatus;
  final bool hasData;

  const PayrollMatrixDayCell({
    required this.date,
    required this.primaryLabel,
    required this.secondaryTags,
    this.secondaryDescriptions = const [],
    required this.fillColorHex,
    required this.textColorHex,
    required this.primaryStatus,
    required this.hasData,
  });

  factory PayrollMatrixDayCell.placeholder(DateTime date) {
    return PayrollMatrixDayCell(
      date: DateTime(date.year, date.month, date.day),
      primaryLabel: '-',
      secondaryTags: const [],
      secondaryDescriptions: const [],
      fillColorHex: '#FFFFFF',
      textColorHex: '#111827',
      primaryStatus: null,
      hasData: false,
    );
  }

  bool get hasTags => secondaryTags.isNotEmpty;

  /// Short export text using abbreviation tags (e.g. "OT", "TLT").
  String get exportText {
    if (secondaryTags.isEmpty) {
      return primaryLabel;
    }
    return '$primaryLabel\n${secondaryTags.join(' ')}';
  }

  /// Enriched export text using full descriptive labels with duration.
  /// Example: "07:00 / 17:00\nLembur 45m" instead of "07:00 / 17:00\nOT".
  String get enrichedExportText {
    final descriptions = secondaryDescriptions.isNotEmpty
        ? secondaryDescriptions
        : secondaryTags;
    if (descriptions.isEmpty) {
      return primaryLabel;
    }
    return '$primaryLabel\n${descriptions.join(' | ')}';
  }
}
