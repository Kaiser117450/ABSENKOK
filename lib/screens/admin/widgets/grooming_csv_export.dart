import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/grooming_qc_service.dart';

class GroomingCsvExport {
  static const csvHeader = 'tanggal,jam,outlet,employee_name,position,'
      'attendance_type,skor_ai,skor_override,override_note,override_by,'
      'wajah_bersih,seragam,rambut,rambut_panjang,penutup_kepala,photo_quality,'
      'reasoning,photo_url';

  static String buildCsv(List<GroomingRow> rows) {
    final buf = StringBuffer(csvHeader)..writeln();
    for (final r in rows) {
      final tgl = '${r.scannedAt.year.toString().padLeft(4, '0')}-'
          '${r.scannedAt.month.toString().padLeft(2, '0')}-'
          '${r.scannedAt.day.toString().padLeft(2, '0')}';
      final jam = '${r.scannedAt.hour.toString().padLeft(2, '0')}:'
          '${r.scannedAt.minute.toString().padLeft(2, '0')}';
      buf.writeln([
        tgl,
        jam,
        _esc(r.outletName),
        _esc(r.employeeName),
        _esc(r.employeePosition),
        r.attendanceType,
        r.groomingScore?.toStringAsFixed(1) ?? '',
        r.qcOverrideScore?.toStringAsFixed(1) ?? '',
        _esc(r.qcOverrideNote ?? ''),
        _esc(r.qcOverriddenBy ?? ''),
        r.faceCleanShave ?? '',
        r.uniformCompliant ?? '',
        r.hairNeat ?? '',
        r.hairLength ?? '',
        r.headCovering ?? '',
        r.photoQuality,
        _esc(r.reasoning ?? ''),
        _esc(r.photoUrl),
      ].join(','));
    }
    return buf.toString();
  }

  static String _esc(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}

class GroomingCsvExportButton extends StatelessWidget {
  final List<GroomingRow> rows;
  const GroomingCsvExportButton({super.key, required this.rows});

  Future<void> _share() async {
    final csv = GroomingCsvExport.buildCsv(rows);
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/grooming_qc_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'Grooming QC export');
  }

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        onPressed: rows.isEmpty ? null : _share,
        icon: const Icon(Icons.file_download_outlined),
        label: const Text('Export CSV'),
      );
}
