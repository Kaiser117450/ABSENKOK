import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';
import 'package:absensi_enakko_flutter/screens/admin/admin_reports_screen.dart';
import 'package:absensi_enakko_flutter/widgets/attendance_policy_signal_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AttendancePolicyRecapDay buildRecap({
    required String employeeId,
    required AttendancePolicyPrimaryStatus primaryStatus,
    required AttendancePolicySeverity primarySeverity,
    DateTime? logicalDate,
    List<AttendancePolicySignal> detailSignals = const [],
    List<String> detailNotes = const [],
    AttendancePolicyStatus attendanceStatus = AttendancePolicyStatus.hadir,
    LateKind lateKind = LateKind.none,
    bool isManagerExempt = false,
    String? managerPosition,
    ShiftBand? shiftBand = ShiftBand.pagi,
    bool logicalDayComplete = true,
    String? incompleteReason,
    int? netWorkMinutes = 600,
    int? totalBreakMinutes = 30,
    int? overtimeMinutes = 0,
    int? shortWorkMinutes = 0,
    int? excessBreakMinutes = 0,
  }) {
    return AttendancePolicyRecapDay(
      logicalDate: logicalDate ?? DateTime(2026, 3, 26),
      employeeId: employeeId,
      employeeName: 'Employee $employeeId',
      outletId: 'outlet-1',
      outletName: 'Outlet Utama',
      shiftBand: shiftBand,
      requiredWorkMinutes: 600,
      lateCutoffLocal: '07:00',
      breakFirstDeadlineLocal: '09:00',
      attendanceStatus: attendanceStatus,
      lateKind: lateKind,
      isLate: lateKind != LateKind.none,
      breakFirstEligible: lateKind == LateKind.breakFirstEligible,
      breakFirstConfirmed: lateKind == LateKind.breakFirstConfirmed,
      firstScanLocal: DateTime(2026, 3, 26, 7, 15),
      firstBreakLocal: DateTime(2026, 3, 26, 12, 0),
      lastPulangLocal: DateTime(2026, 3, 26, 17, 15),
      notes: null,
      primaryStatus: primaryStatus,
      primarySeverity: primarySeverity,
      detailSignals: detailSignals,
      detailNotes: detailNotes,
      isManagerExempt: isManagerExempt,
      managerPosition: managerPosition,
      logicalDayComplete: logicalDayComplete,
      incompleteReason: incompleteReason,
      netWorkMinutes: netWorkMinutes,
      totalBreakMinutes: totalBreakMinutes,
      overtimeMinutes: overtimeMinutes,
      shortWorkMinutes: shortWorkMinutes,
      excessBreakMinutes: excessBreakMinutes,
      pairedBreakCount: 1,
    );
  }

  group('admin strict recap helpers', () {
    test(
      'filter selection isolates manager_exempt, hadir_tanpa_jadwal, and pending recap rows',
      () {
        final managerRecap = buildRecap(
          employeeId: 'emp-1',
          primaryStatus: AttendancePolicyPrimaryStatus.exemptManager,
          primarySeverity: AttendancePolicySeverity.info,
          detailSignals: const [
            AttendancePolicySignal.late,
            AttendancePolicySignal.exemptManager,
          ],
          isManagerExempt: true,
          managerPosition: 'Kepala Gerai',
        );
        final missingClockOutRecap = buildRecap(
          employeeId: 'emp-2',
          primaryStatus: AttendancePolicyPrimaryStatus.belumAbsenPulang,
          primarySeverity: AttendancePolicySeverity.red,
          detailSignals: const [AttendancePolicySignal.belumAbsenPulang],
        );
        final activeIncompleteRecap = buildRecap(
          employeeId: 'emp-3',
          primaryStatus: AttendancePolicyPrimaryStatus.activeIncomplete,
          primarySeverity: AttendancePolicySeverity.info,
          detailSignals: const [AttendancePolicySignal.activeIncomplete],
          logicalDayComplete: false,
          incompleteReason: 'Menunggu clock-out',
        );
        final fallbackNoScheduleRecap = buildRecap(
          employeeId: 'emp-4',
          primaryStatus: AttendancePolicyPrimaryStatus.hadirTanpaJadwal,
          primarySeverity: AttendancePolicySeverity.info,
          attendanceStatus: AttendancePolicyStatus.hadirTanpaJadwal,
          detailSignals: const [AttendancePolicySignal.hadirTanpaJadwal],
          shiftBand: null,
          netWorkMinutes: 480,
          totalBreakMinutes: 45,
          overtimeMinutes: 15,
        );
        final regularRecap = buildRecap(
          employeeId: 'emp-5',
          primaryStatus: AttendancePolicyPrimaryStatus.hadir,
          primarySeverity: AttendancePolicySeverity.info,
        );

        final rows = [
          managerRecap,
          missingClockOutRecap,
          activeIncompleteRecap,
          fallbackNoScheduleRecap,
          regularRecap,
        ];

        expect(
          filterPolicyRecapRows(rows, PolicyRecapFilter.managerExempt),
          [managerRecap],
        );
        expect(
          filterPolicyRecapRows(rows, PolicyRecapFilter.hadirTanpaJadwal),
          [fallbackNoScheduleRecap],
        );
        expect(
          filterPolicyRecapRows(rows, PolicyRecapFilter.belumAbsenPulang),
          [missingClockOutRecap, activeIncompleteRecap],
        );
      },
    );

    testWidgets(
      'PolicyRecapTile shows one primary badge, detail chip, and manager exemption copy',
      (tester) async {
        final recap = buildRecap(
          employeeId: 'emp-1',
          primaryStatus: AttendancePolicyPrimaryStatus.exemptManager,
          primarySeverity: AttendancePolicySeverity.info,
          detailSignals: const [
            AttendancePolicySignal.late,
            AttendancePolicySignal.exemptManager,
          ],
          detailNotes: const [
            'Posisi kepala gerai exempt dari penalti merah telat, kurang jam, dan istirahat berlebih.',
          ],
          isManagerExempt: true,
          managerPosition: 'Kepala Gerai',
          netWorkMinutes: 540,
          shortWorkMinutes: 60,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PolicyRecapTile(recap: recap, scanCountMap: const <String, int>{}),
            ),
          ),
        );

        expect(find.text('Manager exempt'), findsWidgets);
        expect(find.text('Terlambat'), findsOneWidget);
        expect(find.byType(AttendancePolicySignalChip), findsWidgets);
        expect(find.textContaining('tidak kena penalti merah'), findsOneWidget);
        expect(find.textContaining('Kerja '), findsOneWidget);
      },
    );

    testWidgets(
      'PolicyRecapTile keeps strict signals and fallback no-schedule copy visible together',
      (tester) async {
        final strictOvernightRecap = buildRecap(
          employeeId: 'emp-6',
          primaryStatus: AttendancePolicyPrimaryStatus.late,
          primarySeverity: AttendancePolicySeverity.red,
          logicalDate: DateTime(2026, 3, 27),
          detailSignals: const [
            AttendancePolicySignal.late,
            AttendancePolicySignal.excessBreak,
          ],
          detailNotes: const ['Break malam melebihi kontrak.'],
          lateKind: LateKind.normal,
          netWorkMinutes: 510,
          totalBreakMinutes: 90,
          excessBreakMinutes: 45,
        );
        final fallbackNoScheduleRecap = buildRecap(
          employeeId: 'emp-7',
          primaryStatus: AttendancePolicyPrimaryStatus.hadirTanpaJadwal,
          primarySeverity: AttendancePolicySeverity.info,
          logicalDate: DateTime(2026, 3, 27),
          attendanceStatus: AttendancePolicyStatus.hadirTanpaJadwal,
          detailSignals: const [AttendancePolicySignal.hadirTanpaJadwal],
          shiftBand: null,
          netWorkMinutes: 480,
          totalBreakMinutes: 45,
          overtimeMinutes: 15,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  PolicyRecapTile(recap: strictOvernightRecap, scanCountMap: const <String, int>{}),
                  PolicyRecapTile(recap: fallbackNoScheduleRecap, scanCountMap: const <String, int>{}),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Employee emp-6'), findsOneWidget);
        expect(find.text('Employee emp-7'), findsOneWidget);
        expect(find.text('Tanpa jadwal'), findsOneWidget);
        expect(
          find.text(
            'Hadir tanpa jadwal; aturan kontrak tetap dipakai untuk menghitung jam kerja, istirahat, dan lembur.',
          ),
          findsOneWidget,
        );
        expect(find.text('Istirahat berlebih'), findsOneWidget);
        expect(find.textContaining('Break malam melebihi kontrak'),
            findsOneWidget);
      },
    );
  });
}
