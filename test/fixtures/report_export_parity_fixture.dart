import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/outlet_operating_mode.dart';

class ReportExportParityExpectation {
  const ReportExportParityExpectation({
    required this.primaryLabel,
    required this.secondaryTags,
    required this.severityFamily,
    required this.isCompatibilityRow,
  });

  final String primaryLabel;
  final List<String> secondaryTags;
  final String severityFamily;
  final bool isCompatibilityRow;
}

class ReportExportParityFixtureBundle {
  const ReportExportParityFixtureBundle({
    required this.startDate,
    required this.endDate,
    required this.outletId,
    required this.outletName,
    required this.outletOperatingMode,
    required this.employees,
    required this.strictRows,
    required this.attendanceLogs,
    required this.expectationsByKey,
    required this.scenarioIds,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String outletId;
  final String outletName;
  final OutletOperatingMode outletOperatingMode;
  final List<Employee> employees;
  final List<AttendancePolicyRecapDay> strictRows;
  final List<AttendanceLog> attendanceLogs;
  final Map<String, ReportExportParityExpectation> expectationsByKey;
  final List<String> scenarioIds;
}

const List<String> reportExportParityScenarioIds = <String>[
  'full-time',
  'part-time',
  'overtime',
  'outlet-24-jam',
  'outlet-normal',
  'late-normal',
  'no-show',
  'legacy-fallback-no-schedule',
];

ReportExportParityFixtureBundle buildReportExportParityFixtureBundle() {
  const outletId = 'outlet-parity';
  const outletName = 'Outlet Parity';
  const outletOperatingMode = OutletOperatingMode.normal;

  final employees = <Employee>[
    _buildEmployee(
      id: 'emp-full-time',
      name: 'Ayu Full Time',
      contract: EmployeeContract.fulltime,
      outletId: outletId,
    ),
    _buildEmployee(
      id: 'emp-part-time',
      name: 'Bima Part Time',
      contract: EmployeeContract.parttime,
      outletId: outletId,
    ),
    _buildEmployee(
      id: 'emp-overtime',
      name: 'Citra Overtime',
      contract: EmployeeContract.fulltime,
      outletId: outletId,
    ),
    _buildEmployee(
      id: 'emp-outlet-24-jam',
      name: 'Dewi Overnight',
      contract: EmployeeContract.fulltime,
      outletId: outletId,
    ),
    _buildEmployee(
      id: 'emp-outlet-normal',
      name: 'Eka Outlet Normal',
      contract: EmployeeContract.fulltime,
      outletId: outletId,
    ),
    _buildEmployee(
      id: 'emp-late-normal',
      name: 'Farah Telat Normal',
      contract: EmployeeContract.parttime,
      outletId: outletId,
    ),
    _buildEmployee(
      id: 'emp-no-show',
      name: 'Gilang No Show',
      contract: EmployeeContract.fulltime,
      outletId: outletId,
    ),
    _buildEmployee(
      id: 'emp-legacy-fallback-no-schedule',
      name: 'Hana Tanpa Jadwal',
      contract: EmployeeContract.parttime,
      outletId: outletId,
    ),
  ];

  final employeeById = <String, Employee>{
    for (final employee in employees) employee.id: employee,
  };

  final strictRows = <AttendancePolicyRecapDay>[
    _buildStrictRow(
      employee: employeeById['emp-full-time']!,
      logicalDate: DateTime(2026, 3, 24),
      firstScanLocal: DateTime(2026, 3, 24, 7, 0),
      lastPulangLocal: DateTime(2026, 3, 24, 17, 0),
      primaryStatus: AttendancePolicyPrimaryStatus.hadir,
      primarySeverity: AttendancePolicySeverity.info,
      attendanceStatus: AttendancePolicyStatus.hadir,
      netWorkMinutes: 600,
    ),
    _buildStrictRow(
      employee: employeeById['emp-part-time']!,
      logicalDate: DateTime(2026, 3, 24),
      firstScanLocal: DateTime(2026, 3, 24, 8, 0),
      lastPulangLocal: DateTime(2026, 3, 24, 17, 0),
      primaryStatus: AttendancePolicyPrimaryStatus.hadir,
      primarySeverity: AttendancePolicySeverity.info,
      attendanceStatus: AttendancePolicyStatus.hadir,
      netWorkMinutes: 540,
    ),
    _buildStrictRow(
      employee: employeeById['emp-overtime']!,
      logicalDate: DateTime(2026, 3, 25),
      firstScanLocal: DateTime(2026, 3, 25, 7, 0),
      lastPulangLocal: DateTime(2026, 3, 25, 19, 15),
      primaryStatus: AttendancePolicyPrimaryStatus.overtime,
      primarySeverity: AttendancePolicySeverity.yellow,
      attendanceStatus: AttendancePolicyStatus.hadir,
      detailSignals: const <AttendancePolicySignal>[
        AttendancePolicySignal.overtime,
      ],
      overtimeMinutes: 135,
      netWorkMinutes: 735,
    ),
    _buildStrictRow(
      employee: employeeById['emp-outlet-24-jam']!,
      logicalDate: DateTime(2026, 3, 18),
      firstScanLocal: DateTime(2026, 3, 18, 15, 0),
      lastPulangLocal: DateTime(2026, 3, 19, 1, 20),
      primaryStatus: AttendancePolicyPrimaryStatus.late,
      primarySeverity: AttendancePolicySeverity.yellow,
      attendanceStatus: AttendancePolicyStatus.hadir,
      detailSignals: const <AttendancePolicySignal>[
        AttendancePolicySignal.late,
      ],
      lateKind: LateKind.normal,
      isLate: true,
      netWorkMinutes: 620,
    ),
    _buildStrictRow(
      employee: employeeById['emp-outlet-normal']!,
      logicalDate: DateTime(2026, 3, 26),
      firstScanLocal: DateTime(2026, 3, 26, 7, 5),
      lastPulangLocal: DateTime(2026, 3, 26, 17, 3),
      primaryStatus: AttendancePolicyPrimaryStatus.hadir,
      primarySeverity: AttendancePolicySeverity.info,
      attendanceStatus: AttendancePolicyStatus.hadir,
      netWorkMinutes: 598,
    ),
    _buildStrictRow(
      employee: employeeById['emp-late-normal']!,
      logicalDate: DateTime(2026, 3, 27),
      firstScanLocal: DateTime(2026, 3, 27, 10, 15),
      lastPulangLocal: DateTime(2026, 3, 27, 19, 15),
      primaryStatus: AttendancePolicyPrimaryStatus.late,
      primarySeverity: AttendancePolicySeverity.yellow,
      attendanceStatus: AttendancePolicyStatus.hadir,
      detailSignals: const <AttendancePolicySignal>[
        AttendancePolicySignal.late,
      ],
      lateKind: LateKind.normal,
      isLate: true,
      netWorkMinutes: 540,
    ),
    _buildStrictRow(
      employee: employeeById['emp-no-show']!,
      logicalDate: DateTime(2026, 3, 28),
      firstScanLocal: null,
      lastPulangLocal: null,
      primaryStatus: AttendancePolicyPrimaryStatus.absence,
      primarySeverity: AttendancePolicySeverity.red,
      attendanceStatus: AttendancePolicyStatus.tidakHadir,
      detailSignals: const <AttendancePolicySignal>[
        AttendancePolicySignal.absence,
      ],
      netWorkMinutes: 0,
      shortWorkMinutes: 600,
    ),
  ];

  final attendanceLogs = <AttendanceLog>[
    _buildLog(
      id: 'legacy-in',
      employeeId: employeeById['emp-legacy-fallback-no-schedule']!.id,
      outletId: outletId,
      type: AttendanceType.masuk,
      scannedAt: '2026-03-21T08:00:00+08:00',
    ),
    _buildLog(
      id: 'legacy-out',
      employeeId: employeeById['emp-legacy-fallback-no-schedule']!.id,
      outletId: outletId,
      type: AttendanceType.pulang,
      scannedAt: '2026-03-21T17:00:00+08:00',
    ),
  ];

  final expectationsByKey = <String, ReportExportParityExpectation>{
    reportExportParityKey(
      employeeById['emp-full-time']!.id,
      DateTime(2026, 3, 24),
    ): const ReportExportParityExpectation(
      primaryLabel: '07:00 / 17:00',
      secondaryTags: <String>[],
      severityFamily: 'neutral',
      isCompatibilityRow: false,
    ),
    reportExportParityKey(
      employeeById['emp-part-time']!.id,
      DateTime(2026, 3, 24),
    ): const ReportExportParityExpectation(
      primaryLabel: '08:00 / 17:00',
      secondaryTags: <String>[],
      severityFamily: 'neutral',
      isCompatibilityRow: false,
    ),
    reportExportParityKey(
      employeeById['emp-overtime']!.id,
      DateTime(2026, 3, 25),
    ): const ReportExportParityExpectation(
      primaryLabel: '07:00 / 19:15',
      secondaryTags: <String>['OT'],
      severityFamily: 'yellow',
      isCompatibilityRow: false,
    ),
    reportExportParityKey(
      employeeById['emp-outlet-24-jam']!.id,
      DateTime(2026, 3, 18),
    ): const ReportExportParityExpectation(
      primaryLabel: 'Terlambat',
      secondaryTags: <String>['TLT'],
      severityFamily: 'yellow',
      isCompatibilityRow: false,
    ),
    reportExportParityKey(
      employeeById['emp-outlet-normal']!.id,
      DateTime(2026, 3, 26),
    ): const ReportExportParityExpectation(
      primaryLabel: '07:05 / 17:03',
      secondaryTags: <String>[],
      severityFamily: 'neutral',
      isCompatibilityRow: false,
    ),
    reportExportParityKey(
      employeeById['emp-late-normal']!.id,
      DateTime(2026, 3, 27),
    ): const ReportExportParityExpectation(
      primaryLabel: 'Terlambat',
      secondaryTags: <String>['TLT'],
      severityFamily: 'yellow',
      isCompatibilityRow: false,
    ),
    reportExportParityKey(
      employeeById['emp-no-show']!.id,
      DateTime(2026, 3, 28),
    ): const ReportExportParityExpectation(
      primaryLabel: 'Tidak Hadir',
      secondaryTags: <String>['ABS'],
      severityFamily: 'red',
      isCompatibilityRow: false,
    ),
    reportExportParityKey(
      employeeById['emp-legacy-fallback-no-schedule']!.id,
      DateTime(2026, 3, 21),
    ): const ReportExportParityExpectation(
      primaryLabel: 'Hadir tanpa jadwal',
      secondaryTags: <String>[],
      severityFamily: 'info',
      isCompatibilityRow: true,
    ),
  };

  return ReportExportParityFixtureBundle(
    startDate: DateTime(2026, 3, 18),
    endDate: DateTime(2026, 3, 28),
    outletId: outletId,
    outletName: outletName,
    outletOperatingMode: outletOperatingMode,
    employees: List<Employee>.unmodifiable(employees),
    strictRows: List<AttendancePolicyRecapDay>.unmodifiable(strictRows),
    attendanceLogs: List<AttendanceLog>.unmodifiable(attendanceLogs),
    expectationsByKey: Map<String, ReportExportParityExpectation>.unmodifiable(
      expectationsByKey,
    ),
    scenarioIds: List<String>.unmodifiable(reportExportParityScenarioIds),
  );
}

String reportExportParityKey(String employeeId, DateTime logicalDate) {
  final dateOnly = DateTime(
    logicalDate.year,
    logicalDate.month,
    logicalDate.day,
  );
  return '$employeeId|'
      '${dateOnly.year.toString().padLeft(4, '0')}-'
      '${dateOnly.month.toString().padLeft(2, '0')}-'
      '${dateOnly.day.toString().padLeft(2, '0')}';
}

Employee _buildEmployee({
  required String id,
  required String name,
  required EmployeeContract contract,
  required String outletId,
}) {
  return Employee(
    id: id,
    name: name,
    homeOutletId: outletId,
    isActive: true,
    createdAt: '2026-03-01T00:00:00Z',
    updatedAt: '2026-03-01T00:00:00Z',
    employmentContract: contract,
  );
}

AttendanceLog _buildLog({
  required String id,
  required String employeeId,
  required String outletId,
  required AttendanceType type,
  required String scannedAt,
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

AttendancePolicyRecapDay _buildStrictRow({
  required Employee employee,
  required DateTime logicalDate,
  required DateTime? firstScanLocal,
  required DateTime? lastPulangLocal,
  required AttendancePolicyPrimaryStatus primaryStatus,
  required AttendancePolicySeverity primarySeverity,
  required AttendancePolicyStatus attendanceStatus,
  List<AttendancePolicySignal> detailSignals = const <AttendancePolicySignal>[],
  LateKind lateKind = LateKind.none,
  bool isLate = false,
  int? netWorkMinutes,
  int? overtimeMinutes = 0,
  int? shortWorkMinutes = 0,
}) {
  return AttendancePolicyRecapDay(
    logicalDate: logicalDate,
    employeeId: employee.id,
    employeeName: employee.name,
    outletId: 'outlet-parity',
    outletName: 'Outlet Parity',
    shiftBand: null,
    requiredWorkMinutes:
        employee.employmentContract == EmployeeContract.parttime ? 540 : 600,
    lateCutoffLocal: '07:00',
    attendanceStatus: attendanceStatus,
    lateKind: lateKind,
    isLate: isLate,
    firstScanLocal: firstScanLocal,
    firstBreakLocal: null,
    lastPulangLocal: lastPulangLocal,
    notes: null,
    primaryStatus: primaryStatus,
    primarySeverity: primarySeverity,
    detailSignals: detailSignals,
    detailNotes: const <String>[],
    logicalDayComplete: true,
    netWorkMinutes: netWorkMinutes,
    totalBreakMinutes: 0,
    overtimeMinutes: overtimeMinutes,
    shortWorkMinutes: shortWorkMinutes,
    excessBreakMinutes: 0,
    pairedBreakCount: 0,
  );
}
