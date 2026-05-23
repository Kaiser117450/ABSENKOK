import 'package:absensi_enakko_flutter/screens/admin/widgets/grooming_override_dialog.dart';
import 'package:absensi_enakko_flutter/services/grooming_qc_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GroomingRow _row() => GroomingRow(
      attendanceLogId: 'a1',
      photoUrl: '',
      employeeId: 'e1',
      employeeName: 'Budi',
      employeePosition: 'Kasir',
      outletId: 'o1',
      outletName: 'Bali',
      attendanceType: 'masuk',
      scannedAt: DateTime(2026, 5, 23),
      analyzedAt: DateTime(2026, 5, 23),
      faceDetected: true,
      faceCount: 1,
      photoQuality: 'clear',
      groomingScore: 4.5,
      qcOverrideScore: null,
      qcOverrideNote: null,
      qcOverriddenBy: null,
      qcOverriddenAt: null,
      safeSearchPassed: true,
      faceCleanShave: 'ok',
      uniformCompliant: 'ok',
      hairNeat: 'ok',
      headCovering: 'none',
      reasoning: null,
      qcCorrections: const {},
    );

void main() {
  testWidgets('Save disabled until note >=10 chars', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (ctx) => TextButton(
          onPressed: () {
            showDialog(
                context: ctx,
                builder: (_) => GroomingOverrideDialog(row: _row()));
          },
          child: const Text('open')),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final saveBtn = find.widgetWithText(FilledButton, 'Simpan');
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'ok lah');
    await tester.pump();
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'cukup panjang banget');
    await tester.pump();
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNotNull);
  });
}
