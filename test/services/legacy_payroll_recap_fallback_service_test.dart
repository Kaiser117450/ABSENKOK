import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/outlet_operating_mode.dart';
import 'package:absensi_enakko_flutter/services/legacy_payroll_recap_fallback_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Employee buildEmployee({
    required String id,
    required EmployeeContract contract,
  }) {
    return Employee(
      id: id,
      name: 'Employee $id',
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
    String? notes,
  }) {
    return AttendanceLog(
      id: id,
      employeeId: employeeId,
      scanOutletId: 'outlet-1',
      type: type,
      scannedAt: scannedAt,
      createdAt: scannedAt,
      notes: notes,
    );
  }

  AttendancePolicyRecapDay buildStrictRow({
    required String employeeId,
    required DateTime logicalDate,
  }) {
    return AttendancePolicyRecapDay(
      logicalDate: logicalDate,
      employeeId: employeeId,
      employeeName: 'Employee $employeeId',
      outletId: 'outlet-1',
      outletName: 'Outlet Utama',
      shiftBand: null,
      requiredWorkMinutes: 540,
      lateCutoffLocal: null,
      breakFirstDeadlineLocal: null,
      attendanceStatus: AttendancePolicyStatus.hadirTanpaJadwal,
      lateKind: LateKind.none,
      isLate: false,
      breakFirstEligible: false,
      breakFirstConfirmed: false,
      firstScanLocal: DateTime(2026, 3, 25, 7, 0),
      firstBreakLocal: null,
      lastPulangLocal: DateTime(2026, 3, 25, 17, 0),
      notes: null,
      primaryStatus: AttendancePolicyPrimaryStatus.hadirTanpaJadwal,
      primarySeverity: AttendancePolicySeverity.info,
      detailSignals: const [],
      detailNotes: const [],
      logicalDayComplete: true,
      netWorkMinutes: 540,
      totalBreakMinutes: 0,
      overtimeMinutes: 0,
      shortWorkMinutes: 0,
      excessBreakMinutes: 0,
      pairedBreakCount: 0,
    );
  }

  group('LegacyPayrollRecapFallbackService', () {
    const service = LegacyPayrollRecapFallbackService();

    test('derives different required work minutes from employee contract', () {
      final fulltime = buildEmployee(
        id: 'emp-full',
        contract: EmployeeContract.fulltime,
      );
      final parttime = buildEmployee(
        id: 'emp-part',
        contract: EmployeeContract.parttime,
      );
      final employeesById = <String, Employee>{
        fulltime.id: fulltime,
        parttime.id: parttime,
      };
      final sourceDays = service.buildSourceDays(
        logs: <AttendanceLog>[
          buildLog(
            id: 'full-in',
            employeeId: fulltime.id,
            type: AttendanceType.masuk,
            scannedAt: '2026-03-25T07:00:00+08:00',
          ),
          buildLog(
            id: 'full-out',
            employeeId: fulltime.id,
            type: AttendanceType.pulang,
            scannedAt: '2026-03-25T17:00:00+08:00',
          ),
          buildLog(
            id: 'part-in',
            employeeId: parttime.id,
            type: AttendanceType.masuk,
            scannedAt: '2026-03-25T07:00:00+08:00',
          ),
          buildLog(
            id: 'part-out',
            employeeId: parttime.id,
            type: AttendanceType.pulang,
            scannedAt: '2026-03-25T17:00:00+08:00',
          ),
        ],
        employeesById: employeesById,
        outletId: 'outlet-1',
        outletName: 'Outlet Utama',
        outletOperatingMode: OutletOperatingMode.normal,
      );

      final rows = service.synthesizeMissingRows(
        sourceDays: sourceDays,
        strictRows: const <AttendancePolicyRecapDay>[],
        now: DateTime(2026, 3, 26, 10),
      );

      final fulltimeRow =
          rows.firstWhere((row) => row.employeeId == fulltime.id);
      final parttimeRow =
          rows.firstWhere((row) => row.employeeId == parttime.id);

      expect(fulltimeRow.requiredWorkMinutes, 600);
      expect(parttimeRow.requiredWorkMinutes, 540);
      expect(parttimeRow.overtimeMinutes, 60);
      expect(fulltimeRow.overtimeMinutes, 0);
    });

    test('uses relaxed break allowance for overtime legacy rows', () {
      final employee = buildEmployee(
        id: 'emp-part',
        contract: EmployeeContract.parttime,
      );
      final sourceDays = service.buildSourceDays(
        logs: <AttendanceLog>[
          buildLog(
            id: 'in',
            employeeId: employee.id,
            type: AttendanceType.masuk,
            scannedAt: '2026-03-25T07:00:00+08:00',
          ),
          buildLog(
            id: 'break',
            employeeId: employee.id,
            type: AttendanceType.breakTime,
            scannedAt: '2026-03-25T12:00:00+08:00',
          ),
          buildLog(
            id: 'back',
            employeeId: employee.id,
            type: AttendanceType.kembali,
            scannedAt: '2026-03-25T14:00:00+08:00',
          ),
          buildLog(
            id: 'out',
            employeeId: employee.id,
            type: AttendanceType.pulang,
            scannedAt: '2026-03-25T19:00:00+08:00',
          ),
        ],
        employeesById: <String, Employee>{employee.id: employee},
        outletId: 'outlet-1',
        outletName: 'Outlet Utama',
        outletOperatingMode: OutletOperatingMode.normal,
      );

      final row = service
          .synthesizeMissingRows(
            sourceDays: sourceDays,
            strictRows: const <AttendancePolicyRecapDay>[],
            now: DateTime(2026, 3, 26, 10),
          )
          .single;

      expect(row.overtimeMinutes, 60);
      expect(row.totalBreakMinutes, 120);
      expect(row.excessBreakMinutes, 0);
    });

    test('builds overnight-safe source days for twenty-four-hour outlets', () {
      final employee = buildEmployee(
        id: 'emp-24h',
        contract: EmployeeContract.fulltime,
      );

      final sourceDays = service.buildSourceDays(
        logs: <AttendanceLog>[
          buildLog(
            id: 'in',
            employeeId: employee.id,
            type: AttendanceType.masuk,
            scannedAt: '2026-03-25T15:00:00+08:00',
          ),
          buildLog(
            id: 'break',
            employeeId: employee.id,
            type: AttendanceType.breakTime,
            scannedAt: '2026-03-25T23:30:00+08:00',
          ),
          buildLog(
            id: 'back',
            employeeId: employee.id,
            type: AttendanceType.kembali,
            scannedAt: '2026-03-26T00:30:00+08:00',
          ),
          buildLog(
            id: 'out',
            employeeId: employee.id,
            type: AttendanceType.pulang,
            scannedAt: '2026-03-26T01:30:00+08:00',
          ),
        ],
        employeesById: <String, Employee>{employee.id: employee},
        outletId: 'outlet-1',
        outletName: 'Outlet 24 Jam',
        outletOperatingMode: OutletOperatingMode.twentyFourHour,
      );

      expect(sourceDays, hasLength(1));
      expect(sourceDays.single.logicalDate, DateTime(2026, 3, 25));
      expect(sourceDays.single.logs, hasLength(4));
    });

    test('skips strict keys and never fabricates late or absence signals', () {
      final employee = buildEmployee(
        id: 'emp-1',
        contract: EmployeeContract.fulltime,
      );
      final sourceDays = service.buildSourceDays(
        logs: <AttendanceLog>[
          buildLog(
            id: 'in',
            employeeId: employee.id,
            type: AttendanceType.masuk,
            scannedAt: '2026-03-25T07:00:00+08:00',
          ),
          buildLog(
            id: 'out',
            employeeId: employee.id,
            type: AttendanceType.pulang,
            scannedAt: '2026-03-25T17:00:00+08:00',
          ),
        ],
        employeesById: <String, Employee>{employee.id: employee},
        outletId: 'outlet-1',
        outletName: 'Outlet Utama',
        outletOperatingMode: OutletOperatingMode.normal,
      );

      final strictRows = <AttendancePolicyRecapDay>[
        buildStrictRow(
          employeeId: employee.id,
          logicalDate: DateTime(2026, 3, 25),
        ),
      ];
      final skipped = service.synthesizeMissingRows(
        sourceDays: sourceDays,
        strictRows: strictRows,
        now: DateTime(2026, 3, 26, 10),
      );
      expect(skipped, isEmpty);

      final row = service
          .synthesizeMissingRows(
            sourceDays: sourceDays,
            strictRows: const <AttendancePolicyRecapDay>[],
            now: DateTime(2026, 3, 26, 10),
          )
          .single;

      expect(row.lateCutoffLocal, isNull);
      expect(row.breakFirstDeadlineLocal, isNull);
      expect(row.isLate, isFalse);
      expect(row.lateKind, LateKind.none);
      expect(row.detailSignals, isNot(contains(AttendancePolicySignal.late)));
      expect(
          row.detailSignals, isNot(contains(AttendancePolicySignal.absence)));
    });

    test('marks missing pulang as an honest incomplete legacy day', () {
      final employee = buildEmployee(
        id: 'emp-incomplete',
        contract: EmployeeContract.fulltime,
      );
      final sourceDays = service.buildSourceDays(
        logs: <AttendanceLog>[
          buildLog(
            id: 'in',
            employeeId: employee.id,
            type: AttendanceType.masuk,
            scannedAt: '2026-03-25T07:00:00+08:00',
          ),
          buildLog(
            id: 'break',
            employeeId: employee.id,
            type: AttendanceType.breakTime,
            scannedAt: '2026-03-25T12:00:00+08:00',
          ),
          buildLog(
            id: 'back',
            employeeId: employee.id,
            type: AttendanceType.kembali,
            scannedAt: '2026-03-25T12:30:00+08:00',
          ),
        ],
        employeesById: <String, Employee>{employee.id: employee},
        outletId: 'outlet-1',
        outletName: 'Outlet Utama',
        outletOperatingMode: OutletOperatingMode.normal,
      );

      final row = service
          .synthesizeMissingRows(
            sourceDays: sourceDays,
            strictRows: const <AttendancePolicyRecapDay>[],
            now: DateTime(2026, 3, 26, 10),
          )
          .single;

      expect(
        row.primaryStatus,
        AttendancePolicyPrimaryStatus.belumAbsenPulang,
      );
      expect(row.logicalDayComplete, isFalse);
      expect(
        row.detailSignals,
        contains(AttendancePolicySignal.belumAbsenPulang),
      );
      expect(
          row.detailSignals, contains(AttendancePolicySignal.hadirTanpaJadwal));
      expect(row.lateCutoffLocal, isNull);
    });
  });
}
