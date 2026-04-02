import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';
import 'package:absensi_enakko_flutter/services/payroll_matrix_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Employee buildEmployee({
    required String id,
    required String name,
    required EmployeeContract contract,
    bool isActive = true,
    DateTime? archivedAt,
  }) {
    return Employee(
      id: id,
      name: name,
      employeeCode: 'EMP-$id',
      homeOutletId: 'outlet-1',
      isActive: isActive,
      createdAt: '2026-03-01T00:00:00Z',
      updatedAt: '2026-03-01T00:00:00Z',
      archivedAt: archivedAt,
      employmentContract: contract,
    );
  }

  AttendancePolicyRecapDay buildRecap({
    required String employeeId,
    required DateTime logicalDate,
    AttendancePolicyPrimaryStatus primaryStatus =
        AttendancePolicyPrimaryStatus.hadir,
    List<AttendancePolicySignal> detailSignals =
        const <AttendancePolicySignal>[],
    AttendancePolicyStatus attendanceStatus = AttendancePolicyStatus.hadir,
    DateTime? firstScanLocal,
    DateTime? lastPulangLocal,
    bool isLate = false,
    LateKind lateKind = LateKind.none,
    ShiftBand? shiftBand = ShiftBand.pagi,
    AttendancePolicySeverity primarySeverity = AttendancePolicySeverity.info,
    int requiredWorkMinutes = 540,
    int netWorkMinutes = 540,
    int totalBreakMinutes = 30,
    int overtimeMinutes = 0,
    int shortWorkMinutes = 0,
    int excessBreakMinutes = 0,
  }) {
    return AttendancePolicyRecapDay(
      logicalDate: logicalDate,
      employeeId: employeeId,
      employeeName: 'Employee $employeeId',
      outletId: 'outlet-1',
      outletName: 'Outlet Utama',
      shiftBand: shiftBand,
      requiredWorkMinutes: requiredWorkMinutes,
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
      netWorkMinutes: netWorkMinutes,
      totalBreakMinutes: totalBreakMinutes,
      overtimeMinutes: overtimeMinutes,
      shortWorkMinutes: shortWorkMinutes,
      excessBreakMinutes: excessBreakMinutes,
      pairedBreakCount: 1,
    );
  }

  test(
      'buildPayrollMatrix filters archived employees and sorts FULLTIME then PARTTIME',
      () {
    final dataset = buildPayrollMatrix(
      startDate: DateTime(2026, 3, 25),
      endDate: DateTime(2026, 3, 27),
      employees: <Employee>[
        buildEmployee(
          id: 'part-b',
          name: 'Budi',
          contract: EmployeeContract.parttime,
        ),
        buildEmployee(
          id: 'full-c',
          name: 'Cici',
          contract: EmployeeContract.fulltime,
          archivedAt: DateTime(2026, 3, 20),
        ),
        buildEmployee(
          id: 'full-a',
          name: 'Ayu',
          contract: EmployeeContract.fulltime,
        ),
        buildEmployee(
          id: 'inactive',
          name: 'Dedi',
          contract: EmployeeContract.fulltime,
          isActive: false,
        ),
      ],
      recapRows: <AttendancePolicyRecapDay>[
        buildRecap(
          employeeId: 'full-a',
          logicalDate: DateTime(2026, 3, 25),
          primaryStatus: AttendancePolicyPrimaryStatus.late,
          detailSignals: const <AttendancePolicySignal>[
            AttendancePolicySignal.late,
          ],
          firstScanLocal: DateTime(2026, 3, 25, 7, 10),
          lastPulangLocal: DateTime(2026, 3, 25, 17, 0),
          isLate: true,
          lateKind: LateKind.normal,
        ),
        buildRecap(
          employeeId: 'part-b',
          logicalDate: DateTime(2026, 3, 26),
          primaryStatus: AttendancePolicyPrimaryStatus.overtime,
          detailSignals: const <AttendancePolicySignal>[
            AttendancePolicySignal.overtime,
          ],
          firstScanLocal: DateTime(2026, 3, 26, 10, 0),
          lastPulangLocal: DateTime(2026, 3, 26, 19, 0),
        ),
      ],
    );

    expect(dataset.dates, hasLength(3));
    expect(dataset.rows.map((row) => row.employeeName).toList(), <String>[
      'Ayu',
      'Budi',
    ]);
    expect(dataset.rows.first.employmentContract, EmployeeContract.fulltime);
    expect(dataset.rows.last.employmentContract, EmployeeContract.parttime);
  });

  test(
      'buildPayrollMatrix creates one cell per date with placeholders for missing rows',
      () {
    final dataset = buildPayrollMatrix(
      startDate: DateTime(2026, 3, 25),
      endDate: DateTime(2026, 3, 27),
      employees: <Employee>[
        buildEmployee(
          id: 'full-a',
          name: 'Ayu',
          contract: EmployeeContract.fulltime,
        ),
      ],
      recapRows: <AttendancePolicyRecapDay>[
        buildRecap(
          employeeId: 'full-a',
          logicalDate: DateTime(2026, 3, 26),
          primaryStatus: AttendancePolicyPrimaryStatus.absence,
          attendanceStatus: AttendancePolicyStatus.tidakHadir,
        ),
      ],
    );

    final row = dataset.rows.single;

    expect(row.cells, hasLength(3));
    expect(row.cells[0].primaryLabel, '-');
    expect(row.cells[1].primaryLabel, 'Tidak Hadir');
    expect(row.cells[2].primaryLabel, '-');
    expect(row.absenceCount, 1);
  });

  test('fallback hadir tanpa jadwal rows render as populated matrix cells', () {
    final dataset = buildPayrollMatrix(
      startDate: DateTime(2026, 3, 25),
      endDate: DateTime(2026, 3, 25),
      employees: <Employee>[
        buildEmployee(
          id: 'fallback-1',
          name: 'Bima',
          contract: EmployeeContract.parttime,
        ),
      ],
      recapRows: <AttendancePolicyRecapDay>[
        buildRecap(
          employeeId: 'fallback-1',
          logicalDate: DateTime(2026, 3, 25),
          primaryStatus: AttendancePolicyPrimaryStatus.hadirTanpaJadwal,
          attendanceStatus: AttendancePolicyStatus.hadirTanpaJadwal,
          detailSignals: const <AttendancePolicySignal>[
            AttendancePolicySignal.hadirTanpaJadwal,
            AttendancePolicySignal.shortWork,
          ],
          shiftBand: null,
          firstScanLocal: DateTime(2026, 3, 25, 7, 0),
          lastPulangLocal: DateTime(2026, 3, 25, 15, 30),
          primarySeverity: AttendancePolicySeverity.info,
          shortWorkMinutes: 90,
          netWorkMinutes: 450,
          totalBreakMinutes: 30,
        ),
      ],
    );

    final row = dataset.rows.single;

    expect(row.cells.single.hasData, isTrue);
    expect(row.cells.single.primaryLabel, 'Hadir tanpa jadwal');
    expect(row.cells.single.secondaryTags, contains('KJG'));
    expect(row.cells.single.primaryLabel, isNot('-'));
  });

  test('mixed strict and fallback rows share one overnight-safe logical date',
      () {
    final dataset = buildPayrollMatrix(
      startDate: DateTime(2026, 3, 25),
      endDate: DateTime(2026, 3, 26),
      employees: <Employee>[
        buildEmployee(
          id: 'overnight-1',
          name: 'Citra',
          contract: EmployeeContract.fulltime,
        ),
      ],
      recapRows: <AttendancePolicyRecapDay>[
        buildRecap(
          employeeId: 'overnight-1',
          logicalDate: DateTime(2026, 3, 25),
          primaryStatus: AttendancePolicyPrimaryStatus.overtime,
          attendanceStatus: AttendancePolicyStatus.hadirTanpaJadwal,
          detailSignals: const <AttendancePolicySignal>[
            AttendancePolicySignal.hadirTanpaJadwal,
            AttendancePolicySignal.overtime,
          ],
          shiftBand: null,
          firstScanLocal: DateTime(2026, 3, 25, 15, 0),
          lastPulangLocal: DateTime(2026, 3, 26, 1, 30),
          primarySeverity: AttendancePolicySeverity.yellow,
          netWorkMinutes: 600,
          totalBreakMinutes: 60,
          overtimeMinutes: 60,
        ),
        buildRecap(
          employeeId: 'overnight-1',
          logicalDate: DateTime(2026, 3, 26),
          primaryStatus: AttendancePolicyPrimaryStatus.hadir,
          attendanceStatus: AttendancePolicyStatus.hadir,
          firstScanLocal: DateTime(2026, 3, 26, 9, 0),
          lastPulangLocal: DateTime(2026, 3, 26, 17, 0),
        ),
      ],
    );

    final row = dataset.rows.single;

    expect(row.cells, hasLength(2));
    expect(row.cells[0].primaryLabel, '15:00 / 01:30');
    expect(row.cells[1].primaryLabel, '09:00 / 17:00');
    expect(row.overtimeCount, 1);
  });
}
