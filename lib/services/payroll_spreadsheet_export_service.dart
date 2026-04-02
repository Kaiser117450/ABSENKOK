import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import 'package:absensi_enakko_flutter/models/payroll_matrix_day_cell.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';

typedef TemporaryDirectoryProvider = Future<Directory> Function();

class PayrollSpreadsheetExportService {
  PayrollSpreadsheetExportService({
    TemporaryDirectoryProvider? temporaryDirectoryProvider,
  }) : _temporaryDirectoryProvider =
            temporaryDirectoryProvider ?? getTemporaryDirectory;

  static const String sheetName = 'Rekap Payroll';
  static const List<String> forbiddenFields = <String>[
    'latitude',
    'longitude',
    'capture_mode',
    'queue_order',
    'requires_admin_review',
    'detail_note',
  ];

  final TemporaryDirectoryProvider _temporaryDirectoryProvider;

  Future<File> exportPayrollSpreadsheet({
    required String outletName,
    required DateTime startDate,
    required DateTime endDate,
    required PayrollMatrixDataset dataset,
  }) async {
    final normalizedStart = _dateOnly(startDate);
    final normalizedEnd = _dateOnly(endDate);
    if (normalizedEnd.isBefore(normalizedStart)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'End date must not be before start date',
      );
    }

    final workbook = xlsio.Workbook();
    try {
      final sheet = workbook.worksheets[0];
      sheet.name = sheetName;
      sheet.showGridlines = false;

      final dates = _resolveDates(
        dataset: dataset,
        startDate: normalizedStart,
        endDate: normalizedEnd,
      );
      final lastColumn =
          2 + dates.length + PayrollMatrixRow.summaryLabels.length;

      _configureSheetLayout(sheet, lastColumn: lastColumn);
      _writeHeaders(sheet, dates: dates);

      for (var rowIndex = 0; rowIndex < dataset.rows.length; rowIndex++) {
        _writeEmployeeRow(
          sheet,
          excelRowIndex: rowIndex + 2,
          dates: dates,
          row: dataset.rows[rowIndex],
        );
      }

      final bytes = workbook.saveAsStream();
      final directory = await _temporaryDirectoryProvider();
      final filename = _buildFilename(
        outletName: outletName,
        startDate: normalizedStart,
        endDate: normalizedEnd,
      );
      final file = File(path.join(directory.path, filename));
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } finally {
      workbook.dispose();
    }
  }

  void _configureSheetLayout(
    xlsio.Worksheet sheet, {
    required int lastColumn,
  }) {
    sheet.getRangeByName('A1').columnWidth = 24;
    sheet.getRangeByName('B1').columnWidth = 14;

    for (var column = 3; column <= lastColumn; column++) {
      sheet.getRangeByIndex(1, column).columnWidth =
          column <= lastColumn - PayrollMatrixRow.summaryLabels.length ? 14 : 12;
    }

    sheet.getRangeByIndex(1, 1, 1, lastColumn).rowHeight = 30;
    sheet.getRangeByName('C2').freezePanes();
  }

  void _writeHeaders(
    xlsio.Worksheet sheet, {
    required List<DateTime> dates,
  }) {
    final headerStyle = sheet.getRangeByIndex(
      1,
      1,
      1,
      2 + dates.length + PayrollMatrixRow.summaryLabels.length,
    ).cellStyle;
    headerStyle.backColor = '#F9FAFB';
    headerStyle.fontColor = '#111827';
    headerStyle.bold = true;
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;
    headerStyle.wrapText = true;
    headerStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    headerStyle.borders.all.color = '#E5E7EB';

    sheet.getRangeByName('A1').setText('Karyawan');
    sheet.getRangeByName('B1').setText('Kontrak');

    for (var index = 0; index < dates.length; index++) {
      final range = sheet.getRangeByIndex(1, index + 3);
      range.setText(_formatDateHeader(dates[index]));
    }

    for (var index = 0; index < PayrollMatrixRow.summaryLabels.length; index++) {
      final range = sheet.getRangeByIndex(1, dates.length + 3 + index);
      range.setText(PayrollMatrixRow.summaryLabels[index]);
    }
  }

  void _writeEmployeeRow(
    xlsio.Worksheet sheet, {
    required int excelRowIndex,
    required List<DateTime> dates,
    required PayrollMatrixRow row,
  }) {
    sheet.getRangeByIndex(excelRowIndex, 1, excelRowIndex, 2).rowHeight = 34;

    final identityRange = sheet.getRangeByIndex(excelRowIndex, 1, excelRowIndex, 2);
    identityRange.cellStyle.backColor = '#FFFFFF';
    identityRange.cellStyle.fontColor = '#111827';
    identityRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    identityRange.cellStyle.borders.all.color = '#E5E7EB';
    identityRange.cellStyle.vAlign = xlsio.VAlignType.center;

    sheet.getRangeByIndex(excelRowIndex, 1).setText(row.employeeName);
    sheet.getRangeByIndex(excelRowIndex, 2).setText(row.employmentContract.dbValue);

    for (var index = 0; index < dates.length; index++) {
      final dayCell = index < row.cells.length
          ? row.cells[index]
          : PayrollMatrixDayCell.placeholder(dates[index]);
      final range = sheet.getRangeByIndex(excelRowIndex, index + 3);
      range.setText(dayCell.exportText);
      range.cellStyle.wrapText = true;
      range.cellStyle.backColor = dayCell.fillColorHex;
      range.cellStyle.fontColor = dayCell.textColorHex;
      range.cellStyle.hAlign = xlsio.HAlignType.center;
      range.cellStyle.vAlign = xlsio.VAlignType.center;
      range.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      range.cellStyle.borders.all.color = '#E5E7EB';
    }

    final summaryValues = row.summaryValuesInOrder;
    for (var index = 0; index < summaryValues.length; index++) {
      final range = sheet.getRangeByIndex(
        excelRowIndex,
        dates.length + 3 + index,
      );
      range.setNumber(summaryValues[index].toDouble());
      range.cellStyle.backColor = '#FFFFFF';
      range.cellStyle.fontColor = '#111827';
      range.cellStyle.hAlign = xlsio.HAlignType.center;
      range.cellStyle.vAlign = xlsio.VAlignType.center;
      range.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      range.cellStyle.borders.all.color = '#E5E7EB';
    }
  }

  List<DateTime> _resolveDates({
    required PayrollMatrixDataset dataset,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    if (dataset.dates.isNotEmpty) {
      return dataset.dates.map(_dateOnly).toList(growable: false);
    }

    final dates = <DateTime>[];
    var cursor = startDate;
    while (!cursor.isAfter(endDate)) {
      dates.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return dates;
  }

  String _buildFilename({
    required String outletName,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final outletSlug = _slugifyOutletName(outletName);
    return 'rekap_payroll_${outletSlug}_${_formatDateToken(startDate)}_${_formatDateToken(endDate)}.xlsx';
  }

  String _slugifyOutletName(String outletName) {
    final normalized = outletName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? 'outlet' : normalized;
  }

  String _formatDateHeader(DateTime date) {
    const weekdays = <String>[
      'Min',
      'Sen',
      'Sel',
      'Rab',
      'Kam',
      'Jum',
      'Sab',
    ];
    const months = <String>[
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${weekdays[date.weekday % 7]}\n${date.day} ${months[date.month]}';
  }

  String _formatDateToken(DateTime date) {
    return '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
