import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/shift_schedule.dart';
import 'package:absensi_enakko_flutter/screens/admin/shift_scheduler_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Employee buildEmployee() {
    return const Employee(
      id: 'emp-1',
      name: 'Ayu',
      homeOutletId: 'outlet-1',
      isActive: true,
      createdAt: '2026-03-01T00:00:00Z',
      updatedAt: '2026-03-01T00:00:00Z',
      employmentContract: EmployeeContract.parttime,
    );
  }

  ScheduleEntry buildEntry(Employee employee) {
    return ScheduleEntry.fromEmployee(
      id: 'entry-1',
      date: DateTime(2026, 3, 28),
      employee: employee,
      shift: ShiftSlot.pagi(contract: employee.employmentContract),
    );
  }

  Future<void> pumpEditor(WidgetTester tester) async {
    final employee = buildEmployee();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleAssignedEntryEditorSheet(
            employee: employee,
            entry: buildEntry(employee),
            onDelete: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ScheduleAssignedEntryEditorSheet', () {
    testWidgets('uses readable dark labels for band chips', (tester) async {
      await pumpEditor(tester);

      final selectedChip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey<String>('schedule-band-PAGI')),
      );
      final unselectedChip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey<String>('schedule-band-SIANG')),
      );

      expect(selectedChip.labelStyle?.color, const Color(0xFF111827));
      expect(unselectedChip.labelStyle?.color, const Color(0xFF111827));
      expect(selectedChip.selectedColor, const Color(0xFFE2E8F0));
      expect(unselectedChip.backgroundColor, const Color(0xFFF8FAFC));
    });

    testWidgets('keeps required-hours chips readable when disabled by libur',
        (tester) async {
      await pumpEditor(tester);

      await tester
          .tap(find.byKey(const ValueKey<String>('schedule-band-LIBUR')));
      await tester.pumpAndSettle();

      final disabledChip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey<String>('schedule-hours-480')),
      );

      expect(disabledChip.onSelected, isNull);
      expect(disabledChip.labelStyle?.color, const Color(0xFF111827));
      expect(disabledChip.disabledColor, const Color(0xFFE5E7EB));
    });
  });
}
