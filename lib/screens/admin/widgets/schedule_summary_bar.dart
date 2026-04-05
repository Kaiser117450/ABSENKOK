import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';
import 'package:absensi_enakko_flutter/models/shift_schedule.dart';

/// Compact summary bar showing shift distribution for the current week.
///
/// Displays counts for Pagi / Siang / Sore / Libur including sakit, izin,
/// and approved time-off entries counted as libur.
class ScheduleSummaryBar extends StatelessWidget {
  final List<ScheduleEntry> entries;
  final List<Employee> employees;
  final DateTime startDate;
  final Map<String, Map<String, AttendanceType>> sakitIzinMap;
  final Map<String, List<DateTime>> timeOffMap;

  const ScheduleSummaryBar({
    super.key,
    required this.entries,
    required this.employees,
    required this.startDate,
    required this.sakitIzinMap,
    required this.timeOffMap,
  });

  @override
  Widget build(BuildContext context) {
    int pagiCount = 0;
    int siangCount = 0;
    int soreCount = 0;
    int liburCount = 0;

    // Count from schedule entries
    for (final entry in entries) {
      switch (entry.shift.band) {
        case ShiftBand.pagi:
          pagiCount++;
        case ShiftBand.siang:
          siangCount++;
        case ShiftBand.sore:
          soreCount++;
        case ShiftBand.libur:
          liburCount++;
      }
    }

    // Count sakit/izin/timeoff as libur (these are not in entries)
    final days = List.generate(7, (i) => startDate.add(Duration(days: i)));
    for (final emp in employees) {
      for (final day in days) {
        final dateKey = DateFormat('yyyy-MM-dd').format(day);
        final hasSakitIzin = sakitIzinMap[emp.id]?[dateKey] != null;
        final hasTimeOff = (timeOffMap[emp.id] ?? []).any((d) =>
            d.year == day.year && d.month == day.month && d.day == day.day);
        if (hasSakitIzin || hasTimeOff) {
          // Only count if there's no schedule entry already counted
          final hasEntry = entries.any((e) =>
              e.employeeId == emp.id &&
              e.date.year == day.year &&
              e.date.month == day.month &&
              e.date.day == day.day);
          if (!hasEntry) {
            liburCount++;
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          _chip('Pagi', pagiCount, const Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          _chip('Siang', siangCount, const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          _chip('Sore', soreCount, const Color(0xFFF97316)),
          const SizedBox(width: 8),
          _chip('Libur', liburCount, const Color(0xFFDC2626)),
        ],
      ),
    );
  }

  Widget _chip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '$label: $count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
