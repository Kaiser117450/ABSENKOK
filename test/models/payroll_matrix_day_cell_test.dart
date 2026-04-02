import 'package:absensi_enakko_flutter/models/payroll_matrix_day_cell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PayrollMatrixDayCell', () {
    test('placeholder uses explicit dash label for missing roster dates', () {
      final cell = PayrollMatrixDayCell.placeholder(DateTime(2026, 3, 27));

      expect(cell.primaryLabel, '-');
      expect(cell.secondaryTags, isEmpty);
      expect(cell.hasData, isFalse);
      expect(cell.fillColorHex, '#FFFFFF');
      expect(cell.textColorHex, '#111827');
    });

    test('exportText appends compact tags on a second line', () {
      final cell = PayrollMatrixDayCell(
        date: DateTime(2026, 3, 27),
        primaryLabel: '07:00 / 17:00',
        secondaryTags: const ['TLT', 'OT'],
        fillColorHex: '#FEF3C7',
        textColorHex: '#92400E',
        primaryStatus: null,
        hasData: true,
      );

      expect(cell.exportText, '07:00 / 17:00\nTLT OT');
    });
  });
}
