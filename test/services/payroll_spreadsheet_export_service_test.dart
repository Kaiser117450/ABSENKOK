import 'dart:convert';
import 'dart:io';

import 'package:absensi_enakko_flutter/models/payroll_matrix_day_cell.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';
import 'package:absensi_enakko_flutter/services/admin_policy_recap_dataset_service.dart';
import 'package:absensi_enakko_flutter/services/payroll_matrix_builder.dart';
import 'package:absensi_enakko_flutter/services/payroll_spreadsheet_export_service.dart';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../fixtures/report_export_parity_fixture.dart';

void main() {
  group('PayrollSpreadsheetExportService', () {
    const recapDatasetService = AdminPolicyRecapDatasetService();
    late Directory tempDir;

    setUp(() async {
      tempDir =
          await Directory.systemTemp.createTemp('payroll-spreadsheet-test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        'generates a real payroll workbook for mixed strict and fallback matrix rows with locked headers and no forbidden fields',
        () async {
      final context = _buildParitySpreadsheetContext(recapDatasetService);
      final service = PayrollSpreadsheetExportService(
        temporaryDirectoryProvider: () async => tempDir,
      );

      final file = await service.exportPayrollSpreadsheet(
        outletName: context.bundle.outletName,
        startDate: context.bundle.startDate,
        endDate: context.bundle.endDate,
        dataset: context.dataset,
      );

      expect(await file.exists(), isTrue);
      expect(file.path, endsWith('.xlsx'));
      expect(path.basename(file.path),
          'rekap_payroll_outlet_parity_20260318_20260328.xlsx');

      final bytes = await file.readAsBytes();
      final workbook = Excel.decodeBytes(bytes);
      expect(workbook.tables.containsKey('Rekap Payroll'), isTrue);

      final sheet = workbook.tables['Rekap Payroll']!;
      final headerValues = sheet.rows.first
          .whereType<Data>()
          .map((cell) => cell.value.toString())
          .toList(growable: false);
      final allValues = sheet.rows
          .expand((row) => row)
          .whereType<Data>()
          .map((cell) => cell.value.toString())
          .toList(growable: false);

      expect(headerValues.take(2).toList(growable: false), <String>[
        'Karyawan',
        'Kontrak',
      ]);
      expect(
        headerValues
            .skip(2 + context.dataset.dates.length)
            .take(PayrollMatrixRow.summaryLabels.length)
            .toList(growable: false),
        PayrollMatrixRow.summaryLabels,
      );

      final lateCell = context.cellFor(
        'emp-outlet-24-jam',
        DateTime(2026, 3, 18),
      );
      final overtimeCell =
          context.cellFor('emp-overtime', DateTime(2026, 3, 25));
      final absenceCell = context.cellFor('emp-no-show', DateTime(2026, 3, 28));
      final fallbackCell = context.cellFor(
        'emp-legacy-fallback-no-schedule',
        DateTime(2026, 3, 21),
      );

      expect(allValues, contains('Ayu Full Time'));
      expect(allValues, contains('FULLTIME'));
      expect(allValues, contains('Hana Tanpa Jadwal'));
      expect(allValues, contains('PARTTIME'));
      expect(allValues, contains(lateCell.exportText));
      expect(allValues, contains(overtimeCell.exportText));
      expect(allValues, contains(absenceCell.exportText));
      expect(allValues, contains(fallbackCell.exportText));
      expect(lateCell.exportText, contains('TLT'));
      expect(overtimeCell.exportText, contains('OT'));
      expect(absenceCell.exportText, contains('ABS'));
      expect(fallbackCell.exportText, contains('Hadir tanpa jadwal'));

      final archive = ZipDecoder().decodeBytes(bytes);
      final stylesXml = _archiveFileText(archive, 'xl/styles.xml');
      final worksheetXml =
          _archiveFileText(archive, 'xl/worksheets/sheet1.xml');
      final workbookXmlText = archive.files
          .where((file) => file.isFile)
          .map((file) =>
              utf8.decode(file.content as List<int>, allowMalformed: true))
          .join('\n');
      final workbookStyles = _WorkbookStyles.parse(stylesXml);

      for (final styledCell in <_ExpectedStyledCell>[
        _ExpectedStyledCell(
          employeeId: 'emp-outlet-24-jam',
          date: DateTime(2026, 3, 18),
          expectedCell: lateCell,
        ),
        _ExpectedStyledCell(
          employeeId: 'emp-overtime',
          date: DateTime(2026, 3, 25),
          expectedCell: overtimeCell,
        ),
        _ExpectedStyledCell(
          employeeId: 'emp-no-show',
          date: DateTime(2026, 3, 28),
          expectedCell: absenceCell,
        ),
        _ExpectedStyledCell(
          employeeId: 'emp-legacy-fallback-no-schedule',
          date: DateTime(2026, 3, 21),
          expectedCell: fallbackCell,
        ),
      ]) {
        final cellReference = context.cellReferenceFor(
          styledCell.employeeId,
          styledCell.date,
        );
        final styleIndex = _extractCellStyleIndex(worksheetXml, cellReference);
        final resolvedStyle = workbookStyles.resolve(styleIndex);
        expect(
          resolvedStyle.fillColorHex,
          styledCell.expectedCell.fillColorHex,
          reason:
              '$cellReference should preserve fillColorHex from parity data',
        );
        expect(
          resolvedStyle.textColorHex,
          styledCell.expectedCell.textColorHex,
          reason:
              '$cellReference should preserve textColorHex from parity data',
        );
      }

      for (final forbiddenField
          in PayrollSpreadsheetExportService.forbiddenFields) {
        expect(
          workbookXmlText.contains(forbiddenField),
          isFalse,
          reason: 'Workbook should not expose $forbiddenField',
        );
      }
    });
  });
}

_ParitySpreadsheetContext _buildParitySpreadsheetContext(
  AdminPolicyRecapDatasetService recapDatasetService,
) {
  final bundle = buildReportExportParityFixtureBundle();
  final recapDataset = recapDatasetService.build(
    employees: bundle.employees,
    strictRows: bundle.strictRows,
    attendanceLogs: bundle.attendanceLogs,
    outletId: bundle.outletId,
    outletName: bundle.outletName,
    outletOperatingMode: bundle.outletOperatingMode,
    now: DateTime(2026, 3, 29, 10),
  );

  final dataset = buildPayrollMatrix(
    startDate: bundle.startDate,
    endDate: bundle.endDate,
    employees: bundle.employees,
    recapRows: recapDataset.mergedRows,
  );

  return _ParitySpreadsheetContext(bundle: bundle, dataset: dataset);
}

class _ParitySpreadsheetContext {
  const _ParitySpreadsheetContext({
    required this.bundle,
    required this.dataset,
  });

  final ReportExportParityFixtureBundle bundle;
  final PayrollMatrixDataset dataset;

  PayrollMatrixDayCell cellFor(String employeeId, DateTime date) {
    final row = dataset.rows
        .firstWhere((candidate) => candidate.employeeId == employeeId);
    return row.cells.firstWhere(
      (candidate) => candidate.hasData && _isSameDate(candidate.date, date),
    );
  }

  String cellReferenceFor(String employeeId, DateTime date) {
    final rowIndex = dataset.rows
        .indexWhere((candidate) => candidate.employeeId == employeeId);
    expect(rowIndex, isNonNegative);

    final columnIndex = dataset.dates.indexWhere(
      (candidate) => _isSameDate(candidate, date),
    );
    expect(columnIndex, isNonNegative);

    return '${_excelColumnName(columnIndex + 3)}${rowIndex + 2}';
  }
}

class _ExpectedStyledCell {
  const _ExpectedStyledCell({
    required this.employeeId,
    required this.date,
    required this.expectedCell,
  });

  final String employeeId;
  final DateTime date;
  final PayrollMatrixDayCell expectedCell;
}

class _WorkbookStyles {
  _WorkbookStyles({
    required this.fillColors,
    required this.fontColors,
    required this.cellXfs,
  });

  factory _WorkbookStyles.parse(String stylesXml) {
    return _WorkbookStyles(
      fillColors: _extractNamedColors(stylesXml, 'fills', 'fill', 'fgColor'),
      fontColors: _extractNamedColors(stylesXml, 'fonts', 'font', 'color'),
      cellXfs: _extractCellXfs(stylesXml),
    );
  }

  final List<String?> fillColors;
  final List<String?> fontColors;
  final List<_WorkbookCellXf> cellXfs;

  _ResolvedWorkbookStyle resolve(int styleIndex) {
    final xf = cellXfs[styleIndex];
    return _ResolvedWorkbookStyle(
      fillColorHex: fillColors[xf.fillId],
      textColorHex: fontColors[xf.fontId],
    );
  }
}

class _WorkbookCellXf {
  const _WorkbookCellXf({
    required this.fillId,
    required this.fontId,
  });

  final int fillId;
  final int fontId;
}

class _ResolvedWorkbookStyle {
  const _ResolvedWorkbookStyle({
    required this.fillColorHex,
    required this.textColorHex,
  });

  final String? fillColorHex;
  final String? textColorHex;
}

String _archiveFileText(Archive archive, String archivePath) {
  final file =
      archive.files.firstWhere((candidate) => candidate.name == archivePath);
  return utf8.decode(file.content as List<int>, allowMalformed: true);
}

int _extractCellStyleIndex(String worksheetXml, String cellReference) {
  final match = RegExp(
    '<c\\b(?=[^>]*\\br="$cellReference")(?=[^>]*\\bs="(\\d+)")[^>]*>',
  ).firstMatch(worksheetXml);
  expect(match, isNotNull, reason: 'Missing style index for $cellReference');
  return int.parse(match!.group(1)!);
}

List<String?> _extractNamedColors(
  String stylesXml,
  String blockTag,
  String itemTag,
  String colorTag,
) {
  final block = _extractXmlBlock(stylesXml, blockTag);
  expect(block, isNotNull, reason: '$blockTag should exist in styles.xml');

  return RegExp('<$itemTag\\b[\\s\\S]*?</$itemTag>')
      .allMatches(block!)
      .map((match) {
    final colorMatch = RegExp(
      '<$colorTag\\b[^>]*rgb="([A-Fa-f0-9]+)"',
    ).firstMatch(match.group(0)!);
    if (colorMatch == null) {
      return null;
    }
    return _normalizeRgb(colorMatch.group(1)!);
  }).toList(growable: false);
}

List<_WorkbookCellXf> _extractCellXfs(String stylesXml) {
  final block = _extractXmlBlock(stylesXml, 'cellXfs');
  expect(block, isNotNull, reason: 'cellXfs should exist in styles.xml');

  return RegExp(r'<xf\b[^>]*/>|<xf\b[\s\S]*?</xf>')
      .allMatches(block!)
      .map((match) {
    final entry = match.group(0)!;
    return _WorkbookCellXf(
      fillId: _extractAttributeInt(entry, 'fillId') ?? 0,
      fontId: _extractAttributeInt(entry, 'fontId') ?? 0,
    );
  }).toList(growable: false);
}

String? _extractXmlBlock(String xml, String tag) {
  final match = RegExp('<$tag\\b[^>]*>([\\s\\S]*?)</$tag>').firstMatch(xml);
  return match?.group(1);
}

int? _extractAttributeInt(String xml, String attribute) {
  final match = RegExp('$attribute="(\\d+)"').firstMatch(xml);
  return match == null ? null : int.parse(match.group(1)!);
}

String _normalizeRgb(String value) {
  final normalized = value.toUpperCase();
  final rgb = normalized.length > 6
      ? normalized.substring(normalized.length - 6)
      : normalized.padLeft(6, '0');
  return '#$rgb';
}

String _excelColumnName(int columnIndex) {
  var index = columnIndex;
  final buffer = StringBuffer();

  while (index > 0) {
    final remainder = (index - 1) % 26;
    buffer.writeCharCode(65 + remainder);
    index = (index - 1) ~/ 26;
  }

  return buffer.toString().split('').reversed.join();
}

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
