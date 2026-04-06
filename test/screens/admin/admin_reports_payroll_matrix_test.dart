import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/screens/admin/admin_reports_screen.dart';
import 'package:absensi_enakko_flutter/services/admin_policy_recap_dataset_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/report_export_parity_fixture.dart';

void main() {
  const recapService = AdminPolicyRecapDatasetService();

  ({
    List<AttendancePolicyRecapDay> rows,
    List<AttendancePolicyRecapDay> fallbackRows
  }) buildCompatibilityRows() {
    final bundle = buildReportExportParityFixtureBundle();
    final recapDataset = recapService.build(
      employees: bundle.employees,
      strictRows: bundle.strictRows,
      attendanceLogs: bundle.attendanceLogs,
      outletId: bundle.outletId,
      outletName: bundle.outletName,
      outletOperatingMode: bundle.outletOperatingMode,
      now: DateTime(2026, 3, 29, 10),
    );

    return (
      rows: recapDataset.mergedRows,
      fallbackRows: recapDataset.fallbackRows,
    );
  }

  Future<void> pumpPolicyRecapTab(
    WidgetTester tester, {
    required bool hasSelectedOutlet,
    required List<AttendancePolicyRecapDay> rows,
    List<AttendancePolicyRecapDay> fallbackRows =
        const <AttendancePolicyRecapDay>[],
    String? policyError,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 640,
            child: PolicyRecapTab(
              isLoading: false,
              hasSelectedOutlet: hasSelectedOutlet,
              policyError: policyError,
              rows: rows,
              fallbackRows: fallbackRows,
              selectedFilter: PolicyRecapFilter.semua,
              onFilterChanged: (_) {},
              loadingBuilder: () => const SizedBox.shrink(),
              scanCountMap: const <String, int>{},
              canExportPayrollPdf: true,
              canExportPayrollSpreadsheet: true,
              exportingPayrollPdf: false,
              exportingSpreadsheet: false,
              onExportPayrollPdf: () {},
              onExportPayrollSpreadsheet: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('PolicyRecapTab payroll support', () {
    testWidgets('keeps the no-outlet recap empty state reachable',
        (tester) async {
      await pumpPolicyRecapTab(
        tester,
        hasSelectedOutlet: false,
        rows: const <AttendancePolicyRecapDay>[],
      );

      expect(find.text('Belum Ada Data Rekap'), findsOneWidget);
      expect(
        find.text('Pilih satu outlet untuk melihat recap harian.'),
        findsOneWidget,
      );
    });

    testWidgets('shows compatibility copy and payroll support CTAs',
        (tester) async {
      final recapRows = buildCompatibilityRows();

      await pumpPolicyRecapTab(
        tester,
        hasSelectedOutlet: true,
        rows: recapRows.rows,
        fallbackRows: recapRows.fallbackRows,
      );

      expect(find.text('Mode kompatibilitas aktif'), findsOneWidget);
      expect(
        find.text(
          'Sebagian hari admin recap dipulihkan dari log absensi dan kontrak karena jadwal belum tersedia.',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Output Payroll'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Output Payroll'), findsOneWidget);
      expect(
        find.text(
          'PDF payroll dan spreadsheet tetap tersedia sebagai output gaji dari dataset recap yang sama.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ekspor PDF Payroll'), findsOneWidget);
      expect(find.text('Ekspor Spreadsheet'), findsOneWidget);
    });
  });
}
