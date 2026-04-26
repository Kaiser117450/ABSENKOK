import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/outlet_operating_mode.dart';
import 'package:absensi_enakko_flutter/services/admin_policy_recap_dataset_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    String outletId = 'outlet-1',
  }) {
    return AttendanceLog(
      id: id,
      employeeId: employeeId,
      scanOutletId: outletId,
      type: type,
      scannedAt: scannedAt,
      createdAt: scannedAt,
    );
  }

  AttendancePolicyRecapDay buildStrictRow({
    required Employee employee,
    required DateTime logicalDate,
    AttendancePolicyStatus attendanceStatus = AttendancePolicyStatus.hadir,
    AttendancePolicyPrimaryStatus primaryStatus =
        AttendancePolicyPrimaryStatus.hadir,
    AttendancePolicySeverity primarySeverity = AttendancePolicySeverity.info,
    List<AttendancePolicySignal> detailSignals =
        const <AttendancePolicySignal>[],
  }) {
    return AttendancePolicyRecapDay(
      logicalDate: logicalDate,
      employeeId: employee.id,
      employeeName: employee.name,
      outletId: 'outlet-1',
      outletName: 'Outlet Utama',
      shiftBand: null,
      requiredWorkMinutes:
          employee.employmentContract == EmployeeContract.parttime ? 540 : 600,
      lateCutoffLocal: '07:00',
      attendanceStatus: attendanceStatus,
      lateKind: detailSignals.contains(AttendancePolicySignal.late)
          ? LateKind.normal
          : LateKind.none,
      isLate: detailSignals.contains(AttendancePolicySignal.late),
      firstScanLocal: DateTime(2026, 3, 25, 7, 0),
      firstBreakLocal: null,
      lastPulangLocal: DateTime(2026, 3, 25, 17, 0),
      notes: 'strict',
      primaryStatus: primaryStatus,
      primarySeverity: primarySeverity,
      detailSignals: detailSignals,
      detailNotes: const <String>['strict'],
      logicalDayComplete: true,
      netWorkMinutes: 600,
      totalBreakMinutes: 0,
      overtimeMinutes: 0,
      shortWorkMinutes: 0,
      excessBreakMinutes: 0,
      pairedBreakCount: 0,
    );
  }

  group('AdminPolicyRecapDatasetService', () {
    const service = AdminPolicyRecapDatasetService();

    test('injects a fallback row when strict rows are empty', () {
      final ayu = buildEmployee(
        id: 'emp-01',
        name: 'Ayu',
        contract: EmployeeContract.fulltime,
      );

      final result = service.build(
        employees: <Employee>[ayu],
        strictRows: const <AttendancePolicyRecapDay>[],
        attendanceLogs: <AttendanceLog>[
          buildLog(
            id: 'ayu-in',
            employeeId: ayu.id,
            type: AttendanceType.masuk,
            scannedAt: '2026-03-25T07:00:00+08:00',
          ),
          buildLog(
            id: 'ayu-out',
            employeeId: ayu.id,
            type: AttendanceType.pulang,
            scannedAt: '2026-03-25T17:10:00+08:00',
          ),
        ],
        outletId: 'outlet-1',
        outletName: 'Outlet Utama',
        outletOperatingMode: OutletOperatingMode.normal,
        now: DateTime(2026, 3, 26, 10),
      );

      expect(result.strictRows, isEmpty);
      expect(result.fallbackRows, hasLength(1));
      expect(result.mergedRows, hasLength(1));
      expect(result.fallbackRows, isNotEmpty);

      final fallbackRow = result.fallbackRows.single;
      expect(fallbackRow.employeeId, ayu.id);
      expect(fallbackRow.logicalDate, DateTime(2026, 3, 25));
      expect(
        fallbackRow.attendanceStatus,
        AttendancePolicyStatus.hadirTanpaJadwal,
      );
      expect(fallbackRow.lateCutoffLocal, isNull);
    });

    test(
        'keeps strict rows on duplicate keys and adds only missing fallback keys',
        () {
      final ayu = buildEmployee(
        id: 'emp-01',
        name: 'Ayu',
        contract: EmployeeContract.fulltime,
      );
      final budi = buildEmployee(
        id: 'emp-02',
        name: 'Budi',
        contract: EmployeeContract.parttime,
      );
      final strictRow = buildStrictRow(
        employee: ayu,
        logicalDate: DateTime(2026, 3, 25),
        primaryStatus: AttendancePolicyPrimaryStatus.late,
        primarySeverity: AttendancePolicySeverity.red,
        detailSignals: const <AttendancePolicySignal>[
          AttendancePolicySignal.late,
        ],
      );

      final result = service.build(
        employees: <Employee>[ayu, budi],
        strictRows: <AttendancePolicyRecapDay>[strictRow],
        attendanceLogs: <AttendanceLog>[
          buildLog(
            id: 'ayu-in',
            employeeId: ayu.id,
            type: AttendanceType.masuk,
            scannedAt: '2026-03-25T07:15:00+08:00',
          ),
          buildLog(
            id: 'ayu-out',
            employeeId: ayu.id,
            type: AttendanceType.pulang,
            scannedAt: '2026-03-25T17:00:00+08:00',
          ),
          buildLog(
            id: 'budi-in',
            employeeId: budi.id,
            type: AttendanceType.masuk,
            scannedAt: '2026-03-25T08:00:00+08:00',
          ),
          buildLog(
            id: 'budi-out',
            employeeId: budi.id,
            type: AttendanceType.pulang,
            scannedAt: '2026-03-25T16:30:00+08:00',
          ),
        ],
        outletId: 'outlet-1',
        outletName: 'Outlet Utama',
        outletOperatingMode: OutletOperatingMode.normal,
        now: DateTime(2026, 3, 26, 10),
      );

      expect(result.strictRows, hasLength(1));
      expect(result.fallbackRows, hasLength(1));
      expect(result.mergedRows, hasLength(2));
      expect(result.fallbackRows, isNotEmpty);

      expect(
        result.mergedRows.map((row) => row.employeeName).toList(),
        <String>['Ayu', 'Budi'],
      );
      expect(result.mergedRows.first.primaryStatus,
          AttendancePolicyPrimaryStatus.late);
      expect(
        result.mergedRows.first.detailSignals,
        contains(AttendancePolicySignal.late),
      );
      expect(result.mergedRows.last.employeeId, budi.id);
    });

    test(
        'keeps overnight twenty-four-hour fallback rows on the prior logical date',
        () {
      final ayu = buildEmployee(
        id: 'emp-01',
        name: 'Ayu',
        contract: EmployeeContract.fulltime,
      );
      final citra = buildEmployee(
        id: 'emp-03',
        name: 'Citra',
        contract: EmployeeContract.parttime,
      );
      final strictRow = buildStrictRow(
        employee: ayu,
        logicalDate: DateTime(2026, 3, 25),
      );

      final result = service.build(
        employees: <Employee>[ayu, citra],
        strictRows: <AttendancePolicyRecapDay>[strictRow],
        attendanceLogs: <AttendanceLog>[
          buildLog(
            id: 'citra-in',
            employeeId: citra.id,
            type: AttendanceType.masuk,
            scannedAt: '2026-03-25T15:00:00+08:00',
          ),
          buildLog(
            id: 'citra-break',
            employeeId: citra.id,
            type: AttendanceType.breakTime,
            scannedAt: '2026-03-25T23:30:00+08:00',
          ),
          buildLog(
            id: 'citra-back',
            employeeId: citra.id,
            type: AttendanceType.kembali,
            scannedAt: '2026-03-26T00:30:00+08:00',
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

      expect(result.mergedRows, hasLength(2));
      expect(
        result.mergedRows
            .where((row) => row.employeeId == citra.id)
            .single
            .logicalDate,
        DateTime(2026, 3, 25),
      );
      expect(
        result.mergedRows
            .where((row) => row.logicalDate == DateTime(2026, 3, 26)),
        isEmpty,
      );
    });

    test('does not inject fallback rows when strict rows already cover logs',
        () {
      final ayu = buildEmployee(
        id: 'emp-01',
        name: 'Ayu',
        contract: EmployeeContract.fulltime,
      );
      final strictRow = buildStrictRow(
        employee: ayu,
        logicalDate: DateTime(2026, 3, 25),
      );

      final result = service.build(
        employees: <Employee>[ayu],
        strictRows: <AttendancePolicyRecapDay>[strictRow],
        attendanceLogs: <AttendanceLog>[
          buildLog(
            id: 'ayu-in',
            employeeId: ayu.id,
            type: AttendanceType.masuk,
            scannedAt: '2026-03-25T07:00:00+08:00',
          ),
          buildLog(
            id: 'ayu-out',
            employeeId: ayu.id,
            type: AttendanceType.pulang,
            scannedAt: '2026-03-25T17:00:00+08:00',
          ),
        ],
        outletId: 'outlet-1',
        outletName: 'Outlet Utama',
        outletOperatingMode: OutletOperatingMode.normal,
        now: DateTime(2026, 3, 26, 10),
      );

      expect(result.strictRows, hasLength(1));
      expect(result.fallbackRows, isEmpty);
      expect(result.mergedRows, hasLength(1));
      expect(result.mergedRows.single.primaryStatus,
          AttendancePolicyPrimaryStatus.hadir);
      expect(result.mergedRows.single.lateCutoffLocal, '07:00');
    });
  });
}
