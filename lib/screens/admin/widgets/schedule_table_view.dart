import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/shift_schedule.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/schedule_cells.dart';

/// Wraps [TableView.builder] with pinned header row and employee column.
///
/// Receives ALL data and callbacks from the parent screen — does NOT manage
/// state itself. Dispatches to cell builder functions in `schedule_cells.dart`.
class ScheduleTableView extends StatelessWidget {
  final List<Employee> employees;
  final OutletSchedule? currentSchedule;
  final DateTime startDate;
  final Map<String, Map<String, AttendanceType>> sakitIzinMap;
  final Map<String, List<DateTime>> timeOffMap;
  final Map<String, int> leaveBalance;
  final bool isBulkMode;
  final Set<String> selectedEmployeeIds;

  // Callbacks
  final void Function(Employee emp, DateTime date) onCellTap;
  final void Function(ScheduleEntry entry) onEntryTap;
  final void Function(Employee emp) onTimeOffTap;
  final VoidCallback onToggleSelectAll;
  final void Function(String empId) onToggleEmployee;

  // Helpers passed from parent (reuse existing logic, don't duplicate)
  final AttendanceType? Function(String empId, DateTime date) getSakitIzin;
  final bool Function(String empId, DateTime date) getHasTimeOff;

  const ScheduleTableView({
    super.key,
    required this.employees,
    required this.currentSchedule,
    required this.startDate,
    required this.sakitIzinMap,
    required this.timeOffMap,
    required this.leaveBalance,
    required this.isBulkMode,
    required this.selectedEmployeeIds,
    required this.onCellTap,
    required this.onEntryTap,
    required this.onTimeOffTap,
    required this.onToggleSelectAll,
    required this.onToggleEmployee,
    required this.getSakitIzin,
    required this.getHasTimeOff,
  });

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return const Center(child: Text('Tidak ada karyawan'));
    }

    final days = List.generate(7, (i) => startDate.add(Duration(days: i)));

    return TableView.builder(
      diagonalDragBehavior: DiagonalDragBehavior.free,
      pinnedRowCount: 1,
      pinnedColumnCount: 1,
      columnCount: 8, // 1 name col + 7 day cols
      rowCount: employees.length + 1, // +1 for header row
      cellBuilder: (BuildContext context, TableVicinity vicinity) {
        // Row 0, Col 0 → corner cell
        if (vicinity.row == 0 && vicinity.column == 0) {
          return buildCornerCell(
            isBulkMode: isBulkMode,
            allSelected: selectedEmployeeIds.length == employees.length &&
                employees.isNotEmpty,
            onToggleSelectAll: onToggleSelectAll,
          );
        }

        // Row 0 → header cell
        if (vicinity.row == 0) {
          return buildHeaderCell(
            date: days[vicinity.column - 1],
            weekStart: startDate,
          );
        }

        // Col 0 → employee cell
        if (vicinity.column == 0) {
          final emp = employees[vicinity.row - 1];
          return buildEmployeeCell(
            emp: emp,
            isBulkMode: isBulkMode,
            isSelected: selectedEmployeeIds.contains(emp.id),
            leaveBalance: leaveBalance[emp.id] ?? 0,
            onToggle: () => onToggleEmployee(emp.id),
            onTimeOffTap: () => onTimeOffTap(emp),
          );
        }

        // All others → shift cell
        final emp = employees[vicinity.row - 1];
        final date = days[vicinity.column - 1];
        return buildShiftCell(
          emp: emp,
          date: date,
          schedule: currentSchedule,
          sakitIzin: getSakitIzin(emp.id, date),
          hasTimeOff: getHasTimeOff(emp.id, date),
          onTapEmpty: () => onCellTap(emp, date),
          onTapAssigned: onEntryTap,
        );
      },
      columnBuilder: (int index) {
        if (index == 0) {
          // Employee name column — fixed 120px
          return const TableSpan(extent: FixedTableSpanExtent(120));
        }
        // Day columns — max of (75px fixed, 1/7 viewport fraction)
        final dayIndex = index - 1;
        final date = days[dayIndex];
        final isToday = _isToday(date);
        return TableSpan(
          extent: const MaxTableSpanExtent(
            FixedTableSpanExtent(92),
            FractionalTableSpanExtent(1 / 7),
          ),
          backgroundDecoration: isToday
              ? TableSpanDecoration(color: Colors.amber.withValues(alpha: 0.08))
              : null,
          foregroundDecoration: const TableSpanDecoration(
            border: TableSpanBorder(
              trailing: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
            ),
          ),
        );
      },
      rowBuilder: (int index) {
        if (index == 0) {
          // Header row — fixed 44px
          return const TableSpan(extent: FixedTableSpanExtent(44));
        }
        // Data rows — taller to allow the policy hint to wrap.
        return const TableSpan(
          extent: FixedTableSpanExtent(72),
          foregroundDecoration: TableSpanDecoration(
            border: TableSpanBorder(
              trailing: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
            ),
          ),
        );
      },
    );
  }

  /// Checks whether [date] is today.
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
