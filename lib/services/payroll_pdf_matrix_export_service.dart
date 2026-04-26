import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:absensi_enakko_flutter/models/payroll_matrix_day_cell.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';
import 'package:absensi_enakko_flutter/services/payroll_matrix_semantics.dart';
import 'package:absensi_enakko_flutter/services/pdf_service.dart';

typedef PayrollPdfTemporaryDirectoryProvider = Future<Directory> Function();
typedef PayrollPdfLogoLoader = Future<Uint8List?> Function();
typedef PayrollPdfNowProvider = DateTime Function();

class PayrollPdfMatrixCellPreview {
  final String primaryLabel;
  final List<String> secondaryTags;
  final List<String> secondaryDescriptions;
  final String fillColorHex;
  final String textColorHex;

  const PayrollPdfMatrixCellPreview({
    required this.primaryLabel,
    required this.secondaryTags,
    this.secondaryDescriptions = const [],
    required this.fillColorHex,
    required this.textColorHex,
  });

  factory PayrollPdfMatrixCellPreview.fromCell(PayrollMatrixDayCell cell) {
    return PayrollPdfMatrixCellPreview(
      primaryLabel: cell.primaryLabel,
      secondaryTags: List<String>.from(cell.secondaryTags),
      secondaryDescriptions: List<String>.from(cell.secondaryDescriptions),
      fillColorHex: cell.fillColorHex,
      textColorHex: cell.textColorHex,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'primaryLabel': primaryLabel,
      'secondaryTags': secondaryTags,
      'secondaryDescriptions': secondaryDescriptions,
      'fillColorHex': fillColorHex,
      'textColorHex': textColorHex,
    };
  }
}

class PayrollPdfMatrixRowPreview {
  final String employeeName;
  final String employmentContract;
  final String employeeRole;
  final List<PayrollPdfMatrixCellPreview> cells;
  final List<int> summaryValues;
  final bool isManagerExempt;

  const PayrollPdfMatrixRowPreview({
    required this.employeeName,
    required this.employmentContract,
    required this.employeeRole,
    required this.cells,
    required this.summaryValues,
    this.isManagerExempt = false,
  });

  PayrollPdfMatrixRowPreview slice({
    required int start,
    required int end,
  }) {
    return PayrollPdfMatrixRowPreview(
      employeeName: employeeName,
      employmentContract: employmentContract,
      employeeRole: employeeRole,
      cells: cells.sublist(start, end),
      summaryValues: summaryValues,
      isManagerExempt: isManagerExempt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'employeeName': employeeName,
      'employmentContract': employmentContract,
      'employeeRole': employeeRole,
      'cells': cells.map((cell) => cell.toJson()).toList(growable: false),
      'summaryValues': summaryValues,
    };
  }
}

class PayrollPdfMatrixPagePreview {
  final List<DateTime> dates;
  final List<PayrollPdfMatrixRowPreview> rows;

  const PayrollPdfMatrixPagePreview({
    required this.dates,
    required this.rows,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'dates':
          dates.map((date) => date.toIso8601String()).toList(growable: false),
      'rows': rows.map((row) => row.toJson()).toList(growable: false),
    };
  }
}

class PayrollPdfSummaryMetricPreview {
  final String tag;
  final String label;
  final int value;
  final String fillColorHex;
  final String textColorHex;

  const PayrollPdfSummaryMetricPreview({
    required this.tag,
    required this.label,
    required this.value,
    required this.fillColorHex,
    required this.textColorHex,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tag': tag,
      'label': label,
      'value': value,
      'fillColorHex': fillColorHex,
      'textColorHex': textColorHex,
    };
  }
}

class PayrollPdfDocumentPreview {
  final String title;
  final String outletName;
  final String periodLabel;
  final List<PayrollPdfSummaryMetricPreview> summaryMetrics;
  final List<String> legendTags;
  final List<PayrollPdfMatrixPagePreview> matrixPages;

  const PayrollPdfDocumentPreview({
    required this.title,
    required this.outletName,
    required this.periodLabel,
    required this.summaryMetrics,
    required this.legendTags,
    required this.matrixPages,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'outletName': outletName,
      'periodLabel': periodLabel,
      'summaryMetrics': summaryMetrics
          .map((metric) => metric.toJson())
          .toList(growable: false),
      'legendTags': legendTags,
      'matrixPages':
          matrixPages.map((page) => page.toJson()).toList(growable: false),
    };
  }
}

class PayrollPdfMatrixExportService {
  PayrollPdfMatrixExportService({
    PayrollPdfTemporaryDirectoryProvider? temporaryDirectoryProvider,
    PayrollPdfLogoLoader? logoLoader,
    PayrollPdfNowProvider? nowProvider,
    PayrollMatrixSemantics semantics = const PayrollMatrixSemantics(),
  })  : _temporaryDirectoryProvider =
            temporaryDirectoryProvider ?? getTemporaryDirectory,
        _logoLoader = logoLoader ?? PdfService.loadBrandLogo,
        _nowProvider = nowProvider ?? DateTime.now,
        _semantics = semantics;

  static const String reportTitle = 'Insight Payroll PDF';
  static const List<String> forbiddenFields = <String>[
    'latitude',
    'longitude',
    'capture_mode',
    'queue_order',
    'requires_admin_review',
    'detail_note',
  ];

  static const int _maxDateColumnsPerPage = 10;
  static const int _maxRowsPerPage = 10;

  final PayrollPdfTemporaryDirectoryProvider _temporaryDirectoryProvider;
  final PayrollPdfLogoLoader _logoLoader;
  final PayrollPdfNowProvider _nowProvider;
  final PayrollMatrixSemantics _semantics;

  Future<File> buildPayrollPdf({
    required PayrollMatrixDataset dataset,
    required String outletName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final bytes = await buildPayrollPdfBytes(
      dataset: dataset,
      outletName: outletName,
      startDate: startDate,
      endDate: endDate,
    );
    final directory = await _temporaryDirectoryProvider();
    final filename = _buildFilename(
      outletName: outletName,
      startDate: _dateOnly(startDate),
      endDate: _dateOnly(endDate),
    );
    final file = File(path.join(directory.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @visibleForTesting
  Future<Uint8List> buildPayrollPdfBytes({
    required PayrollMatrixDataset dataset,
    required String outletName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final preview = buildPreview(
      dataset: dataset,
      outletName: outletName,
      startDate: startDate,
      endDate: endDate,
    );
    return _buildDocument(preview);
  }

  @visibleForTesting
  PayrollPdfDocumentPreview buildPreview({
    required PayrollMatrixDataset dataset,
    required String outletName,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final normalizedStart = _dateOnly(startDate);
    final normalizedEnd = _dateOnly(endDate);
    if (normalizedEnd.isBefore(normalizedStart)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'End date must not be before start date',
      );
    }
    if (dataset.isEmpty) {
      throw ArgumentError.value(
        dataset,
        'dataset',
        'Payroll matrix dataset must not be empty',
      );
    }

    final dates = _resolveDates(
      dataset: dataset,
      startDate: normalizedStart,
      endDate: normalizedEnd,
    );
    final alignedRows = dataset.rows
        .map(
          (row) => PayrollPdfMatrixRowPreview(
            employeeName: row.employeeName,
            employmentContract: row.employmentContract.dbValue,
            employeeRole: row.employeeRole,
            cells: List<PayrollPdfMatrixCellPreview>.generate(
              dates.length,
              (index) {
                final cell = index < row.cells.length
                    ? row.cells[index]
                    : PayrollMatrixDayCell.placeholder(dates[index]);
                return PayrollPdfMatrixCellPreview.fromCell(cell);
              },
              growable: false,
            ),
            summaryValues: row.summaryValuesInOrder,
            isManagerExempt: row.isManagerExempt,
          ),
        )
        .toList(growable: false);

    final summaryMetrics = _semantics
        .summaryMetricValuesForDataset(
          PayrollMatrixDataset(dates: dates, rows: dataset.rows),
        )
        .map(
          (metric) => PayrollPdfSummaryMetricPreview(
            tag: metric.tag,
            label: metric.label,
            value: metric.value,
            fillColorHex: metric.fillColorHex,
            textColorHex: metric.textColorHex,
          ),
        )
        .toList(growable: false);

    final dateRanges = <({int start, int end})>[];
    for (var start = 0; start < dates.length; start += _maxDateColumnsPerPage) {
      final end = start + _maxDateColumnsPerPage < dates.length
          ? start + _maxDateColumnsPerPage
          : dates.length;
      dateRanges.add((start: start, end: end));
    }

    final matrixPages = <PayrollPdfMatrixPagePreview>[];
    for (final dateRange in dateRanges) {
      for (var rowStart = 0;
          rowStart < alignedRows.length;
          rowStart += _maxRowsPerPage) {
        final rowEnd = rowStart + _maxRowsPerPage < alignedRows.length
            ? rowStart + _maxRowsPerPage
            : alignedRows.length;
        matrixPages.add(
          PayrollPdfMatrixPagePreview(
            dates: dates.sublist(dateRange.start, dateRange.end),
            rows: alignedRows
                .sublist(rowStart, rowEnd)
                .map(
                  (row) => row.slice(
                    start: dateRange.start,
                    end: dateRange.end,
                  ),
                )
                .toList(growable: false),
          ),
        );
      }
    }

    return PayrollPdfDocumentPreview(
      title: reportTitle,
      outletName: outletName,
      periodLabel:
          '${_formatDateLabel(normalizedStart)} - ${_formatDateLabel(normalizedEnd)}',
      summaryMetrics: summaryMetrics,
      legendTags: _semantics.legendTags,
      matrixPages: matrixPages,
    );
  }

  Future<Uint8List> _buildDocument(PayrollPdfDocumentPreview preview) async {
    final pdf = pw.Document();
    final regular = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final logoBytes = await _logoLoader();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => _buildSummaryPage(
          preview: preview,
          regular: regular,
          bold: bold,
          logoBytes: logoBytes,
        ),
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => _buildAnalysisPage(
          preview: preview,
          regular: regular,
          bold: bold,
        ),
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  pw.Widget _buildSummaryPage({
    required PayrollPdfDocumentPreview preview,
    required pw.Font regular,
    required pw.Font bold,
    required Uint8List? logoBytes,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildHeader(
          title: preview.title,
          subtitle: preview.outletName,
          periodLabel: preview.periodLabel,
          regular: regular,
          bold: bold,
          logoBytes: logoBytes,
        ),
        pw.SizedBox(height: 16),
        _buildMetricRow(
          metrics: preview.summaryMetrics.take(3).toList(growable: false),
          regular: regular,
          bold: bold,
        ),
        pw.SizedBox(height: 12),
        _buildMetricRow(
          metrics: preview.summaryMetrics.skip(3).toList(growable: false),
          regular: regular,
          bold: bold,
        ),
        pw.SizedBox(height: 16),
        _buildContractBreakdown(preview: preview, regular: regular, bold: bold),
        pw.SizedBox(height: 16),
        _buildAverageDeficitInsights(
            preview: preview, regular: regular, bold: bold),
        pw.SizedBox(height: 16),
        _buildKepalaGeraiSection(
            preview: preview, regular: regular, bold: bold),
        pw.SizedBox(height: 18),
        pw.Text(
          'Legend payroll',
          style: pw.TextStyle(
            font: bold,
            fontSize: 11,
            color: PdfColor.fromHex('111827'),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: preview.legendTags
              .map((tag) =>
                  _buildLegendChip(tag: tag, regular: regular, bold: bold))
              .toList(growable: false),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'PDF ini hanya berisi insight. Detail matrix payroll lengkap tetap menjadi fokus ekspor spreadsheet.',
          style: pw.TextStyle(
            font: regular,
            fontSize: 9,
            color: PdfColor.fromHex('6B7280'),
          ),
        ),
        pw.Spacer(),
        pw.Text(
          'Dibuat pada: ${_formatTimestamp(_nowProvider())}',
          style: pw.TextStyle(
            font: regular,
            fontSize: 8,
            color: PdfColor.fromHex('9CA3AF'),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildHeader({
    required String title,
    required String subtitle,
    required String periodLabel,
    required pw.Font regular,
    required pw.Font bold,
    required Uint8List? logoBytes,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('FEF2F2'),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildLogo(logoBytes, size: 34),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Ayam Guling Enakko',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 14,
                    color: PdfColor.fromHex('DC2626'),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 16,
                    color: PdfColor.fromHex('111827'),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Outlet: $subtitle',
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 10,
                    color: PdfColor.fromHex('374151'),
                  ),
                ),
                pw.Text(
                  'Periode: $periodLabel',
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 10,
                    color: PdfColor.fromHex('374151'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMetricRow({
    required List<PayrollPdfSummaryMetricPreview> metrics,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    final children = metrics
        .map(
          (metric) => pw.Expanded(
            child: _buildMetricCard(
              metric: metric,
              regular: regular,
              bold: bold,
            ),
          ),
        )
        .toList();
    while (children.length < 3) {
      children.add(pw.Expanded(child: pw.SizedBox()));
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        children[0],
        pw.SizedBox(width: 10),
        children[1],
        pw.SizedBox(width: 10),
        children[2],
      ],
    );
  }

  pw.Widget _buildMetricCard({
    required PayrollPdfSummaryMetricPreview metric,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex(metric.fillColorHex),
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromHex('E5E7EB')),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            metric.label,
            style: pw.TextStyle(
              font: regular,
              fontSize: 9,
              color: PdfColor.fromHex(metric.textColorHex),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '${metric.value}',
            style: pw.TextStyle(
              font: bold,
              fontSize: 22,
              color: PdfColor.fromHex(metric.textColorHex),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildLegendChip({
    required String tag,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    final metric = _semantics.summaryMetrics.firstWhere(
      (item) => item.tag == tag,
      orElse: () => const PayrollMatrixSummaryMetric(
        tag: PayrollMatrixSemantics.managerExemptTag,
        label: 'Manager Exempt',
        fillColorHex: '#F8FAFC',
        textColorHex: '#334155',
      ),
    );
    // Show "TAG = Full Label" for clarity, e.g. "OT = Lembur"
    final displayText = '$tag = ${metric.label}';
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex(metric.fillColorHex),
        borderRadius: pw.BorderRadius.circular(999),
        border: pw.Border.all(color: PdfColor.fromHex('E5E7EB')),
      ),
      child: pw.Text(
        displayText,
        style: pw.TextStyle(
          font: tag == PayrollMatrixSemantics.managerExemptTag ? regular : bold,
          fontSize: 8,
          color: PdfColor.fromHex(metric.textColorHex),
        ),
      ),
    );
  }

  pw.Widget _buildContractBreakdown({
    required PayrollPdfDocumentPreview preview,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    final contractCounts = <String, int>{};
    for (final page in preview.matrixPages) {
      for (final row in page.rows) {
        contractCounts[row.employmentContract] =
            (contractCounts[row.employmentContract] ?? 0) + 1;
      }
    }

    final fulltimeCount = contractCounts['FULLTIME'] ?? 0;
    final parttimeCount = contractCounts['PARTTIME'] ?? 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('F8FAFC'),
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromHex('E2E8F0')),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Breakdown Kontrak Karyawan',
            style: pw.TextStyle(
              font: bold,
              fontSize: 11,
              color: PdfColor.fromHex('111827'),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Fulltime: $fulltimeCount | Parttime: $parttimeCount',
            style: pw.TextStyle(
              font: regular,
              fontSize: 9,
              color: PdfColor.fromHex('475569'),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildAverageDeficitInsights({
    required PayrollPdfDocumentPreview preview,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    final deficitData = <Map<String, dynamic>>[];

    for (final page in preview.matrixPages) {
      for (final row in page.rows) {
        final workDays = _countWorkDays(row.cells);
        if (workDays == 0) continue;

        final totalShortWorkMinutes =
            _extractTotalMinutes(row.cells, 'Kurang Jam');
        final totalExcessBreakMinutes =
            _extractTotalMinutes(row.cells, 'Break Lebih');

        final avgShortWork = totalShortWorkMinutes / workDays;
        final avgExcessBreak = totalExcessBreakMinutes / workDays;

        if (avgShortWork > 0 || avgExcessBreak > 0) {
          deficitData.add({
            'name': row.employeeName,
            'contract': row.employmentContract,
            'avgShortWork': avgShortWork,
            'avgExcessBreak': avgExcessBreak,
          });
        }
      }
    }

    if (deficitData.isEmpty) {
      return pw.SizedBox();
    }

    // Sort by total deficit (short work + excess break)
    deficitData.sort((a, b) => (b['avgShortWork'] + b['avgExcessBreak'])
        .compareTo(a['avgShortWork'] + a['avgExcessBreak']));

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('FEF2F2'),
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromHex('FECACA')),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Rata-Rata Deficit Harian',
            style: pw.TextStyle(
              font: bold,
              fontSize: 11,
              color: PdfColor.fromHex('111827'),
            ),
          ),
          pw.SizedBox(height: 8),
          ...deficitData.take(5).map((data) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  '- ${data['name']} (${data['contract']}): Kurang ${_formatMinutesToHours(data['avgShortWork'])}, Break +${_formatMinutesToHours(data['avgExcessBreak'])}',
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 8,
                    color: PdfColor.fromHex('B91C1C'),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  pw.Widget _buildAnalysisPage({
    required PayrollPdfDocumentPreview preview,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    // Deduplicate employees across matrix pages (same employee appears in each date-range page)
    final seen = <String>{};
    final employees = <Map<String, dynamic>>[];
    for (final page in preview.matrixPages) {
      for (final row in page.rows) {
        if (seen.contains(row.employeeName)) {
          continue;
        }
        seen.add(row.employeeName);
        final late = row.summaryValues.isNotEmpty ? row.summaryValues[0] : 0;
        final shortWork =
            row.summaryValues.length > 1 ? row.summaryValues[1] : 0;
        final excessBreak =
            row.summaryValues.length > 2 ? row.summaryValues[2] : 0;
        final absence = row.summaryValues.length > 3 ? row.summaryValues[3] : 0;
        final total = late + shortWork + excessBreak + absence;
        employees.add({
          'name': row.isManagerExempt
              ? '[Kepala Gerai] ${row.employeeName}'
              : row.employeeName,
          'contract': row.employmentContract,
          'isManager': row.isManagerExempt,
          'late': late,
          'shortWork': shortWork,
          'excessBreak': excessBreak,
          'absence': absence,
          'total': total,
        });
      }
    }
    employees.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
    final maxIssues =
        employees.isEmpty ? 1 : math.max(1, employees.first['total'] as int);
    final cleanCount = employees.where((e) => e['total'] == 0).length;
    final display = employees.take(20).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Page header
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('7C3AED'),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('ANALISIS MASALAH KARYAWAN',
                  style: pw.TextStyle(
                      font: bold,
                      fontSize: 13,
                      color: PdfColor.fromHex('FFFFFF'))),
              pw.Text('${preview.outletName} · ${preview.periodLabel}',
                  style: pw.TextStyle(
                      font: regular,
                      fontSize: 8,
                      color: PdfColor.fromHex('DDD6FE'))),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        // Legend
        pw.Row(children: [
          _buildAnalysisLegend('Terlambat', 'F59E0B', regular),
          pw.SizedBox(width: 10),
          _buildAnalysisLegend('Kurang Jam', 'EF4444', regular),
          pw.SizedBox(width: 10),
          _buildAnalysisLegend('Break Lebih', 'DC2626', regular),
          pw.SizedBox(width: 10),
          _buildAnalysisLegend('Tidak Hadir', '991B1B', regular),
          pw.Spacer(),
          pw.Text('$cleanCount karyawan bersih',
              style: pw.TextStyle(
                  font: bold, fontSize: 8, color: PdfColor.fromHex('059669'))),
        ]),
        pw.SizedBox(height: 10),
        // Bar rows
        ...display.map((emp) {
          final total = emp['total'] as int;
          final late = emp['late'] as int;
          final sw = emp['shortWork'] as int;
          final eb = emp['excessBreak'] as int;
          final ab = emp['absence'] as int;
          final name = (emp['name'] as String);
          final displayName =
              name.length > 18 ? '${name.substring(0, 18)}…' : name;
          final remaining = maxIssues - total;

          final segments = <pw.Widget>[];
          if (late > 0) {
            segments.add(pw.Flexible(
                flex: late,
                child: pw.Container(color: PdfColor.fromHex('F59E0B'))));
          }
          if (sw > 0) {
            segments.add(pw.Flexible(
                flex: sw,
                child: pw.Container(color: PdfColor.fromHex('EF4444'))));
          }
          if (eb > 0) {
            segments.add(pw.Flexible(
                flex: eb,
                child: pw.Container(color: PdfColor.fromHex('DC2626'))));
          }
          if (ab > 0) {
            segments.add(pw.Flexible(
                flex: ab,
                child: pw.Container(color: PdfColor.fromHex('991B1B'))));
          }
          if (remaining > 0) {
            segments.add(pw.Flexible(
                flex: remaining,
                child: pw.Container(color: PdfColor.fromHex('F3F4F6'))));
          }

          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.SizedBox(
                    width: 110,
                    child: pw.Text(displayName,
                        style: pw.TextStyle(
                          font: (emp['isManager'] as bool) ? bold : regular,
                          fontSize: 8,
                          color: PdfColor.fromHex('374151'),
                        )),
                  ),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Container(
                      height: 13,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('F3F4F6'),
                        borderRadius: pw.BorderRadius.circular(2),
                      ),
                      child: total == 0
                          ? pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 6),
                              child: pw.Align(
                                alignment: pw.Alignment.centerLeft,
                                child: pw.Text('Bersih',
                                    style: pw.TextStyle(
                                        font: regular,
                                        fontSize: 7,
                                        color: PdfColor.fromHex('059669'))),
                              ),
                            )
                          : pw.Row(children: segments),
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.SizedBox(
                    width: 20,
                    child: pw.Text(total == 0 ? '-' : '$total',
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: total == 0
                              ? PdfColor.fromHex('059669')
                              : PdfColor.fromHex('B91C1C'),
                        ),
                        textAlign: pw.TextAlign.right),
                  ),
                ]),
          );
        }),
        pw.Spacer(),
        pw.Text(
          'Dibuat pada: ${_formatTimestamp(_nowProvider())}',
          style: pw.TextStyle(
              font: regular, fontSize: 8, color: PdfColor.fromHex('9CA3AF')),
        ),
      ],
    );
  }

  pw.Widget _buildAnalysisLegend(
      String label, String colorHex, pw.Font regular) {
    return pw.Row(children: [
      pw.Container(
          width: 10,
          height: 10,
          decoration: pw.BoxDecoration(
              color: PdfColor.fromHex(colorHex),
              borderRadius: pw.BorderRadius.circular(2))),
      pw.SizedBox(width: 4),
      pw.Text(label,
          style: pw.TextStyle(
              font: regular, fontSize: 8, color: PdfColor.fromHex('374151'))),
    ]);
  }

  pw.Widget _buildKepalaGeraiSection({
    required PayrollPdfDocumentPreview preview,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    final managerEmployees = <Map<String, dynamic>>[];

    for (final page in preview.matrixPages) {
      for (final row in page.rows) {
        // Check if employee has Manager Exempt (ME) tag in any cell
        final hasManagerExempt = row.cells.any((cell) =>
            cell.secondaryTags.contains('ME') ||
            cell.secondaryDescriptions
                .any((desc) => desc.contains('Manager Exempt')));

        if (hasManagerExempt) {
          final presentDays = row.cells
              .where((cell) =>
                  cell.primaryLabel.isNotEmpty &&
                  !cell.primaryLabel.contains('Tidak Hadir') &&
                  !cell.primaryLabel.contains('Belum'))
              .length;

          final absentDays = row.cells
              .where((cell) => cell.primaryLabel.contains('Tidak Hadir'))
              .length;

          managerEmployees.add({
            'name': row.employeeName,
            'contract': row.employmentContract,
            'presentDays': presentDays,
            'absentDays': absentDays,
          });
        }
      }
    }

    if (managerEmployees.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('F8FAFC'),
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromHex('CBD5E1')),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'KEPALA GERAI / STORE MANAGER',
            style: pw.TextStyle(
              font: bold,
              fontSize: 11,
              color: PdfColor.fromHex('111827'),
            ),
          ),
          pw.SizedBox(height: 8),
          ...managerEmployees.map((manager) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  '[Kepala Gerai] ${manager['name']} (${manager['contract']}) - Hadir: ${manager['presentDays']} hari, Tidak hadir: ${manager['absentDays']} hari (tanpa penalti)',
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 8,
                    color: PdfColor.fromHex('334155'),
                  ),
                ),
              )),
          if (managerEmployees.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Catatan: Manager exempt tidak dikenakan penalti untuk keterlambatan atau deficit jam kerja.',
              style: pw.TextStyle(
                font: regular,
                fontSize: 7,
                color: PdfColor.fromHex('64748B'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _countWorkDays(List<PayrollPdfMatrixCellPreview> cells) {
    return cells
        .where((cell) =>
            cell.primaryLabel.isNotEmpty &&
            !cell.primaryLabel.contains('Libur') &&
            !cell.primaryLabel.contains('Cuti') &&
            !cell.primaryLabel.contains('Izin'))
        .length;
  }

  double _extractTotalMinutes(
      List<PayrollPdfMatrixCellPreview> cells, String type) {
    double total = 0;
    for (final cell in cells) {
      for (final desc in cell.secondaryDescriptions) {
        if (desc.contains(type)) {
          final minutes = _parseMinutesFromDescription(desc);
          if (minutes != null) total += minutes;
        }
      }
    }
    return total;
  }

  double? _parseMinutesFromDescription(String description) {
    // Parse formats like "Kurang Jam 1j 30m" or "Break Lebih 45m"
    final regex = RegExp(r'(\d+)j\s*(\d+)m|(\d+)m');
    final match = regex.firstMatch(description);
    if (match != null) {
      if (match.group(1) != null && match.group(2) != null) {
        // Format: "1j 30m"
        final hours = int.parse(match.group(1)!);
        final minutes = int.parse(match.group(2)!);
        return (hours * 60 + minutes).toDouble();
      } else if (match.group(3) != null) {
        // Format: "45m"
        return int.parse(match.group(3)!).toDouble();
      }
    }
    return null;
  }

  String _formatMinutesToHours(double minutes) {
    if (minutes <= 0) return '0m';
    final totalMinutes = minutes.round();
    if (totalMinutes < 60) return '${totalMinutes}m';
    final hours = totalMinutes ~/ 60;
    final remainder = totalMinutes % 60;
    if (remainder == 0) return '${hours}j';
    return '${hours}j ${remainder}m';
  }

  pw.Widget _buildLogo(Uint8List? logoBytes, {double size = 34}) {
    if (logoBytes != null) {
      return pw.ClipRRect(
        horizontalRadius: 8,
        verticalRadius: 8,
        child: pw.Image(
          pw.MemoryImage(logoBytes),
          width: size,
          height: size,
          fit: pw.BoxFit.contain,
        ),
      );
    }

    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('DC2626'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Center(
        child: pw.Text(
          'E',
          style: pw.TextStyle(
            fontSize: size * 0.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ),
    );
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
    final outletSlug = outletName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final resolvedOutletSlug = outletSlug.isEmpty ? 'outlet' : outletSlug;
    return 'rekap_payroll_pdf_${resolvedOutletSlug}_${_formatDateToken(startDate)}_${_formatDateToken(endDate)}.pdf';
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _formatDateToken(DateTime date) {
    return '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
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

  String _formatTimestamp(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')} '
        '${_monthName(value.month)} ${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String _monthName(int month) {
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
    return months[month];
  }
}
