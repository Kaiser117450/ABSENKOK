import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/employee.dart';
import '../models/shift_schedule.dart';

class AttendancePerScanPdfRow {
  final String nama;
  final String jabatan;
  final String outlet;
  final String jenis;
  final String waktu;
  final String latitude;
  final String longitude;
  final String catatan;

  const AttendancePerScanPdfRow({
    required this.nama,
    required this.jabatan,
    required this.outlet,
    required this.jenis,
    required this.waktu,
    required this.latitude,
    required this.longitude,
    required this.catatan,
  });
}

class AttendanceDailyPdfRow {
  final String tanggal;
  final String nama;
  final String outlet;
  final String status;
  final String masuk;
  final String pulang;
  final String kerja;
  final String istirahat;
  final String jumlahScan;
  final String catatan;

  const AttendanceDailyPdfRow({
    required this.tanggal,
    required this.nama,
    required this.outlet,
    required this.status,
    required this.masuk,
    required this.pulang,
    required this.kerja,
    required this.istirahat,
    required this.jumlahScan,
    required this.catatan,
  });
}

class AttendanceDailyPdfStats {
  final int totalKaryawan;
  final int totalMasuk;
  final int totalTidakHadir;
  final int totalBelumPulang;
  final int totalScan;
  final List<AttendanceDailyPdfEmployeeRow> employeeRows;

  const AttendanceDailyPdfStats({
    required this.totalKaryawan,
    required this.totalMasuk,
    required this.totalTidakHadir,
    required this.totalBelumPulang,
    required this.totalScan,
    required this.employeeRows,
  });
}

class AttendanceDailyPdfEmployeeRow {
  final String nama;
  final int masukCount;
  final int tidakHadirCount;
  final int belumPulangCount;
  final String avgMasukStr;
  final String avgPulangStr;
  final String totalKerjaStr;

  const AttendanceDailyPdfEmployeeRow({
    required this.nama,
    required this.masukCount,
    required this.tidakHadirCount,
    required this.belumPulangCount,
    required this.avgMasukStr,
    required this.avgPulangStr,
    required this.totalKerjaStr,
  });
}

/// Service untuk generate PDF jadwal shift
class PdfService {
  /// Load logo from assets, returns null if not available
  static Future<Uint8List?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/logo_enakko.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> loadBrandLogo() => _loadLogo();

  /// Build logo widget — image if available, red "E" box fallback
  static pw.Widget _buildLogo(Uint8List? logoBytes, {double size = 50}) {
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
            fontSize: size * 0.56,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ),
    );
  }

  static Future<void> generateAndShareSchedule({
    required OutletSchedule schedule,
    required List<Employee> employees,
    required String outletName,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy');
    final logoBytes = await _loadLogo();

    final ttf = pw.Font.helvetica();
    final ttfBold = pw.Font.helveticaBold();

    final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final daysCount =
        schedule.endDate.difference(schedule.startDate).inDays + 1;

    // Scale day column width based on count — narrower when many days
    final double dayColWidth = daysCount <= 7
        ? 60
        : daysCount <= 14
            ? 48
            : 38;

    final createdAt = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Dibuat pada: $createdAt',
              style: pw.TextStyle(
                font: ttf,
                fontSize: 8,
                color: PdfColor.fromHex('9CA3AF'),
              ),
            ),
            pw.Text(
              'Hal. ${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(
                font: ttf,
                fontSize: 8,
                color: PdfColor.fromHex('9CA3AF'),
              ),
            ),
          ],
        ),
        build: (context) {
          return [
            // Header dengan Logo
            pw.Row(
              children: [
                _buildLogo(logoBytes, size: 50),
                pw.SizedBox(width: 16),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Ayam Guling Enakko',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        font: ttfBold,
                        color: PdfColor.fromHex('DC2626'),
                      ),
                    ),
                    pw.Text(
                      'Jadwal Shift - $outletName',
                      style: pw.TextStyle(
                        fontSize: 14,
                        font: ttf,
                        color: PdfColor.fromHex('6B7280'),
                      ),
                    ),
                    pw.Text(
                      'Periode: ${dateFormat.format(schedule.startDate)} - ${dateFormat.format(schedule.endDate)}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        font: ttf,
                        color: PdfColor.fromHex('9CA3AF'),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // Legend
            pw.Row(
              children: [
                _buildLegendChip('Pagi', PdfColor.fromHex('3B82F6'), ttf),
                pw.SizedBox(width: 12),
                _buildLegendChip('Siang', PdfColor.fromHex('F59E0B'), ttf),
                pw.SizedBox(width: 12),
                _buildLegendChip('Sore', PdfColor.fromHex('F97316'), ttf),
                pw.SizedBox(width: 12),
                _buildLegendChip('Libur', PdfColor.fromHex('DC2626'), ttf),
                pw.SizedBox(width: 12),
                _buildLegendChip('Sakit', PdfColor.fromHex('991B1B'), ttf),
                pw.SizedBox(width: 12),
                _buildLegendChip('Izin', PdfColor.fromHex('1E40AF'), ttf),
              ],
            ),

            pw.SizedBox(height: 16),

            // Schedule Table
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColor.fromHex('E5E7EB'),
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5), // Employee name — flex to fill remaining space
                for (int i = 1; i <= daysCount; i++)
                  i: pw.FixedColumnWidth(dayColWidth),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('FEE2E2'),
                  ),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'KARYAWAN',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          font: ttfBold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    ...List.generate(daysCount, (i) {
                      final date = schedule.startDate.add(Duration(days: i));
                      return pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              days[date.weekday % 7],
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: ttfBold,
                                fontSize: 9,
                              ),
                            ),
                            pw.Text(
                              '${date.day}',
                              style: pw.TextStyle(
                                font: ttf,
                                fontSize: 8,
                                color: PdfColor.fromHex('6B7280'),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),

                // Data rows
                ...employees.map((emp) {
                  final employeeEntries = schedule.entries
                      .where((e) => e.employeeId == emp.id)
                      .toList();

                  final String? commonRole = _getMostCommonRole(employeeEntries);

                  return pw.TableRow(
                    children: [
                      // Employee name cell
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('F9FAFB'),
                        ),
                        child: commonRole != null && commonRole.isNotEmpty
                            ? pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  pw.Text(
                                    emp.name,
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      font: ttfBold,
                                      fontSize: 8,
                                    ),
                                    maxLines: 2,
                                    overflow: pw.TextOverflow.clip,
                                  ),
                                  pw.SizedBox(height: 1),
                                  pw.Text(
                                    commonRole,
                                    style: pw.TextStyle(
                                      font: ttf,
                                      fontSize: 6,
                                      color: PdfColor.fromHex('6B7280'),
                                    ),
                                  ),
                                ],
                              )
                            : pw.Text(
                                emp.name,
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  font: ttfBold,
                                  fontSize: 8,
                                ),
                                maxLines: 2,
                                overflow: pw.TextOverflow.clip,
                              ),
                      ),

                      // Day cells
                      ...List.generate(daysCount, (dayIndex) {
                        final date =
                            schedule.startDate.add(Duration(days: dayIndex));

                        final entries = schedule.entries
                            .where((e) =>
                                e.employeeId == emp.id &&
                                e.date.year == date.year &&
                                e.date.month == date.month &&
                                e.date.day == date.day)
                            .toList();

                        if (entries.isEmpty) {
                          return pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              '-',
                              style: pw.TextStyle(font: ttf, fontSize: 8),
                              textAlign: pw.TextAlign.center,
                            ),
                          );
                        }

                        final entry = entries.first;
                        final shiftColors =
                            _getShiftColors(entry.shift.name, entry.status);

                        return pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          color: shiftColors.background,
                          child: pw.Center(
                            child: pw.Text(
                              _getShiftLabel(entry),
                              style: pw.TextStyle(
                                font: ttf,
                                fontSize: 8,
                                color: shiftColors.text,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    // Save PDF
    final directory = await getTemporaryDirectory();
    final fileName =
        'jadwal_${outletName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(schedule.startDate)}.pdf';
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    // Share PDF
    await Share.shareXFiles(
      [XFile(filePath)],
      text:
          'Jadwal Shift $outletName - ${dateFormat.format(schedule.startDate)} sampai ${dateFormat.format(schedule.endDate)}',
    );
  }

  static Future<void> generateAndShareAttendancePerScanPdf({
    required List<AttendancePerScanPdfRow> rows,
    required DateTime startDate,
    required DateTime endDate,
    required String outletName,
  }) async {
    final pdf = pw.Document();
    final ttf = pw.Font.helvetica();
    final ttfBold = pw.Font.helveticaBold();
    final logoBytes = await _loadLogo();
    final range =
        '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          _buildAttendanceHeader(
            title: 'Laporan Absensi - Per Scan',
            outletName: outletName,
            dateRange: range,
            rowCount: rows.length,
            font: ttf,
            fontBold: ttfBold,
            logoBytes: logoBytes,
          ),
          pw.SizedBox(height: 12),
          if (rows.isEmpty)
            pw.Text('Tidak ada data pada rentang ini.',
                style: pw.TextStyle(font: ttf))
          else
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColor.fromHex('E5E7EB'), width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2), // Nama
                1: const pw.FlexColumnWidth(1.5), // Jabatan
                2: const pw.FlexColumnWidth(1.5), // Outlet
                3: const pw.FixedColumnWidth(52), // Jenis
                4: const pw.FixedColumnWidth(90), // Waktu
                5: const pw.FixedColumnWidth(52), // Lat
                6: const pw.FixedColumnWidth(52), // Lng
                7: const pw.FlexColumnWidth(2), // Catatan
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration:
                      pw.BoxDecoration(color: PdfColor.fromHex('DC2626')),
                  children: [
                    'Nama',
                    'Jabatan',
                    'Outlet',
                    'Jenis',
                    'Waktu',
                    'Lat',
                    'Lng',
                    'Catatan'
                  ]
                      .map((h) => pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 5),
                            child: pw.Text(h,
                                style: pw.TextStyle(
                                    font: ttfBold,
                                    fontSize: 9,
                                    color: PdfColors.white)),
                          ))
                      .toList(),
                ),
                // Data rows
                ...rows.asMap().entries.map((entry) {
                  final i = entry.key;
                  final row = entry.value;
                  final isOdd = i % 2 == 1;
                  final jenisColor = _typeTextColor(row.jenis);

                  return pw.TableRow(
                    decoration: isOdd
                        ? pw.BoxDecoration(color: PdfColor.fromHex('F9FAFB'))
                        : null,
                    children: [
                      _pdfCell(row.nama, ttf),
                      _pdfCell(row.jabatan, ttf),
                      _pdfCell(row.outlet, ttf),
                      _pdfCell(row.jenis, ttfBold,
                          color: jenisColor), // Colored jenis
                      _pdfCell(row.waktu, ttf),
                      _pdfCell(row.latitude, ttf),
                      _pdfCell(row.longitude, ttf),
                      _pdfCell(row.catatan, ttf),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final fileName =
        'laporan_absensi_per_scan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: 'Laporan Absensi Per Scan - $outletName ($range)',
    );
  }

  static Future<void> generateAndShareAttendanceDailyPdf({
    required List<AttendanceDailyPdfRow> rows,
    AttendanceDailyPdfStats? stats,
    required DateTime startDate,
    required DateTime endDate,
    required String outletName,
  }) async {
    final pdf = pw.Document();
    final ttf = pw.Font.helvetica();
    final ttfBold = pw.Font.helveticaBold();
    final logoBytes = await _loadLogo();
    final range =
        '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';

    // Insert summary page first if stats provided
    if (stats != null) {
      pdf.addPage(_buildSummaryPage(
        stats: stats,
        startDate: startDate,
        endDate: endDate,
        outletName: outletName,
        font: ttf,
        fontBold: ttfBold,
        logoBytes: logoBytes,
      ));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          _buildAttendanceHeader(
            title: 'Laporan Absensi - Rekap Harian',
            outletName: outletName,
            dateRange: range,
            rowCount: rows.length,
            font: ttf,
            fontBold: ttfBold,
            logoBytes: logoBytes,
          ),
          pw.SizedBox(height: 12),
          if (rows.isEmpty)
            pw.Text('Tidak ada data pada rentang ini.',
                style: pw.TextStyle(font: ttf))
          else
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColor.fromHex('E5E7EB'), width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(58), // Tanggal
                1: const pw.FlexColumnWidth(2), // Nama
                2: const pw.FlexColumnWidth(1.5), // Outlet
                3: const pw.FixedColumnWidth(52), // Status
                4: const pw.FixedColumnWidth(38), // Masuk
                5: const pw.FixedColumnWidth(38), // Pulang
                6: const pw.FixedColumnWidth(42), // Kerja
                7: const pw.FixedColumnWidth(42), // Istirahat
                8: const pw.FixedColumnWidth(28), // Scan
                9: const pw.FlexColumnWidth(1.5), // Catatan
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration:
                      pw.BoxDecoration(color: PdfColor.fromHex('B91C1C')),
                  children: [
                    'Tanggal',
                    'Nama',
                    'Outlet',
                    'Status',
                    'Masuk',
                    'Pulang',
                    'Kerja',
                    'Istirahat',
                    'Scan',
                    'Catatan',
                  ]
                      .map((h) => pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 5),
                            child: pw.Text(h,
                                style: pw.TextStyle(
                                    font: ttfBold,
                                    fontSize: 9,
                                    color: PdfColors.white)),
                          ))
                      .toList(),
                ),
                // Data rows
                ...rows.asMap().entries.map((entry) {
                  final i = entry.key;
                  final row = entry.value;
                  final isOdd = i % 2 == 1;
                  final statusColor = _statusTextColor(row.status);

                  return pw.TableRow(
                    decoration: isOdd
                        ? pw.BoxDecoration(color: PdfColor.fromHex('F9FAFB'))
                        : null,
                    children: [
                      _pdfCell(row.tanggal, ttf),
                      _pdfCell(row.nama, ttf),
                      _pdfCell(row.outlet, ttf),
                      _pdfCell(row.status, ttfBold,
                          color: statusColor), // Colored status
                      _pdfCell(row.masuk, ttf),
                      _pdfCell(row.pulang, ttf),
                      _pdfCell(row.kerja, ttf),
                      _pdfCell(row.istirahat, ttf),
                      _pdfCell(row.jumlahScan, ttf),
                      _pdfCell(row.catatan, ttf),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final fileName =
        'laporan_absensi_rekap_harian_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: 'Laporan Rekap Harian - $outletName ($range)',
    );
  }

  static pw.Widget _buildAttendanceHeader({
    required String title,
    required String outletName,
    required String dateRange,
    required int rowCount,
    required pw.Font font,
    required pw.Font fontBold,
    Uint8List? logoBytes,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('FEF2F2'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildLogo(logoBytes, size: 34),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Ayam Guling Enakko',
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 14,
                      color: PdfColor.fromHex('B91C1C')),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  title,
                  style: pw.TextStyle(font: fontBold, fontSize: 11),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Outlet: $outletName',
                  style: pw.TextStyle(
                      font: font,
                      fontSize: 9,
                      color: PdfColor.fromHex('374151')),
                ),
                pw.Text(
                  'Periode: $dateRange',
                  style: pw.TextStyle(
                      font: font,
                      fontSize: 9,
                      color: PdfColor.fromHex('374151')),
                ),
              ],
            ),
          ),
          pw.Text(
            '$rowCount baris',
            style: pw.TextStyle(
                font: fontBold,
                fontSize: 10,
                color: PdfColor.fromHex('6B7280')),
          ),
        ],
      ),
    );
  }

  static pw.MultiPage _buildSummaryPage({
    required AttendanceDailyPdfStats stats,
    required DateTime startDate,
    required DateTime endDate,
    required String outletName,
    required pw.Font font,
    required pw.Font fontBold,
    Uint8List? logoBytes,
  }) {
    final range =
        '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';

    final createdAt = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Dibuat pada: $createdAt',
            style: pw.TextStyle(
              font: font,
              fontSize: 8,
              color: PdfColor.fromHex('9CA3AF'),
            ),
          ),
          pw.Text(
            'Hal. ${context.pageNumber}',
            style: pw.TextStyle(
              font: font,
              fontSize: 8,
              color: PdfColor.fromHex('9CA3AF'),
            ),
          ),
        ],
      ),
      build: (context) => [
        _buildAttendanceHeader(
          title: 'Laporan Absensi - Ringkasan',
          outletName: outletName,
          dateRange: range,
          rowCount: stats.totalScan,
          font: font,
          fontBold: fontBold,
          logoBytes: logoBytes,
        ),
        pw.SizedBox(height: 18),
        pw.Row(
          children: [
            pw.Expanded(
              child: _insightCard(
                'Total Karyawan',
                '${stats.totalKaryawan} orang',
                PdfColor.fromHex('0F766E'),
                font,
                fontBold,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _insightCard(
                'Total Masuk',
                '${stats.totalMasuk} kali',
                PdfColor.fromHex('16A34A'),
                font,
                fontBold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            pw.Expanded(
              child: _insightCard(
                'Tidak Hadir',
                '${stats.totalTidakHadir} kali',
                PdfColor.fromHex('DC2626'),
                font,
                fontBold,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _insightCard(
                'Belum Pulang',
                '${stats.totalBelumPulang} kali',
                PdfColor.fromHex('D97706'),
                font,
                fontBold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Ringkasan Per Karyawan',
          style: pw.TextStyle(font: fontBold, fontSize: 14),
        ),
        pw.SizedBox(height: 8),
        if (stats.employeeRows.isEmpty)
          pw.Text(
            'Tidak ada data karyawan.',
            style: pw.TextStyle(font: font, fontSize: 10),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              'No',
              'Nama',
              'Masuk',
              'Tidak Hadir',
              'Belum Pulang',
              'Avg Masuk',
              'Avg Pulang',
              'Total Kerja',
            ],
            data: stats.employeeRows
                .asMap()
                .entries
                .map((entry) => [
                      '${entry.key + 1}',
                      entry.value.nama,
                      '${entry.value.masukCount}',
                      '${entry.value.tidakHadirCount}',
                      '${entry.value.belumPulangCount}',
                      entry.value.avgMasukStr,
                      entry.value.avgPulangStr,
                      entry.value.totalKerjaStr,
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                font: fontBold, fontSize: 9, color: PdfColors.white),
            headerDecoration:
                pw.BoxDecoration(color: PdfColor.fromHex('DC2626')),
            cellStyle: pw.TextStyle(font: font, fontSize: 8.5),
            oddRowDecoration:
                pw.BoxDecoration(color: PdfColor.fromHex('F9FAFB')),
            cellAlignment: pw.Alignment.center,
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FlexColumnWidth(2.8),
              2: const pw.FixedColumnWidth(44),
              3: const pw.FixedColumnWidth(58),
              4: const pw.FixedColumnWidth(60),
              5: const pw.FixedColumnWidth(52),
              6: const pw.FixedColumnWidth(52),
              7: const pw.FixedColumnWidth(58),
            },
          ),
      ],
    );
  }

  static pw.Widget _insightCard(String label, String value, PdfColor accent,
      pw.Font font, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('E5E7EB'), width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: font, fontSize: 9, color: PdfColor.fromHex('6B7280'))),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: pw.TextStyle(font: fontBold, fontSize: 18, color: accent)),
        ],
      ),
    );
  }

  static PdfColor _statusTextColor(String status) {
    switch (status) {
      case 'Sakit':
        return PdfColor.fromHex('DC2626');
      case 'Izin':
        return PdfColor.fromHex('2563EB');
      case 'Belum Pulang':
        return PdfColor.fromHex('D97706');
      default:
        return PdfColor.fromHex('16A34A'); // Hadir = green
    }
  }

  static PdfColor _typeTextColor(String jenis) {
    switch (jenis) {
      case 'Masuk':
        return PdfColor.fromHex('16A34A');
      case 'Istirahat':
        return PdfColor.fromHex('D97706');
      case 'Pulang':
        return PdfColor.fromHex('6B7280');
      case 'Kembali':
        return PdfColor.fromHex('0891B2');
      case 'Sakit':
        return PdfColor.fromHex('DC2626');
      case 'Izin':
        return PdfColor.fromHex('2563EB');
      default:
        return PdfColor.fromHex('374151');
    }
  }

  static pw.Widget _pdfCell(String text, pw.Font font, {PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            font: font,
            fontSize: 8,
            color: color ?? PdfColor.fromHex('374151')),
      ),
    );
  }

  static pw.Widget _buildLegendChip(
      String label, PdfColor color, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static ({PdfColor background, PdfColor text}) _getShiftColors(
      String shiftName, ScheduleStatus? status) {
    // Priority: Sakit/Izin status
    if (status == ScheduleStatus.sakit) {
      return (
        background: PdfColor.fromHex('FECACA'),
        text: PdfColor.fromHex('7F1D1D')
      );
    }
    if (status == ScheduleStatus.izin) {
      return (
        background: PdfColor.fromHex('BFDBFE'),
        text: PdfColor.fromHex('1E3A8A')
      );
    }

    final name = shiftName.toLowerCase();
    if (name.contains('pagi')) {
      return (
        background: PdfColor.fromHex('DBEAFE'),
        text: PdfColor.fromHex('1E40AF')
      );
    } else if (name.contains('siang')) {
      return (
        background: PdfColor.fromHex('FEF3C7'),
        text: PdfColor.fromHex('92400E')
      );
    } else if (name.contains('sore')) {
      return (
        background: PdfColor.fromHex('FFEDD5'),
        text: PdfColor.fromHex('C2410C')
      );
    } else if (name.contains('libur')) {
      return (
        background: PdfColor.fromHex('FEE2E2'),
        text: PdfColor.fromHex('991B1B')
      );
    }
    return (
      background: PdfColor.fromHex('F3F4F6'),
      text: PdfColor.fromHex('374151')
    );
  }

  static String _getShiftLabel(ScheduleEntry entry) {
    if (entry.status == ScheduleStatus.sakit) return 'Sakit';
    if (entry.status == ScheduleStatus.izin) return 'Izin';
    if (entry.status == ScheduleStatus.libur) return 'Libur';
    if (entry.isCustomName && entry.displayName != 'Unknown') {
      return entry.displayName.toUpperCase();
    }

    final name = entry.shift.name.toLowerCase();
    if (name.contains('pagi')) return 'Pagi';
    if (name.contains('siang')) return 'Siang';
    if (name.contains('sore')) return 'Sore';
    if (name.contains('libur')) return 'Libur';
    return entry.shift.name.substring(0, 1).toUpperCase();
  }

  /// Find the most common role for an employee across schedule entries
  /// Returns null if no role is found or if roles are inconsistent
  static String? _getMostCommonRole(List<ScheduleEntry> entries) {
    if (entries.isEmpty) return null;

    final roleCounts = <String, int>{};

    for (final entry in entries) {
      if (entry.role != null && entry.role!.isNotEmpty) {
        roleCounts[entry.role!] = (roleCounts[entry.role!] ?? 0) + 1;
      }
    }

    if (roleCounts.isEmpty) return null;

    // Return the most frequently occurring role
    String mostCommonRole = roleCounts.keys.first;
    int maxCount = roleCounts[mostCommonRole]!;

    for (final entry in roleCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        mostCommonRole = entry.key;
      }
    }

    return mostCommonRole;
  }

  // ─── Test-visible wrappers ──────────────────────────────────────────────
  @visibleForTesting
  static PdfColor statusTextColorForTest(String status) =>
      _statusTextColor(status);

  @visibleForTesting
  static PdfColor typeTextColorForTest(String jenis) => _typeTextColor(jenis);

  @visibleForTesting
  static String? getMostCommonRoleForTest(List<ScheduleEntry> entries) =>
      _getMostCommonRole(entries);
}
