import 'attendance_policy_signal.dart';

class PayrollMatrixDayCell {
  final DateTime date;
  final String primaryLabel;
  final List<String> secondaryTags;
  final String fillColorHex;
  final String textColorHex;
  final AttendancePolicyPrimaryStatus? primaryStatus;
  final bool hasData;

  const PayrollMatrixDayCell({
    required this.date,
    required this.primaryLabel,
    required this.secondaryTags,
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
      fillColorHex: '#FFFFFF',
      textColorHex: '#111827',
      primaryStatus: null,
      hasData: false,
    );
  }

  bool get hasTags => secondaryTags.isNotEmpty;

  String get exportText {
    if (secondaryTags.isEmpty) {
      return primaryLabel;
    }
    return '$primaryLabel\n${secondaryTags.join(' ')}';
  }
}
