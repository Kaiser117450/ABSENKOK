import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_day_cell.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';

typedef TemporaryDirectoryProvider = Future<Directory> Function();

class PayrollSpreadsheetExportService {
  PayrollSpreadsheetExportService({
    TemporaryDirectoryProvider? temporaryDirectoryProvider,
  }) : _temporaryDirectoryProvider =
            temporaryDirectoryProvider ?? getTemporaryDirectory;

  static const String sheetName = 'Rekap Payroll';
  static const String insightSheetName = 'Insight Payroll';
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
    required Iterable<AttendancePolicyRecapDay> recapRows,
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
          3 + dates.length + PayrollMatrixRow.summaryLabels.length;

      _configureSheetLayout(sheet, lastColumn: lastColumn);
      _writeHeaders(sheet, dates: dates);

      // Build dataset with manager sorting
      final sortedDataset = _sortDatasetWithManagersFirst(dataset, recapRows);

      for (var rowIndex = 0; rowIndex < sortedDataset.rows.length; rowIndex++) {
        _writeEmployeeRow(
          sheet,
          excelRowIndex: rowIndex + 2,
          dates: dates,
          row: sortedDataset.rows[rowIndex],
          recapRows: recapRows,
        );
      }

      // Build Sheet 2: Insight Payroll (Area Manager dashboard)
      _buildInsightSheet(
        workbook,
        dataset: sortedDataset,
        outletName: outletName,
        startDate: normalizedStart,
        endDate: normalizedEnd,
        recapRows: recapRows,
      );

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
    sheet.getRangeByName('A1').columnWidth = 26;
    sheet.getRangeByName('B1').columnWidth = 14;
    sheet.getRangeByName('C1').columnWidth = 16;

    for (var column = 4; column <= lastColumn; column++) {
      sheet.getRangeByIndex(1, column).columnWidth =
          column <= lastColumn - PayrollMatrixRow.summaryLabels.length ? 20 : 14;
    }

    sheet.getRangeByIndex(1, 1, 1, lastColumn).rowHeight = 30;
    // Freeze panes: columns A-C (Karyawan, Kontrak, Jabatan) are sticky
    sheet.getRangeByName('D2').freezePanes();
  }

  void _writeHeaders(
    xlsio.Worksheet sheet, {
    required List<DateTime> dates,
  }) {
    final headerStyle = sheet.getRangeByIndex(
      1,
      1,
      1,
      3 + dates.length + PayrollMatrixRow.summaryLabels.length,
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
    sheet.getRangeByName('C1').setText('Jabatan');

    for (var index = 0; index < dates.length; index++) {
      final range = sheet.getRangeByIndex(1, index + 4);
      range.setText(_formatDateHeader(dates[index]));
    }

    for (var index = 0; index < PayrollMatrixRow.summaryLabels.length; index++) {
      final range = sheet.getRangeByIndex(1, dates.length + 4 + index);
      range.setText(PayrollMatrixRow.summaryLabels[index]);
    }
  }

  void _writeEmployeeRow(
    xlsio.Worksheet sheet, {
    required int excelRowIndex,
    required List<DateTime> dates,
    required PayrollMatrixRow row,
    required Iterable<AttendancePolicyRecapDay> recapRows,
  }) {
    // Check if employee is a manager
    final isManager = recapRows.any((recap) =>
        recap.employeeId == row.employeeId && recap.isManagerExempt);

    // Taller rows for enriched descriptions with duration info
    sheet.getRangeByIndex(excelRowIndex, 1, excelRowIndex, 3).rowHeight = 40;

    final identityRange = sheet.getRangeByIndex(excelRowIndex, 1, excelRowIndex, 3);
    identityRange.cellStyle.backColor = '#FFFFFF';
    identityRange.cellStyle.fontColor = '#111827';
    identityRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    identityRange.cellStyle.borders.all.color = '#E5E7EB';
    identityRange.cellStyle.vAlign = xlsio.VAlignType.center;

    // Employee name with manager marker and bold styling
    final employeeName = isManager ? '${row.employeeName} ★' : row.employeeName;
    sheet.getRangeByIndex(excelRowIndex, 1).setText(employeeName);
    if (isManager) {
      sheet.getRangeByIndex(excelRowIndex, 1).cellStyle.bold = true;
    }

    // Contract with human-readable label
    sheet.getRangeByIndex(excelRowIndex, 2).setText(row.employmentContract.label);

    sheet.getRangeByIndex(excelRowIndex, 3).setText(
      row.employeeRole.isNotEmpty ? row.employeeRole : '-',
    );

    for (var index = 0; index < dates.length; index++) {
      final dayCell = index < row.cells.length
          ? row.cells[index]
          : PayrollMatrixDayCell.placeholder(dates[index]);
      final range = sheet.getRangeByIndex(excelRowIndex, index + 4);
      // Use enriched export text with full labels + duration
      range.setText(dayCell.enrichedExportText);
      range.cellStyle.wrapText = true;
      range.cellStyle.backColor = dayCell.fillColorHex;
      range.cellStyle.fontColor = dayCell.textColorHex;
      range.cellStyle.hAlign = xlsio.HAlignType.center;
      range.cellStyle.vAlign = xlsio.VAlignType.center;
      range.cellStyle.fontSize = 9;
      range.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      range.cellStyle.borders.all.color = '#E5E7EB';
    }

    final summaryValues = row.summaryValuesInOrder;
    for (var index = 0; index < summaryValues.length; index++) {
      final range = sheet.getRangeByIndex(
        excelRowIndex,
        dates.length + 4 + index,
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

  PayrollMatrixDataset _sortDatasetWithManagersFirst(
    PayrollMatrixDataset dataset,
    Iterable<AttendancePolicyRecapDay> recapRows,
  ) {
    // Create a map of employee IDs to check if they're managers
    final managerIds = <String>{};
    for (final recap in recapRows) {
      if (recap.isManagerExempt) {
        managerIds.add(recap.employeeId);
      }
    }

    // Sort rows with managers first
    final sortedRows = List<PayrollMatrixRow>.from(dataset.rows)
      ..sort((a, b) {
        final aIsManager = managerIds.contains(a.employeeId);
        final bIsManager = managerIds.contains(b.employeeId);

        if (aIsManager && !bIsManager) return -1;
        if (!aIsManager && bIsManager) return 1;

        // Both are managers or both are not managers - maintain original order
        return 0;
      });

    return PayrollMatrixDataset(
      dates: dataset.dates,
      rows: sortedRows,
    );
  }

  // ---------------------------------------------------------------------------
  // Sheet 2: Insight Payroll — Area Manager Dashboard (Professional)
  // ---------------------------------------------------------------------------

  void _buildInsightSheet(
    xlsio.Workbook workbook, {
    required PayrollMatrixDataset dataset,
    required String outletName,
    required DateTime startDate,
    required DateTime endDate,
    required Iterable<AttendancePolicyRecapDay> recapRows,
  }) {
    final sheet = workbook.worksheets.addWithName(insightSheetName);
    sheet.showGridlines = false;

    sheet.getRangeByIndex(1, 1).columnWidth = 28;
    sheet.getRangeByIndex(1, 2).columnWidth = 14;
    sheet.getRangeByIndex(1, 3).columnWidth = 14;
    sheet.getRangeByIndex(1, 4).columnWidth = 14;
    sheet.getRangeByIndex(1, 5).columnWidth = 14;
    sheet.getRangeByIndex(1, 6).columnWidth = 14;
    sheet.getRangeByIndex(1, 7).columnWidth = 14;
    sheet.getRangeByIndex(1, 8).columnWidth = 16;
    sheet.getRangeByIndex(1, 9).columnWidth = 18;

    var currentRow = 1;

    // --- Section 1: Branded Header ---
    currentRow = _writeInsightHeader(
      sheet,
      row: currentRow,
      outletName: outletName,
      startDate: startDate,
      endDate: endDate,
    );

    // --- Section 2: Navigation Buttons ---
    currentRow = _writeNavigationBar(sheet, row: currentRow);

    // --- Section 3: Overall Statistics KPI Cards ---
    final statsAnchorRow = currentRow;
    currentRow = _writeOverallStats(sheet, row: currentRow, dataset: dataset);

    // --- Section 4: Per-employee summary with mini cart ---
    final empAnchorRow = currentRow;
    currentRow = _writeEmployeeSummaryTable(
      sheet,
      row: currentRow,
      dataset: dataset,
      recapRows: recapRows,
    );

    // --- Section 5: Top performers / issues ---
    final topAnchorRow = currentRow;
    _writeTopInsights(sheet, row: currentRow, dataset: dataset, recapRows: recapRows);

    // Write hyperlink targets back into nav buttons
    _applyNavigationHyperlinks(sheet, statsRow: statsAnchorRow, empRow: empAnchorRow, topRow: topAnchorRow);

    // Freeze: keep header + nav always visible
    sheet.getRangeByIndex(6, 1).freezePanes();
  }

  int _writeInsightHeader(
    xlsio.Worksheet sheet, {
    required int row,
    required String outletName,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final brandRange = sheet.getRangeByIndex(row, 1, row, 9);
    brandRange.merge();
    brandRange.setText('ENAKKO PAYROLL INSIGHT');
    brandRange.cellStyle.bold = true;
    brandRange.cellStyle.fontSize = 16;
    brandRange.cellStyle.fontColor = '#FFFFFF';
    brandRange.cellStyle.backColor = '#DC2626';
    brandRange.cellStyle.hAlign = xlsio.HAlignType.center;
    brandRange.cellStyle.vAlign = xlsio.VAlignType.center;
    brandRange.rowHeight = 40;

    final outletRange = sheet.getRangeByIndex(row + 1, 1, row + 1, 9);
    outletRange.merge();
    outletRange.setText(outletName.toUpperCase());
    outletRange.cellStyle.bold = true;
    outletRange.cellStyle.fontSize = 12;
    outletRange.cellStyle.fontColor = '#111827';
    outletRange.cellStyle.backColor = '#FEF2F2';
    outletRange.cellStyle.hAlign = xlsio.HAlignType.center;
    outletRange.cellStyle.vAlign = xlsio.VAlignType.center;
    outletRange.rowHeight = 28;

    final periodRange = sheet.getRangeByIndex(row + 2, 1, row + 2, 9);
    periodRange.merge();
    periodRange.setText(
      'Periode: ${_formatDateLabel(startDate)} — ${_formatDateLabel(endDate)}',
    );
    periodRange.cellStyle.fontSize = 10;
    periodRange.cellStyle.fontColor = '#6B7280';
    periodRange.cellStyle.backColor = '#FEF2F2';
    periodRange.cellStyle.hAlign = xlsio.HAlignType.center;
    periodRange.cellStyle.vAlign = xlsio.VAlignType.center;
    periodRange.rowHeight = 22;

    return row + 3;
  }

  int _writeNavigationBar(xlsio.Worksheet sheet, {required int row}) {
    final navLabel = sheet.getRangeByIndex(row, 1, row, 9);
    navLabel.merge();
    navLabel.setText('NAVIGASI CEPAT');
    navLabel.cellStyle.bold = true;
    navLabel.cellStyle.fontSize = 9;
    navLabel.cellStyle.fontColor = '#6B7280';
    navLabel.cellStyle.backColor = '#F8FAFC';
    navLabel.cellStyle.hAlign = xlsio.HAlignType.center;
    navLabel.rowHeight = 18;
    row++;

    void styleNavButton(xlsio.Range range, String label) {
      range.setText(label);
      range.cellStyle.bold = true;
      range.cellStyle.fontSize = 10;
      range.cellStyle.fontColor = '#FFFFFF';
      range.cellStyle.backColor = '#2563EB';
      range.cellStyle.hAlign = xlsio.HAlignType.center;
      range.cellStyle.vAlign = xlsio.VAlignType.center;
      range.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      range.cellStyle.borders.all.color = '#1D4ED8';
    }

    final btn1 = sheet.getRangeByIndex(row, 1, row, 3);
    btn1.merge();
    styleNavButton(btn1, '\u25BC  Ringkasan KPI');

    final btn2 = sheet.getRangeByIndex(row, 4, row, 6);
    btn2.merge();
    styleNavButton(btn2, '\u25BC  Per Karyawan');

    final btn3 = sheet.getRangeByIndex(row, 7, row, 9);
    btn3.merge();
    styleNavButton(btn3, '\u25BC  Top Insight');

    sheet.getRangeByIndex(row, 1).rowHeight = 28;

    return row + 2; // skip blank row
  }

  void _applyNavigationHyperlinks(
    xlsio.Worksheet sheet, {
    required int statsRow,
    required int empRow,
    required int topRow,
  }) {
    // Internal sheet hyperlinks for navigation
    try {
      sheet.hyperlinks.add(
        sheet.getRangeByIndex(5, 1, 5, 3),
        xlsio.HyperlinkType.workbook,
        "'$insightSheetName'!A$statsRow",
        'Ringkasan KPI',
        'Ke Ringkasan KPI',
      );
      sheet.hyperlinks.add(
        sheet.getRangeByIndex(5, 4, 5, 6),
        xlsio.HyperlinkType.workbook,
        "'$insightSheetName'!A$empRow",
        'Per Karyawan',
        'Ke Per Karyawan',
      );
      sheet.hyperlinks.add(
        sheet.getRangeByIndex(5, 7, 5, 9),
        xlsio.HyperlinkType.workbook,
        "'$insightSheetName'!A$topRow",
        'Top Insight',
        'Ke Top Insight',
      );
    } catch (_) {
      // Hyperlinks may not be supported in all viewers — degrade gracefully
    }
  }

  int _writeOverallStats(
    xlsio.Worksheet sheet, {
    required int row,
    required PayrollMatrixDataset dataset,
  }) {
    final sectionTitle = sheet.getRangeByIndex(row, 1, row, 9);
    sectionTitle.merge();
    sectionTitle.setText('\u2588  RINGKASAN KESELURUHAN');
    sectionTitle.cellStyle.bold = true;
    sectionTitle.cellStyle.fontSize = 11;
    sectionTitle.cellStyle.fontColor = '#FFFFFF';
    sectionTitle.cellStyle.backColor = '#1E40AF';
    sectionTitle.cellStyle.hAlign = xlsio.HAlignType.left;
    sectionTitle.rowHeight = 28;
    row++;

    final totalEmployees = dataset.rows.length;
    final totalDays = dataset.dates.length;

    var totalLate = 0;
    var totalShortWork = 0;
    var totalExcessBreak = 0;
    var totalAbsence = 0;
    var totalOvertime = 0;
    var totalHadirDays = 0;

    for (final r in dataset.rows) {
      totalLate += r.lateCount;
      totalShortWork += r.shortWorkCount;
      totalExcessBreak += r.excessBreakCount;
      totalAbsence += r.absenceCount;
      totalOvertime += r.overtimeCount;

      for (final cell in r.cells) {
        if (cell.hasData && cell.primaryStatus != null) {
          final isAbsent = cell.primaryStatus ==
                  AttendancePolicyPrimaryStatus.absence ||
              cell.primaryStatus ==
                  AttendancePolicyPrimaryStatus.belumMasuk;
          if (!isAbsent) totalHadirDays++;
        }
      }
    }

    final possibleDays = totalEmployees * totalDays;
    final kehadiranRate =
        possibleDays > 0 ? (totalHadirDays / possibleDays * 100) : 0.0;

    // KPI cards in a 4-column grid (label + value pairs)
    void writeKpiCard(int r, int col, String label, String value, String bgColor, String fgColor) {
      final labelRange = sheet.getRangeByIndex(r, col);
      labelRange.setText(label);
      labelRange.cellStyle.fontSize = 9;
      labelRange.cellStyle.fontColor = '#6B7280';
      labelRange.cellStyle.backColor = bgColor;
      labelRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      labelRange.cellStyle.borders.all.color = '#E5E7EB';
      labelRange.cellStyle.vAlign = xlsio.VAlignType.center;

      final valueRange = sheet.getRangeByIndex(r, col + 1);
      valueRange.setText(value);
      valueRange.cellStyle.bold = true;
      valueRange.cellStyle.fontSize = 14;
      valueRange.cellStyle.fontColor = fgColor;
      valueRange.cellStyle.backColor = bgColor;
      valueRange.cellStyle.hAlign = xlsio.HAlignType.center;
      valueRange.cellStyle.vAlign = xlsio.VAlignType.center;
      valueRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      valueRange.cellStyle.borders.all.color = '#E5E7EB';
    }

    sheet.getRangeByIndex(row, 1, row + 3, 9).rowHeight = 32;

    // Row 1: Karyawan | Hari | Kehadiran | Terlambat
    writeKpiCard(row, 1, 'Karyawan', '$totalEmployees', '#EFF6FF', '#1E40AF');
    writeKpiCard(row, 3, 'Hari', '$totalDays', '#EFF6FF', '#1E40AF');
    writeKpiCard(row, 5, 'Kehadiran', '${kehadiranRate.toStringAsFixed(1)}%',
        kehadiranRate >= 90 ? '#F0FDF4' : '#FEF2F2',
        kehadiranRate >= 90 ? '#059669' : '#DC2626');
    writeKpiCard(row, 7, 'Terlambat', '$totalLate',
        totalLate > 0 ? '#FFFBEB' : '#F0FDF4',
        totalLate > 0 ? '#92400E' : '#059669');
    row++;

    // Row 2: Kurang Jam | Break Lebih | Tidak Hadir | Lembur
    writeKpiCard(row, 1, 'Kurang Jam', '$totalShortWork',
        totalShortWork > 0 ? '#FEF2F2' : '#F0FDF4',
        totalShortWork > 0 ? '#B91C1C' : '#059669');
    writeKpiCard(row, 3, 'Break Lebih', '$totalExcessBreak',
        totalExcessBreak > 0 ? '#FEF2F2' : '#F0FDF4',
        totalExcessBreak > 0 ? '#B91C1C' : '#059669');
    writeKpiCard(row, 5, 'Tidak Hadir', '$totalAbsence',
        totalAbsence > 0 ? '#FEF2F2' : '#F0FDF4',
        totalAbsence > 0 ? '#B91C1C' : '#059669');
    writeKpiCard(row, 7, 'Lembur', '$totalOvertime',
        totalOvertime > 0 ? '#FFFBEB' : '#F8FAFC',
        totalOvertime > 0 ? '#92400E' : '#6B7280');
    row++;

    return row + 1;
  }

  int _writeEmployeeSummaryTable(
    xlsio.Worksheet sheet, {
    required int row,
    required PayrollMatrixDataset dataset,
    required Iterable<AttendancePolicyRecapDay> recapRows,
  }) {
    final sectionTitle = sheet.getRangeByIndex(row, 1, row, 9);
    sectionTitle.merge();
    sectionTitle.setText('\u2588  RINGKASAN PER KARYAWAN');
    sectionTitle.cellStyle.bold = true;
    sectionTitle.cellStyle.fontSize = 11;
    sectionTitle.cellStyle.fontColor = '#FFFFFF';
    sectionTitle.cellStyle.backColor = '#1E40AF';
    sectionTitle.cellStyle.hAlign = xlsio.HAlignType.left;
    sectionTitle.rowHeight = 28;
    row++;

    const headers = <String>[
      'Karyawan',
      'Kontrak',
      'Terlambat',
      'Kurang Jam',
      'Break Lebih',
      'Tidak Hadir',
      'Lembur',
      'Avg Kurang',
      'Avg Break Lebih',
    ];

    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(row, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 9;
      cell.cellStyle.fontColor = '#111827';
      cell.cellStyle.backColor = '#F1F5F9';
      cell.cellStyle.hAlign = xlsio.HAlignType.center;
      cell.cellStyle.vAlign = xlsio.VAlignType.center;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      cell.cellStyle.borders.all.color = '#CBD5E1';
    }
    row++;

    final employeeAverages = _calculateEmployeeAverages(recapRows);

    // Totals accumulators for mini cart
    var sumLate = 0;
    var sumShort = 0;
    var sumBreak = 0;
    var sumAbsence = 0;
    var sumOvertime = 0;

    for (var i = 0; i < dataset.rows.length; i++) {
      final r = dataset.rows[i];
      final averages = employeeAverages[r.employeeId] ??
          const (avgShort: 0.0, avgBreak: 0.0);
      final isEvenRow = i % 2 == 0;
      final rowBgColor = isEvenRow ? '#FFFFFF' : '#F8FAFC';

      final nameCell = sheet.getRangeByIndex(row, 1);
      nameCell.setText(r.employeeName);
      nameCell.cellStyle.fontColor = '#111827';
      nameCell.cellStyle.backColor = rowBgColor;
      nameCell.cellStyle.vAlign = xlsio.VAlignType.center;
      nameCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      nameCell.cellStyle.borders.all.color = '#E5E7EB';

      final contractCell = sheet.getRangeByIndex(row, 2);
      contractCell.setText(r.employmentContract.label);
      contractCell.cellStyle.fontColor = '#6B7280';
      contractCell.cellStyle.backColor = rowBgColor;
      contractCell.cellStyle.hAlign = xlsio.HAlignType.center;
      contractCell.cellStyle.vAlign = xlsio.VAlignType.center;
      contractCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      contractCell.cellStyle.borders.all.color = '#E5E7EB';

      // Issue counts with conditional formatting
      final values = <({int count, String bgHigh, String fgHigh})>[
        (count: r.lateCount, bgHigh: '#FEF3C7', fgHigh: '#92400E'),
        (count: r.shortWorkCount, bgHigh: '#FEE2E2', fgHigh: '#B91C1C'),
        (count: r.excessBreakCount, bgHigh: '#FEE2E2', fgHigh: '#B91C1C'),
        (count: r.absenceCount, bgHigh: '#FEE2E2', fgHigh: '#B91C1C'),
        (count: r.overtimeCount, bgHigh: '#FEF3C7', fgHigh: '#92400E'),
      ];

      sumLate += r.lateCount;
      sumShort += r.shortWorkCount;
      sumBreak += r.excessBreakCount;
      sumAbsence += r.absenceCount;
      sumOvertime += r.overtimeCount;

      for (var col = 0; col < values.length; col++) {
        final cell = sheet.getRangeByIndex(row, col + 3);
        cell.setNumber(values[col].count.toDouble());
        cell.cellStyle.backColor = values[col].count > 0 ? values[col].bgHigh : rowBgColor;
        cell.cellStyle.fontColor = values[col].count > 0 ? values[col].fgHigh : '#9CA3AF';
        cell.cellStyle.bold = values[col].count > 0;
        cell.cellStyle.hAlign = xlsio.HAlignType.center;
        cell.cellStyle.vAlign = xlsio.VAlignType.center;
        cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        cell.cellStyle.borders.all.color = '#E5E7EB';
      }

      final avgShortCell = sheet.getRangeByIndex(row, 8);
      avgShortCell.setText(_formatMinutesToDuration(averages.avgShort));
      avgShortCell.cellStyle.fontColor = averages.avgShort > 0 ? '#B91C1C' : '#9CA3AF';
      avgShortCell.cellStyle.backColor = rowBgColor;
      avgShortCell.cellStyle.hAlign = xlsio.HAlignType.center;
      avgShortCell.cellStyle.vAlign = xlsio.VAlignType.center;
      avgShortCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      avgShortCell.cellStyle.borders.all.color = '#E5E7EB';

      final avgBreakCell = sheet.getRangeByIndex(row, 9);
      avgBreakCell.setText(_formatMinutesToDuration(averages.avgBreak));
      avgBreakCell.cellStyle.fontColor = averages.avgBreak > 0 ? '#B91C1C' : '#9CA3AF';
      avgBreakCell.cellStyle.backColor = rowBgColor;
      avgBreakCell.cellStyle.hAlign = xlsio.HAlignType.center;
      avgBreakCell.cellStyle.vAlign = xlsio.VAlignType.center;
      avgBreakCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      avgBreakCell.cellStyle.borders.all.color = '#E5E7EB';

      row++;
    }

    // --- Mini Cart: Totals Row ---
    final cartStyle = sheet.getRangeByIndex(row, 1, row, 9);
    cartStyle.rowHeight = 30;

    final cartLabel = sheet.getRangeByIndex(row, 1, row, 2);
    cartLabel.merge();
    cartLabel.setText('TOTAL');
    cartLabel.cellStyle.bold = true;
    cartLabel.cellStyle.fontSize = 10;
    cartLabel.cellStyle.fontColor = '#FFFFFF';
    cartLabel.cellStyle.backColor = '#334155';
    cartLabel.cellStyle.hAlign = xlsio.HAlignType.center;
    cartLabel.cellStyle.vAlign = xlsio.VAlignType.center;
    cartLabel.cellStyle.borders.all.lineStyle = xlsio.LineStyle.medium;
    cartLabel.cellStyle.borders.all.color = '#1E293B';

    final cartValues = <int>[sumLate, sumShort, sumBreak, sumAbsence, sumOvertime];
    for (var col = 0; col < cartValues.length; col++) {
      final cell = sheet.getRangeByIndex(row, col + 3);
      cell.setNumber(cartValues[col].toDouble());
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 11;
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.backColor = '#334155';
      cell.cellStyle.hAlign = xlsio.HAlignType.center;
      cell.cellStyle.vAlign = xlsio.VAlignType.center;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.medium;
      cell.cellStyle.borders.all.color = '#1E293B';
    }

    // Empty cells for avg columns in cart
    for (var col = 8; col <= 9; col++) {
      final cell = sheet.getRangeByIndex(row, col);
      cell.setText('—');
      cell.cellStyle.bold = true;
      cell.cellStyle.fontColor = '#94A3B8';
      cell.cellStyle.backColor = '#334155';
      cell.cellStyle.hAlign = xlsio.HAlignType.center;
      cell.cellStyle.vAlign = xlsio.VAlignType.center;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.medium;
      cell.cellStyle.borders.all.color = '#1E293B';
    }

    row += 2; // skip blank row after cart
    return row;
  }

  Map<String, ({double avgShort, double avgBreak})> _calculateEmployeeAverages(
    Iterable<AttendancePolicyRecapDay> recapRows,
  ) {
    final employeeData = <String, List<AttendancePolicyRecapDay>>{};

    for (final recap in recapRows) {
      employeeData.putIfAbsent(recap.employeeId, () => []).add(recap);
    }

    final averages = <String, ({double avgShort, double avgBreak})>{};

    for (final entry in employeeData.entries) {
      final employeeRecaps = entry.value;
      var totalShortMinutes = 0.0;
      var totalBreakMinutes = 0.0;
      var workDayCount = 0;

      for (final recap in employeeRecaps) {
        if (recap.attendanceStatus == AttendancePolicyStatus.hadir ||
            recap.attendanceStatus == AttendancePolicyStatus.hadirTanpaJadwal) {
          workDayCount++;
          totalShortMinutes += (recap.shortWorkMinutes ?? 0);
          totalBreakMinutes += (recap.excessBreakMinutes ?? 0);
        }
      }

      final avgShort = workDayCount > 0 ? totalShortMinutes / workDayCount : 0.0;
      final avgBreak = workDayCount > 0 ? totalBreakMinutes / workDayCount : 0.0;

      averages[entry.key] = (avgShort: avgShort, avgBreak: avgBreak);
    }

    return averages;
  }

  String _formatMinutesToDuration(double minutes) {
    if (minutes <= 0) return '-';

    final totalMinutes = minutes.round();
    final hours = totalMinutes ~/ 60;
    final remainingMinutes = totalMinutes % 60;

    if (hours > 0) {
      return '${hours}j ${remainingMinutes}m';
    } else {
      return '${remainingMinutes}m';
    }
  }

  void _writeTopInsights(
    xlsio.Worksheet sheet, {
    required int row,
    required PayrollMatrixDataset dataset,
    required Iterable<AttendancePolicyRecapDay> recapRows,
  }) {
    final sectionTitle = sheet.getRangeByIndex(row, 1, row, 9);
    sectionTitle.merge();
    sectionTitle.setText('\u2588  TOP INSIGHT UNTUK AREA MANAGER');
    sectionTitle.cellStyle.bold = true;
    sectionTitle.cellStyle.fontSize = 12;
    sectionTitle.cellStyle.fontColor = '#FFFFFF';
    sectionTitle.cellStyle.backColor = '#DC2626';
    sectionTitle.cellStyle.hAlign = xlsio.HAlignType.left;
    sectionTitle.rowHeight = 32;
    row++;

    final employeeAverages = _calculateEmployeeAverages(recapRows);

    // Kepala Gerai section
    final managers = dataset.rows
        .where((r) => recapRows.any((recap) =>
            recap.employeeId == r.employeeId && recap.isManagerExempt))
        .toList();

    if (managers.isNotEmpty) {
      _writeInsightSubSection(
        sheet,
        row: row,
        title: 'KEPALA GERAI',
        entries: managers
            .map((r) => '\u2605  ${r.employeeName} (${r.employmentContract.label}) — '
                'Masuk: ${r.cells.where((c) => c.hasData && c.primaryStatus != AttendancePolicyPrimaryStatus.absence).length} hari')
            .toList(),
        bgColor: '#F0FDF4',
        fgColor: '#059669',
        borderColor: '#059669',
      );
      row += 2 + managers.length;
    }

    // Sort by issue severity
    final sorted = List<PayrollMatrixRow>.from(dataset.rows)
      ..sort((a, b) {
        final aTotal =
            a.lateCount + a.shortWorkCount + a.excessBreakCount + a.absenceCount;
        final bTotal =
            b.lateCount + b.shortWorkCount + b.excessBreakCount + b.absenceCount;
        return bTotal.compareTo(aTotal);
      });

    // Top 5 problematic
    final problematicEntries = sorted
        .take(math.min(5, sorted.length))
        .where((r) =>
            r.lateCount + r.shortWorkCount + r.excessBreakCount + r.absenceCount > 0)
        .map((r) {
      final averages = employeeAverages[r.employeeId] ?? const (avgShort: 0.0, avgBreak: 0.0);
      final total = r.lateCount + r.shortWorkCount + r.excessBreakCount + r.absenceCount;
      String text = '\u26A0  ${r.employeeName} — $total masalah';
      if (averages.avgShort > 0 || averages.avgBreak > 0) {
        text += ' (kurang: ${_formatMinutesToDuration(averages.avgShort)}, break: ${_formatMinutesToDuration(averages.avgBreak)})';
      }
      return text;
    }).toList();

    _writeInsightSubSection(
      sheet,
      row: row,
      title: 'KARYAWAN PALING BANYAK MASALAH',
      entries: problematicEntries,
      bgColor: '#FEF2F2',
      fgColor: '#B91C1C',
      borderColor: '#FECACA',
    );
    row += 2 + problematicEntries.length;

    // Top 5 overtime
    final sortedOt = List<PayrollMatrixRow>.from(dataset.rows)
      ..sort((a, b) => b.overtimeCount.compareTo(a.overtimeCount));

    final overtimeEntries = sortedOt
        .take(math.min(5, sortedOt.length))
        .where((r) => r.overtimeCount > 0)
        .map((r) => '\u23F0  ${r.employeeName} — Lembur ${r.overtimeCount} hari')
        .toList();

    _writeInsightSubSection(
      sheet,
      row: row,
      title: 'KARYAWAN PALING BANYAK LEMBUR',
      entries: overtimeEntries,
      bgColor: '#FFFBEB',
      fgColor: '#92400E',
      borderColor: '#FDE68A',
    );
    row += 2 + overtimeEntries.length;

    // Clean employees
    final cleanEmployees = dataset.rows.where((r) =>
        r.lateCount == 0 &&
        r.shortWorkCount == 0 &&
        r.excessBreakCount == 0 &&
        r.absenceCount == 0);

    final cleanEntries = cleanEmployees
        .take(math.min(10, cleanEmployees.length))
        .map((r) => '\u2713  ${r.employeeName} (${r.employmentContract.label})')
        .toList();

    _writeInsightSubSection(
      sheet,
      row: row,
      title: 'KARYAWAN TANPA MASALAH',
      entries: cleanEntries,
      bgColor: '#F0FDF4',
      fgColor: '#059669',
      borderColor: '#BBF7D0',
    );
  }

  void _writeInsightSubSection(
    xlsio.Worksheet sheet, {
    required int row,
    required String title,
    required List<String> entries,
    required String bgColor,
    required String fgColor,
    required String borderColor,
  }) {
    final titleCell = sheet.getRangeByIndex(row, 1, row, 9);
    titleCell.merge();
    titleCell.setText(title);
    titleCell.cellStyle.bold = true;
    titleCell.cellStyle.fontSize = 10;
    titleCell.cellStyle.fontColor = fgColor;
    titleCell.cellStyle.backColor = bgColor;
    titleCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    titleCell.cellStyle.borders.all.color = borderColor;
    titleCell.rowHeight = 26;
    row++;

    if (entries.isEmpty) {
      final emptyCell = sheet.getRangeByIndex(row, 1, row, 9);
      emptyCell.merge();
      emptyCell.setText('  (tidak ada)');
      emptyCell.cellStyle.fontColor = '#9CA3AF';
      emptyCell.cellStyle.italic = true;
      emptyCell.cellStyle.fontSize = 9;
      return;
    }

    for (final entry in entries) {
      final cell = sheet.getRangeByIndex(row, 1, row, 9);
      cell.merge();
      cell.setText('  $entry');
      cell.cellStyle.fontColor = '#374151';
      cell.cellStyle.fontSize = 9;
      cell.cellStyle.wrapText = true;
      cell.rowHeight = 20;
      row++;
    }
  }

  String _formatDateLabel(DateTime date) {
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
    return '${date.day} ${months[date.month]} ${date.year}';
  }
}
