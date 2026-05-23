import 'package:absensi_enakko_flutter/screens/admin/widgets/grooming_card.dart';
import 'package:absensi_enakko_flutter/services/grooming_qc_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GroomingRow _row({
  double? score,
  double? override,
  String? cleanShave = 'ok',
  String? uniform = 'ok',
  String? hair = 'ok',
  String? head = 'none',
}) =>
    GroomingRow(
      attendanceLogId: 'a1',
      photoUrl: '',
      employeeId: 'e1',
      employeeName: 'Budi',
      employeePosition: 'Kasir',
      outletId: 'o1',
      outletName: 'Bali',
      attendanceType: 'masuk',
      scannedAt: DateTime(2026, 5, 23, 7, 2),
      analyzedAt: DateTime(2026, 5, 23, 7, 3),
      faceDetected: true,
      faceCount: 1,
      photoQuality: 'clear',
      groomingScore: score,
      qcOverrideScore: override,
      qcOverrideNote: null,
      qcOverriddenBy: null,
      qcOverriddenAt: null,
      safeSearchPassed: true,
      faceCleanShave: cleanShave,
      uniformCompliant: uniform,
      hairNeat: hair,
      headCovering: head,
      reasoning: 'Wajah bersih. Seragam OK. Foto jelas.',
      qcCorrections: const {},
    );

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('renders beard chip when faceCleanShave=beard', (tester) async {
    await tester.pumpWidget(_wrap(GroomingCard(
      row: _row(cleanShave: 'beard'),
      onTapPhoto: () {},
      onTapOverride: () {},
    )));
    expect(find.text('Jenggot'), findsOneWidget);
  });

  testWidgets('renders Topi chip for cap', (tester) async {
    await tester.pumpWidget(_wrap(GroomingCard(
      row: _row(head: 'cap', hair: 'not_visible'),
      onTapPhoto: () {},
      onTapOverride: () {},
    )));
    expect(find.text('Topi'), findsOneWidget);
    expect(find.text('Rambut tertutup'), findsOneWidget);
  });

  testWidgets('renders override pill when override score set', (tester) async {
    await tester.pumpWidget(_wrap(GroomingCard(
      row: _row(score: 4.5, override: 8.0),
      onTapPhoto: () {},
      onTapOverride: () {},
    )));
    expect(find.textContaining('4.5→8.0'), findsOneWidget);
  });

  testWidgets('hijab chip is informational, not danger', (tester) async {
    await tester.pumpWidget(_wrap(GroomingCard(
      row: _row(head: 'hijab', hair: 'not_visible'),
      onTapPhoto: () {},
      onTapOverride: () {},
    )));
    expect(find.text('Hijab'), findsOneWidget);
    expect(find.text('Rambut tertutup'), findsOneWidget);
    expect(find.text('Rambut acak'), findsNothing);
  });

  testWidgets('override button fires callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(GroomingCard(
      row: _row(),
      onTapPhoto: () {},
      onTapOverride: () => tapped = true,
    )));
    await tester.tap(find.text('Override skor'));
    expect(tapped, isTrue);
  });
}
