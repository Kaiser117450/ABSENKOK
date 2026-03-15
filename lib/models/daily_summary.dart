import '../models/employee.dart';
import '../models/outlet.dart';

/// Status of a daily attendance summary entry.
/// Used to select the correct rendering path in _DailySummaryTile.
enum DailySummaryStatus { normal, sakit, izin, belumPulang }

/// Aggregated daily attendance data for one employee on one day.
class DailySummary {
  final String dateLabel; // "YYYY-MM-DD"
  final Employee? employee;
  final Outlet? outlet;
  final DateTime? firstMasuk;
  final DateTime? lastPulang;
  final Duration? workDuration;
  final Duration totalBreak;
  final int scanCount;
  final DailySummaryStatus status;   // normal/sakit/izin — controls tile rendering
  final String? statusNotes;         // from attendance_logs.notes — shown below badge

  const DailySummary({
    required this.dateLabel,
    required this.employee,
    required this.outlet,
    required this.firstMasuk,
    required this.lastPulang,
    required this.workDuration,
    required this.totalBreak,
    required this.scanCount,
    required this.status,
    this.statusNotes,
  });
}
