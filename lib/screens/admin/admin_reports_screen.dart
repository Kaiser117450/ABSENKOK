import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:absensi_enakko_flutter/core/supabase_client.dart';
import 'package:absensi_enakko_flutter/core/theme.dart';
import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/models/daily_summary.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/outlet.dart';
import 'package:absensi_enakko_flutter/models/outlet_operating_mode.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';
import 'package:absensi_enakko_flutter/providers/app_provider.dart';
import 'package:absensi_enakko_flutter/services/admin_policy_recap_dataset_service.dart';
import 'package:absensi_enakko_flutter/services/attendance_policy_recap_service.dart';
import 'package:absensi_enakko_flutter/services/badge_service.dart';
import 'package:absensi_enakko_flutter/services/payroll_matrix_builder.dart';
import 'package:absensi_enakko_flutter/services/payroll_pdf_matrix_export_service.dart';
import 'package:absensi_enakko_flutter/services/payroll_spreadsheet_export_service.dart';
import 'package:absensi_enakko_flutter/services/pdf_service.dart';
import 'package:absensi_enakko_flutter/widgets/app_card.dart';
import 'package:absensi_enakko_flutter/widgets/app_empty_state.dart';
import 'package:absensi_enakko_flutter/widgets/app_toast.dart';
import 'package:absensi_enakko_flutter/widgets/shimmer_skeleton.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Admin Reports Screen
// ─────────────────────────────────────────────────────────────────────────────

enum PolicyRecapFilter {
  semua,
  terlambat,
  kurangJamKerja,
  istirahatBerlebih,
  lembur,
  tidakHadir,
  managerExempt,
  hadirTanpaJadwal,
  belumAbsenPulang,
}

extension PolicyRecapFilterLabel on PolicyRecapFilter {
  String get label {
    switch (this) {
      case PolicyRecapFilter.semua:
        return 'Semua';
      case PolicyRecapFilter.terlambat:
        return 'Terlambat';
      case PolicyRecapFilter.kurangJamKerja:
        return 'Kurang jam kerja';
      case PolicyRecapFilter.istirahatBerlebih:
        return 'Istirahat berlebih';
      case PolicyRecapFilter.lembur:
        return 'Lembur';
      case PolicyRecapFilter.tidakHadir:
        return 'Tidak Hadir';
      case PolicyRecapFilter.managerExempt:
        return 'Manager exempt';
      case PolicyRecapFilter.hadirTanpaJadwal:
        return 'Hadir Tanpa Jadwal';
      case PolicyRecapFilter.belumAbsenPulang:
        return 'Belum absen pulang';
    }
  }
}

bool matchesPolicyRecapFilter(
  AttendancePolicyRecapDay row,
  PolicyRecapFilter filter,
) {
  switch (filter) {
    case PolicyRecapFilter.semua:
      return true;
    case PolicyRecapFilter.terlambat:
      return row.hasSignal(AttendancePolicySignal.late) ||
          row.primaryStatus == AttendancePolicyPrimaryStatus.late ||
          row.isLate ||
          row.lateKind != LateKind.none;
    case PolicyRecapFilter.kurangJamKerja:
      return row.hasSignal(AttendancePolicySignal.shortWork) ||
          row.primaryStatus == AttendancePolicyPrimaryStatus.shortWork;
    case PolicyRecapFilter.istirahatBerlebih:
      return row.hasSignal(AttendancePolicySignal.excessBreak) ||
          row.primaryStatus == AttendancePolicyPrimaryStatus.excessBreak;
    case PolicyRecapFilter.lembur:
      return row.hasSignal(AttendancePolicySignal.overtime) ||
          row.primaryStatus == AttendancePolicyPrimaryStatus.overtime;
    case PolicyRecapFilter.tidakHadir:
      return row.hasSignal(AttendancePolicySignal.absence) ||
          row.primaryStatus == AttendancePolicyPrimaryStatus.absence ||
          row.attendanceStatus == AttendancePolicyStatus.tidakHadir;
    case PolicyRecapFilter.managerExempt:
      return row.isManagerExempt ||
          row.hasSignal(AttendancePolicySignal.exemptManager) ||
          row.primaryStatus == AttendancePolicyPrimaryStatus.exemptManager;
    case PolicyRecapFilter.hadirTanpaJadwal:
      return row.hasSignal(AttendancePolicySignal.hadirTanpaJadwal) ||
          row.primaryStatus == AttendancePolicyPrimaryStatus.hadirTanpaJadwal ||
          row.attendanceStatus == AttendancePolicyStatus.hadirTanpaJadwal;
    case PolicyRecapFilter.belumAbsenPulang:
      return _isPendingPolicyRecapRow(row);
  }
}

bool _isBelumAbsenPulangPolicyRecapRow(AttendancePolicyRecapDay row) {
  return row.hasSignal(AttendancePolicySignal.belumAbsenPulang) ||
      row.primaryStatus == AttendancePolicyPrimaryStatus.belumAbsenPulang;
}

bool _isActiveIncompletePolicyRecapRow(AttendancePolicyRecapDay row) {
  return row.hasSignal(AttendancePolicySignal.activeIncomplete) ||
      row.primaryStatus == AttendancePolicyPrimaryStatus.activeIncomplete;
}

bool _isPendingPolicyRecapRow(AttendancePolicyRecapDay row) {
  return _isBelumAbsenPulangPolicyRecapRow(row) ||
      _isActiveIncompletePolicyRecapRow(row);
}

List<AttendancePolicyRecapDay> filterPolicyRecapRows(
  Iterable<AttendancePolicyRecapDay> rows,
  PolicyRecapFilter filter,
) {
  return rows
      .where((row) => matchesPolicyRecapFilter(row, filter))
      .toList(growable: false);
}

String buildPolicyRecapReasonCopy(AttendancePolicyRecapDay recap) {
  final hasStrictContract =
      recap.primaryStatus != null || recap.detailSignals.isNotEmpty;

  if (hasStrictContract) {
    if (recap.isManagerExempt ||
        recap.hasSignal(AttendancePolicySignal.exemptManager) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.exemptManager) {
      return '${recap.managerPosition ?? 'Kepala toko / kepala gerai'} tetap terlihat di recap, tetapi tidak kena penalti merah untuk telat, kurang jam, atau istirahat berlebih.';
    }

    if (recap.hasSignal(AttendancePolicySignal.activeIncomplete) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.activeIncomplete) {
      return 'Hari masih berjalan; hasil final akan dikunci setelah chain selesai.';
    }

    if (recap.hasSignal(AttendancePolicySignal.belumAbsenPulang) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.belumAbsenPulang) {
      return 'Chain selesai tanpa kembali atau clock-out yang cocok, jadi hari ini ditandai belum absen pulang.';
    }

    if (recap.hasSignal(AttendancePolicySignal.hadirTanpaJadwal) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.hadirTanpaJadwal) {
      return 'Hadir tanpa jadwal; aturan kontrak tetap dipakai untuk menghitung jam kerja, istirahat, dan lembur.';
    }

    // Non-working day statuses — show clear copy so tile is not mistaken for absence
    if (recap.primaryStatus == AttendancePolicyPrimaryStatus.libur ||
        recap.attendanceStatus == AttendancePolicyStatus.libur) {
      return 'Hari libur sesuai jadwal.';
    }
    if (recap.primaryStatus == AttendancePolicyPrimaryStatus.sakit) {
      final n = recap.notes?.trim();
      return (n != null && n.isNotEmpty) ? 'Sakit: $n' : 'Karyawan izin sakit.';
    }
    if (recap.primaryStatus == AttendancePolicyPrimaryStatus.izin) {
      final n = recap.notes?.trim();
      return (n != null && n.isNotEmpty) ? 'Izin: $n' : 'Karyawan izin.';
    }
    if (recap.primaryStatus == AttendancePolicyPrimaryStatus.cuti) {
      return 'Karyawan sedang cuti.';
    }

    final strictNotes = recap.detailNotes
        .map((note) => note.trim())
        .where((note) => note.isNotEmpty)
        .toList(growable: false);
    if (strictNotes.isNotEmpty) {
      return strictNotes.first;
    }
  }

  if (recap.attendanceStatus == AttendancePolicyStatus.belumMasuk) {
    return 'Hari kerja masih berjalan dan belum ada scan masuk.';
  }

  if (recap.attendanceStatus == AttendancePolicyStatus.tidakHadir) {
    return 'Tidak ada scan pada hari kerja yang sudah selesai.';
  }

  if (recap.attendanceStatus == AttendancePolicyStatus.hadirTanpaJadwal) {
    return 'Hadir tanpa jadwal';
  }

  if (recap.lateKind == LateKind.normal) {
    return 'Terlambat: scan pertama ${_formatPolicyTime(recap.firstScanLocal)}, batas ${recap.lateCutoffLocal ?? '--:--'}';
  }

  if (recap.lateKind == LateKind.normal) {
    return 'Terlambat: scan pertama ${_formatPolicyTime(recap.firstScanLocal)}, batas ${recap.lateCutoffLocal ?? '--:--'}';
  }

  final notes = recap.notes?.trim();
  if (notes != null && notes.isNotEmpty) {
    return notes;
  }

  if (recap.attendanceStatus == AttendancePolicyStatus.hadir) {
    return 'Masuk ${_formatPolicyTime(recap.firstScanLocal)} · Pulang ${_formatPolicyTime(recap.lastPulangLocal)}';
  }

  return recap.attendanceStatus.label;
}

String _formatPolicyTime(DateTime? dt) {
  if (dt == null) return '--:--';
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _formatPolicyMinutes(int? minutes) {
  if (minutes == null || minutes <= 0) return '0m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '${remainder}m';
  if (remainder == 0) return '${hours}j';
  return '${hours}j ${remainder}m';
}

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  List<Outlet> _outlets = [];
  String? _selectedOutletId;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _endDate = DateTime.now();

  List<_ReportRow> _rows = [];
  bool _loading = false;
  bool _exportingCsv = false;
  bool _exportingPdf = false;
  bool _exportingPayrollPdf = false;
  bool _exportingSpreadsheet = false;
  SpreadsheetSortMode _spreadsheetSortMode = SpreadsheetSortMode.bermasalah;
  bool _hasLoaded = false;

  // Pagination
  static const int _limit = 50;
  int _currentOffset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Rekap Harian — independent full-dataset fetch (no pagination)
  List<_ReportRow> _dailyRows = [];
  List<AttendancePolicyRecapDay> _policyRecapRows = [];
  List<AttendancePolicyRecapDay> _policyRecapFallbackRows = [];
  PayrollMatrixDataset? _payrollMatrixDataset;
  bool _loadingDaily = false;
  PolicyRecapFilter _selectedPolicyRecapFilter = PolicyRecapFilter.semua;
  String _policyRecapNameQuery = '';
  String? _policyRecapError;
  String? _payrollExportStatusMessage;
  bool _payrollExportStatusIsError = false;
  final AdminPolicyRecapDatasetService _adminPolicyRecapDatasetService =
      const AdminPolicyRecapDatasetService();
  final AttendancePolicyRecapService _attendancePolicyRecapService =
      const AttendancePolicyRecapService();
  final PayrollPdfMatrixExportService _payrollPdfMatrixExportService =
      PayrollPdfMatrixExportService();
  final PayrollSpreadsheetExportService _payrollSpreadsheetExportService =
      PayrollSpreadsheetExportService();

  // Tab: 0 = Per Scan, 1 = Rekap Harian
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!mounted || _tabCtrl.indexIsChanging) return;
      setState(() {});
    });
    // Role scoped: auto-set outlet sebelum load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = ref.read(appProvider);
      if (appState.isScopedOutletAdmin &&
          appState.primaryScopedOutletId != null) {
        setState(() => _selectedOutletId = appState.primaryScopedOutletId);
      }
    });
    _loadOutlets();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Load data ───────────────────────────────────────────────────────────────

  Future<void> _loadOutlets() async {
    try {
      final appState = ref.read(appProvider);
      if (appState.isScopedOutletAdmin && appState.scopedOutletIds.isEmpty) {
        if (mounted) {
          setState(() {
            _outlets = const <Outlet>[];
            _selectedOutletId = null;
          });
        }
        return;
      }

      var query = SupabaseClientFactory.admin
          .from('outlets')
          .select('*')
          .eq('is_active', true);
      if (appState.isScopedOutletAdmin) {
        query = query.inFilter('id', appState.scopedOutletIds);
      }
      final data = await query.order('name');
      if (mounted) {
        setState(() {
          _outlets = (data as List)
              .map((e) => Outlet.fromJson(e as Map<String, dynamic>))
              .toList();
          if (appState.isScopedOutletAdmin &&
              !appState.canAccessOutlet(_selectedOutletId)) {
            _selectedOutletId = _outlets.firstOrNull?.id;
          }
        });
      }
    } catch (_) {}
  }

  String? _activeOutletFilterId() {
    final appState = ref.read(appProvider);
    if (!appState.isScopedOutletAdmin) {
      return _selectedOutletId;
    }
    if (appState.canAccessOutlet(_selectedOutletId)) {
      return _selectedOutletId;
    }
    return appState.primaryScopedOutletId;
  }

  void _markDataDirty() {
    _hasLoaded = false;
    _rows = [];
    _dailyRows = [];
    _policyRecapRows = [];
    _policyRecapFallbackRows = [];
    _payrollMatrixDataset = null;
    _currentOffset = 0;
    _hasMore = true;
    _isLoadingMore = false;
    _loading = false;
    _loadingDaily = false;
    _selectedPolicyRecapFilter = PolicyRecapFilter.semua;
    _policyRecapNameQuery = '';
    _policyRecapError = null;
    _exportingPayrollPdf = false;
    _exportingSpreadsheet = false;
    _payrollExportStatusMessage = null;
    _payrollExportStatusIsError = false;
  }

  dynamic _buildAttendanceBaseQuery() {
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end =
        DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

    dynamic query = SupabaseClientFactory.admin
        .from('attendance_logs')
        .select('*, employees(*), outlets(*)')
        .gte('scanned_at', start.toUtc().toIso8601String())
        .lte('scanned_at', end.toUtc().toIso8601String());

    final activeOutletId = _activeOutletFilterId();
    if (activeOutletId != null) {
      query = query.eq('scan_outlet_id', activeOutletId);
    }
    return query;
  }

  Future<List<_ReportRow>> _fetchAllRowsForExport({
    bool ascending = true,
    int batchSize = 1000,
    int maxRows = 5000,
  }) async {
    final allRows = <_ReportRow>[];
    var offset = 0;

    while (allRows.length < maxRows) {
      final remaining = maxRows - allRows.length;
      final currentBatchSize = math.min(batchSize, remaining);
      final data = await _buildAttendanceBaseQuery()
          .order('scanned_at', ascending: ascending)
          .range(offset, offset + currentBatchSize - 1);

      final batch = (data as List)
          .map((e) => _ReportRow.fromJson(e as Map<String, dynamic>))
          .toList();
      allRows.addAll(batch);

      if (batch.length < currentBatchSize) break;
      offset += currentBatchSize;
    }

    return allRows;
  }

  Future<void> _loadReport({bool reset = true}) async {
    // Warm badge cache for BadgeAvatar rendering
    BadgeService.instance.fetchAll();
    if (reset) {
      setState(() {
        _loading = true;
        _hasLoaded = true;
        _rows = [];
        _currentOffset = 0;
        _hasMore = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final data = await _buildAttendanceBaseQuery()
          .order('scanned_at', ascending: false) // newest first
          .range(_currentOffset, _currentOffset + _limit - 1);

      if (mounted) {
        final newRows = (data as List)
            .map((e) => _ReportRow.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          if (reset) {
            _rows = newRows;
          } else {
            _rows.addAll(newRows);
          }
          _hasMore = newRows.length == _limit;
          _currentOffset += _limit;
          _loading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadDailySummaryData() async {
    final outletId = _activeOutletFilterId()?.trim();
    final isSingleOutlet = outletId != null && outletId.isNotEmpty;

    setState(() {
      _loadingDaily = true;
      _policyRecapError = null;
    });

    try {
      final allRowsFuture = _fetchAllRowsForExport(ascending: true);
      final employeesFuture = isSingleOutlet
          ? _fetchPayrollRoster(outletId)
          : _fetchAllEmployeesForPayroll();
      final recapFuture = () async {
        try {
          if (isSingleOutlet) {
            // Single outlet — call RPC directly
            final rows = await _attendancePolicyRecapService
                .fetchAdminSchedulePolicyRecap(
              outletId: outletId,
              startDate: _startDate,
              endDate: _endDate,
            );
            return (rows: rows, error: null as String?);
          } else {
            // "Semua" — call RPC for each active outlet and merge
            final outletIds = _outlets.map((o) => o.id).toList(growable: false);
            if (outletIds.isEmpty) {
              return (
                rows: const <AttendancePolicyRecapDay>[],
                error: null as String?,
              );
            }
            final rows =
                await _attendancePolicyRecapService.fetchAllOutletsPolicyRecap(
              outletIds: outletIds,
              startDate: _startDate,
              endDate: _endDate,
            );
            return (rows: rows, error: null as String?);
          }
        } catch (e) {
          return (
            rows: const <AttendancePolicyRecapDay>[],
            error: e.toString(),
          );
        }
      }();

      final allRows = await allRowsFuture;
      final employees = await employeesFuture;
      final recapResult = await recapFuture;
      if (!mounted) return;

      final AdminPolicyRecapDatasetResult recapDataset;
      if (isSingleOutlet) {
        final payrollOutletContext = _resolvePayrollOutletContext(allRows);
        recapDataset = _adminPolicyRecapDatasetService.build(
          employees: employees,
          strictRows: recapResult.rows,
          attendanceLogs: allRows.map((row) => row.log),
          outletId: outletId,
          outletName: payrollOutletContext.outletName,
          outletOperatingMode: payrollOutletContext.operatingMode,
          now: DateTime.now(),
        );
      } else {
        // "Semua" — build dataset per outlet then merge all results
        recapDataset = _buildAllOutletsRecapDataset(
          employees: employees,
          strictRows: recapResult.rows,
          allRows: allRows,
        );
      }

      final payrollDataset = employees.isNotEmpty
          ? buildPayrollMatrix(
              startDate: _startDate,
              endDate: _endDate,
              employees: employees,
              recapRows: recapDataset.mergedRows,
            )
          : const PayrollMatrixDataset(
              dates: <DateTime>[],
              rows: <PayrollMatrixRow>[],
            );

      setState(() {
        _dailyRows = allRows;
        _policyRecapRows = recapDataset.mergedRows;
        _policyRecapFallbackRows = recapDataset.fallbackRows;
        _payrollMatrixDataset = payrollDataset;
        _selectedPolicyRecapFilter = PolicyRecapFilter.semua;
        _policyRecapNameQuery = '';
        _policyRecapError = recapResult.error;
        _loadingDaily = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingDaily = false);
    }
  }

  /// Build recap dataset for "Semua" mode by grouping employees per outlet
  /// and running the fallback service for each outlet independently, then
  /// merging all results.
  AdminPolicyRecapDatasetResult _buildAllOutletsRecapDataset({
    required List<Employee> employees,
    required List<AttendancePolicyRecapDay> strictRows,
    required List<_ReportRow> allRows,
  }) {
    // Build a lookup of outlet id → outlet for resolving names/modes
    final outletById = <String, Outlet>{
      for (final outlet in _outlets) outlet.id: outlet,
    };

    // Also gather outlet info from attendance logs for outlets not in
    // the dropdown (edge case: employee scanned at an unlisted outlet)
    for (final row in allRows) {
      final outlet = row.outlet;
      if (outlet != null && !outletById.containsKey(outlet.id)) {
        outletById[outlet.id] = outlet;
      }
    }

    // Group employees by home_outlet_id
    final employeesByOutlet = <String, List<Employee>>{};
    for (final emp in employees) {
      final homeOutletId = emp.homeOutletId;
      if (homeOutletId != null && homeOutletId.isNotEmpty) {
        employeesByOutlet
            .putIfAbsent(homeOutletId, () => <Employee>[])
            .add(emp);
      }
    }

    final allMergedRows = <AttendancePolicyRecapDay>[];
    final allStrictRows = <AttendancePolicyRecapDay>[];
    final allFallbackRows = <AttendancePolicyRecapDay>[];

    // For each outlet that has employees, run the dataset builder
    for (final entry in employeesByOutlet.entries) {
      final oId = entry.key;
      final outletEmployees = entry.value;
      final outlet = outletById[oId];
      final outletName = outlet?.name ?? 'Outlet';
      final operatingMode = outlet?.operatingMode ?? OutletOperatingMode.normal;

      final result = _adminPolicyRecapDatasetService.build(
        employees: outletEmployees,
        strictRows: strictRows.where((r) => r.outletId == oId),
        attendanceLogs: allRows.map((row) => row.log),
        outletId: oId,
        outletName: outletName,
        outletOperatingMode: operatingMode,
        now: DateTime.now(),
      );

      allMergedRows.addAll(result.mergedRows);
      allStrictRows.addAll(result.strictRows);
      allFallbackRows.addAll(result.fallbackRows);
    }

    // Also handle strict rows from outlets with no local employees
    // (employee may be assigned to a different outlet but scheduled here)
    final coveredOutletIds = employeesByOutlet.keys.toSet();
    final uncoveredStrictRows = strictRows
        .where((r) => !coveredOutletIds.contains(r.outletId))
        .toList(growable: false);
    allMergedRows.addAll(uncoveredStrictRows);
    allStrictRows.addAll(uncoveredStrictRows);

    // Deduplicate by employee+date key (prefer strict over fallback)
    final deduped = <String, AttendancePolicyRecapDay>{};
    for (final row in allMergedRows) {
      final key =
          '${row.employeeId}|${row.logicalDate.year}-${row.logicalDate.month.toString().padLeft(2, '0')}-${row.logicalDate.day.toString().padLeft(2, '0')}';
      // First entry wins (strict rows were added first)
      deduped.putIfAbsent(key, () => row);
    }

    final mergedSorted = deduped.values.toList(growable: false)
      ..sort((a, b) {
        final dc = a.logicalDate.compareTo(b.logicalDate);
        if (dc != 0) return dc;
        return a.employeeName
            .toLowerCase()
            .compareTo(b.employeeName.toLowerCase());
      });

    return AdminPolicyRecapDatasetResult(
      mergedRows: mergedSorted,
      strictRows: allStrictRows,
      fallbackRows: allFallbackRows,
    );
  }

  Future<List<Employee>> _fetchPayrollRoster(String outletId) async {
    final data = await SupabaseClientFactory.admin
        .from('employees')
        .select('*')
        .eq('is_active', true)
        .eq('home_outlet_id', outletId)
        .order('name');

    return (data as List)
        .map((item) => Employee.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Employee>> _fetchAllEmployeesForPayroll() async {
    final appState = ref.read(appProvider);
    var query = SupabaseClientFactory.admin
        .from('employees')
        .select('*')
        .eq('is_active', true);
    if (appState.isScopedOutletAdmin) {
      if (appState.scopedOutletIds.isEmpty) {
        return const <Employee>[];
      }
      query = query.inFilter('home_outlet_id', appState.scopedOutletIds);
    }
    final data = await query.order('name');
    return (data as List)
        .map((item) => Employee.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  ({String outletName, OutletOperatingMode operatingMode})
      _resolvePayrollOutletContext(List<_ReportRow> sourceRows) {
    final selectedOutletId = _activeOutletFilterId()?.trim();
    if (selectedOutletId != null && selectedOutletId.isNotEmpty) {
      for (final outlet in _outlets) {
        if (outlet.id == selectedOutletId) {
          return (
            outletName: outlet.name,
            operatingMode: outlet.operatingMode,
          );
        }
      }

      for (final row in sourceRows) {
        final outlet = row.outlet;
        if (outlet != null && outlet.id == selectedOutletId) {
          return (
            outletName: outlet.name,
            operatingMode: outlet.operatingMode,
          );
        }
      }
    }

    return (
      outletName: _resolvedOutletName(),
      operatingMode: OutletOperatingMode.normal,
    );
  }

  // ── CSV export ───────────────────────────────────────────────────────────────

  Future<void> _exportCsv() async {
    if (_exportingCsv || _loading || _loadingDaily) return;
    setState(() => _exportingCsv = true);

    try {
      final allRows = _dailyRows.isNotEmpty
          ? _dailyRows
          : await _fetchAllRowsForExport(ascending: true);
      if (allRows.isEmpty) {
        if (mounted) {
          AppToast.info(context, 'Tidak ada data untuk diekspor');
        }
        return;
      }

      final isRekap = _tabCtrl.index == 1;
      final buffer = StringBuffer();

      if (isRekap) {
        buffer.writeln(
            'Tanggal,Nama,Outlet,Status,Masuk,Pulang,Kerja,Istirahat,Jumlah Scan,Catatan');
        final summaries = _computeDailySummaries(sourceRows: allRows);
        for (final summary in summaries) {
          final date = _escapeCsv(_formatDateLabelForExport(summary.dateLabel));
          final name = _escapeCsv(summary.employee?.name ?? '-');
          final outlet = _escapeCsv(summary.outlet?.name ?? '-');
          final status = _escapeCsv(_statusLabel(summary.status));
          final masuk = _escapeCsv(_formatHm(summary.firstMasuk));
          final pulang = _escapeCsv(_formatHm(summary.lastPulang));
          final kerja = _escapeCsv(_durationText(summary.workDuration));
          final istirahat = _escapeCsv(_durationText(summary.totalBreak));
          final scanCount = summary.scanCount.toString();
          final notes = _escapeCsv(summary.statusNotes ?? '');
          buffer.writeln(
              '$date,$name,$outlet,$status,$masuk,$pulang,$kerja,$istirahat,$scanCount,$notes');
        }
      } else {
        buffer.writeln(
            'Nama,Jabatan,Outlet,Jenis,Waktu Lokal,Latitude,Longitude,Catatan');
        final sorted = [...allRows]..sort((a, b) =>
            _safeDateTime(b.log.scannedAt)
                .compareTo(_safeDateTime(a.log.scannedAt)));

        for (final row in sorted) {
          final name = _escapeCsv(row.employee?.name ?? '-');
          final jabatan = _escapeCsv(row.employee?.position ?? '-');
          final outlet = _escapeCsv(row.outlet?.name ?? '-');
          final type = _escapeCsv(row.log.type.label);
          final time = _escapeCsv(_formatLocalDateTime(row.log.scannedAt));
          final lat = row.log.lat?.toString() ?? '';
          final lng = row.log.lng?.toString() ?? '';
          final notes = _escapeCsv(row.log.notes ?? '');
          buffer.writeln('$name,$jabatan,$outlet,$type,$time,$lat,$lng,$notes');
        }
      }

      final dir = await getTemporaryDirectory();
      final filename = isRekap
          ? 'absensi_rekap_harian_${_exportToken()}.csv'
          : 'absensi_per_scan_${_exportToken()}.csv';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject:
            isRekap ? 'Laporan Rekap Harian Enakko' : 'Laporan Per Scan Enakko',
      );
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Gagal mengekspor CSV');
      }
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_exportingPdf || _loading || _loadingDaily) return;
    setState(() => _exportingPdf = true);

    try {
      final allRows = _dailyRows.isNotEmpty
          ? _dailyRows
          : await _fetchAllRowsForExport(ascending: true);
      if (allRows.isEmpty) {
        if (mounted) {
          AppToast.info(context, 'Tidak ada data untuk diekspor');
        }
        return;
      }

      final outletName = _resolvedOutletName();
      final isRekap = _tabCtrl.index == 1;
      if (isRekap) {
        final summaries = _computeDailySummaries(sourceRows: allRows);
        final rows = summaries
            .map(
              (summary) => AttendanceDailyPdfRow(
                tanggal: _formatDateLabelForExport(summary.dateLabel),
                nama: summary.employee?.name ?? '-',
                outlet: summary.outlet?.name ?? '-',
                status: _statusLabel(summary.status),
                masuk: _formatHm(summary.firstMasuk),
                pulang: _formatHm(summary.lastPulang),
                kerja: _durationText(summary.workDuration),
                istirahat: _durationText(summary.totalBreak),
                jumlahScan: summary.scanCount.toString(),
                catatan: summary.statusNotes ?? '',
              ),
            )
            .toList();

        final stats = _computeExportStats(summaries);
        await PdfService.generateAndShareAttendanceDailyPdf(
          rows: rows,
          stats: stats,
          startDate: _startDate,
          endDate: _endDate,
          outletName: outletName,
        );
      } else {
        final sorted = [...allRows]..sort((a, b) =>
            _safeDateTime(b.log.scannedAt)
                .compareTo(_safeDateTime(a.log.scannedAt)));

        final rows = sorted
            .map(
              (row) => AttendancePerScanPdfRow(
                nama: row.employee?.name ?? '-',
                jabatan: row.employee?.position ?? '-',
                outlet: row.outlet?.name ?? '-',
                jenis: row.log.type.label,
                waktu: _formatLocalDateTime(row.log.scannedAt),
                latitude: row.log.lat?.toString() ?? '-',
                longitude: row.log.lng?.toString() ?? '-',
                catatan: row.log.notes ?? '',
              ),
            )
            .toList();

        await PdfService.generateAndShareAttendancePerScanPdf(
          rows: rows,
          startDate: _startDate,
          endDate: _endDate,
          outletName: outletName,
        );
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Gagal mengekspor PDF');
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  bool get _hasValidPayrollDateRange => !_endDate.isBefore(_startDate);

  bool get _canExportPayrollSpreadsheet {
    final dataset = _payrollMatrixDataset;
    return _hasValidPayrollDateRange &&
        dataset != null &&
        !dataset.isEmpty &&
        !_exportingSpreadsheet &&
        !_loadingDaily;
  }

  bool get _canExportPayrollPdf {
    final dataset = _payrollMatrixDataset;
    return _hasValidPayrollDateRange &&
        dataset != null &&
        !dataset.isEmpty &&
        !_exportingPayrollPdf &&
        !_loadingDaily;
  }

  Future<void> _exportPayrollPdf() async {
    if (!_canExportPayrollPdf) {
      return;
    }

    final dataset = _payrollMatrixDataset;
    if (dataset == null || dataset.isEmpty) {
      return;
    }

    final outletName = _resolvedOutletName();
    setState(() {
      _exportingPayrollPdf = true;
      _payrollExportStatusMessage = 'Menyiapkan PDF payroll...';
      _payrollExportStatusIsError = false;
    });

    try {
      final file = await _payrollPdfMatrixExportService.buildPayrollPdf(
        dataset: dataset,
        outletName: outletName,
        startDate: _startDate,
        endDate: _endDate,
      );

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'application/pdf',
          ),
        ],
        subject: 'Rekap Payroll PDF Enakko - $outletName',
      );

      if (!mounted) return;
      setState(() {
        _payrollExportStatusMessage = 'PDF payroll siap dibagikan.';
        _payrollExportStatusIsError = false;
      });
      AppToast.success(context, 'PDF payroll siap dibagikan.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _payrollExportStatusMessage =
            'PDF payroll belum bisa dibuat. Coba lagi. Jika masih gagal, gunakan spreadsheet lalu laporkan ke admin.';
        _payrollExportStatusIsError = true;
      });
      AppToast.error(
        context,
        'PDF payroll belum bisa dibuat. Coba lagi. Jika masih gagal, gunakan spreadsheet lalu laporkan ke admin.',
      );
    } finally {
      if (mounted) {
        setState(() => _exportingPayrollPdf = false);
      }
    }
  }

  Future<void> _exportPayrollSpreadsheet() async {
    if (!_canExportPayrollSpreadsheet) {
      return;
    }

    final dataset = _payrollMatrixDataset;
    if (dataset == null || dataset.isEmpty) {
      return;
    }

    final outletName = _resolvedOutletName();
    setState(() {
      _exportingSpreadsheet = true;
      _payrollExportStatusMessage = 'Menyiapkan spreadsheet payroll...';
      _payrollExportStatusIsError = false;
    });

    try {
      final file =
          await _payrollSpreadsheetExportService.exportPayrollSpreadsheet(
        outletName: outletName,
        startDate: _startDate,
        endDate: _endDate,
        dataset: dataset,
        recapRows: _policyRecapRows,
        sortMode: _spreadsheetSortMode,
      );

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: 'Rekap Payroll Enakko - $outletName',
      );

      if (!mounted) return;
      setState(() {
        _payrollExportStatusMessage = 'Spreadsheet siap dibagikan.';
        _payrollExportStatusIsError = false;
      });
      AppToast.success(context, 'Spreadsheet siap dibagikan.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _payrollExportStatusMessage =
            'Spreadsheet belum bisa dibuat. Periksa outlet, rentang tanggal, dan koneksi lalu coba lagi.';
        _payrollExportStatusIsError = true;
      });
      AppToast.error(
        context,
        'Spreadsheet belum bisa dibuat. Periksa outlet, rentang tanggal, dan koneksi lalu coba lagi.',
      );
    } finally {
      if (mounted) {
        setState(() => _exportingSpreadsheet = false);
      }
    }
  }

  String _escapeCsv(String val) {
    var sanitized = val;
    if (sanitized.isNotEmpty && '=+-@'.contains(sanitized[0])) {
      sanitized = "'$sanitized";
    }

    if (sanitized.contains(',') ||
        sanitized.contains('"') ||
        sanitized.contains('\n')) {
      return '"${sanitized.replaceAll('"', '""')}"';
    }
    return sanitized;
  }

  DateTime _safeDateTime(String isoStr) {
    final dt = DateTime.tryParse(isoStr)?.toLocal();
    return dt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatLocalDateTime(String isoStr) {
    final dt = DateTime.tryParse(isoStr)?.toLocal();
    if (dt == null) return isoStr;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatHm(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _durationText(Duration? duration) {
    if (duration == null || duration.inMinutes <= 0) return '-';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}j';
    return '${hours}j ${minutes}m';
  }

  String _statusLabel(DailySummaryStatus status) {
    switch (status) {
      case DailySummaryStatus.sakit:
        return 'Sakit';
      case DailySummaryStatus.izin:
        return 'Izin';
      case DailySummaryStatus.belumPulang:
        return 'Belum Pulang';
      case DailySummaryStatus.normal:
        return 'Hadir';
    }
  }

  String _formatDateLabelForExport(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _exportToken() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }

  String _resolvedOutletName() {
    final activeOutletId = _activeOutletFilterId();
    if (activeOutletId == null) return 'Semua Outlet';
    for (final outlet in _outlets) {
      if (outlet.id == activeOutletId) return outlet.name;
    }
    return 'Outlet Terpilih';
  }

  String _formatDate(DateTime dt) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (range != null && mounted) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
        _markDataDirty();
      });
    }
  }

  // ── Rekap Harian computation ──────────────────────────────────────────────

  /// Group raw rows by (employeeId, dateString) and compute daily summary.
  List<DailySummary> _computeDailySummaries({List<_ReportRow>? sourceRows}) {
    final source = sourceRows ?? _dailyRows;
    // Sort ascending by time for correct duration calc
    final sorted = [...source]
      ..sort((a, b) => a.log.scannedAt.compareTo(b.log.scannedAt));

    // Group key = "employeeId|YYYY-MM-DD"
    final Map<String, List<_ReportRow>> groups = {};
    for (final row in sorted) {
      final dt = DateTime.tryParse(row.log.scannedAt)?.toLocal();
      if (dt == null) continue;
      final dateKey =
          '${row.log.employeeId}|${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      groups.putIfAbsent(dateKey, () => []).add(row);
    }

    // Second pass: re-attach orphaned pulang records (before 12:00) to prior day's group.
    // Handles cross-day night shifts (e.g., masuk 22:00 Day1, pulang 06:00 Day2).
    // IMPORTANT: collect mutations, apply after loop to avoid ConcurrentModificationError.
    final keysToRemove = <String>[];
    final rowsToAdd = <String, List<_ReportRow>>{};

    for (final entry in groups.entries) {
      final key = entry.key; // "employeeId|YYYY-MM-DD"
      final rows = entry.value;

      final hasMasuk = rows.any((r) => r.log.type == AttendanceType.masuk);
      if (hasMasuk) {
        continue; // Group already has masuk — no re-attachment needed
      }

      final employeeId = key.split('|')[0];
      final dateStr = key.split('|')[1];
      final groupDate = DateTime.tryParse(dateStr);
      if (groupDate == null) continue;

      // Find pulang records before noon — these are night-shift pulang scans
      final orphanPulangs = rows.where((r) {
        final dt = DateTime.tryParse(r.log.scannedAt)?.toLocal();
        return dt != null &&
            r.log.type == AttendanceType.pulang &&
            dt.hour < 12;
      }).toList();

      if (orphanPulangs.isEmpty) continue;

      // Build prior-day key
      final priorDate = groupDate.subtract(const Duration(days: 1));
      final priorKey =
          '$employeeId|${priorDate.year}-${priorDate.month.toString().padLeft(2, '0')}-${priorDate.day.toString().padLeft(2, '0')}';

      // Only re-attach if prior day has a masuk group — no phantom session creation
      if (!groups.containsKey(priorKey)) continue;

      rowsToAdd.putIfAbsent(priorKey, () => []).addAll(orphanPulangs);
      final remaining = rows.where((r) => !orphanPulangs.contains(r)).toList();
      if (remaining.isEmpty) {
        keysToRemove.add(key);
      } else {
        groups[key] = remaining;
      }
    }

    // Apply mutations after iteration — Dart forbids map modification during forEach
    for (final k in keysToRemove) {
      groups.remove(k);
    }
    for (final entry in rowsToAdd.entries) {
      groups[entry.key]!.addAll(entry.value);
      groups[entry.key]!
          .sort((a, b) => a.log.scannedAt.compareTo(b.log.scannedAt));
    }

    final summaries = <DailySummary>[];

    groups.forEach((key, rows) {
      final datePart = key.split('|')[1];
      final employee = rows.first.employee;
      final outlet = rows.first.outlet;

      // Find first masuk and last pulang
      DateTime? firstMasuk;
      DateTime? lastPulang;

      for (final r in rows) {
        final dt = DateTime.tryParse(r.log.scannedAt)?.toLocal();
        if (dt == null) continue;
        if (r.log.type == AttendanceType.masuk && firstMasuk == null) {
          firstMasuk = dt;
        }
        if (r.log.type == AttendanceType.pulang) {
          lastPulang = dt;
        }
      }

      // Compute total break duration
      // Logic: pair each breakTime with the next masuk after it
      Duration totalBreak = Duration.zero;
      DateTime? breakStart;
      for (final r in rows) {
        final dt = DateTime.tryParse(r.log.scannedAt)?.toLocal();
        if (dt == null) continue;
        if (r.log.type == AttendanceType.breakTime) {
          breakStart = dt;
        } else if (r.log.type == AttendanceType.kembali && breakStart != null) {
          // kembali = selesai istirahat
          final diff = dt.difference(breakStart);
          if (diff.isNegative == false) totalBreak += diff;
          breakStart = null;
        }
      }

      // Compute work duration = pulang - firstMasuk - totalBreak
      Duration? workDuration;
      if (firstMasuk != null && lastPulang != null) {
        final raw = lastPulang.difference(firstMasuk);
        workDuration = raw - totalBreak;
        if (workDuration.isNegative) workDuration = raw;
      }

      // Detect sakit/izin-only days (per REQ-M1-01).
      // Rule: if NO masuk scan exists AND sakit or izin scan exists → badge mode.
      // If masuk exists alongside sakit/izin (data error) → show normal 4-cell view.
      final hasMasukScan = rows.any((r) => r.log.type == AttendanceType.masuk);
      final hasSakit = rows.any((r) => r.log.type == AttendanceType.sakit);
      final hasIzin = rows.any((r) => r.log.type == AttendanceType.izin);

      DailySummaryStatus dayStatus = DailySummaryStatus.normal;
      if (!hasMasukScan && hasSakit) dayStatus = DailySummaryStatus.sakit;
      if (!hasMasukScan && hasIzin) dayStatus = DailySummaryStatus.izin;

      // Detect "belum pulang" — has masuk but no pulang, and it is a past date.
      // Guard: do NOT apply for today (employee may still be working).
      final groupDate = DateTime.tryParse(datePart);
      final today = DateTime.now();
      final isToday = groupDate != null &&
          groupDate.year == today.year &&
          groupDate.month == today.month &&
          groupDate.day == today.day;

      if (!isToday &&
          dayStatus == DailySummaryStatus.normal &&
          firstMasuk != null &&
          lastPulang == null) {
        dayStatus = DailySummaryStatus.belumPulang;
      }

      String? dayNotes;
      if (dayStatus == DailySummaryStatus.sakit ||
          dayStatus == DailySummaryStatus.izin) {
        dayNotes = rows
            .firstWhere(
              (r) =>
                  r.log.type == AttendanceType.sakit ||
                  r.log.type == AttendanceType.izin,
            )
            .log
            .notes;
      }

      summaries.add(DailySummary(
        dateLabel: datePart,
        employee: employee,
        outlet: outlet,
        firstMasuk: firstMasuk,
        lastPulang: lastPulang,
        workDuration: workDuration,
        totalBreak: totalBreak,
        scanCount: rows.length,
        status: dayStatus,
        statusNotes: dayNotes,
      ));
    });

    // Sort by date desc then employee name
    summaries.sort((a, b) {
      final dateComp = b.dateLabel.compareTo(a.dateLabel);
      if (dateComp != 0) return dateComp;
      return (a.employee?.name ?? '').compareTo(b.employee?.name ?? '');
    });

    return summaries;
  }

  // ── Export stats computation ──────────────────────────────────────────────

  AttendanceDailyPdfStats _computeExportStats(List<DailySummary> summaries) {
    // Group by employee
    final Map<String, List<DailySummary>> byEmployee = {};
    for (final s in summaries) {
      final key = s.employee?.id ?? 'unknown';
      byEmployee.putIfAbsent(key, () => []).add(s);
    }

    final employeeRows = <AttendanceDailyPdfEmployeeRow>[];
    int globalMasuk = 0;
    int globalTidakHadir = 0;
    int globalBelumPulang = 0;
    int globalScan = 0;

    for (final entry in byEmployee.entries) {
      final empSummaries = entry.value;
      final name = empSummaries.first.employee?.name ?? 'Tidak Diketahui';

      final masukDays =
          empSummaries.where((s) => s.firstMasuk != null).toList();
      final tidakHadirDays = empSummaries
          .where((s) =>
              s.status == DailySummaryStatus.sakit ||
              s.status == DailySummaryStatus.izin)
          .toList();
      final belumPulangDays = empSummaries
          .where((s) => s.status == DailySummaryStatus.belumPulang)
          .toList();

      // Avg masuk
      final masukTimes = masukDays
          .where((s) => s.firstMasuk != null)
          .map((s) => s.firstMasuk!.hour * 60 + s.firstMasuk!.minute)
          .toList();
      final avgMasukStr =
          masukTimes.isEmpty ? '--:--' : _avgMinutesToHm(masukTimes);

      // Avg pulang
      final pulangTimes = masukDays
          .where((s) => s.lastPulang != null)
          .map((s) => s.lastPulang!.hour * 60 + s.lastPulang!.minute)
          .toList();
      final avgPulangStr =
          pulangTimes.isEmpty ? '--:--' : _avgMinutesToHm(pulangTimes);

      // Total kerja
      Duration totalKerja = Duration.zero;
      for (final s in masukDays) {
        if (s.workDuration != null && !s.workDuration!.isNegative) {
          totalKerja += s.workDuration!;
        }
      }
      final totalKerjaStr =
          _durationText(totalKerja.inMinutes > 0 ? totalKerja : null);

      employeeRows.add(AttendanceDailyPdfEmployeeRow(
        nama: name,
        masukCount: masukDays.length,
        tidakHadirCount: tidakHadirDays.length,
        belumPulangCount: belumPulangDays.length,
        avgMasukStr: avgMasukStr,
        avgPulangStr: avgPulangStr,
        totalKerjaStr: totalKerjaStr,
      ));

      globalMasuk += masukDays.length;
      globalTidakHadir += tidakHadirDays.length;
      globalBelumPulang += belumPulangDays.length;
      globalScan += empSummaries.fold(0, (sum, s) => sum + s.scanCount);
    }

    // Sort by name
    employeeRows
        .sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    final totalEmployees = byEmployee.keys.length;

    return AttendanceDailyPdfStats(
      totalKaryawan: totalEmployees,
      totalMasuk: globalMasuk,
      totalTidakHadir: globalTidakHadir,
      totalBelumPulang: globalBelumPulang,
      totalScan: globalScan,
      employeeRows: employeeRows,
    );
  }

  String _avgMinutesToHm(List<int> minutesList) {
    if (minutesList.isEmpty) return '--:--';
    final avg = minutesList.reduce((a, b) => a + b) ~/ minutesList.length;
    return '${(avg ~/ 60).toString().padLeft(2, '0')}:${(avg % 60).toString().padLeft(2, '0')}';
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── FILTER PANEL ──────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              // Date range picker
              GestureDetector(
                onTap: _pickDateRange,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        '${_formatDate(_startDate)} – ${_formatDate(_endDate)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down,
                          color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Outlet + Load button row
              LayoutBuilder(
                builder: (context, constraints) {
                  final appState = ref.watch(appProvider);
                  final isFullAdmin = appState.isAdmin;
                  final isKepalaGerai = appState.isKepalaGerai;
                  const double buttonWidth = 96;
                  const double spacerWidth = 8;
                  final double dropdownWidth =
                      constraints.maxWidth - buttonWidth - spacerWidth;
                  // Kepala gerai: tampilkan nama outlet statis (tidak bisa ganti)
                  final lockedOutletName = isKepalaGerai
                      ? (_outlets
                              .where((o) => o.id == _selectedOutletId)
                              .map((o) => o.name)
                              .firstOrNull ??
                          'Outlet Saya')
                      : null;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: dropdownWidth,
                        child: isKepalaGerai
                            // Read-only outlet label untuk kepala_gerai
                            ? InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Outlet',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  suffixIcon: Icon(Icons.lock_outline,
                                      size: 16, color: Colors.grey),
                                ),
                                child: Text(
                                  lockedOutletName!,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            // Dropdown biasa untuk admin penuh dan area supervisor.
                            : DropdownButtonFormField<String?>(
                                initialValue: _selectedOutletId,
                                isDense: true,
                                decoration: const InputDecoration(
                                  labelText: 'Outlet',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                items: [
                                  if (isFullAdmin)
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Semua Outlet'),
                                    ),
                                  ..._outlets
                                      .map((o) => DropdownMenuItem<String?>(
                                            value: o.id,
                                            child: Text(
                                              o.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          )),
                                ],
                                onChanged: (v) => setState(() {
                                  _selectedOutletId = v;
                                  _markDataDirty();
                                }),
                              ),
                      ),
                      const SizedBox(width: spacerWidth),
                      SizedBox(
                        width: buttonWidth,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  _loadReport(reset: true);
                                  _loadDailySummaryData();
                                },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Tampilkan'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        // ── TAB BAR ───────────────────────────────────────────────────
        if (_hasLoaded) ...[
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: 'Per Scan'),
                Tab(text: 'Rekap Harian'),
              ],
            ),
          ),
          if (_tabCtrl.index == 0)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '${_rows.length} data scan',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: (_exportingCsv ||
                            _exportingPdf ||
                            _loading ||
                            _loadingDaily)
                        ? null
                        : _exportCsv,
                    icon: _exportingCsv
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary))
                        : const Icon(Icons.download_outlined,
                            size: 16, color: AppColors.primary),
                    label: Text(
                      _exportingCsv ? '...' : 'CSV',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: (_exportingPdf ||
                            _exportingCsv ||
                            _loading ||
                            _loadingDaily)
                        ? null
                        : _exportPdf,
                    icon: _exportingPdf
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary))
                        : const Icon(Icons.picture_as_pdf_outlined,
                            size: 16, color: AppColors.primary),
                    label: Text(
                      _exportingPdf ? '...' : 'PDF',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],

        // ── LIST CONTENT ──────────────────────────────────────────────
        Expanded(
          child: !_hasLoaded
              ? const AppEmptyState(
                  icon: Icons.bar_chart_outlined,
                  heading: 'Pilih Rentang Tanggal',
                  subtext: 'Pilih rentang tanggal lalu klik Tampilkan',
                )
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildPerScanTab(),
                    _buildRekapHarian(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPerScanTab() {
    if (_loading) {
      return _buildReportShimmer();
    }

    if (_rows.isEmpty) {
      return const AppEmptyState(
        icon: Icons.bar_chart_outlined,
        heading: 'Belum Ada Data',
        subtext: 'Tidak ada data absensi pada rentang waktu ini',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rows.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _rows.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator(color: AppColors.primary)
                  : ElevatedButton(
                      onPressed: () => _loadReport(reset: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text('Muat Lebih Banyak'),
                    ),
            ),
          );
        }
        return _ReportTile(row: _rows[i]);
      },
    );
  }

  Widget _buildRekapHarian() {
    // Hitung scan count per (employeeId, logicalDate) dari raw logs
    final scanCountMap = <String, int>{};
    for (final row in _dailyRows) {
      final dt = DateTime.tryParse(row.log.scannedAt)?.toLocal();
      if (dt == null) continue;
      final key =
          '${row.log.employeeId}|${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      scanCountMap[key] = (scanCountMap[key] ?? 0) + 1;
    }

    return PolicyRecapTab(
      isLoading: _loadingDaily,
      hasSelectedOutlet: true,
      policyError: _policyRecapError,
      rows: _policyRecapRows,
      fallbackRows: _policyRecapFallbackRows,
      selectedFilter: _selectedPolicyRecapFilter,
      onFilterChanged: (filter) {
        setState(() => _selectedPolicyRecapFilter = filter);
      },
      loadingBuilder: _buildReportShimmer,
      scanCountMap: scanCountMap,
      canExportPayrollPdf: _canExportPayrollPdf,
      canExportPayrollSpreadsheet: _canExportPayrollSpreadsheet,
      exportingPayrollPdf: _exportingPayrollPdf,
      exportingSpreadsheet: _exportingSpreadsheet,
      onExportPayrollPdf: _canExportPayrollPdf ? _exportPayrollPdf : null,
      onExportPayrollSpreadsheet:
          _canExportPayrollSpreadsheet ? _exportPayrollSpreadsheet : null,
      payrollExportStatusMessage: _payrollExportStatusMessage,
      payrollExportStatusIsError: _payrollExportStatusIsError,
      spreadsheetSortMode: _spreadsheetSortMode,
      onSortModeChanged: (mode) => setState(() => _spreadsheetSortMode = mode),
      nameQuery: _policyRecapNameQuery,
      onNameQueryChanged: (query) {
        setState(() => _policyRecapNameQuery = query);
      },
    );
  }

  Widget _buildReportShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          6,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: const [
                  ShimmerSkeleton(width: 36, height: 36, borderRadius: 18),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerSkeleton(
                            width: 120, height: 13, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerSkeleton(
                            width: 180, height: 11, borderRadius: 4),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  ShimmerSkeleton(width: 70, height: 11, borderRadius: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PolicyRecapTab extends StatelessWidget {
  const PolicyRecapTab({
    super.key,
    required this.isLoading,
    required this.hasSelectedOutlet,
    required this.policyError,
    required this.rows,
    required this.fallbackRows,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.loadingBuilder,
    required this.scanCountMap,
    required this.canExportPayrollPdf,
    required this.canExportPayrollSpreadsheet,
    required this.exportingPayrollPdf,
    required this.exportingSpreadsheet,
    this.onExportPayrollPdf,
    this.onExportPayrollSpreadsheet,
    this.payrollExportStatusMessage,
    this.payrollExportStatusIsError = false,
    this.emptyNoDataSubtext = 'Tidak ada hari recap pada rentang waktu ini.',
    this.spreadsheetSortMode = SpreadsheetSortMode.bermasalah,
    this.onSortModeChanged,
    this.nameQuery = '',
    this.onNameQueryChanged,
  });

  final bool isLoading;
  final bool hasSelectedOutlet;
  final String? policyError;
  final List<AttendancePolicyRecapDay> rows;
  final List<AttendancePolicyRecapDay> fallbackRows;
  final PolicyRecapFilter selectedFilter;
  final ValueChanged<PolicyRecapFilter> onFilterChanged;
  final Widget Function() loadingBuilder;
  final Map<String, int> scanCountMap;
  final String emptyNoDataSubtext;
  final bool canExportPayrollPdf;
  final bool canExportPayrollSpreadsheet;
  final bool exportingPayrollPdf;
  final bool exportingSpreadsheet;
  final VoidCallback? onExportPayrollPdf;
  final VoidCallback? onExportPayrollSpreadsheet;
  final String? payrollExportStatusMessage;
  final bool payrollExportStatusIsError;
  final SpreadsheetSortMode spreadsheetSortMode;
  final ValueChanged<SpreadsheetSortMode>? onSortModeChanged;
  final String nameQuery;
  final ValueChanged<String>? onNameQueryChanged;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return loadingBuilder();
    }

    if (!hasSelectedOutlet) {
      return const AppEmptyState(
        icon: Icons.storefront_outlined,
        heading: 'Belum Ada Data Rekap',
        subtext: 'Pilih satu outlet untuk melihat recap harian.',
      );
    }

    if (policyError != null && rows.isEmpty) {
      return const AppEmptyState(
        icon: Icons.rule_folder_outlined,
        heading: 'Rekap Policy Belum Tersedia',
        subtext:
            'Patch Phase 55 untuk rekap policy belum aktif di outlet ini. Coba lagi setelah SQL rollout disetujui.',
      );
    }

    final normalizedQuery = nameQuery.trim().toLowerCase();
    final filteredRows = filterPolicyRecapRows(rows, selectedFilter)
        .where(
          (row) =>
              normalizedQuery.isEmpty ||
              row.employeeName.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false)
      ..sort(_comparePolicyRecapRowsNewestFirst);
    final pendingBelumPulangCount =
        rows.where(_isBelumAbsenPulangPolicyRecapRow).length;
    final activeIncompleteCount =
        rows.where(_isActiveIncompletePolicyRecapRow).length;
    final pendingCount = pendingBelumPulangCount + activeIncompleteCount;
    final hasActiveFilter =
        selectedFilter != PolicyRecapFilter.semua || normalizedQuery.isNotEmpty;

    final summaryChips = <Widget>[
      _PolicyMetaChip(
        icon: Icons.calendar_month_outlined,
        label: '${rows.length} hari recap',
      ),
      if (pendingCount > 0)
        _PolicyMetaChip(
          icon: Icons.pending_actions_outlined,
          label: '$pendingCount pending',
        ),
      if (pendingBelumPulangCount > 0)
        _PolicyMetaChip(
          icon: Icons.logout_outlined,
          label: '$pendingBelumPulangCount belum pulang',
        ),
      if (activeIncompleteCount > 0)
        _PolicyMetaChip(
          icon: Icons.timelapse_outlined,
          label: '$activeIncompleteCount hari berjalan',
        ),
    ];

    final statusColor =
        payrollExportStatusIsError ? AppColors.danger : AppColors.textSecondary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        // ── Spreadsheet sort picker ───────────────────────────────
        if (onSortModeChanged != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Urutkan Spreadsheet:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('🔴 Bermasalah',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: spreadsheetSortMode ==
                                        SpreadsheetSortMode.bermasalah
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: spreadsheetSortMode ==
                                        SpreadsheetSortMode.bermasalah
                                    ? Colors.white
                                    : Colors.grey[800])),
                        selected: spreadsheetSortMode ==
                            SpreadsheetSortMode.bermasalah,
                        onSelected: (_) =>
                            onSortModeChanged!(SpreadsheetSortMode.bermasalah),
                        selectedColor: const Color(0xFFDC2626),
                        backgroundColor: Colors.grey[100],
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('⏱️ Terlambat',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: spreadsheetSortMode ==
                                        SpreadsheetSortMode.terlambat
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: spreadsheetSortMode ==
                                        SpreadsheetSortMode.terlambat
                                    ? Colors.white
                                    : Colors.grey[800])),
                        selected: spreadsheetSortMode ==
                            SpreadsheetSortMode.terlambat,
                        onSelected: (_) =>
                            onSortModeChanged!(SpreadsheetSortMode.terlambat),
                        selectedColor: const Color(0xFFDC2626),
                        backgroundColor: Colors.grey[100],
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('⏱️ Overtime',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: spreadsheetSortMode ==
                                        SpreadsheetSortMode.overtime
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: spreadsheetSortMode ==
                                        SpreadsheetSortMode.overtime
                                    ? Colors.white
                                    : Colors.grey[800])),
                        selected:
                            spreadsheetSortMode == SpreadsheetSortMode.overtime,
                        onSelected: (_) =>
                            onSortModeChanged!(SpreadsheetSortMode.overtime),
                        selectedColor: const Color(0xFFDC2626),
                        backgroundColor: Colors.grey[100],
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('✅ Aman',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: spreadsheetSortMode ==
                                        SpreadsheetSortMode.aman
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: spreadsheetSortMode ==
                                        SpreadsheetSortMode.aman
                                    ? Colors.white
                                    : Colors.grey[800])),
                        selected:
                            spreadsheetSortMode == SpreadsheetSortMode.aman,
                        onSelected: (_) =>
                            onSortModeChanged!(SpreadsheetSortMode.aman),
                        selectedColor: const Color(0xFF059669),
                        backgroundColor: Colors.grey[100],
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        // ── Export buttons at top ──────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _CompactExportButton(
                icon: Icons.grid_on_outlined,
                label: 'Spreadsheet',
                isLoading: exportingSpreadsheet,
                onPressed: canExportPayrollSpreadsheet
                    ? onExportPayrollSpreadsheet
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactExportButton(
                icon: Icons.picture_as_pdf_outlined,
                label: 'PDF Insight',
                isLoading: exportingPayrollPdf,
                onPressed: canExportPayrollPdf ? onExportPayrollPdf : null,
              ),
            ),
          ],
        ),
        if (payrollExportStatusMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            payrollExportStatusMessage!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
        // ── Policy error partial warning ──────────────────────────
        if (policyError != null && rows.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: const Text(
              'Sebagian hasil recap dimuat lewat mode pemulihan karena fetch policy utama belum lengkap.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
        // ── Summary chips ─────────────────────────────────────────
        if (summaryChips.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: summaryChips,
            ),
          ),
        ],
        // ── Filter toggle + chips ─────────────────────────────────
        const SizedBox(height: 12),
        if (onNameQueryChanged != null) ...[
          _PolicyRecapSearchField(
            initialValue: nameQuery,
            onChanged: onNameQueryChanged!,
          ),
          const SizedBox(height: 12),
        ],
        _PolicyRecapFilterSection(
          selectedFilter: selectedFilter,
          onFilterChanged: onFilterChanged,
          hasActiveFilter: hasActiveFilter,
        ),
        const SizedBox(height: 12),
        // ── Filtered rows ─────────────────────────────────────────
        if (filteredRows.isEmpty)
          AppEmptyState(
            icon: Icons.event_busy_outlined,
            heading: 'Belum Ada Hari yang Cocok',
            subtext: normalizedQuery.isNotEmpty
                ? 'Tidak ada nama karyawan yang cocok dengan pencarian "$nameQuery".'
                : selectedFilter == PolicyRecapFilter.semua
                    ? emptyNoDataSubtext
                    : 'Tidak ada hari yang cocok dengan filter ${selectedFilter.label.toLowerCase()} pada rentang ini.',
          )
        else
          ...filteredRows.map(
            (row) => PolicyRecapTile(recap: row, scanCountMap: scanCountMap),
          ),
      ],
    );
  }
}

int _comparePolicyRecapRowsNewestFirst(
  AttendancePolicyRecapDay left,
  AttendancePolicyRecapDay right,
) {
  final leftDate = DateTime(
    left.logicalDate.year,
    left.logicalDate.month,
    left.logicalDate.day,
  );
  final rightDate = DateTime(
    right.logicalDate.year,
    right.logicalDate.month,
    right.logicalDate.day,
  );
  final dateComparison = rightDate.compareTo(leftDate);
  if (dateComparison != 0) return dateComparison;
  final nameComparison = left.employeeName
      .toLowerCase()
      .compareTo(right.employeeName.toLowerCase());
  if (nameComparison != 0) return nameComparison;
  return left.employeeId.compareTo(right.employeeId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

class _ReportRow {
  final AttendanceLog log;
  final Employee? employee;
  final Outlet? outlet;

  _ReportRow({required this.log, this.employee, this.outlet});

  factory _ReportRow.fromJson(Map<String, dynamic> json) {
    final empJson = json['employees'] as Map<String, dynamic>?;
    final outJson = json['outlets'] as Map<String, dynamic>?;
    return _ReportRow(
      log: AttendanceLog.fromJson(json),
      employee: empJson != null ? Employee.fromJson(empJson) : null,
      outlet: outJson != null ? Outlet.fromJson(outJson) : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-Scan Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ReportTile extends StatelessWidget {
  final _ReportRow row;

  const _ReportTile({required this.row});

  Color get _typeColor {
    switch (row.log.type) {
      case AttendanceType.masuk:
        return AppColors.success;
      case AttendanceType.kembali:
        return const Color(0xFF0891B2);
      case AttendanceType.breakTime:
        return AppColors.accent;
      case AttendanceType.pulang:
        return AppColors.danger;
      case AttendanceType.sakit:
        return const Color(0xFFDC2626);
      case AttendanceType.izin:
        return const Color(0xFF2563EB);
    }
  }

  String _formatDateTime(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des'
      ];
      return '${dt.day} ${months[dt.month]}, '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                row.log.type.emoji,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.employee?.name ?? '-',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  '${row.outlet?.name ?? '-'} · ${row.log.type.label}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Text(
            _formatDateTime(row.log.scannedAt),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _typeColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Policy Recap Tile — Rekap Harian Phase 55
// ─────────────────────────────────────────────────────────────────────────────

class PolicyRecapTile extends StatelessWidget {
  final AttendancePolicyRecapDay recap;
  final Map<String, int> scanCountMap;

  const PolicyRecapTile({
    super.key,
    required this.recap,
    required this.scanCountMap,
  });

  String _formatDate(DateTime dt) {
    const days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    return '${days[dt.weekday % 7]}, ${dt.day} ${months[dt.month]} ${dt.year}';
  }

  int _scanCount() {
    final d = recap.logicalDate;
    final key =
        '${recap.employeeId}|${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return scanCountMap[key] ?? 0;
  }

  List<Widget> _buildSignalBadges() {
    final badges = <Widget>[];

    // Non-working day states: show one identifying badge and return early.
    // Without this, libur/sakit/izin/cuti tiles appear blank (all "--") and
    // look identical to absent employees.
    if (recap.primaryStatus == AttendancePolicyPrimaryStatus.libur ||
        recap.attendanceStatus == AttendancePolicyStatus.libur) {
      return [
        _SignalBadge(
          label: 'Libur',
          bgColor: const Color(0xFFF3F4F6),
          textColor: const Color(0xFF6B7280),
        ),
      ];
    }
    if (recap.primaryStatus == AttendancePolicyPrimaryStatus.sakit ||
        recap.attendanceStatus == AttendancePolicyStatus.sakit) {
      return [
        _SignalBadge(
          label: 'Sakit',
          bgColor: const Color(0xFFFEF3C7),
          textColor: const Color(0xFF92400E),
        ),
      ];
    }
    if (recap.primaryStatus == AttendancePolicyPrimaryStatus.izin ||
        recap.attendanceStatus == AttendancePolicyStatus.izin) {
      return [
        _SignalBadge(
          label: 'Izin',
          bgColor: const Color(0xFFDBEAFE),
          textColor: const Color(0xFF1E40AF),
        ),
      ];
    }
    if (recap.primaryStatus == AttendancePolicyPrimaryStatus.cuti ||
        recap.attendanceStatus == AttendancePolicyStatus.cuti) {
      return [
        _SignalBadge(
          label: 'Cuti',
          bgColor: const Color(0xFFF3E8FF),
          textColor: const Color(0xFF7C3AED),
        ),
      ];
    }

    // Attendance status badges
    if (recap.attendanceStatus == AttendancePolicyStatus.tidakHadir ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.absence ||
        recap.hasSignal(AttendancePolicySignal.absence)) {
      badges.add(_SignalBadge(
        label: 'Tidak Hadir',
        bgColor: const Color(0xFFFEE2E2),
        textColor: const Color(0xFFDC2626),
      ));
    }

    if (recap.attendanceStatus == AttendancePolicyStatus.hadirTanpaJadwal ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.hadirTanpaJadwal ||
        recap.hasSignal(AttendancePolicySignal.hadirTanpaJadwal)) {
      badges.add(_SignalBadge(
        label: 'Hadir Tanpa Jadwal',
        bgColor: const Color(0xFFECFEFF),
        textColor: const Color(0xFF0F766E),
      ));
    }

    // Late
    if (recap.isLate ||
        recap.lateKind == LateKind.normal ||
        recap.hasSignal(AttendancePolicySignal.late) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.late) {
      badges.add(_SignalBadge(
        label: 'Terlambat',
        bgColor: const Color(0xFFFEF3C7),
        textColor: const Color(0xFF92400E),
      ));
    }

    // Short work
    if (recap.hasSignal(AttendancePolicySignal.shortWork) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.shortWork) {
      final shortMin = recap.shortWorkMinutes ?? 0;
      final shortLabel = shortMin > 0
          ? 'Kurang Jam (${_formatPolicyMinutes(shortMin)})'
          : 'Kurang Jam Kerja';
      badges.add(_SignalBadge(
        label: shortLabel,
        bgColor: const Color(0xFFFEE2E2),
        textColor: const Color(0xFFDC2626),
      ));
    }

    // Excess break
    if (recap.hasSignal(AttendancePolicySignal.excessBreak) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.excessBreak) {
      final excessMin = recap.excessBreakMinutes ?? 0;
      final excessLabel = excessMin > 0
          ? 'Istirahat Berlebih (+${_formatPolicyMinutes(excessMin)})'
          : 'Istirahat Berlebih';
      badges.add(_SignalBadge(
        label: excessLabel,
        bgColor: const Color(0xFFFEE2E2),
        textColor: const Color(0xFFDC2626),
      ));
    }

    // Overtime
    if (recap.hasSignal(AttendancePolicySignal.overtime) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.overtime) {
      final otMin = recap.overtimeMinutes ?? 0;
      final otLabel =
          otMin > 0 ? 'Lembur (${_formatPolicyMinutes(otMin)})' : 'Lembur';
      badges.add(_SignalBadge(
        label: otLabel,
        bgColor: const Color(0xFFFEF3C7),
        textColor: const Color(0xFF92400E),
      ));
    }

    // Manager exempt
    if (recap.isManagerExempt ||
        recap.hasSignal(AttendancePolicySignal.exemptManager) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.exemptManager) {
      badges.add(_SignalBadge(
        label: 'Manager Exempt',
        bgColor: const Color(0xFFF8FAFC),
        textColor: const Color(0xFF334155),
      ));
    }

    // Belum absen pulang
    if (recap.hasSignal(AttendancePolicySignal.belumAbsenPulang) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.belumAbsenPulang) {
      badges.add(_SignalBadge(
        label: 'Belum Absen Pulang',
        bgColor: const Color(0xFFFEE2E2),
        textColor: const Color(0xFFDC2626),
      ));
    }

    // Active incomplete (still working today)
    if (recap.hasSignal(AttendancePolicySignal.activeIncomplete) ||
        recap.primaryStatus == AttendancePolicyPrimaryStatus.activeIncomplete) {
      badges.add(_SignalBadge(
        label: 'Hari Berjalan',
        bgColor: const Color(0xFFDBEAFE),
        textColor: const Color(0xFF1E40AF),
      ));
    }

    return badges;
  }

  String? _buildReasonText() {
    final reason = buildPolicyRecapReasonCopy(recap);
    // Don't show generic status labels as reason — they're already visible
    if (reason == recap.attendanceStatus.label) return null;
    if (reason.isEmpty) return null;
    return reason;
  }

  @override
  Widget build(BuildContext context) {
    final initial = recap.employeeName.isNotEmpty
        ? recap.employeeName[0].toUpperCase()
        : '?';
    final count = _scanCount();

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: avatar · nama · badge scan ──────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recap.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${recap.outletName} · ${_formatDate(recap.logicalDate)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count scan',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // ── 4 time chips ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _TimeChip(
                  icon: Icons.login_outlined,
                  label: 'Masuk',
                  value: _formatPolicyTime(recap.firstScanLocal),
                  bgColor: const Color(0xFFDCFCE7),
                  textColor: const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TimeChip(
                  icon: Icons.logout_outlined,
                  label: 'Pulang',
                  value: _formatPolicyTime(recap.lastPulangLocal),
                  bgColor: const Color(0xFFFEE2E2),
                  textColor: const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TimeChip(
                  icon: Icons.timer_outlined,
                  label: 'Kerja',
                  value: _formatPolicyMinutes(recap.netWorkMinutes),
                  bgColor: const Color(0xFFFEE2E2),
                  textColor: const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TimeChip(
                  icon: Icons.free_breakfast_outlined,
                  label: 'Istirahat',
                  value: (recap.totalBreakMinutes ?? 0) > 0
                      ? _formatPolicyMinutes(recap.totalBreakMinutes)
                      : '–',
                  bgColor: const Color(0xFFFEF9C3),
                  textColor: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          // ── Violation / status badges ──────────────────────────────
          if (_buildSignalBadges().isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _buildSignalBadges(),
            ),
          ],
          // ── Reason copy ─────────────────────────────────────────────
          if (_buildReasonText() != null) ...[
            const SizedBox(height: 8),
            Text(
              _buildReasonText()!,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact Export Button
// ─────────────────────────────────────────────────────────────────────────────

class _CompactExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _CompactExportButton({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        side: BorderSide(
          color: onPressed != null ? AppColors.primary : AppColors.border,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : Icon(icon, size: 16, color: AppColors.primary),
      label: Text(
        isLoading ? '...' : label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color:
              onPressed != null ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Policy Name Search
// ─────────────────────────────────────────────────────────────────────────────

class _PolicyRecapSearchField extends StatefulWidget {
  const _PolicyRecapSearchField({
    required this.initialValue,
    required this.onChanged,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_PolicyRecapSearchField> createState() =>
      _PolicyRecapSearchFieldState();
}

class _PolicyRecapSearchFieldState extends State<_PolicyRecapSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _PolicyRecapSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Bersihkan pencarian',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              ),
        labelText: 'Cari nama karyawan',
        hintText: 'Ketik nama',
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Toggle Section (AnimatedCrossFade)
// ─────────────────────────────────────────────────────────────────────────────

class _PolicyRecapFilterSection extends StatefulWidget {
  final PolicyRecapFilter selectedFilter;
  final ValueChanged<PolicyRecapFilter> onFilterChanged;
  final bool hasActiveFilter;

  const _PolicyRecapFilterSection({
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.hasActiveFilter,
  });

  @override
  State<_PolicyRecapFilterSection> createState() =>
      _PolicyRecapFilterSectionState();
}

class _PolicyRecapFilterSectionState extends State<_PolicyRecapFilterSection> {
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showFilters = !_showFilters),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 20,
                    color: widget.hasActiveFilter
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  if (widget.hasActiveFilter)
                    Positioned(
                      top: -2,
                      right: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              Text(
                widget.hasActiveFilter ? widget.selectedFilter.label : 'Filter',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.hasActiveFilter
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _showFilters
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _showFilters
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PolicyRecapFilter.values.map((filter) {
                final isSelected = filter == widget.selectedFilter;
                return ChoiceChip(
                  label: Text(filter.label),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: AppColors.primary.withValues(alpha: 0.12),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  onSelected: (_) => widget.onFilterChanged(filter),
                );
              }).toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Policy Meta Chip
// ─────────────────────────────────────────────────────────────────────────────

class _PolicyMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PolicyMetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color bgColor;
  final Color textColor;

  const _TimeChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: textColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalBadge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const _SignalBadge({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
