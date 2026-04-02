import 'dart:io';
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
  final String fillColorHex;
  final String textColorHex;

  const PayrollPdfMatrixCellPreview({
    required this.primaryLabel,
    required this.secondaryTags,
    required this.fillColorHex,
    required this.textColorHex,
  });

  factory PayrollPdfMatrixCellPreview.fromCell(PayrollMatrixDayCell cell) {
    return PayrollPdfMatrixCellPreview(
      primaryLabel: cell.primaryLabel,
      secondaryTags: List<String>.from(cell.secondaryTags),
      fillColorHex: cell.fillColorHex,
      textColorHex: cell.textColorHex,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'primaryLabel': primaryLabel,
      'secondaryTags': secondaryTags,
      'fillColorHex': fillColorHex,
      'textColorHex': textColorHex,
    };
  }
}

class PayrollPdfMatrixRowPreview {
  final String employeeName;
  final String employmentContract;
  final List<PayrollPdfMatrixCellPreview> cells;
  final List<int> summaryValues;

  const PayrollPdfMatrixRowPreview({
    required this.employeeName,
    required this.employmentContract,
    required this.cells,
    required this.summaryValues,
  });

  PayrollPdfMatrixRowPreview slice({
    required int start,
    required int end,
  }) {
    return PayrollPdfMatrixRowPreview(
      employeeName: employeeName,
      employmentContract: employmentContract,
      cells: cells.sublist(start, end),
      summaryValues: summaryValues,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'employeeName': employeeName,
      'employmentContract': employmentContract,
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
      'dates': dates.map((date) => date.toIso8601String()).toList(growable: false),
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
  final bool isCompatibilityMode;
  final String? compatibilityTitle;
  final String? compatibilityBody;
  final List<PayrollPdfSummaryMetricPreview> summaryMetrics;
  final List<String> legendTags;
  final List<PayrollPdfMatrixPagePreview> matrixPages;

  const PayrollPdfDocumentPreview({
    required this.title,
    required this.outletName,
    required this.periodLabel,
    required this.isCompatibilityMode,
    required this.compatibilityTitle,
    required this.compatibilityBody,
    required this.summaryMetrics,
    required this.legendTags,
    required this.matrixPages,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'outletName': outletName,
      'periodLabel': periodLabel,
      'isCompatibilityMode': isCompatibilityMode,
      'compatibilityTitle': compatibilityTitle,
      'compatibilityBody': compatibilityBody,
      'summaryMetrics': summaryMetrics
          .map((metric) => metric.toJson())
          .toList(growable: false),
      'legendTags': legendTags,
      'matrixPages': matrixPages.map((page) => page.toJson()).toList(growable: false),
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

  static const String reportTitle = 'Rekap Payroll PDF';
  static const String compatibilityModeTitle = 'Mode kompatibilitas aktif';
  static const String compatibilityModeBody =
      'Sebagian hari payroll dihitung dari log absensi dan kontrak karena jadwal belum tersedia.';
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
    required bool isCompatibilityMode,
  }) async {
    final bytes = await buildPayrollPdfBytes(
      dataset: dataset,
      outletName: outletName,
      startDate: startDate,
      endDate: endDate,
      isCompatibilityMode: isCompatibilityMode,
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
    required bool isCompatibilityMode,
  }) async {
    final preview = buildPreview(
      dataset: dataset,
      outletName: outletName,
      startDate: startDate,
      endDate: endDate,
      isCompatibilityMode: isCompatibilityMode,
    );
    return _buildDocument(preview);
  }

  @visibleForTesting
  PayrollPdfDocumentPreview buildPreview({
    required PayrollMatrixDataset dataset,
    required String outletName,
    required DateTime startDate,
    required DateTime endDate,
    required bool isCompatibilityMode,
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
      isCompatibilityMode: isCompatibilityMode,
      compatibilityTitle:
          isCompatibilityMode ? compatibilityModeTitle : null,
      compatibilityBody:
          isCompatibilityMode ? compatibilityModeBody : null,
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

    for (var index = 0; index < preview.matrixPages.length; index++) {
      final page = preview.matrixPages[index];
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (context) => _buildMatrixPage(
            preview: preview,
            page: page,
            pageIndex: index + 1,
            pageCount: preview.matrixPages.length,
            regular: regular,
            bold: bold,
          ),
        ),
      );
    }

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
        if (preview.isCompatibilityMode) ...[
          pw.SizedBox(height: 14),
          _buildCompatibilityBanner(
            title: preview.compatibilityTitle!,
            body: preview.compatibilityBody!,
            regular: regular,
            bold: bold,
          ),
        ],
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
              .map((tag) => _buildLegendChip(tag: tag, regular: regular, bold: bold))
              .toList(growable: false),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Warna matrix mengikuti semantik payroll recap yang sama dengan spreadsheet.',
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

  pw.Widget _buildCompatibilityBanner({
    required String title,
    required String body,
    required pw.Font regular,
    required pw.Font bold,
  }) {
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
            title,
            style: pw.TextStyle(
              font: bold,
              fontSize: 11,
              color: PdfColor.fromHex('111827'),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            body,
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
        label: PayrollMatrixSemantics.managerExemptTag,
        fillColorHex: '#F8FAFC',
        textColorHex: '#334155',
      ),
    );
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex(metric.fillColorHex),
        borderRadius: pw.BorderRadius.circular(999),
        border: pw.Border.all(color: PdfColor.fromHex('E5E7EB')),
      ),
      child: pw.Text(
        tag,
        style: pw.TextStyle(
          font: tag == PayrollMatrixSemantics.managerExemptTag ? regular : bold,
          fontSize: 9,
          color: PdfColor.fromHex(metric.textColorHex),
        ),
      ),
    );
  }

  pw.Widget _buildMatrixPage({
    required PayrollPdfDocumentPreview preview,
    required PayrollPdfMatrixPagePreview page,
    required int pageIndex,
    required int pageCount,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(86),
      1: const pw.FixedColumnWidth(52),
    };
    for (var index = 0; index < page.dates.length; index++) {
      columnWidths[index + 2] = const pw.FixedColumnWidth(44);
    }
    for (var index = 0; index < PayrollMatrixRow.summaryLabels.length; index++) {
      columnWidths[page.dates.length + 2 + index] = const pw.FixedColumnWidth(38);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  preview.title,
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 13,
                    color: PdfColor.fromHex('111827'),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${preview.outletName} - ${preview.periodLabel}',
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 9,
                    color: PdfColor.fromHex('6B7280'),
                  ),
                ),
              ],
            ),
            pw.Text(
              'Hal. $pageIndex / $pageCount',
              style: pw.TextStyle(
                font: regular,
                fontSize: 8,
                color: PdfColor.fromHex('9CA3AF'),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(
            color: PdfColor.fromHex('E5E7EB'),
            width: 0.5,
          ),
          columnWidths: columnWidths,
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('F9FAFB'),
              ),
              children: [
                _buildHeaderCell('Karyawan', bold),
                _buildHeaderCell('Kontrak', bold),
                ...page.dates.map(
                  (date) => _buildHeaderCell(_formatDateHeader(date), bold),
                ),
                ...PayrollMatrixRow.summaryLabels.map(
                  (label) => _buildHeaderCell(label, bold),
                ),
              ],
            ),
            ...page.rows.map(
              (row) => pw.TableRow(
                children: [
                  _buildIdentityCell(
                    row.employeeName,
                    regular,
                    align: pw.TextAlign.left,
                  ),
                  _buildIdentityCell(
                    row.employmentContract,
                    regular,
                  ),
                  ...row.cells.map(
                    (cell) => _buildMatrixCell(
                      cell: cell,
                      regular: regular,
                      bold: bold,
                    ),
                  ),
                  ...row.summaryValues.map(
                    (value) => _buildSummaryValueCell(value, regular),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (page.dates.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            'Rentang halaman: ${_formatDateLabel(page.dates.first)} - ${_formatDateLabel(page.dates.last)}',
            style: pw.TextStyle(
              font: regular,
              fontSize: 8,
              color: PdfColor.fromHex('9CA3AF'),
            ),
          ),
        ],
        pw.SizedBox(height: 4),
        pw.Text(
          'Kolom ringkasan di kanan mengikuti urutan payroll matrix: Terlambat, Kurang Jam, Break Lebih, Tidak Hadir, Lembur.',
          style: pw.TextStyle(
            font: regular,
            fontSize: 8,
            color: PdfColor.fromHex('9CA3AF'),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildHeaderCell(String text, pw.Font bold) {
    return pw.Container(
      height: 34,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: bold,
          fontSize: 8,
          color: PdfColor.fromHex('111827'),
        ),
      ),
    );
  }

  pw.Widget _buildIdentityCell(
    String text,
    pw.Font regular, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Container(
      height: 40,
      alignment: align == pw.TextAlign.left
          ? pw.Alignment.centerLeft
          : pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: regular,
          fontSize: 8,
          color: PdfColor.fromHex('111827'),
        ),
      ),
    );
  }

  pw.Widget _buildMatrixCell({
    required PayrollPdfMatrixCellPreview cell,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    return pw.Container(
      height: 40,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      color: PdfColor.fromHex(cell.fillColorHex),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            cell.primaryLabel,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: bold,
              fontSize: 6.8,
              color: PdfColor.fromHex(cell.textColorHex),
            ),
          ),
          if (cell.secondaryTags.isNotEmpty) ...[
            pw.SizedBox(height: 1),
            pw.Text(
              cell.secondaryTags.join(' '),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: regular,
                fontSize: 6.3,
                color: PdfColor.fromHex(cell.textColorHex),
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildSummaryValueCell(int value, pw.Font regular) {
    return pw.Container(
      height: 40,
      alignment: pw.Alignment.center,
      color: PdfColor.fromHex('#FFFFFF'),
      child: pw.Text(
        '$value',
        style: pw.TextStyle(
          font: regular,
          fontSize: 8,
          color: PdfColor.fromHex('111827'),
        ),
      ),
    );
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
