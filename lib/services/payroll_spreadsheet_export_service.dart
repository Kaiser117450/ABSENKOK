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
  // Sheet 2: Insight Payroll — Area Manager Dashboard
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

    var currentRow = 1;

    // --- Section 1: Header ---
    currentRow = _writeInsightHeader(
      sheet,
      row: currentRow,
      outletName: outletName,
      startDate: startDate,
      endDate: endDate,
    );

    // --- Section 2: Overall Statistics ---
    currentRow = _writeOverallStats(sheet, row: currentRow, dataset: dataset);

    // --- Section 3: Per-employee summary with mini bar charts ---
    currentRow = _writeEmployeeSummaryTable(
      sheet,
      row: currentRow,
      dataset: dataset,
      recapRows: recapRows,
    );

    // --- Section 4: Top performers / issues ---
    _writeTopInsights(sheet, row: currentRow, dataset: dataset, recapRows: recapRows);

    // Freeze header row
    sheet.getRangeByIndex(2, 1).freezePanes();
  }

  int _writeInsightHeader(
    xlsio.Worksheet sheet, {
    required int row,
    required String outletName,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    sheet.getRangeByIndex(row, 1).columnWidth = 26;
    sheet.getRangeByIndex(row, 2).columnWidth = 14;
    sheet.getRangeByIndex(row, 3).columnWidth = 14;
    sheet.getRangeByIndex(row, 4).columnWidth = 14;
    sheet.getRangeByIndex(row, 5).columnWidth = 14;
    sheet.getRangeByIndex(row, 6).columnWidth = 14;
    sheet.getRangeByIndex(row, 7).columnWidth = 16;
    sheet.getRangeByIndex(row, 8).columnWidth = 16;
    sheet.getRangeByIndex(row, 9).columnWidth = 22;

    // Title row
    final titleRange = sheet.getRangeByIndex(row, 1, row, 9);
    titleRange.merge();
    titleRange.setText(
      'INSIGHT PAYROLL — $outletName',
    );
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.fontSize = 14;
    titleRange.cellStyle.fontColor = '#DC2626';
    titleRange.cellStyle.backColor = '#FEF2F2';
    titleRange.cellStyle.hAlign = xlsio.HAlignType.center;
    titleRange.cellStyle.vAlign = xlsio.VAlignType.center;
    titleRange.rowHeight = 36;

    // Period row
    final periodRange = sheet.getRangeByIndex(row + 1, 1, row + 1, 9);
    periodRange.merge();
    periodRange.setText(
      'Periode: ${_formatDateLabel(startDate)} - ${_formatDateLabel(endDate)}',
    );
    periodRange.cellStyle.fontSize = 10;
    periodRange.cellStyle.fontColor = '#6B7280';
    periodRange.cellStyle.hAlign = xlsio.HAlignType.center;
    periodRange.cellStyle.vAlign = xlsio.VAlignType.center;
    periodRange.rowHeight = 22;

    return row + 3; // Skip a blank row
  }

  int _writeOverallStats(
    xlsio.Worksheet sheet, {
    required int row,
    required PayrollMatrixDataset dataset,
  }) {
    // Section title
    final sectionTitle = sheet.getRangeByIndex(row, 1, row, 9);
    sectionTitle.merge();
    sectionTitle.setText('RINGKASAN KESELURUHAN');
    sectionTitle.cellStyle.bold = true;
    sectionTitle.cellStyle.fontSize = 11;
    sectionTitle.cellStyle.fontColor = '#111827';
    sectionTitle.cellStyle.backColor = '#F3F4F6';
    sectionTitle.cellStyle.borders.bottom.lineStyle = xlsio.LineStyle.thin;
    sectionTitle.cellStyle.borders.bottom.color = '#D1D5DB';
    sectionTitle.rowHeight = 26;

    row++;

    final totalEmployees = dataset.rows.length;
    final totalDays = dataset.dates.length;

    // Compute totals
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

    // Stats labels and values in a 2-column grid layout
    final stats = <({String label, String value, String color})>[
      (
        label: 'Total Karyawan',
        value: '$totalEmployees',
        color: '#1E40AF',
      ),
      (
        label: 'Total Hari',
        value: '$totalDays',
        color: '#1E40AF',
      ),
      (
        label: 'Tingkat Kehadiran',
        value: '${kehadiranRate.toStringAsFixed(1)}%',
        color: kehadiranRate >= 90 ? '#059669' : '#DC2626',
      ),
      (
        label: 'Total Terlambat',
        value: '$totalLate',
        color: '#92400E',
      ),
      (
        label: 'Total Kurang Jam',
        value: '$totalShortWork',
        color: '#B91C1C',
      ),
      (
        label: 'Total Break Lebih',
        value: '$totalExcessBreak',
        color: '#B91C1C',
      ),
      (
        label: 'Total Tidak Hadir',
        value: '$totalAbsence',
        color: '#B91C1C',
      ),
      (
        label: 'Total Lembur',
        value: '$totalOvertime',
        color: '#92400E',
      ),
    ];

    for (var i = 0; i < stats.length; i += 2) {
      final left = stats[i];
      // Label left
      sheet.getRangeByIndex(row, 1).setText(left.label);
      sheet.getRangeByIndex(row, 1).cellStyle.fontColor = '#374151';
      sheet.getRangeByIndex(row, 1).cellStyle.fontSize = 10;
      // Value left
      sheet.getRangeByIndex(row, 2).setText(left.value);
      sheet.getRangeByIndex(row, 2).cellStyle.bold = true;
      sheet.getRangeByIndex(row, 2).cellStyle.fontColor = left.color;
      sheet.getRangeByIndex(row, 2).cellStyle.fontSize = 10;
      sheet.getRangeByIndex(row, 2).cellStyle.hAlign = xlsio.HAlignType.center;

      if (i + 1 < stats.length) {
        final right = stats[i + 1];
        // Label right
        sheet.getRangeByIndex(row, 4).setText(right.label);
        sheet.getRangeByIndex(row, 4).cellStyle.fontColor = '#374151';
        sheet.getRangeByIndex(row, 4).cellStyle.fontSize = 10;
        // Value right
        sheet.getRangeByIndex(row, 5).setText(right.value);
        sheet.getRangeByIndex(row, 5).cellStyle.bold = true;
        sheet.getRangeByIndex(row, 5).cellStyle.fontColor = right.color;
        sheet.getRangeByIndex(row, 5).cellStyle.fontSize = 10;
        sheet.getRangeByIndex(row, 5).cellStyle.hAlign =
            xlsio.HAlignType.center;
      }

      row++;
    }

    return row + 1; // Skip a blank row
  }

  int _writeEmployeeSummaryTable(
    xlsio.Worksheet sheet, {
    required int row,
    required PayrollMatrixDataset dataset,
    required Iterable<AttendancePolicyRecapDay> recapRows,
  }) {
    // Section title
    final sectionTitle = sheet.getRangeByIndex(row, 1, row, 9);
    sectionTitle.merge();
    sectionTitle.setText('RINGKASAN PER KARYAWAN');
    sectionTitle.cellStyle.bold = true;
    sectionTitle.cellStyle.fontSize = 11;
    sectionTitle.cellStyle.fontColor = '#111827';
    sectionTitle.cellStyle.backColor = '#F3F4F6';
    sectionTitle.cellStyle.borders.bottom.lineStyle = xlsio.LineStyle.thin;
    sectionTitle.cellStyle.borders.bottom.color = '#D1D5DB';
    sectionTitle.rowHeight = 26;
    row++;

    // Header
    const headers = <String>[
      'Karyawan',
      'Kontrak',
      'Terlambat',
      'Kurang Jam',
      'Break Lebih',
      'Tidak Hadir',
      'Lembur',
      'Rata-rata Kurang',
      'Rata-rata Break Lebih',
    ];

    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(row, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 9;
      cell.cellStyle.fontColor = '#111827';
      cell.cellStyle.backColor = '#F9FAFB';
      cell.cellStyle.hAlign = xlsio.HAlignType.center;
      cell.cellStyle.vAlign = xlsio.VAlignType.center;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      cell.cellStyle.borders.all.color = '#E5E7EB';
    }
    row++;

    // Build employee averages map
    final employeeAverages = _calculateEmployeeAverages(recapRows);

    // Find max total issues for chart scaling
    var maxIssues = 1;
    for (final r in dataset.rows) {
      final total =
          r.lateCount + r.shortWorkCount + r.excessBreakCount + r.absenceCount;
      if (total > maxIssues) maxIssues = total;
    }

    // Data rows with averages
    for (final r in dataset.rows) {
      final averages = employeeAverages[r.employeeId] ??
          const (avgShort: 0.0, avgBreak: 0.0);

      // Name
      final nameCell = sheet.getRangeByIndex(row, 1);
      nameCell.setText(r.employeeName);
      nameCell.cellStyle.fontColor = '#111827';
      nameCell.cellStyle.vAlign = xlsio.VAlignType.center;
      nameCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      nameCell.cellStyle.borders.all.color = '#E5E7EB';

      // Contract
      final contractCell = sheet.getRangeByIndex(row, 2);
      contractCell.setText(r.employmentContract.label);
      contractCell.cellStyle.fontColor = '#111827';
      contractCell.cellStyle.vAlign = xlsio.VAlignType.center;
      contractCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      contractCell.cellStyle.borders.all.color = '#E5E7EB';

      // Summary values with color coding
      final values = <({int count, String bgColor, String fgColor})>[
        (
          count: r.lateCount,
          bgColor: r.lateCount > 0 ? '#FEF3C7' : '#FFFFFF',
          fgColor: r.lateCount > 0 ? '#92400E' : '#111827',
        ),
        (
          count: r.shortWorkCount,
          bgColor: r.shortWorkCount > 0 ? '#FEE2E2' : '#FFFFFF',
          fgColor: r.shortWorkCount > 0 ? '#B91C1C' : '#111827',
        ),
        (
          count: r.excessBreakCount,
          bgColor: r.excessBreakCount > 0 ? '#FEE2E2' : '#FFFFFF',
          fgColor: r.excessBreakCount > 0 ? '#B91C1C' : '#111827',
        ),
        (
          count: r.absenceCount,
          bgColor: r.absenceCount > 0 ? '#FEE2E2' : '#FFFFFF',
          fgColor: r.absenceCount > 0 ? '#B91C1C' : '#111827',
        ),
        (
          count: r.overtimeCount,
          bgColor: r.overtimeCount > 0 ? '#FEF3C7' : '#FFFFFF',
          fgColor: r.overtimeCount > 0 ? '#92400E' : '#111827',
        ),
      ];

      for (var col = 0; col < values.length; col++) {
        final cell = sheet.getRangeByIndex(row, col + 3);
        cell.setNumber(values[col].count.toDouble());
        cell.cellStyle.backColor = values[col].bgColor;
        cell.cellStyle.fontColor = values[col].fgColor;
        cell.cellStyle.bold = values[col].count > 0;
        cell.cellStyle.hAlign = xlsio.HAlignType.center;
        cell.cellStyle.vAlign = xlsio.VAlignType.center;
        cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        cell.cellStyle.borders.all.color = '#E5E7EB';
      }

      // Average short work
      final avgShortCell = sheet.getRangeByIndex(row, 8);
      avgShortCell.setText(_formatMinutesToDuration(averages.avgShort));
      avgShortCell.cellStyle.fontColor = averages.avgShort > 0 ? '#B91C1C' : '#111827';
      avgShortCell.cellStyle.hAlign = xlsio.HAlignType.center;
      avgShortCell.cellStyle.vAlign = xlsio.VAlignType.center;
      avgShortCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      avgShortCell.cellStyle.borders.all.color = '#E5E7EB';

      // Average excess break
      final avgBreakCell = sheet.getRangeByIndex(row, 9);
      avgBreakCell.setText(_formatMinutesToDuration(averages.avgBreak));
      avgBreakCell.cellStyle.fontColor = averages.avgBreak > 0 ? '#B91C1C' : '#111827';
      avgBreakCell.cellStyle.hAlign = xlsio.HAlignType.center;
      avgBreakCell.cellStyle.vAlign = xlsio.VAlignType.center;
      avgBreakCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      avgBreakCell.cellStyle.borders.all.color = '#E5E7EB';

      row++;
    }

    return row + 1; // Skip a blank row
  }

  Map<String, ({double avgShort, double avgBreak})> _calculateEmployeeAverages(
    Iterable<AttendancePolicyRecapDay> recapRows,
  ) {
    final employeeData = <String, List<AttendancePolicyRecapDay>>{};

    // Group recap rows by employee
    for (final recap in recapRows) {
      employeeData.putIfAbsent(recap.employeeId, () => []).add(recap);
    }

    // Calculate averages for each employee
    final averages = <String, ({double avgShort, double avgBreak})>{};

    for (final entry in employeeData.entries) {
      final employeeRecaps = entry.value;
      var totalShortMinutes = 0.0;
      var totalBreakMinutes = 0.0;
      var workDayCount = 0;

      for (final recap in employeeRecaps) {
        // Only count work days (not absences, holidays, etc.)
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
    // Section title with improved styling
    final sectionTitle = sheet.getRangeByIndex(row, 1, row, 9);
    sectionTitle.merge();
    sectionTitle.setText('TOP INSIGHT UNTUK AREA MANAGER');
    sectionTitle.cellStyle.bold = true;
    sectionTitle.cellStyle.fontSize = 12;
    sectionTitle.cellStyle.fontColor = '#DC2626';
    sectionTitle.cellStyle.backColor = '#FEF2F2';
    sectionTitle.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    sectionTitle.cellStyle.borders.all.color = '#DC2626';
    sectionTitle.cellStyle.hAlign = xlsio.HAlignType.center;
    sectionTitle.rowHeight = 30;
    row++;

    // Build employee averages for detailed insights
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
        icon: '★',
        entries: managers
            .map((r) => '${r.employeeName} (${r.employmentContract.label}) — '
                'Masuk: ${r.cells.where((c) => c.hasData && c.primaryStatus != AttendancePolicyPrimaryStatus.absence).length} hari')
            .toList(),
        color: '#059669',
        isManagerSection: true,
      );
      row += 2 + managers.length;
    }

    // Sort employees by issue severity
    final sorted = List<PayrollMatrixRow>.from(dataset.rows)
      ..sort((a, b) {
        final aTotal =
            a.lateCount + a.shortWorkCount + a.excessBreakCount + a.absenceCount;
        final bTotal =
            b.lateCount + b.shortWorkCount + b.excessBreakCount + b.absenceCount;
        return bTotal.compareTo(aTotal); // Descending
      });

    // Top 5 most problematic employees with detailed info
    final problematicEntries = sorted
        .take(math.min(5, sorted.length))
        .where((r) =>
            r.lateCount +
                r.shortWorkCount +
                r.excessBreakCount +
                r.absenceCount >
            0)
        .map((r) {
      final averages = employeeAverages[r.employeeId] ??
          const (avgShort: 0.0, avgBreak: 0.0);
      final total =
          r.lateCount + r.shortWorkCount + r.excessBreakCount + r.absenceCount;

      String detailText = '${r.employeeName} (${r.employmentContract.label}) — $total masalah';
      if (averages.avgShort > 0 || averages.avgBreak > 0) {
        final avgShortText = _formatMinutesToDuration(averages.avgShort);
        final avgBreakText = _formatMinutesToDuration(averages.avgBreak);
        detailText += '\n     Rata-rata kurang: $avgShortText, break lebih: $avgBreakText';
      }
      return detailText;
    }).toList();

    _writeInsightSubSection(
      sheet,
      row: row,
      title: 'Karyawan Paling Banyak Masalah',
      icon: '!',
      entries: problematicEntries,
      color: '#B91C1C',
    );
    row += 2 + problematicEntries.length;

    // Top 5 overtime employees with contract info
    final sortedOt = List<PayrollMatrixRow>.from(dataset.rows)
      ..sort((a, b) => b.overtimeCount.compareTo(a.overtimeCount));

    final overtimeEntries = sortedOt
        .take(math.min(5, sortedOt.length))
        .where((r) => r.overtimeCount > 0)
        .map((r) => '${r.employeeName} (${r.employmentContract.label}) — Lembur ${r.overtimeCount} hari')
        .toList();

    _writeInsightSubSection(
      sheet,
      row: row,
      title: 'Karyawan Paling Banyak Lembur',
      icon: '+',
      entries: overtimeEntries,
      color: '#92400E',
    );
    row += 2 + overtimeEntries.length;

    // Clean employees (no issues) with contract info
    final cleanEmployees = dataset.rows.where((r) =>
        r.lateCount == 0 &&
        r.shortWorkCount == 0 &&
        r.excessBreakCount == 0 &&
        r.absenceCount == 0);

    final cleanEntries = cleanEmployees
        .take(math.min(10, cleanEmployees.length))
        .map((r) => '${r.employeeName} (${r.employmentContract.label})')
        .toList();

    _writeInsightSubSection(
      sheet,
      row: row,
      title: 'Karyawan Tanpa Masalah (Sempurna)',
      icon: '\u2713',
      entries: cleanEntries,
      color: '#059669',
    );
  }

  void _writeInsightSubSection(
    xlsio.Worksheet sheet, {
    required int row,
    required String title,
    required String icon,
    required List<String> entries,
    required String color,
    bool isManagerSection = false,
  }) {
    // Sub-section title with improved styling
    final titleCell = sheet.getRangeByIndex(row, 1, row, 9);
    titleCell.merge();
    titleCell.setText('$icon  $title');
    titleCell.cellStyle.bold = true;
    titleCell.cellStyle.fontSize = isManagerSection ? 11 : 10;
    titleCell.cellStyle.fontColor = color;
    if (isManagerSection) {
      titleCell.cellStyle.backColor = '#F0FDF4';
      titleCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      titleCell.cellStyle.borders.all.color = color;
    }
    titleCell.rowHeight = isManagerSection ? 28 : 24;
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

    // Add explanatory text for sections
    if (title.contains('Paling Banyak Masalah')) {
      final explanationCell = sheet.getRangeByIndex(row, 1, row, 9);
      explanationCell.merge();
      explanationCell.setText('  Karyawan dengan total pelanggaran tertinggi dan rata-rata defisit waktu kerja:');
      explanationCell.cellStyle.fontColor = '#6B7280';
      explanationCell.cellStyle.fontSize = 9;
      explanationCell.cellStyle.italic = true;
      row++;
    } else if (title.contains('Paling Banyak Lembur')) {
      final explanationCell = sheet.getRangeByIndex(row, 1, row, 9);
      explanationCell.merge();
      explanationCell.setText('  Karyawan dengan frekuensi lembur tertinggi:');
      explanationCell.cellStyle.fontColor = '#6B7280';
      explanationCell.cellStyle.fontSize = 9;
      explanationCell.cellStyle.italic = true;
      row++;
    } else if (title.contains('KEPALA GERAI')) {
      final explanationCell = sheet.getRangeByIndex(row, 1, row, 9);
      explanationCell.merge();
      explanationCell.setText('  Manager dengan status khusus (exempt dari penalty):');
      explanationCell.cellStyle.fontColor = '#6B7280';
      explanationCell.cellStyle.fontSize = 9;
      explanationCell.cellStyle.italic = true;
      row++;
    }

    for (final entry in entries) {
      final cell = sheet.getRangeByIndex(row, 1, row, 9);
      cell.merge();
      cell.setText('  • $entry');
      cell.cellStyle.fontColor = '#374151';
      cell.cellStyle.fontSize = 9;
      cell.cellStyle.wrapText = true;
      cell.rowHeight = entry.contains('\n') ? 32 : 20;
      row++;
    }
  }

  String _buildMiniBar(int length, int value) {
    if (value == 0) return '\u2713 Bersih';
    // Use block characters for visual bar
    final blocks = '\u2588' * length;
    return '$blocks $value';
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
