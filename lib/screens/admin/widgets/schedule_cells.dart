import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:absensi_enakko_flutter/core/theme.dart';
import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';
import 'package:absensi_enakko_flutter/models/shift_schedule.dart';

/// Builds the top-left corner cell (row 0, col 0).
///
/// In bulk mode shows a select-all checkbox; otherwise shows "KARYAWAN" label.
TableViewCell buildCornerCell({
  required bool isBulkMode,
  required bool allSelected,
  required VoidCallback onToggleSelectAll,
}) {
  return TableViewCell(
    child: Container(
      color: isBulkMode
          ? Colors.orange.withValues(alpha: 0.15)
          : AppColors.primary.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: isBulkMode
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Checkbox(
                    value: allSelected,
                    onChanged: (_) => onToggleSelectAll(),
                    activeColor: Colors.orange,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Semua',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
            )
          : const Text(
              'KARYAWAN',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
    ),
  );
}

/// Builds a header cell for a day column (row 0, col 1..7).
///
/// Shows abbreviated day name and day number.
TableViewCell buildHeaderCell({
  required DateTime date,
  required DateTime weekStart,
}) {
  const dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  // DateTime.weekday: Monday=1 ... Sunday=7 → index 0..6
  final dayAbbr = dayNames[date.weekday - 1];

  return TableViewCell(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          dayAbbr,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          '${date.day}',
          style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
        ),
      ],
    ),
  );
}

/// Builds the employee name cell (col 0, row 1..N).
///
/// In bulk mode shows a selection checkbox; otherwise shows leave balance
/// badge and a time-off shortcut button.
TableViewCell buildEmployeeCell({
  required Employee emp,
  required bool isBulkMode,
  required bool isSelected,
  required int leaveBalance,
  required VoidCallback onToggle,
  required VoidCallback onTimeOffTap,
}) {
  return TableViewCell(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      color: isBulkMode && isSelected
          ? Colors.orange.withValues(alpha: 0.08)
          : Colors.grey.shade50,
      child: Row(
        children: [
          if (isBulkMode)
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => onToggle(),
                activeColor: Colors.orange,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
          else
            const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  emp.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (leaveBalance > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+$leaveBalance',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!isBulkMode)
            Material(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: onTimeOffTap,
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Builds a shift/schedule cell (row 1..N, col 1..7).
///
/// Priority: sakitIzin overlay → timeOff overlay → schedule entry → empty "+"
TableViewCell buildShiftCell({
  required Employee emp,
  required DateTime date,
  required OutletSchedule? schedule,
  required AttendanceType? sakitIzin,
  required bool hasTimeOff,
  required VoidCallback onTapEmpty,
  required void Function(ScheduleEntry entry) onTapAssigned,
}) {
  // Sakit/Izin overlay — NOT tappable
  if (sakitIzin != null) {
    return TableViewCell(
      child: Container(
        padding: const EdgeInsets.all(4),
        alignment: Alignment.center,
        child: _chip(sakitIzin.label, sakitIzin.color, Icons.medical_services),
      ),
    );
  }

  // Time-off overlay — NOT tappable
  if (hasTimeOff) {
    return TableViewCell(
      child: Container(
        padding: const EdgeInsets.all(4),
        alignment: Alignment.center,
        child: _chip('Libur', const Color(0xFFDC2626), Icons.beach_access),
      ),
    );
  }

  // Look up schedule entries for this employee + date
  final entries = schedule?.entries
          .where((e) =>
              e.employeeId == emp.id &&
              e.date.year == date.year &&
              e.date.month == date.month &&
              e.date.day == date.day)
          .toList() ??
      [];

  // Empty cell — tappable "+"
  if (entries.isEmpty) {
    return TableViewCell(
      child: GestureDetector(
        onTap: onTapEmpty,
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.add, size: 18, color: Colors.grey.shade400),
        ),
      ),
    );
  }

  // Assigned shift — tappable chip
  final entry = entries.first;
  final shiftBand = entry.shift.band;
  final (bg, fg, icon) = switch (shiftBand) {
    ShiftBand.pagi => (
        const Color(0xFFDBEAFE),
        const Color(0xFF1E40AF),
        Icons.wb_sunny,
      ),
    ShiftBand.siang => (
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
        Icons.wb_twilight,
      ),
    ShiftBand.sore => (
        const Color(0xFFFFEDD5),
        const Color(0xFFC2410C),
        Icons.nights_stay,
      ),
    ShiftBand.libur => (
        const Color(0xFFFEE2E2),
        const Color(0xFF991B1B),
        Icons.beach_access,
      ),
  };

  return TableViewCell(
    child: GestureDetector(
      onTap: () => onTapAssigned(entry),
      child: Container(
        padding: const EdgeInsets.all(4),
        alignment: Alignment.center,
        child: _policyChip(entry.shift, fg, icon, bg: bg),
      ),
    ),
  );
}

/// Renders a compact colored chip with an icon and label.
///
/// Matches the existing `_chip()` from `shift_scheduler_screen.dart`.
Widget _chip(String label, Color color, IconData icon, {Color? bg}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    decoration: BoxDecoration(
      color: bg ?? color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

Widget _policyChip(ShiftSlot shift, Color color, IconData icon, {Color? bg}) {
  final primaryLabel = shift.band == ShiftBand.libur
      ? 'Libur'
      : '${shift.band.label} - ${_formatRequiredHours(shift.requiredWorkMinutes)}';
  final secondaryLabel = shift.band == ShiftBand.libur
      ? 'Hari libur'
      : '${_formatClock(shift.lateCutoffHour, shift.lateCutoffMinute)} batas telat';

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    decoration: BoxDecoration(
      color: bg ?? color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 11, color: color),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                primaryLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                secondaryLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _formatRequiredHours(int requiredWorkMinutes) {
  final hours = requiredWorkMinutes ~/ 60;
  return '${hours}j';
}

String _formatClock(int hour, int minute) {
  final hh = hour.toString().padLeft(2, '0');
  final mm = minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
