import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/shift_schedule.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/schedule_policy_summary_card.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/schedule_table_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SchedulePolicySummaryCard', () {
    testWidgets('renders locked policy copy and WITA cutoffs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SchedulePolicySummaryCard(),
          ),
        ),
      );

      expect(find.text('Aturan Jadwal Minggu Ini'), findsOneWidget);
      expect(
        find.text(
          'Band dan jam wajib menjadi acuan utama. Jam lama hanya tampil sebagai petunjuk kecil bila masih dibutuhkan.',
        ),
        findsOneWidget,
      );
      expect(find.text('Pagi 07:00\nSiang 10:00\nSore 15:00'), findsOneWidget);
      expect(find.text('FULLTIME 10j\nPARTTIME 9j'), findsOneWidget);
    });
  });

  group('ScheduleTableView', () {
    testWidgets('renders band-first policy labels as the primary chip copy',
        (tester) async {
      final employee = Employee(
        id: 'emp-1',
        name: 'Budi',
        isActive: true,
        createdAt: '',
        updatedAt: '',
        employmentContract: EmployeeContract.fulltime,
      );
      final logicalDate = DateTime(2026, 3, 23);
      final schedule = OutletSchedule(
        id: 'schedule-1',
        outletId: 'outlet-1',
        startDate: logicalDate,
        endDate: logicalDate.add(const Duration(days: 6)),
        template: ShiftTemplate.standard('outlet-1'),
        entries: [
          ScheduleEntry.fromEmployee(
            id: 'entry-1',
            date: logicalDate,
            employee: employee,
            shift: ShiftSlot.pagi(
              contract: employee.employmentContract,
            ),
          ),
        ],
        createdAt: logicalDate,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 960,
              height: 240,
              child: ScheduleTableView(
                employees: [employee],
                currentSchedule: schedule,
                startDate: logicalDate,
                sakitIzinMap: const <String, Map<String, AttendanceType>>{},
                timeOffMap: const <String, List<DateTime>>{},
                leaveBalance: const <String, int>{},
                isBulkMode: false,
                selectedEmployeeIds: const <String>{},
                onCellTap: (_, __) {},
                onEntryTap: (_) {},
                onTimeOffTap: (_) {},
                onToggleSelectAll: () {},
                onToggleEmployee: (_) {},
                getSakitIzin: (_, __) => null,
                getHasTimeOff: (_, __) => false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pagi - 10j'), findsOneWidget);
      expect(find.text('07:00 batas telat'), findsOneWidget);
      expect(find.text('09:00 - 17:00'), findsNothing);
    });
  });
}
