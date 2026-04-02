import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_day_cell.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';
import 'package:absensi_enakko_flutter/services/payroll_matrix_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AttendancePolicyRecapDay buildRecap({
    required DateTime logicalDate,
    AttendancePolicyPrimaryStatus? primaryStatus,
    AttendancePolicyStatus attendanceStatus = AttendancePolicyStatus.hadir,
    List<AttendancePolicySignal> detailSignals =
        const <AttendancePolicySignal>[],
    DateTime? firstScanLocal,
    DateTime? lastPulangLocal,
    bool isLate = false,
    LateKind lateKind = LateKind.none,
    ShiftBand? shiftBand = ShiftBand.pagi,
    AttendancePolicySeverity primarySeverity = AttendancePolicySeverity.info,
  }) {
    return AttendancePolicyRecapDay(
      logicalDate: logicalDate,
      employeeId: 'emp-1',
      employeeName: 'Ayu',
      outletId: 'outlet-1',
      outletName: 'Outlet Utama',
      shiftBand: shiftBand,
      requiredWorkMinutes: 540,
      lateCutoffLocal: shiftBand == null ? null : '07:00',
      breakFirstDeadlineLocal: shiftBand == null ? null : '09:00',
      attendanceStatus: attendanceStatus,
      lateKind: lateKind,
      isLate: isLate,
      breakFirstEligible: false,
      breakFirstConfirmed: false,
      firstScanLocal: firstScanLocal,
      firstBreakLocal: null,
      lastPulangLocal: lastPulangLocal,
      notes: null,
      primaryStatus: primaryStatus,
      primarySeverity: primarySeverity,
      detailSignals: detailSignals,
      detailNotes: const <String>[],
      isManagerExempt: false,
      managerPosition: null,
      logicalDayComplete: true,
      netWorkMinutes: 540,
      totalBreakMinutes: 30,
      overtimeMinutes: 0,
      shortWorkMinutes: 0,
      excessBreakMinutes: 0,
      pairedBreakCount: 1,
    );
  }

  group('PayrollMatrixSemantics', () {
    const semantics = PayrollMatrixSemantics();

    test('explicit non-time labels never return blank strings', () {
      final cases = <AttendancePolicyRecapDay>[
        buildRecap(
          logicalDate: DateTime(2026, 3, 20),
          primaryStatus: AttendancePolicyPrimaryStatus.libur,
          attendanceStatus: AttendancePolicyStatus.libur,
        ),
        buildRecap(
          logicalDate: DateTime(2026, 3, 21),
          primaryStatus: AttendancePolicyPrimaryStatus.izin,
          attendanceStatus: AttendancePolicyStatus.izin,
        ),
        buildRecap(
          logicalDate: DateTime(2026, 3, 22),
          primaryStatus: AttendancePolicyPrimaryStatus.sakit,
          attendanceStatus: AttendancePolicyStatus.sakit,
        ),
        buildRecap(
          logicalDate: DateTime(2026, 3, 23),
          primaryStatus: AttendancePolicyPrimaryStatus.cuti,
          attendanceStatus: AttendancePolicyStatus.cuti,
        ),
        buildRecap(
          logicalDate: DateTime(2026, 3, 24),
          primaryStatus: AttendancePolicyPrimaryStatus.absence,
          attendanceStatus: AttendancePolicyStatus.tidakHadir,
        ),
        buildRecap(
          logicalDate: DateTime(2026, 3, 25),
          primaryStatus: AttendancePolicyPrimaryStatus.hadirTanpaJadwal,
          attendanceStatus: AttendancePolicyStatus.hadirTanpaJadwal,
        ),
        buildRecap(
          logicalDate: DateTime(2026, 3, 26),
          primaryStatus: AttendancePolicyPrimaryStatus.belumAbsenPulang,
        ),
        buildRecap(
          logicalDate: DateTime(2026, 3, 27),
          primaryStatus: AttendancePolicyPrimaryStatus.belumMasuk,
          attendanceStatus: AttendancePolicyStatus.belumMasuk,
        ),
      ];

      final labels = cases
          .map((recap) =>
              semantics.buildDayCell(date: recap.logicalDate, recap: recap))
          .map((cell) => cell.primaryLabel)
          .toList(growable: false);

      expect(labels, const <String>[
        'Libur',
        'Izin',
        'Sakit',
        'Cuti',
        'Tidak Hadir',
        'Hadir tanpa jadwal',
        'Belum Absen Pulang',
        'Belum Masuk',
      ]);
    });

    test('secondary tags use the exact uppercase payroll vocabulary', () {
      final recap = buildRecap(
        logicalDate: DateTime(2026, 3, 27),
        primaryStatus: AttendancePolicyPrimaryStatus.late,
        detailSignals: const <AttendancePolicySignal>[
          AttendancePolicySignal.overtime,
          AttendancePolicySignal.shortWork,
          AttendancePolicySignal.excessBreak,
          AttendancePolicySignal.absence,
          AttendancePolicySignal.exemptManager,
        ],
        firstScanLocal: DateTime(2026, 3, 27, 7, 5),
        lastPulangLocal: DateTime(2026, 3, 27, 17, 10),
        isLate: true,
        lateKind: LateKind.normal,
      );

      final cell = semantics.buildDayCell(
        date: recap.logicalDate,
        recap: recap,
      );

      expect(cell.secondaryTags, const <String>[
        'TLT',
        'KJG',
        'BRK',
        'ABS',
        'OT',
        'ME',
      ]);
    });

    test('summary counts ignore non-payroll audit signals', () {
      final recap = buildRecap(
        logicalDate: DateTime(2026, 3, 27),
        primaryStatus: AttendancePolicyPrimaryStatus.hadirTanpaJadwal,
        attendanceStatus: AttendancePolicyStatus.hadirTanpaJadwal,
        detailSignals: const <AttendancePolicySignal>[
          AttendancePolicySignal.exemptManager,
        ],
      );

      final counts = semantics.countsForRecap(recap);

      expect(counts.lateCount, 0);
      expect(counts.shortWorkCount, 0);
      expect(counts.excessBreakCount, 0);
      expect(counts.absenceCount, 0);
      expect(counts.overtimeCount, 0);
    });

    test('fallback-compatible no-schedule penalties keep payroll-facing tags',
        () {
      final recap = buildRecap(
        logicalDate: DateTime(2026, 3, 28),
        primaryStatus: AttendancePolicyPrimaryStatus.shortWork,
        attendanceStatus: AttendancePolicyStatus.hadirTanpaJadwal,
        detailSignals: const <AttendancePolicySignal>[
          AttendancePolicySignal.hadirTanpaJadwal,
          AttendancePolicySignal.shortWork,
        ],
        shiftBand: null,
        firstScanLocal: DateTime(2026, 3, 28, 7, 0),
        lastPulangLocal: DateTime(2026, 3, 28, 15, 0),
        primarySeverity: AttendancePolicySeverity.red,
      );

      final cell = semantics.buildDayCell(
        date: recap.logicalDate,
        recap: recap,
      );
      final counts = semantics.countsForRecap(recap);

      expect(cell.primaryLabel, '07:00 / 15:00');
      expect(cell.secondaryTags, contains('KJG'));
      expect(cell.secondaryTags, isNot(contains('ABS')));
      expect(cell.secondaryTags, isNot(contains('TLT')));
      expect(counts.shortWorkCount, 1);
      expect(counts.absenceCount, 0);
      expect(counts.lateCount, 0);
    });

    test('summary metrics keep locked order and aggregate dataset totals', () {
      final dataset = PayrollMatrixDataset(
        dates: <DateTime>[
          DateTime(2026, 3, 18),
          DateTime(2026, 3, 21),
        ],
        rows: <PayrollMatrixRow>[
          PayrollMatrixRow(
            employeeId: 'emp-1',
            employeeName: 'Ayu',
            employmentContract: EmployeeContract.fulltime,
            cells: <PayrollMatrixDayCell>[
              PayrollMatrixDayCell(
                date: DateTime(2026, 3, 18),
                primaryLabel: '07:12 / 17:05',
                secondaryTags: const <String>['TLT'],
                fillColorHex: '#FEF3C7',
                textColorHex: '#92400E',
                primaryStatus: AttendancePolicyPrimaryStatus.late,
                hasData: true,
              ),
              PayrollMatrixDayCell.placeholder(DateTime(2026, 3, 21)),
            ],
            lateCount: 1,
            shortWorkCount: 0,
            excessBreakCount: 0,
            absenceCount: 0,
            overtimeCount: 0,
          ),
          PayrollMatrixRow(
            employeeId: 'emp-2',
            employeeName: 'Citra',
            employmentContract: EmployeeContract.parttime,
            cells: <PayrollMatrixDayCell>[
              PayrollMatrixDayCell.placeholder(DateTime(2026, 3, 18)),
              PayrollMatrixDayCell(
                date: DateTime(2026, 3, 21),
                primaryLabel: 'Hadir Tanpa Jadwal',
                secondaryTags: const <String>[],
                fillColorHex: '#ECFEFF',
                textColorHex: '#0F766E',
                primaryStatus: AttendancePolicyPrimaryStatus.hadirTanpaJadwal,
                hasData: true,
              ),
            ],
            lateCount: 0,
            shortWorkCount: 0,
            excessBreakCount: 0,
            absenceCount: 0,
            overtimeCount: 0,
          ),
        ],
      );

      final summary = semantics.summarizeDataset(dataset);
      final metrics = semantics.summaryMetricValuesForDataset(dataset);

      expect(summary.lateCount, 1);
      expect(summary.shortWorkCount, 0);
      expect(summary.excessBreakCount, 0);
      expect(summary.absenceCount, 0);
      expect(summary.overtimeCount, 0);
      expect(
        metrics.map((metric) => metric.label).toList(growable: false),
        const <String>[
          'Terlambat',
          'Kurang Jam',
          'Break Lebih',
          'Tidak Hadir',
          'Lembur',
        ],
      );
      expect(
        semantics.legendTags,
        const <String>['TLT', 'KJG', 'BRK', 'ABS', 'OT', 'ME'],
      );
      expect(metrics.first.tag, PayrollMatrixSemantics.lateTag);
      expect(metrics.first.value, 1);
      expect(metrics.first.fillColorHex, '#FEF3C7');
      expect(metrics.first.textColorHex, '#92400E');
    });
  });
}
