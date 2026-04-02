class ScheduleGapNoticeEntry {
  const ScheduleGapNoticeEntry({
    required this.employeeId,
    required this.employeeName,
    required this.outletId,
    required this.outletName,
    required this.logicalDate,
    required this.statusLabel,
    required this.helperText,
  });

  final String employeeId;
  final String employeeName;
  final String outletId;
  final String outletName;
  final DateTime logicalDate;
  final String statusLabel;
  final String helperText;
}

class ScheduleGapNoticeResult {
  const ScheduleGapNoticeResult({
    required this.entries,
  });

  final List<ScheduleGapNoticeEntry> entries;

  bool get hasNotices => entries.isNotEmpty;
  int get count => entries.length;
}
