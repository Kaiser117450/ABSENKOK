import 'package:absensi_enakko_flutter/models/payroll_rollout_acceptance.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/payroll_rollout_acceptance_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<PayrollScenarioReview> buildPendingReviews() {
    return requiredPayrollRolloutScenarioIds
        .map(
          (scenarioId) => PayrollScenarioReview(
            scenarioId: scenarioId,
            logicalWorkdayLabel: '2026-03-31',
            contextLabel: 'Menunggu bukti parity',
            evidenceBySource: const <PayrollEvidenceSource,
                PayrollEvidenceSnapshot>{},
          ),
        )
        .toList(growable: false);
  }

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1280,
              child: PayrollRolloutAcceptancePanel(
                reviews: buildPendingReviews(),
                outletName: 'Outlet Pusat',
                startDate: DateTime(2026, 3, 25),
                endDate: DateTime(2026, 3, 31),
                onDownloadValidationBundle: (_) async {},
                onMarkPayrollReady: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('PayrollRolloutAcceptancePanel', () {
    testWidgets(
        'renders readiness banner copy, scenario labels, evidence headers, and validation action',
        (tester) async {
      await pumpPanel(tester);

      expect(find.text('Rollout Payroll'), findsOneWidget);
      expect(find.text('Payroll belum aman dipakai'), findsOneWidget);
      expect(find.text('Mode rollout additive'), findsOneWidget);
      expect(find.text('Skenario wajib'), findsOneWidget);
      expect(find.text('Bukti parity'), findsOneWidget);
      expect(find.text('Full-time'), findsOneWidget);
      expect(find.text('Part-time'), findsOneWidget);
      expect(find.text('Lembur'), findsOneWidget);
      expect(find.text('Outlet 24 jam'), findsOneWidget);
      expect(find.text('Outlet normal'), findsOneWidget);
      expect(find.text('Break-first'), findsOneWidget);
      expect(find.text('No-show'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Spreadsheet'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Portal'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Unduh Bukti Validasi'), findsOneWidget);
    });

    testWidgets(
        'keeps primary CTA disabled until ready and only shows destructive dialog after review trigger',
        (tester) async {
      await pumpPanel(tester);

      final markReadyButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Tandai Siap Payroll'),
      );
      expect(markReadyButton.onPressed, isNull);

      final validationButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Unduh Bukti Validasi'),
      );
      expect(validationButton.onPressed, isNotNull);

      expect(find.text('Terapkan perubahan database'), findsNothing);

      await tester.ensureVisible(find.text('Review database additive'));
      await tester.tap(find.text('Review database additive'));
      await tester.pumpAndSettle();

      expect(find.text('Terapkan perubahan database'), findsOneWidget);
    });
  });
}
