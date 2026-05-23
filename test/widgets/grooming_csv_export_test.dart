import 'package:absensi_enakko_flutter/screens/admin/widgets/grooming_csv_export.dart';
import 'package:absensi_enakko_flutter/services/grooming_qc_service.dart';
import 'package:flutter_test/flutter_test.dart';

GroomingRow _row() => GroomingRow(
      attendanceLogId: 'a1',
      photoUrl: 'https://r2/photo.jpg',
      employeeId: 'e1',
      employeeName: 'Budi, Si',
      employeePosition: 'Kasir',
      outletId: 'o1',
      outletName: 'Bali',
      attendanceType: 'masuk',
      scannedAt: DateTime(2026, 5, 23, 7, 2),
      analyzedAt: DateTime(2026, 5, 23, 7, 3),
      faceDetected: true,
      faceCount: 1,
      photoQuality: 'clear',
      groomingScore: 6.5,
      qcOverrideScore: 8.0,
      qcOverrideNote: 'Label salah, "rapi" kok',
      qcOverriddenBy: null,
      qcOverriddenAt: null,
      safeSearchPassed: true,
      faceCleanShave: 'ok',
      uniformCompliant: 'ok',
      hairNeat: 'ok',
      headCovering: 'none',
      reasoning: 'Wajah bersih. Seragam OK. Foto jelas.',
      qcCorrections: const {},
    );

void main() {
  test('header is the agreed columns', () {
    expect(GroomingCsvExport.csvHeader.split(',').length, 17);
    expect(GroomingCsvExport.csvHeader, contains('penutup_kepala'));
  });

  test('escapes commas and quotes', () {
    final csv = GroomingCsvExport.buildCsv([_row()]);
    expect(csv, contains('"Budi, Si"'));
    expect(csv, contains('"Label salah, ""rapi"" kok"'));
    expect(csv, contains('6.5'));
    expect(csv, contains('8.0'));
    expect(csv, contains('2026-05-23'));
  });
}
