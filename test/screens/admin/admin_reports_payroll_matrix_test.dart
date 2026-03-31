import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/outlet_operating_mode.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_day_cell.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';
import 'package:absensi_enakko_flutter/models/payroll_rollout_acceptance.dart';
import 'package:absensi_enakko_flutter/screens/admin/admin_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PayrollMatrixDataset buildDataset() {
    return PayrollMatrixDataset(
      dates: <DateTime>[
        DateTime(2026, 3, 25),
      ],
      rows: <PayrollMatrixRow>[
        PayrollMatrixRow(
          employeeId: 'emp-1',
          employeeName: 'Ayu',
          employmentContract: EmployeeContract.fulltime,
          cells: <PayrollMatrixDayCell>[
            PayrollMatrixDayCell(
              date: DateTime(2026, 3, 25),
              primaryLabel: '07:00 / 17:00',
              secondaryTags: <String>['TLT'],
              fillColorHex: '#FEF3C7',
              textColorHex: '#92400E',
              primaryStatus: null,
              hasData: true,
            ),
          ],
          lateCount: 1,
          shortWorkCount: 0,
          excessBreakCount: 0,
          absenceCount: 0,
          overtimeCount: 0,
        ),
      ],
    );
  }

  Employee buildEmployee({
    required String id,
    required String name,
    required EmployeeContract contract,
  }) {
    return Employee(
      id: id,
      name: name,
      homeOutletId: 'outlet-1',
      isActive: true,
      createdAt: '2026-03-01T00:00:00Z',
      updatedAt: '2026-03-01T00:00:00Z',
      employmentContract: contract,
    );
  }

  AttendanceLog buildLog({
    required String id,
    required String employeeId,
    required AttendanceType type,
    required String scannedAt,
  }) {
    return AttendanceLog(
      id: id,
      employeeId: employeeId,
      scanOutletId: 'outlet-1',
      type: type,
      scannedAt: scannedAt,
      createdAt: scannedAt,
    );
  }

  AttendancePolicyRecapDay buildStrictRecapDay({
    required Employee employee,
    required DateTime logicalDate,
  }) {
    return AttendancePolicyRecapDay(
      logicalDate: logicalDate,
      employeeId: employee.id,
      employeeName: employee.name,
      outletId: 'outlet-1',
      outletName: 'Outlet 24 Jam',
      shiftBand: null,
      requiredWorkMinutes:
          employee.employmentContract == EmployeeContract.parttime ? 540 : 600,
      lateCutoffLocal: null,
      breakFirstDeadlineLocal: null,
      attendanceStatus: AttendancePolicyStatus.hadir,
      lateKind: LateKind.none,
      isLate: false,
      breakFirstEligible: false,
      breakFirstConfirmed: false,
      firstScanLocal: DateTime(2026, 3, 25, 7, 0),
      firstBreakLocal: null,
      lastPulangLocal: DateTime(2026, 3, 25, 17, 0),
      notes: null,
      primaryStatus: AttendancePolicyPrimaryStatus.hadir,
      primarySeverity: AttendancePolicySeverity.info,
      detailSignals: const <AttendancePolicySignal>[],
      detailNotes: const <String>[],
      logicalDayComplete: true,
      netWorkMinutes: 600,
      totalBreakMinutes: 0,
      overtimeMinutes: 0,
      shortWorkMinutes: 0,
      excessBreakMinutes: 0,
      pairedBreakCount: 0,
    );
  }

  List<PayrollScenarioReview> buildRolloutReviews() {
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

  Future<void> pumpRecapTab(
    WidgetTester tester, {
    required bool hasSelectedOutlet,
    required PayrollMatrixDataset? dataset,
    String? policyError,
    bool isCompatibilityMode = false,
    bool isExportingPdf = false,
    bool isExportingSpreadsheet = false,
    String? exportStatusMessage,
    bool exportStatusIsError = false,
    bool canExportPdf = true,
    bool canExportSpreadsheet = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 640,
            child: PayrollRecapTab(
              isLoading: false,
              hasSelectedOutlet: hasSelectedOutlet,
              policyError: policyError,
              dataset: dataset,
              isCompatibilityMode: isCompatibilityMode,
              isExportingPdf: isExportingPdf,
              isExportingSpreadsheet: isExportingSpreadsheet,
              exportStatusMessage: exportStatusMessage,
              exportStatusIsError: exportStatusIsError,
              canExportPdf: canExportPdf,
              canExportSpreadsheet: canExportSpreadsheet,
              onExportPdf: canExportPdf ? () {} : null,
              onExportSpreadsheet: canExportSpreadsheet ? () {} : null,
              rolloutReviews: buildRolloutReviews(),
              rolloutOutletName: 'Outlet 24 Jam',
              rolloutStartDate: DateTime(2026, 3, 25),
              rolloutEndDate: DateTime(2026, 3, 31),
              onDownloadValidationBundle: (_) async {},
              loadingBuilder: () => const SizedBox.shrink(),
              emptyNoDataSubtext:
                  'Tidak ada data payroll pada rentang waktu ini.',
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('PayrollRecapTab', () {
    test(
        'buildPayrollRecapDatasetWithCompatibility merges strict and overnight fallback rows without duplicate next-day cells',
        () {
      final ayu = buildEmployee(
        id: 'emp-1',
        name: 'Ayu',
        contract: EmployeeContract.fulltime,
      );
      final citra = buildEmployee(
        id: 'emp-2',
        name: 'Citra',
        contract: EmployeeContract.parttime,
      );

      final result = buildPayrollRecapDatasetWithCompatibility(
        startDate: DateTime(2026, 3, 25),
        endDate: DateTime(2026, 3, 26),
        employees: <Employee>[ayu, citra],
        strictRows: <AttendancePolicyRecapDay>[
          buildStrictRecapDay(
            employee: ayu,
            logicalDate: DateTime(2026, 3, 25),
          ),
        ],
        attendanceLogs: <AttendanceLog>[
          buildLog(
            id: 'citra-in',
            employeeId: citra.id,
            type: AttendanceType.masuk,
            scannedAt: '2026-03-25T15:00:00+08:00',
          ),
          buildLog(
            id: 'citra-out',
            employeeId: citra.id,
            type: AttendanceType.pulang,
            scannedAt: '2026-03-26T01:20:00+08:00',
          ),
        ],
        outletId: 'outlet-1',
        outletName: 'Outlet 24 Jam',
        outletOperatingMode: OutletOperatingMode.twentyFourHour,
        now: DateTime(2026, 3, 26, 10),
      );

      expect(result.isCompatibilityMode, isTrue);
      expect(result.fallbackRows, hasLength(1));
      expect(result.mergedRows, hasLength(2));
      expect(result.dataset.dates, <DateTime>[
        DateTime(2026, 3, 25),
        DateTime(2026, 3, 26),
      ]);

      final citraRow =
          result.dataset.rows.firstWhere((row) => row.employeeId == citra.id);
      expect(citraRow.cells[0].hasData, isTrue);
      expect(citraRow.cells[0].primaryLabel, '15:00 / 01:20');
      expect(citraRow.cells[1].hasData, isFalse);
    });

    testWidgets(
        'renders rollout panel while payroll PDF primary CTA and spreadsheet secondary CTA stay available',
        (tester) async {
      await pumpRecapTab(
        tester,
        hasSelectedOutlet: true,
        dataset: buildDataset(),
      );

      expect(find.text('Rollout Payroll'), findsOneWidget);
      expect(find.text('Rekap Payroll'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Ekspor PDF Payroll'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Ekspor Spreadsheet'),
        findsOneWidget,
      );
      expect(find.text('CSV'), findsNothing);
    });

    testWidgets('shows loading feedback while payroll PDF export is running',
        (tester) async {
      await pumpRecapTab(
        tester,
        hasSelectedOutlet: true,
        dataset: buildDataset(),
        isExportingPdf: true,
        exportStatusMessage: 'Menyiapkan PDF payroll...',
      );

      expect(find.text('Menyiapkan PDF payroll...'), findsOneWidget);
    });

    testWidgets('disables payroll PDF CTA when export is not allowed',
        (tester) async {
      await pumpRecapTab(
        tester,
        hasSelectedOutlet: true,
        dataset: buildDataset(),
        canExportPdf: false,
      );

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Ekspor PDF Payroll'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('shows success feedback after payroll PDF is ready',
        (tester) async {
      await pumpRecapTab(
        tester,
        hasSelectedOutlet: true,
        dataset: buildDataset(),
        exportStatusMessage: 'PDF payroll siap dibagikan.',
      );

      expect(find.text('PDF payroll siap dibagikan.'), findsOneWidget);
    });

    testWidgets('keeps spreadsheet CTA available as secondary action',
        (tester) async {
      await pumpRecapTab(
        tester,
        hasSelectedOutlet: true,
        dataset: buildDataset(),
        canExportSpreadsheet: false,
      );

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Ekspor Spreadsheet'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets(
        'shows compatibility note and keeps matrix visible when strict policy fetch fails',
        (tester) async {
      await pumpRecapTab(
        tester,
        hasSelectedOutlet: true,
        dataset: buildDataset(),
        policyError: 'RPC unavailable',
        isCompatibilityMode: true,
      );

      expect(find.text(payrollCompatibilityModeTitle), findsOneWidget);
      expect(find.text(payrollCompatibilityModeBody), findsOneWidget);
      expect(find.text('Rekap Policy Belum Tersedia'), findsNothing);
      expect(find.text('Ekspor PDF Payroll'), findsOneWidget);
      expect(find.text('Ekspor Spreadsheet'), findsOneWidget);
      expect(find.text('Ayu'), findsOneWidget);
    });

    testWidgets('keeps the no-outlet payroll empty state reachable',
        (tester) async {
      await pumpRecapTab(
        tester,
        hasSelectedOutlet: false,
        dataset: null,
      );

      expect(find.text('Belum Ada Data Payroll'), findsOneWidget);
      expect(
        find.text('Pilih satu outlet untuk menghitung payroll matrix.'),
        findsOneWidget,
      );
    });

    testWidgets('keeps the strict policy blocker when no dataset is usable',
        (tester) async {
      await pumpRecapTab(
        tester,
        hasSelectedOutlet: true,
        dataset: null,
        policyError: 'RPC unavailable',
      );

      expect(find.text('Rekap Policy Belum Tersedia'), findsOneWidget);
    });
  });
}
