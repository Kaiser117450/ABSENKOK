import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_day_cell.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/payroll_matrix_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PayrollMatrixDataset buildDataset() {
    return PayrollMatrixDataset(
      dates: <DateTime>[
        DateTime(2026, 3, 25),
        DateTime(2026, 3, 26),
      ],
      rows: <PayrollMatrixRow>[
        PayrollMatrixRow(
          employeeId: 'emp-1',
          employeeName: 'Ayu',
          employmentContract: EmployeeContract.fulltime,
          cells: <PayrollMatrixDayCell>[
            PayrollMatrixDayCell(
              date: DateTime(2026, 3, 25),
              primaryLabel: '07:05 / 17:10',
              secondaryTags: <String>['TLT'],
              fillColorHex: '#FEF3C7',
              textColorHex: '#92400E',
              primaryStatus: null,
              hasData: true,
            ),
            PayrollMatrixDayCell.placeholder(DateTime(2026, 3, 26)),
          ],
          lateCount: 1,
          shortWorkCount: 0,
          excessBreakCount: 0,
          absenceCount: 0,
          overtimeCount: 0,
        ),
        PayrollMatrixRow(
          employeeId: 'emp-2',
          employeeName: 'Budi',
          employmentContract: EmployeeContract.parttime,
          cells: <PayrollMatrixDayCell>[
            PayrollMatrixDayCell(
              date: DateTime(2026, 3, 25),
              primaryLabel: 'Libur',
              secondaryTags: <String>[],
              fillColorHex: '#F3F4F6',
              textColorHex: '#6B7280',
              primaryStatus: null,
              hasData: true,
            ),
            PayrollMatrixDayCell(
              date: DateTime(2026, 3, 26),
              primaryLabel: '10:00 / 19:30',
              secondaryTags: <String>['OT'],
              fillColorHex: '#FEF3C7',
              textColorHex: '#92400E',
              primaryStatus: null,
              hasData: true,
            ),
          ],
          lateCount: 0,
          shortWorkCount: 0,
          excessBreakCount: 0,
          absenceCount: 0,
          overtimeCount: 1,
        ),
      ],
    );
  }

  group('PayrollMatrixTable', () {
    testWidgets('renders employee rail, summary order, and day-cell tags',
        (tester) async {
      final dataset = buildDataset();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1100,
              height: 420,
              child: PayrollMatrixTable(
                dataset: dataset,
                dateHeaders: dataset.dates,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('payroll-employee-rail')), findsOneWidget);
      expect(find.text('Ayu'), findsOneWidget);
      expect(find.text('Budi'), findsOneWidget);
      expect(find.text('TLT'), findsOneWidget);
      expect(find.text('OT'), findsOneWidget);

      final summaryTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('payroll-summary-rail')),
              matching: find.byType(Text),
            ),
          )
          .map((widget) => widget.data)
          .whereType<String>()
          .take(5)
          .toList(growable: false);

      expect(summaryTexts, PayrollMatrixRow.summaryLabels);
    });

    testWidgets('stays read-only without InkWell cell interactions',
        (tester) async {
      final dataset = buildDataset();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1100,
              height: 420,
              child: PayrollMatrixTable(
                dataset: dataset,
                dateHeaders: dataset.dates,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(InkWell), findsNothing);
    });
  });
}
