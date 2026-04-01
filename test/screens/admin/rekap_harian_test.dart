import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';
import 'package:absensi_enakko_flutter/screens/admin/admin_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AttendancePolicyRecapDay buildRecap({
    required String employeeId,
    required String employeeName,
    required AttendancePolicyPrimaryStatus primaryStatus,
    required AttendancePolicySeverity primarySeverity,
    List<AttendancePolicySignal> detailSignals = const [],
    List<String> detailNotes = const [],
    AttendancePolicyStatus attendanceStatus = AttendancePolicyStatus.hadir,
    ShiftBand? shiftBand = ShiftBand.pagi,
    LateKind lateKind = LateKind.none,
    bool logicalDayComplete = true,
    int? netWorkMinutes = 540,
    int? totalBreakMinutes = 30,
    int? overtimeMinutes = 0,
    int? shortWorkMinutes = 0,
    int? excessBreakMinutes = 0,
  }) {
    return AttendancePolicyRecapDay(
      logicalDate: DateTime(2026, 3, 28),
      employeeId: employeeId,
      employeeName: employeeName,
      outletId: 'outlet-1',
      outletName: 'Outlet Utama',
      shiftBand: shiftBand,
      requiredWorkMinutes: 540,
      lateCutoffLocal: '07:00',
      breakFirstDeadlineLocal: '09:00',
      attendanceStatus: attendanceStatus,
      lateKind: lateKind,
      isLate: lateKind != LateKind.none,
      breakFirstEligible: lateKind == LateKind.breakFirstEligible,
      breakFirstConfirmed: lateKind == LateKind.breakFirstConfirmed,
      firstScanLocal: DateTime(2026, 3, 28, 7, 15),
      firstBreakLocal: DateTime(2026, 3, 28, 12, 0),
      lastPulangLocal: DateTime(2026, 3, 28, 17, 15),
      notes: null,
      primaryStatus: primaryStatus,
      primarySeverity: primarySeverity,
      detailSignals: detailSignals,
      detailNotes: detailNotes,
      logicalDayComplete: logicalDayComplete,
      netWorkMinutes: netWorkMinutes,
      totalBreakMinutes: totalBreakMinutes,
      overtimeMinutes: overtimeMinutes,
      shortWorkMinutes: shortWorkMinutes,
      excessBreakMinutes: excessBreakMinutes,
      pairedBreakCount: 1,
    );
  }

  Widget buildHarness({
    required List<AttendancePolicyRecapDay> rows,
    List<AttendancePolicyRecapDay> fallbackRows = const [],
  }) {
    return MaterialApp(
      home: Scaffold(
        body: _PolicyRecapHarness(
          rows: rows,
          fallbackRows: fallbackRows,
        ),
      ),
    );
  }

  group('Rekap Harian — widget behavior', () {
    testWidgets(
      'shows merged day rows and compatibility banner only when fallback rows exist',
      (tester) async {
        final strictRow = buildRecap(
          employeeId: 'emp-1',
          employeeName: 'Ayu Strict',
          primaryStatus: AttendancePolicyPrimaryStatus.late,
          primarySeverity: AttendancePolicySeverity.red,
          detailSignals: const [AttendancePolicySignal.late],
          detailNotes: const ['Terlambat melewati cutoff pagi.'],
          lateKind: LateKind.normal,
        );
        final fallbackRow = buildRecap(
          employeeId: 'emp-2',
          employeeName: 'Bimo Fallback',
          primaryStatus: AttendancePolicyPrimaryStatus.hadirTanpaJadwal,
          primarySeverity: AttendancePolicySeverity.info,
          attendanceStatus: AttendancePolicyStatus.hadirTanpaJadwal,
          detailSignals: const [AttendancePolicySignal.hadirTanpaJadwal],
          shiftBand: null,
          netWorkMinutes: 480,
          totalBreakMinutes: 45,
        );

        await tester.pumpWidget(
          buildHarness(
            rows: [strictRow, fallbackRow],
            fallbackRows: [fallbackRow],
          ),
        );

        expect(find.text('Mode kompatibilitas aktif'), findsOneWidget);
        expect(
          find.text(
            'Sebagian hari admin recap dipulihkan dari log absensi dan kontrak karena jadwal belum tersedia.',
          ),
          findsOneWidget,
        );
        expect(find.text('Ayu Strict'), findsOneWidget);
        expect(find.text('Bimo Fallback'), findsOneWidget);

        await tester.pumpWidget(buildHarness(rows: [strictRow]));
        await tester.pumpAndSettle();

        expect(find.text('Mode kompatibilitas aktif'), findsNothing);
      },
    );

    testWidgets(
      'pending filter shows belum absen pulang and hari masih berjalan rows',
      (tester) async {
        final missingClockOutRow = buildRecap(
          employeeId: 'emp-3',
          employeeName: 'Citra Pending',
          primaryStatus: AttendancePolicyPrimaryStatus.belumAbsenPulang,
          primarySeverity: AttendancePolicySeverity.red,
          detailSignals: const [AttendancePolicySignal.belumAbsenPulang],
        );
        final activeIncompleteRow = buildRecap(
          employeeId: 'emp-4',
          employeeName: 'Deni Aktif',
          primaryStatus: AttendancePolicyPrimaryStatus.activeIncomplete,
          primarySeverity: AttendancePolicySeverity.info,
          detailSignals: const [AttendancePolicySignal.activeIncomplete],
          logicalDayComplete: false,
        );
        final managerExemptRow = buildRecap(
          employeeId: 'emp-5',
          employeeName: 'Eka Manager',
          primaryStatus: AttendancePolicyPrimaryStatus.exemptManager,
          primarySeverity: AttendancePolicySeverity.info,
          detailSignals: const [AttendancePolicySignal.exemptManager],
        );

        await tester.pumpWidget(
          buildHarness(
            rows: [missingClockOutRow, activeIncompleteRow, managerExemptRow],
          ),
        );

        await tester.tap(find.text('Belum absen pulang'));
        await tester.pumpAndSettle();

        expect(find.text('Citra Pending'), findsOneWidget);
        expect(find.text('Deni Aktif'), findsOneWidget);
        expect(find.text('Eka Manager'), findsNothing);
      },
    );

    testWidgets(
      'fallback rows stay honest without fabricated lateness or absence',
      (tester) async {
        final strictRow = buildRecap(
          employeeId: 'emp-6',
          employeeName: 'Fajar Strict',
          primaryStatus: AttendancePolicyPrimaryStatus.late,
          primarySeverity: AttendancePolicySeverity.red,
          detailSignals: const [AttendancePolicySignal.late],
          detailNotes: const ['Terlambat melewati cutoff malam.'],
          lateKind: LateKind.normal,
        );
        final fallbackRow = buildRecap(
          employeeId: 'emp-7',
          employeeName: 'Gita Tanpa Jadwal',
          primaryStatus: AttendancePolicyPrimaryStatus.hadirTanpaJadwal,
          primarySeverity: AttendancePolicySeverity.info,
          attendanceStatus: AttendancePolicyStatus.hadirTanpaJadwal,
          detailSignals: const [AttendancePolicySignal.hadirTanpaJadwal],
          shiftBand: null,
          netWorkMinutes: 480,
          totalBreakMinutes: 45,
        );

        await tester.pumpWidget(
          buildHarness(
            rows: [strictRow, fallbackRow],
            fallbackRows: [fallbackRow],
          ),
        );

        expect(
          find.text(
            'Hadir tanpa jadwal; aturan kontrak tetap dipakai untuk menghitung jam kerja, istirahat, dan lembur.',
          ),
          findsOneWidget,
        );
        expect(find.text('Terlambat'), findsWidgets);
        expect(find.text('Tidak hadir'), findsNothing);
      },
    );
  });
}

class _PolicyRecapHarness extends StatefulWidget {
  const _PolicyRecapHarness({
    required this.rows,
    required this.fallbackRows,
  });

  final List<AttendancePolicyRecapDay> rows;
  final List<AttendancePolicyRecapDay> fallbackRows;

  @override
  State<_PolicyRecapHarness> createState() => _PolicyRecapHarnessState();
}

class _PolicyRecapHarnessState extends State<_PolicyRecapHarness> {
  PolicyRecapFilter _selectedFilter = PolicyRecapFilter.semua;

  @override
  Widget build(BuildContext context) {
    return PolicyRecapTab(
      isLoading: false,
      hasSelectedOutlet: true,
      policyError: null,
      rows: widget.rows,
      fallbackRows: widget.fallbackRows,
      selectedFilter: _selectedFilter,
      onFilterChanged: (filter) {
        setState(() => _selectedFilter = filter);
      },
      loadingBuilder: () => const SizedBox.shrink(),
    );
  }
}
