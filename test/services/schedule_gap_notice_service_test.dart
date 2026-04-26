import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/outlet_operating_mode.dart';
import 'package:absensi_enakko_flutter/services/admin_policy_recap_dataset_service.dart';
import 'package:absensi_enakko_flutter/services/schedule_gap_notice_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Employee buildEmployee({
    required String id,
    required String name,
    String outletId = 'outlet-1',
  }) {
    return Employee(
      id: id,
      name: name,
      homeOutletId: outletId,
      isActive: true,
      createdAt: '2026-04-01T00:00:00Z',
      updatedAt: '2026-04-01T00:00:00Z',
      employmentContract: EmployeeContract.fulltime,
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

  AttendancePolicyRecapDay buildFallbackRow({
    required String employeeId,
    required String employeeName,
    required DateTime logicalDate,
    String outletId = 'outlet-1',
    String outletName = 'Outlet Utama',
  }) {
    return AttendancePolicyRecapDay(
      logicalDate: logicalDate,
      employeeId: employeeId,
      employeeName: employeeName,
      outletId: outletId,
      outletName: outletName,
      shiftBand: null,
      requiredWorkMinutes: 600,
      lateCutoffLocal: null,
      attendanceStatus: AttendancePolicyStatus.hadirTanpaJadwal,
      lateKind: LateKind.none,
      isLate: false,
      firstScanLocal: DateTime(
        logicalDate.year,
        logicalDate.month,
        logicalDate.day,
        7,
      ),
      firstBreakLocal: null,
      lastPulangLocal: DateTime(
        logicalDate.year,
        logicalDate.month,
        logicalDate.day,
        16,
      ),
      notes: null,
      primaryStatus: AttendancePolicyPrimaryStatus.hadirTanpaJadwal,
      primarySeverity: AttendancePolicySeverity.info,
      logicalDayComplete: true,
      netWorkMinutes: 540,
      totalBreakMinutes: 30,
      overtimeMinutes: 0,
      shortWorkMinutes: 0,
      excessBreakMinutes: 0,
      pairedBreakCount: 1,
    );
  }

  group('ScheduleGapNoticeService', () {
    test(
        'returns count == 0 and hasNotices == false when fallback rows are empty',
        () {
      final service = ScheduleGapNoticeService(
        datasetService: FakeAdminPolicyRecapDatasetService(
          const AdminPolicyRecapDatasetResult(
            mergedRows: <AttendancePolicyRecapDay>[],
            strictRows: <AttendancePolicyRecapDay>[],
            fallbackRows: <AttendancePolicyRecapDay>[],
          ),
        ),
      );

      final result = service.build(
        employees: <Employee>[buildEmployee(id: 'emp-1', name: 'Ayu')],
        strictRows: const <AttendancePolicyRecapDay>[],
        attendanceLogs: const <AttendanceLog>[],
        outletId: 'outlet-1',
        outletName: 'Outlet Utama',
        outletOperatingMode: OutletOperatingMode.normal,
        now: DateTime(2026, 4, 1, 10),
      );

      expect(result.count, 0);
      expect(result.hasNotices, isFalse);
      expect(result.entries, isEmpty);
    });

    test('maps one fallback row into one notice with the locked copy', () {
      final service = ScheduleGapNoticeService(
        datasetService: FakeAdminPolicyRecapDatasetService(
          AdminPolicyRecapDatasetResult(
            mergedRows: <AttendancePolicyRecapDay>[
              buildFallbackRow(
                employeeId: 'emp-1',
                employeeName: 'Ayu',
                logicalDate: DateTime(2026, 3, 31),
              ),
            ],
            strictRows: const <AttendancePolicyRecapDay>[],
            fallbackRows: <AttendancePolicyRecapDay>[
              buildFallbackRow(
                employeeId: 'emp-1',
                employeeName: 'Ayu',
                logicalDate: DateTime(2026, 3, 31),
              ),
            ],
          ),
        ),
      );

      final result = service.build(
        employees: <Employee>[buildEmployee(id: 'emp-1', name: 'Ayu')],
        strictRows: const <AttendancePolicyRecapDay>[],
        attendanceLogs: const <AttendanceLog>[],
        outletId: 'outlet-1',
        outletName: 'Outlet Utama',
        outletOperatingMode: OutletOperatingMode.normal,
        now: DateTime(2026, 4, 1, 10),
      );

      expect(result.count, 1);
      expect(result.hasNotices, isTrue);
      expect(result.entries.single.employeeId, 'emp-1');
      expect(result.entries.single.employeeName, 'Ayu');
      expect(result.entries.single.logicalDate, DateTime(2026, 3, 31));
      expect(result.entries.single.statusLabel, kScheduleGapNoticeStatusLabel);
      expect(result.entries.single.helperText, kScheduleGapNoticeHelperText);
    });

    test(
        'strict row plus fallback row yields only the fallback-backed notice date',
        () {
      final strictRow = buildFallbackRow(
        employeeId: 'emp-1',
        employeeName: 'Ayu',
        logicalDate: DateTime(2026, 3, 30),
      );
      final fallbackRow = buildFallbackRow(
        employeeId: 'emp-1',
        employeeName: 'Ayu',
        logicalDate: DateTime(2026, 3, 31),
      );
      final service = ScheduleGapNoticeService(
        datasetService: FakeAdminPolicyRecapDatasetService(
          AdminPolicyRecapDatasetResult(
            mergedRows: <AttendancePolicyRecapDay>[strictRow, fallbackRow],
            strictRows: <AttendancePolicyRecapDay>[strictRow],
            fallbackRows: <AttendancePolicyRecapDay>[fallbackRow],
          ),
        ),
      );

      final result = service.build(
        employees: <Employee>[buildEmployee(id: 'emp-1', name: 'Ayu')],
        strictRows: <AttendancePolicyRecapDay>[strictRow],
        attendanceLogs: const <AttendanceLog>[],
        outletId: 'outlet-1',
        outletName: 'Outlet Utama',
        outletOperatingMode: OutletOperatingMode.normal,
        now: DateTime(2026, 4, 1, 10),
      );

      expect(result.count, 1);
      expect(result.entries.single.logicalDate, DateTime(2026, 3, 31));
    });

    test('attendance logs from another outlet do not leak into notice results',
        () {
      const service = ScheduleGapNoticeService();
      final employee = buildEmployee(id: 'emp-1', name: 'Ayu');

      final result = service.build(
        employees: <Employee>[employee],
        strictRows: const <AttendancePolicyRecapDay>[],
        attendanceLogs: <AttendanceLog>[
          buildLog(
            id: 'ayu-in',
            employeeId: employee.id,
            type: AttendanceType.masuk,
            scannedAt: '2026-03-31T07:00:00+08:00',
            outletId: 'outlet-2',
          ),
          buildLog(
            id: 'ayu-out',
            employeeId: employee.id,
            type: AttendanceType.pulang,
            scannedAt: '2026-03-31T16:00:00+08:00',
            outletId: 'outlet-2',
          ),
        ],
        outletId: 'outlet-1',
        outletName: 'Outlet Utama',
        outletOperatingMode: OutletOperatingMode.normal,
        now: DateTime(2026, 4, 1, 10),
      );

      expect(result.count, 0);
      expect(result.hasNotices, isFalse);
    });

    test(
        'deduplicates fallback rows and sorts newest dates first, then employee name',
        () {
      final service = ScheduleGapNoticeService(
        datasetService: FakeAdminPolicyRecapDatasetService(
          AdminPolicyRecapDatasetResult(
            mergedRows: <AttendancePolicyRecapDay>[
              buildFallbackRow(
                employeeId: 'emp-2',
                employeeName: 'Budi',
                logicalDate: DateTime(2026, 3, 30),
              ),
              buildFallbackRow(
                employeeId: 'emp-1',
                employeeName: 'Ayu',
                logicalDate: DateTime(2026, 3, 31),
              ),
              buildFallbackRow(
                employeeId: 'emp-1',
                employeeName: 'Ayu',
                logicalDate: DateTime(2026, 3, 31),
              ),
              buildFallbackRow(
                employeeId: 'emp-3',
                employeeName: 'Cici',
                logicalDate: DateTime(2026, 3, 31),
              ),
            ],
            strictRows: const <AttendancePolicyRecapDay>[],
            fallbackRows: <AttendancePolicyRecapDay>[
              buildFallbackRow(
                employeeId: 'emp-2',
                employeeName: 'Budi',
                logicalDate: DateTime(2026, 3, 30),
              ),
              buildFallbackRow(
                employeeId: 'emp-1',
                employeeName: 'Ayu',
                logicalDate: DateTime(2026, 3, 31),
              ),
              buildFallbackRow(
                employeeId: 'emp-1',
                employeeName: 'Ayu',
                logicalDate: DateTime(2026, 3, 31),
              ),
              buildFallbackRow(
                employeeId: 'emp-3',
                employeeName: 'Cici',
                logicalDate: DateTime(2026, 3, 31),
              ),
            ],
          ),
        ),
      );

      final result = service.build(
        employees: <Employee>[
          buildEmployee(id: 'emp-1', name: 'Ayu'),
          buildEmployee(id: 'emp-2', name: 'Budi'),
          buildEmployee(id: 'emp-3', name: 'Cici'),
        ],
        strictRows: const <AttendancePolicyRecapDay>[],
        attendanceLogs: const <AttendanceLog>[],
        outletId: 'outlet-1',
        outletName: 'Outlet Utama',
        outletOperatingMode: OutletOperatingMode.normal,
        now: DateTime(2026, 4, 1, 10),
      );

      expect(result.count, 3);
      expect(
        result.entries.map((entry) =>
            '${entry.employeeName}|${entry.logicalDate.toIso8601String()}'),
        <String>[
          'Ayu|2026-03-31T00:00:00.000',
          'Cici|2026-03-31T00:00:00.000',
          'Budi|2026-03-30T00:00:00.000',
        ],
      );
    });
  });
}

class FakeAdminPolicyRecapDatasetService
    extends AdminPolicyRecapDatasetService {
  FakeAdminPolicyRecapDatasetService(this.result);

  final AdminPolicyRecapDatasetResult result;

  @override
  AdminPolicyRecapDatasetResult build({
    required Iterable<Employee> employees,
    required Iterable<AttendancePolicyRecapDay> strictRows,
    required Iterable<AttendanceLog> attendanceLogs,
    required String outletId,
    required String outletName,
    required OutletOperatingMode outletOperatingMode,
    DateTime? now,
  }) {
    return result;
  }
}
