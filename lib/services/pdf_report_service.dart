import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/daily_summary.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Internal record types
// ─────────────────────────────────────────────────────────────────────────────

typedef _ReportStats = ({
  int totalHadir,
  double attendanceRate,
  String avgWorkStr,
  int totalSakit,
  int totalScan,
  List<_EmployeeRow> employeeRows,
});

typedef _EmployeeRow = ({
  String name,
  int hadirCount,
  String avgMasukStr,
  String avgPulangStr,
  String totalKerjaStr,
  int sakitCount,
});

// ─────────────────────────────────────────────────────────────────────────────
// PdfReportService
// ─────────────────────────────────────────────────────────────────────────────

/// Service for generating branded attendance PDF reports.
class PdfReportService {
  static Future<void> generateAttendanceReport({
    required List<DailySummary> summaries,
    required DateTime startDate,
    required DateTime endDate,
    required String outletName,
  }) async {
    final pdf = pw.Document();
    final regular = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();

    final stats = _computeStats(summaries);

    // Page 1: Summary
    pdf.addPage(_buildSummaryPage(stats, startDate, endDate, outletName, regular, bold));

    // Page 2+: Employee table chunks (25 rows per page)
    final chunks = _chunkEmployeeRows(stats.employeeRows, 25);
    for (int i = 0; i < chunks.length; i++) {
      pdf.addPage(_buildTablePage(chunks[i], i + 1, regular, bold));
    }

    final dir = await getTemporaryDirectory();
    final fileName =
        'laporan_absensi_${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Laporan Absensi Enakko - $outletName',
    );
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  @visibleForTesting
  static _ReportStats computeStatsForTest(List<DailySummary> summaries) =>
      _computeStats(summaries);

  @visibleForTesting
  static String avgTimeOfDayStrForTest(List<DateTime> times) =>
      _avgTimeOfDayStr(times);

  @visibleForTesting
  static List<List<_EmployeeRow>> chunkEmployeeRowsForTest(
          List<_EmployeeRow> rows, int pageSize) =>
      _chunkEmployeeRows(rows, pageSize);

  static _ReportStats _computeStats(List<DailySummary> summaries) {
    if (summaries.isEmpty) {
      return (
        totalHadir: 0,
        attendanceRate: 0.0,
        avgWorkStr: '0j 0m',
        totalSakit: 0,
        totalScan: 0,
        employeeRows: [],
      );
    }

    // Group by employee id
    final Map<String, List<DailySummary>> byEmployee = {};
    for (final s in summaries) {
      final key = s.employee?.id ?? 'unknown';
      byEmployee.putIfAbsent(key, () => []).add(s);
    }

    // Global aggregates
    int totalHadir = 0;
    int totalSakit = 0;
    int totalScan = 0;
    Duration totalWorkDuration = Duration.zero;

    final Set<String> distinctDates = {};
    final Set<String> distinctEmployees = {};

    for (final s in summaries) {
      distinctDates.add(s.dateLabel);
      final empId = s.employee?.id ?? 'unknown';
      distinctEmployees.add(empId);

      totalScan += s.scanCount;

      if (s.status == DailySummaryStatus.normal && s.firstMasuk != null) {
        totalHadir++;
        if (s.workDuration != null) {
          totalWorkDuration += s.workDuration!;
        }
      }
      if (s.status == DailySummaryStatus.sakit) {
        totalSakit++;
      }
    }

    final totalDays = distinctDates.length;
    final totalEmployees = distinctEmployees.length;

    double attendanceRate = 0.0;
    if (totalEmployees > 0 && totalDays > 0) {
      attendanceRate = (totalHadir / (totalDays * totalEmployees)) * 100;
    }

    String avgWorkStr = '0j 0m';
    if (totalHadir > 0) {
      final avgDuration = Duration(
          microseconds: totalWorkDuration.inMicroseconds ~/ totalHadir);
      final hours = avgDuration.inHours;
      final minutes = avgDuration.inMinutes % 60;
      avgWorkStr = '${hours}j ${minutes}m';
    }

    // Per-employee rows
    final List<_EmployeeRow> employeeRows = [];
    for (final entry in byEmployee.entries) {
      final empSummaries = entry.value;
      final name = empSummaries.first.employee?.name ?? 'Tidak Diketahui';

      final hadirDays = empSummaries
          .where((s) =>
              s.status == DailySummaryStatus.normal && s.firstMasuk != null)
          .toList();
      final sakitDays = empSummaries
          .where((s) => s.status == DailySummaryStatus.sakit)
          .toList();

      final avgMasukStr = _avgTimeOfDayStr(
          hadirDays.map((s) => s.firstMasuk!).toList());
      final avgPulangStr = _avgTimeOfDayStr(
          hadirDays
              .where((s) => s.lastPulang != null)
              .map((s) => s.lastPulang!)
              .toList());

      Duration totalKerja = Duration.zero;
      for (final s in hadirDays) {
        if (s.workDuration != null) {
          totalKerja += s.workDuration!;
        }
      }
      final kerjaHours = totalKerja.inHours;
      final kerjaMinutes = totalKerja.inMinutes % 60;
      final totalKerjaStr = '${kerjaHours}j ${kerjaMinutes}m';

      employeeRows.add((
        name: name,
        hadirCount: hadirDays.length,
        avgMasukStr: avgMasukStr,
        avgPulangStr: avgPulangStr,
        totalKerjaStr: totalKerjaStr,
        sakitCount: sakitDays.length,
      ));
    }

    // Sort alphabetically by name (case-insensitive)
    employeeRows.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return (
      totalHadir: totalHadir,
      attendanceRate: attendanceRate,
      avgWorkStr: avgWorkStr,
      totalSakit: totalSakit,
      totalScan: totalScan,
      employeeRows: employeeRows,
    );
  }

  static String _avgTimeOfDayStr(List<DateTime> times) {
    if (times.isEmpty) return '--:--';
    final totalMinutes =
        times.fold(0, (sum, dt) => sum + dt.hour * 60 + dt.minute);
    final avg = totalMinutes ~/ times.length;
    final h = (avg ~/ 60).toString().padLeft(2, '0');
    final m = (avg % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static List<List<_EmployeeRow>> _chunkEmployeeRows(
      List<_EmployeeRow> rows, int pageSize) {
    if (rows.isEmpty) return [];
    final List<List<_EmployeeRow>> chunks = [];
    for (int i = 0; i < rows.length; i += pageSize) {
      chunks.add(rows.sublist(i,
          i + pageSize < rows.length ? i + pageSize : rows.length));
    }
    return chunks;
  }

  // ── Page builders ───────────────────────────────────────────────────────────

  static pw.Page _buildSummaryPage(
    _ReportStats stats,
    DateTime start,
    DateTime end,
    String outletName,
    pw.Font regular,
    pw.Font bold,
  ) {
    final range =
        '${DateFormat('dd MMM yyyy').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}';

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(
              children: [
                pw.Container(
                  width: 50,
                  height: 50,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('DC2626'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'E',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        font: bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Ayam Guling Enakko',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        font: bold,
                        color: PdfColor.fromHex('DC2626'),
                      ),
                    ),
                    pw.Text(
                      'Laporan Absensi',
                      style: pw.TextStyle(
                        fontSize: 14,
                        font: regular,
                        color: PdfColor.fromHex('6B7280'),
                      ),
                    ),
                    pw.Text(
                      '$range | Outlet: $outletName',
                      style: pw.TextStyle(
                        fontSize: 11,
                        font: regular,
                        color: PdfColor.fromHex('9CA3AF'),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColor.fromHex('E5E7EB'), thickness: 0.5),
            pw.SizedBox(height: 16),

            // 2x2 insight card grid
            pw.Row(
              children: [
                pw.Expanded(
                  child: _insightCard(
                    'Total Hadir',
                    '${stats.totalHadir} hari',
                    PdfColor.fromHex('16A34A'),
                    bold,
                    regular,
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _insightCard(
                    'Tingkat Hadir',
                    '${stats.attendanceRate.toStringAsFixed(1)}%',
                    PdfColor.fromHex('16A34A'),
                    bold,
                    regular,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                pw.Expanded(
                  child: _insightCard(
                    'Rata-rata Jam Kerja',
                    stats.avgWorkStr,
                    PdfColor.fromHex('1D4ED8'),
                    bold,
                    regular,
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _insightCard(
                    'Tidak Hadir',
                    '${stats.totalSakit} kali',
                    PdfColor.fromHex('DC2626'),
                    bold,
                    regular,
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 12),
            pw.Text(
              'Total scan: ${stats.totalScan}',
              style: pw.TextStyle(
                  font: regular,
                  fontSize: 9,
                  color: PdfColor.fromHex('6B7280')),
            ),

            pw.Spacer(),

            // Footer
            pw.Text(
              'Dibuat pada: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(
                font: regular,
                fontSize: 8,
                color: PdfColor.fromHex('9CA3AF'),
              ),
            ),
          ],
        );
      },
    );
  }

  static pw.Page _buildTablePage(
    List<_EmployeeRow> rows,
    int pageNum,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Title
            pw.Row(
              children: [
                pw.Text(
                  'Detail Per Karyawan',
                  style: pw.TextStyle(font: bold, fontSize: 14),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  '(halaman $pageNum)',
                  style: pw.TextStyle(
                      font: regular,
                      fontSize: 10,
                      color: PdfColor.fromHex('6B7280')),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Table
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColor.fromHex('E5E7EB'), width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(20), // No
                1: const pw.FixedColumnWidth(110), // Nama
                2: const pw.FixedColumnWidth(40), // Hadir
                3: const pw.FixedColumnWidth(50), // Avg Masuk
                4: const pw.FixedColumnWidth(50), // Avg Pulang
                5: const pw.FixedColumnWidth(55), // Total Jam
                6: const pw.FixedColumnWidth(40), // Sakit
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration:
                      pw.BoxDecoration(color: PdfColor.fromHex('FEE2E2')),
                  children: [
                    'No',
                    'Nama',
                    'Hadir',
                    'Avg Masuk',
                    'Avg Pulang',
                    'Total Jam',
                    'Sakit'
                  ]
                      .map((h) => _cell(h, bold, isHeader: true))
                      .toList(),
                ),
                // Data rows
                ...rows.asMap().entries.map((entry) {
                  final i = entry.key;
                  final row = entry.value;
                  final bgColor = i.isEven
                      ? PdfColors.white
                      : PdfColor.fromHex('F9FAFB');
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bgColor),
                    children: [
                      _cell('${i + 1}', regular),
                      _cell(row.name, regular,
                          align: pw.TextAlign.left),
                      _cell('${row.hadirCount}', regular),
                      _cell(row.avgMasukStr, regular),
                      _cell(row.avgPulangStr, regular),
                      _cell(row.totalKerjaStr, regular),
                      _cell('${row.sakitCount}', regular),
                    ],
                  );
                }),
              ],
            ),

            pw.Spacer(),

            // Footer: page number
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Hal. $pageNum',
                style: pw.TextStyle(
                    font: regular,
                    fontSize: 8,
                    color: PdfColor.fromHex('9CA3AF')),
              ),
            ),
          ],
        );
      },
    );
  }

  static pw.Widget _insightCard(
    String label,
    String value,
    PdfColor accent,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('E5E7EB'), width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
                font: regular,
                fontSize: 9,
                color: PdfColor.fromHex('6B7280')),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(font: bold, fontSize: 18, color: accent),
          ),
        ],
      ),
    );
  }

  static pw.Widget _cell(
    String text,
    pw.Font font, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 9 : 8,
          color: isHeader
              ? PdfColor.fromHex('374151')
              : PdfColor.fromHex('374151'),
        ),
        textAlign: align,
      ),
    );
  }
}
