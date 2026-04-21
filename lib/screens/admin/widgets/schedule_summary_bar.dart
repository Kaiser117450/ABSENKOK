import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';
import 'package:absensi_enakko_flutter/models/shift_schedule.dart';

/// Compact summary bar showing shift distribution for the current week.
///
/// Displays counts for Pagi / Siang / Sore / Malam / Libur including sakit, izin,
/// and approved time-off entries counted as libur.
class ScheduleSummaryBar extends StatelessWidget {
  final List<ScheduleEntry> entries;
  final List<Employee> employees;
  final DateTime startDate;
  final Map<String, Map<String, AttendanceType>> sakitIzinMap;
  final Map<String, List<DateTime>> timeOffMap;
  final DateTime? selectedDay;

  const ScheduleSummaryBar({
    super.key,
    required this.entries,
    required this.employees,
    required this.startDate,
    required this.sakitIzinMap,
    required this.timeOffMap,
    this.selectedDay,
  });

  @override
  Widget build(BuildContext context) {
    // When no day is selected, show placeholder
    if (selectedDay == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: const Color(0xFFF8FAFC),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Tap header hari untuk lihat ringkasan',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    int pagiCount = 0;
    int siangCount = 0;
    int soreCount = 0;
    int malamCount = 0;
    int liburCount = 0;

    // Filter entries to only those matching selectedDay
    final filteredEntries = entries
        .where((entry) =>
            entry.date.year == selectedDay!.year &&
            entry.date.month == selectedDay!.month &&
            entry.date.day == selectedDay!.day)
        .toList();

    // Count from filtered schedule entries
    for (final entry in filteredEntries) {
      switch (entry.shift.band) {
        case ShiftBand.pagi:
          pagiCount++;
        case ShiftBand.siang:
          siangCount++;
        case ShiftBand.sore:
          soreCount++;
        case ShiftBand.malam:
          malamCount++;
        case ShiftBand.libur:
          liburCount++;
      }
    }

    // Count sakit/izin/timeoff as libur for the selected day only
    for (final emp in employees) {
      final dateKey = DateFormat('yyyy-MM-dd').format(selectedDay!);
      final hasSakitIzin = sakitIzinMap[emp.id]?[dateKey] != null;
      final hasTimeOff = (timeOffMap[emp.id] ?? []).any((d) =>
          d.year == selectedDay!.year &&
          d.month == selectedDay!.month &&
          d.day == selectedDay!.day);
      if (hasSakitIzin || hasTimeOff) {
        // Only count if there's no schedule entry already counted
        final hasEntry = filteredEntries.any((e) =>
            e.employeeId == emp.id &&
            e.date.year == selectedDay!.year &&
            e.date.month == selectedDay!.month &&
            e.date.day == selectedDay!.day);
        if (!hasEntry) {
          liburCount++;
        }
      }
    }

    // Format the selected day label
    const dayNames = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    const monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    final dayName = dayNames[selectedDay!.weekday - 1];
    final monthName = monthNames[selectedDay!.month - 1];
    final dayLabel = 'Ringkasan $dayName, ${selectedDay!.day} $monthName';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dayLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Pagi', pagiCount, const Color(0xFF3B82F6)),
              _chip('Siang', siangCount, const Color(0xFFF59E0B)),
              _chip('Sore', soreCount, const Color(0xFFF97316)),
              _chip('Malam', malamCount, const Color(0xFF4338CA)),
              _chip('Libur', liburCount, const Color(0xFFDC2626)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
