import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:syncfusion_officechart/officechart.dart';

import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_day_cell.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';

typedef TemporaryDirectoryProvider = Future<Directory> Function();

/// Sort mode for the Insight spreadsheet export.
enum SpreadsheetSortMode { terlambat, overtime, aman, bermasalah }

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
    SpreadsheetSortMode sortMode = SpreadsheetSortMode.bermasalah,
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

      // Apply auto-filter to entire data range (header + all employee rows)
      if (sortedDataset.rows.isNotEmpty) {
        sheet.autoFilters.filterRange = sheet.getRangeByIndex(
          1, 1, 1 + sortedDataset.rows.length, lastColumn,
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
        sortMode: sortMode,
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
    required SpreadsheetSortMode sortMode,
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
    sheet.getRangeByIndex(1, 9).columnWidth = 16;
    sheet.getRangeByIndex(1, 10).columnWidth = 16;
    sheet.getRangeByIndex(1, 11).columnWidth = 18;

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
      sortMode: sortMode,
    );

    // --- Section 4b: Charts (Bar + Pie) ---
    currentRow = _writeCharts(
      sheet,
      row: currentRow,
      dataset: dataset,
      recapRows: recapRows,
    );

    // --- Section 5: Top performers / issues ---
    final topAnchorRow = currentRow;
    _writeTopInsights(sheet, row: currentRow, dataset: dataset, recapRows: recapRows, sortMode: sortMode);

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
    final brandRange = sheet.getRangeByIndex(row, 1, row, 11);
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
    final navLabel = sheet.getRangeByIndex(row, 1, row, 11);
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
    final sectionTitle = sheet.getRangeByIndex(row, 1, row, 11);
    sectionTitle.merge();
    sectionTitle.setText('📊  RINGKASAN KESELURUHAN');
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
    required SpreadsheetSortMode sortMode,
  }) {
    final sectionTitle = sheet.getRangeByIndex(row, 1, row, 11);
    sectionTitle.merge();
    sectionTitle.setText('📊  RINGKASAN PER KARYAWAN');
    sectionTitle.cellStyle.bold = true;
    sectionTitle.cellStyle.fontSize = 11;
    sectionTitle.cellStyle.fontColor = '#FFFFFF';
    sectionTitle.cellStyle.backColor = '#1E40AF';
    sectionTitle.cellStyle.hAlign = xlsio.HAlignType.left;
    sectionTitle.rowHeight = 28;
    row++;

    // Capture header row position for auto-filter
    final headerRowIndex = row;

    const headers = <String>[
      'Karyawan',      // col 1
      'Kontrak',       // col 2
      'Terlambat',     // col 3
      'Avg Telat',     // col 4 (NEW)
      'Kurang Jam',    // col 5
      'Break Lebih',   // col 6
      'Tidak Hadir',   // col 7
      'Lembur',        // col 8
      'Avg Lembur',    // col 9 (NEW)
      'Avg Kurang',    // col 10
      'Avg Break Lebih', // col 11
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

    // Build manager IDs set
    final managerIds = <String>{};
    for (final recap in recapRows) {
      if (recap.isManagerExempt) managerIds.add(recap.employeeId);
    }

    // Sort: managers first, then by sortMode criteria
    final sortedRows = List<PayrollMatrixRow>.from(dataset.rows);
    sortedRows.sort((a, b) {
      final aIsManager = managerIds.contains(a.employeeId);
      final bIsManager = managerIds.contains(b.employeeId);
      if (aIsManager != bIsManager) return aIsManager ? -1 : 1;

      final aAvg = employeeAverages[a.employeeId] ??
          const (avgLate: 0.0, avgOvertime: 0.0, avgShort: 0.0, avgBreak: 0.0);
      final bAvg = employeeAverages[b.employeeId] ??
          const (avgLate: 0.0, avgOvertime: 0.0, avgShort: 0.0, avgBreak: 0.0);

      switch (sortMode) {
        case SpreadsheetSortMode.terlambat:
          final cmp = b.lateCount.compareTo(a.lateCount);
          return cmp != 0 ? cmp : bAvg.avgLate.compareTo(aAvg.avgLate);
        case SpreadsheetSortMode.overtime:
          final cmp = b.overtimeCount.compareTo(a.overtimeCount);
          return cmp != 0 ? cmp : bAvg.avgOvertime.compareTo(aAvg.avgOvertime);
        case SpreadsheetSortMode.aman:
          final aTotal = a.lateCount + a.shortWorkCount + a.excessBreakCount + a.absenceCount;
          final bTotal = b.lateCount + b.shortWorkCount + b.excessBreakCount + b.absenceCount;
          return aTotal.compareTo(bTotal);
        case SpreadsheetSortMode.bermasalah:
          final aTotal = a.lateCount + a.shortWorkCount + a.excessBreakCount + a.absenceCount;
          final bTotal = b.lateCount + b.shortWorkCount + b.excessBreakCount + b.absenceCount;
          return bTotal.compareTo(aTotal);
      }
    });

    // Totals accumulators for mini cart
    var sumLate = 0;
    var sumShort = 0;
    var sumBreak = 0;
    var sumAbsence = 0;
    var sumOvertime = 0;

    for (var i = 0; i < sortedRows.length; i++) {
      final r = sortedRows[i];
      final averages = employeeAverages[r.employeeId] ??
          const (avgLate: 0.0, avgOvertime: 0.0, avgShort: 0.0, avgBreak: 0.0);
      final isEvenRow = i % 2 == 0;
      final rowBgColor = isEvenRow ? '#FFFFFF' : '#F8FAFC';
      final isManager = managerIds.contains(r.employeeId);

      // Col 1: Karyawan (manager gets ⭐ prefix + bold)
      final nameCell = sheet.getRangeByIndex(row, 1);
      nameCell.setText(isManager ? '⭐ ${r.employeeName}' : r.employeeName);
      nameCell.cellStyle.fontColor = '#111827';
      nameCell.cellStyle.backColor = rowBgColor;
      nameCell.cellStyle.vAlign = xlsio.VAlignType.center;
      nameCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      nameCell.cellStyle.borders.all.color = '#E5E7EB';
      if (isManager) nameCell.cellStyle.bold = true;

      // Col 2: Kontrak
      final contractCell = sheet.getRangeByIndex(row, 2);
      contractCell.setText(r.employmentContract.label);
      contractCell.cellStyle.fontColor = '#6B7280';
      contractCell.cellStyle.backColor = rowBgColor;
      contractCell.cellStyle.hAlign = xlsio.HAlignType.center;
      contractCell.cellStyle.vAlign = xlsio.VAlignType.center;
      contractCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      contractCell.cellStyle.borders.all.color = '#E5E7EB';

      // Count cells with their column positions
      // Col 3: Terlambat, Col 5: Kurang Jam, Col 6: Break Lebih, Col 7: Tidak Hadir, Col 8: Lembur
      final countCells = <({int col, int count, String bgHigh, String fgHigh})>[
        (col: 3, count: r.lateCount, bgHigh: '#FEF3C7', fgHigh: '#92400E'),
        (col: 5, count: r.shortWorkCount, bgHigh: '#FEE2E2', fgHigh: '#B91C1C'),
        (col: 6, count: r.excessBreakCount, bgHigh: '#FEE2E2', fgHigh: '#B91C1C'),
        (col: 7, count: r.absenceCount, bgHigh: '#FEE2E2', fgHigh: '#B91C1C'),
        (col: 8, count: r.overtimeCount, bgHigh: '#FEF3C7', fgHigh: '#92400E'),
      ];

      sumLate += r.lateCount;
      sumShort += r.shortWorkCount;
      sumBreak += r.excessBreakCount;
      sumAbsence += r.absenceCount;
      sumOvertime += r.overtimeCount;

      for (final v in countCells) {
        final cell = sheet.getRangeByIndex(row, v.col);
        cell.setNumber(v.count.toDouble());
        cell.cellStyle.backColor = v.count > 0 ? v.bgHigh : rowBgColor;
        cell.cellStyle.fontColor = v.count > 0 ? v.fgHigh : '#9CA3AF';
        cell.cellStyle.bold = v.count > 0;
        cell.cellStyle.hAlign = xlsio.HAlignType.center;
        cell.cellStyle.vAlign = xlsio.VAlignType.center;
        cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        cell.cellStyle.borders.all.color = '#E5E7EB';
      }

      // Col 4: Avg Telat (NEW)
      final avgLateCell = sheet.getRangeByIndex(row, 4);
      avgLateCell.setText(_formatMinutesToDuration(averages.avgLate));
      avgLateCell.cellStyle.fontColor = averages.avgLate > 0 ? '#92400E' : '#9CA3AF';
      avgLateCell.cellStyle.backColor = averages.avgLate > 0 ? '#FEF3C7' : rowBgColor;
      avgLateCell.cellStyle.hAlign = xlsio.HAlignType.center;
      avgLateCell.cellStyle.vAlign = xlsio.VAlignType.center;
      avgLateCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      avgLateCell.cellStyle.borders.all.color = '#E5E7EB';

      // Col 9: Avg Lembur (NEW)
      final avgOtCell = sheet.getRangeByIndex(row, 9);
      avgOtCell.setText(_formatMinutesToDuration(averages.avgOvertime));
      avgOtCell.cellStyle.fontColor = averages.avgOvertime > 0 ? '#92400E' : '#9CA3AF';
      avgOtCell.cellStyle.backColor = averages.avgOvertime > 0 ? '#FEF3C7' : rowBgColor;
      avgOtCell.cellStyle.hAlign = xlsio.HAlignType.center;
      avgOtCell.cellStyle.vAlign = xlsio.VAlignType.center;
      avgOtCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      avgOtCell.cellStyle.borders.all.color = '#E5E7EB';

      // Col 10: Avg Kurang
      final avgShortCell = sheet.getRangeByIndex(row, 10);
      avgShortCell.setText(_formatMinutesToDuration(averages.avgShort));
      avgShortCell.cellStyle.fontColor = averages.avgShort > 0 ? '#B91C1C' : '#9CA3AF';
      avgShortCell.cellStyle.backColor = rowBgColor;
      avgShortCell.cellStyle.hAlign = xlsio.HAlignType.center;
      avgShortCell.cellStyle.vAlign = xlsio.VAlignType.center;
      avgShortCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      avgShortCell.cellStyle.borders.all.color = '#E5E7EB';

      // Col 11: Avg Break Lebih
      final avgBreakCell = sheet.getRangeByIndex(row, 11);
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
    final cartStyle = sheet.getRangeByIndex(row, 1, row, 11);
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

    // Count totals at their column positions
    final cartCounts = <({int col, int value})>[
      (col: 3, value: sumLate),
      (col: 5, value: sumShort),
      (col: 6, value: sumBreak),
      (col: 7, value: sumAbsence),
      (col: 8, value: sumOvertime),
    ];
    for (final c in cartCounts) {
      final cell = sheet.getRangeByIndex(row, c.col);
      cell.setNumber(c.value.toDouble());
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 11;
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.backColor = '#334155';
      cell.cellStyle.hAlign = xlsio.HAlignType.center;
      cell.cellStyle.vAlign = xlsio.VAlignType.center;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.medium;
      cell.cellStyle.borders.all.color = '#1E293B';
    }

    // Empty cells for avg columns in cart (cols 4, 9, 10, 11)
    for (final col in <int>[4, 9, 10, 11]) {
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

    // Apply auto-filter to the per-employee summary table (header + data rows, exclude TOTAL)
    if (sortedRows.isNotEmpty) {
      sheet.autoFilters.filterRange = sheet.getRangeByIndex(
        headerRowIndex, 1, headerRowIndex + sortedRows.length, 11,
      );
    }

    return row;
  }

  Map<String, ({double avgLate, double avgOvertime, double avgShort, double avgBreak})> _calculateEmployeeAverages(
    Iterable<AttendancePolicyRecapDay> recapRows,
  ) {
    final employeeData = <String, List<AttendancePolicyRecapDay>>{};

    for (final recap in recapRows) {
      employeeData.putIfAbsent(recap.employeeId, () => []).add(recap);
    }

    final averages = <String, ({double avgLate, double avgOvertime, double avgShort, double avgBreak})>{};

    for (final entry in employeeData.entries) {
      final employeeRecaps = entry.value;
      var totalShortMinutes = 0.0;
      var totalBreakMinutes = 0.0;
      var totalLateMinutes = 0.0;
      var totalOvertimeMinutes = 0.0;
      var workDayCount = 0;
      var lateDayCount = 0;
      var overtimeDayCount = 0;

      for (final recap in employeeRecaps) {
        if (recap.attendanceStatus == AttendancePolicyStatus.hadir ||
            recap.attendanceStatus == AttendancePolicyStatus.hadirTanpaJadwal) {
          workDayCount++;
          totalShortMinutes += (recap.shortWorkMinutes ?? 0);
          totalBreakMinutes += (recap.excessBreakMinutes ?? 0);
        }

        // Late minutes: derive from firstScanLocal - lateCutoffLocal
        if (recap.isLate || recap.lateKind == LateKind.normal) {
          final lateMin = _estimateLateMinutes(recap);
          if (lateMin != null && lateMin > 0) {
            totalLateMinutes += lateMin;
            lateDayCount++;
          }
        }

        // Overtime minutes: directly from recap field
        if (recap.overtimeMinutes != null && recap.overtimeMinutes! > 0) {
          totalOvertimeMinutes += recap.overtimeMinutes!;
          overtimeDayCount++;
        }
      }

      final avgShort = workDayCount > 0 ? totalShortMinutes / workDayCount : 0.0;
      final avgBreak = workDayCount > 0 ? totalBreakMinutes / workDayCount : 0.0;
      final avgLate = lateDayCount > 0 ? totalLateMinutes / lateDayCount : 0.0;
      final avgOvertime = overtimeDayCount > 0 ? totalOvertimeMinutes / overtimeDayCount : 0.0;

      averages[entry.key] = (avgLate: avgLate, avgOvertime: avgOvertime, avgShort: avgShort, avgBreak: avgBreak);
    }

    return averages;
  }

  /// Estimate late minutes from recap data.
  /// Derives from the difference between scheduled cutoff and actual scan.
  static int? _estimateLateMinutes(AttendancePolicyRecapDay recap) {
    if (recap.firstScanLocal == null || recap.lateCutoffLocal == null) {
      return null;
    }
    final cutoff = DateTime.tryParse(recap.lateCutoffLocal!);
    if (cutoff == null) return null;
    final diff = recap.firstScanLocal!.difference(cutoff).inMinutes;
    return diff > 0 ? diff : null;
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

  // ---------------------------------------------------------------------------
  // Charts: Bar (masalah per karyawan) + Pie (proporsi masalah)
  // ---------------------------------------------------------------------------

  int _writeCharts(
    xlsio.Worksheet sheet, {
    required int row,
    required PayrollMatrixDataset dataset,
    required Iterable<AttendancePolicyRecapDay> recapRows,
  }) {
    // Section title
    final sectionTitle = sheet.getRangeByIndex(row, 1, row, 11);
    sectionTitle.merge();
    sectionTitle.setText('\uD83D\uDCCA  DIAGRAM ANALISIS');
    sectionTitle.cellStyle.bold = true;
    sectionTitle.cellStyle.fontSize = 11;
    sectionTitle.cellStyle.fontColor = '#FFFFFF';
    sectionTitle.cellStyle.backColor = '#7C3AED';
    sectionTitle.cellStyle.hAlign = xlsio.HAlignType.left;
    sectionTitle.rowHeight = 28;
    row++;

    // --- Bar Chart Data: Top 10 employees by total issues ---
    final sortedByIssues = List<PayrollMatrixRow>.from(dataset.rows)
      ..sort((a, b) {
        final aTotal = a.lateCount + a.shortWorkCount + a.excessBreakCount + a.absenceCount;
        final bTotal = b.lateCount + b.shortWorkCount + b.excessBreakCount + b.absenceCount;
        return bTotal.compareTo(aTotal);
      });

    final barData = sortedByIssues
        .where((r) => r.lateCount + r.shortWorkCount + r.excessBreakCount + r.absenceCount > 0)
        .take(math.min(10, sortedByIssues.length))
        .toList();

    if (barData.isEmpty) {
      final emptyCell = sheet.getRangeByIndex(row, 1, row, 11);
      emptyCell.merge();
      emptyCell.setText('  (tidak ada data masalah untuk diagram)');
      emptyCell.cellStyle.fontColor = '#9CA3AF';
      emptyCell.cellStyle.italic = true;
      emptyCell.cellStyle.fontSize = 9;
      return row + 2;
    }

    // Write bar chart data block
    final barDataStartRow = row;

    // Headers
    sheet.getRangeByIndex(row, 1).setText('Karyawan');
    sheet.getRangeByIndex(row, 2).setText('Terlambat');
    sheet.getRangeByIndex(row, 3).setText('Kurang Jam');
    sheet.getRangeByIndex(row, 4).setText('Break Lebih');
    sheet.getRangeByIndex(row, 5).setText('Tidak Hadir');

    for (var col = 1; col <= 5; col++) {
      final cell = sheet.getRangeByIndex(row, col);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 8;
      cell.cellStyle.fontColor = '#374151';
      cell.cellStyle.backColor = '#F3F4F6';
      cell.cellStyle.hAlign = xlsio.HAlignType.center;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      cell.cellStyle.borders.all.color = '#E5E7EB';
    }
    row++;

    // Data rows
    for (final r in barData) {
      // Truncate long names for chart readability
      final displayName = r.employeeName.length > 15
          ? '${r.employeeName.substring(0, 15)}...'
          : r.employeeName;
      sheet.getRangeByIndex(row, 1).setText(displayName);
      sheet.getRangeByIndex(row, 2).setNumber(r.lateCount.toDouble());
      sheet.getRangeByIndex(row, 3).setNumber(r.shortWorkCount.toDouble());
      sheet.getRangeByIndex(row, 4).setNumber(r.excessBreakCount.toDouble());
      sheet.getRangeByIndex(row, 5).setNumber(r.absenceCount.toDouble());

      for (var col = 1; col <= 5; col++) {
        final cell = sheet.getRangeByIndex(row, col);
        cell.cellStyle.fontSize = 8;
        cell.cellStyle.fontColor = '#374151';
        cell.cellStyle.hAlign = col == 1 ? xlsio.HAlignType.left : xlsio.HAlignType.center;
        cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        cell.cellStyle.borders.all.color = '#E5E7EB';
      }
      row++;
    }

    final barDataEndRow = row - 1;

    // --- Pie Chart Data: Proportions of total issues ---
    row++; // blank row

    final pieLabelRow = row;
    final pieValueRow = row + 1;

    var totalLate = 0;
    var totalShort = 0;
    var totalBreak = 0;
    var totalAbsence = 0;
    for (final r in dataset.rows) {
      totalLate += r.lateCount;
      totalShort += r.shortWorkCount;
      totalBreak += r.excessBreakCount;
      totalAbsence += r.absenceCount;
    }

    sheet.getRangeByIndex(pieLabelRow, 1).setText('Terlambat');
    sheet.getRangeByIndex(pieLabelRow, 2).setText('Kurang Jam');
    sheet.getRangeByIndex(pieLabelRow, 3).setText('Break Lebih');
    sheet.getRangeByIndex(pieLabelRow, 4).setText('Tidak Hadir');
    sheet.getRangeByIndex(pieValueRow, 1).setNumber(totalLate.toDouble());
    sheet.getRangeByIndex(pieValueRow, 2).setNumber(totalShort.toDouble());
    sheet.getRangeByIndex(pieValueRow, 3).setNumber(totalBreak.toDouble());
    sheet.getRangeByIndex(pieValueRow, 4).setNumber(totalAbsence.toDouble());

    for (var col = 1; col <= 4; col++) {
      final labelCell = sheet.getRangeByIndex(pieLabelRow, col);
      labelCell.cellStyle.bold = true;
      labelCell.cellStyle.fontSize = 8;
      labelCell.cellStyle.fontColor = '#374151';
      labelCell.cellStyle.backColor = '#F3F4F6';
      labelCell.cellStyle.hAlign = xlsio.HAlignType.center;
      labelCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      labelCell.cellStyle.borders.all.color = '#E5E7EB';

      final valCell = sheet.getRangeByIndex(pieValueRow, col);
      valCell.cellStyle.fontSize = 9;
      valCell.cellStyle.fontColor = '#111827';
      valCell.cellStyle.hAlign = xlsio.HAlignType.center;
      valCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      valCell.cellStyle.borders.all.color = '#E5E7EB';
    }

    row = pieValueRow + 1;

    // --- Create Charts ---
    try {
      final charts = ChartCollection(sheet);

      // Bar Chart: Masalah Per Karyawan (stacked bar)
      final barChart = charts.add();
      barChart.chartType = ExcelChartType.bar;
      barChart.dataRange = sheet.getRangeByIndex(barDataStartRow, 1, barDataEndRow, 5);
      barChart.isSeriesInRows = false;
      barChart.chartTitle = 'Masalah Per Karyawan';
      barChart.topRow = barDataStartRow;
      barChart.leftColumn = 6;
      barChart.bottomRow = barDataStartRow + 15;
      barChart.rightColumn = 11;

      // Pie Chart: Proporsi Masalah
      final pieChart = charts.add();
      pieChart.chartType = ExcelChartType.pie;
      pieChart.dataRange = sheet.getRangeByIndex(pieLabelRow, 1, pieValueRow, 4);
      pieChart.isSeriesInRows = false;
      pieChart.chartTitle = 'Proporsi Masalah';
      pieChart.topRow = barDataStartRow + 16;
      pieChart.leftColumn = 6;
      pieChart.bottomRow = barDataStartRow + 30;
      pieChart.rightColumn = 11;

      sheet.charts = charts;
    } catch (_) {
      // Chart creation may fail on some platforms — degrade gracefully
    }

    // Return row after charts area
    return math.max(row, barDataStartRow + 31) + 1;
  }

  void _writeTopInsights(
    xlsio.Worksheet sheet, {
    required int row,
    required PayrollMatrixDataset dataset,
    required Iterable<AttendancePolicyRecapDay> recapRows,
    required SpreadsheetSortMode sortMode,
  }) {
    final sectionTitle = sheet.getRangeByIndex(row, 1, row, 11);
    sectionTitle.merge();
    sectionTitle.setText('📊  TOP INSIGHT UNTUK AREA MANAGER');
    sectionTitle.cellStyle.bold = true;
    sectionTitle.cellStyle.fontSize = 12;
    sectionTitle.cellStyle.fontColor = '#FFFFFF';
    sectionTitle.cellStyle.backColor = '#DC2626';
    sectionTitle.cellStyle.hAlign = xlsio.HAlignType.left;
    sectionTitle.rowHeight = 32;
    row++;

    final employeeAverages = _calculateEmployeeAverages(recapRows);

    // Kepala Gerai section — comprehensive stats
    final managers = dataset.rows
        .where((r) => recapRows.any((recap) =>
            recap.employeeId == r.employeeId && recap.isManagerExempt))
        .toList();

    if (managers.isNotEmpty) {
      final managerEntries = managers.map((r) {
        final mAvg = employeeAverages[r.employeeId] ??
            const (avgLate: 0.0, avgOvertime: 0.0, avgShort: 0.0, avgBreak: 0.0);
        final hadirDays = r.cells
            .where((c) =>
                c.hasData &&
                c.primaryStatus != AttendancePolicyPrimaryStatus.absence)
            .length;
        String entry =
            '⭐ ${r.employeeName} (${r.employmentContract.label}) — Masuk: $hadirDays hari';
        if (r.lateCount > 0) {
          entry +=
              ', Telat: ${r.lateCount}x (avg ${_formatMinutesToDuration(mAvg.avgLate)})';
        }
        if (r.overtimeCount > 0) {
          entry +=
              ', Lembur: ${r.overtimeCount}x (avg ${_formatMinutesToDuration(mAvg.avgOvertime)})';
        }
        return entry;
      }).toList();

      _writeInsightSubSection(
        sheet,
        row: row,
        title: 'KEPALA GERAI',
        entries: managerEntries,
        bgColor: '#F0FDF4',
        fgColor: '#059669',
        borderColor: '#059669',
        boldEntries: true,
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

    // Top 5 problematic — comprehensive with all avg data
    final problematicEntries = sorted
        .take(math.min(5, sorted.length))
        .where((r) =>
            r.lateCount + r.shortWorkCount + r.excessBreakCount + r.absenceCount > 0)
        .map((r) {
      final averages = employeeAverages[r.employeeId] ??
          const (avgLate: 0.0, avgOvertime: 0.0, avgShort: 0.0, avgBreak: 0.0);
      final total =
          r.lateCount + r.shortWorkCount + r.excessBreakCount + r.absenceCount;
      String text = '🔴 ${r.employeeName} — $total masalah';
      final parts = <String>[];
      if (r.lateCount > 0) {
        parts.add(
            'telat: ${r.lateCount}x avg ${_formatMinutesToDuration(averages.avgLate)}');
      }
      if (r.shortWorkCount > 0) {
        parts.add(
            'kurang: ${r.shortWorkCount}x avg ${_formatMinutesToDuration(averages.avgShort)}');
      }
      if (r.excessBreakCount > 0) {
        parts.add(
            'break: ${r.excessBreakCount}x avg ${_formatMinutesToDuration(averages.avgBreak)}');
      }
      if (r.absenceCount > 0) {
        parts.add('absen: ${r.absenceCount}x');
      }
      if (parts.isNotEmpty) text += ' (${parts.join(', ')})';
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

    // Top 5 overtime — with avg duration
    final sortedOt = List<PayrollMatrixRow>.from(dataset.rows)
      ..sort((a, b) => b.overtimeCount.compareTo(a.overtimeCount));

    final overtimeEntries = sortedOt
        .take(math.min(5, sortedOt.length))
        .where((r) => r.overtimeCount > 0)
        .map((r) {
      final otAvg = employeeAverages[r.employeeId] ??
          const (avgLate: 0.0, avgOvertime: 0.0, avgShort: 0.0, avgBreak: 0.0);
      return '⏱️ ${r.employeeName} — Lembur ${r.overtimeCount} hari (avg ${_formatMinutesToDuration(otAvg.avgOvertime)} per hari)';
    }).toList();

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
        .map((r) => '✅ ${r.employeeName} (${r.employmentContract.label})')
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
    bool boldEntries = false,
  }) {
    final titleCell = sheet.getRangeByIndex(row, 1, row, 11);
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
      final emptyCell = sheet.getRangeByIndex(row, 1, row, 11);
      emptyCell.merge();
      emptyCell.setText('  (tidak ada)');
      emptyCell.cellStyle.fontColor = '#9CA3AF';
      emptyCell.cellStyle.italic = true;
      emptyCell.cellStyle.fontSize = 9;
      return;
    }

    for (final entry in entries) {
      final cell = sheet.getRangeByIndex(row, 1, row, 11);
      cell.merge();
      cell.setText('  $entry');
      cell.cellStyle.fontColor = '#374151';
      cell.cellStyle.fontSize = 9;
      cell.cellStyle.wrapText = true;
      if (boldEntries) cell.cellStyle.bold = true;
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
