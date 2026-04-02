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
import 'package:absensi_enakko_flutter/models/payroll_rollout_acceptance.dart';
import 'package:absensi_enakko_flutter/providers/app_provider.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/payroll_matrix_table.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/payroll_rollout_acceptance_panel.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/policy_recap_payroll_support_section.dart';
import 'package:absensi_enakko_flutter/services/admin_policy_recap_dataset_service.dart';
import 'package:absensi_enakko_flutter/services/attendance_policy_recap_service.dart';
import 'package:absensi_enakko_flutter/services/badge_service.dart';
import 'package:absensi_enakko_flutter/services/payroll_matrix_builder.dart';
import 'package:absensi_enakko_flutter/services/payroll_pdf_matrix_export_service.dart';
import 'package:absensi_enakko_flutter/services/payroll_spreadsheet_export_service.dart';
import 'package:absensi_enakko_flutter/services/payroll_validation_bundle_service.dart';
import 'package:absensi_enakko_flutter/services/pdf_service.dart';
import 'package:absensi_enakko_flutter/widgets/app_card.dart';
import 'package:absensi_enakko_flutter/widgets/app_empty_state.dart';
import 'package:absensi_enakko_flutter/widgets/app_toast.dart';
import 'package:absensi_enakko_flutter/widgets/attendance_policy_badge.dart';
import 'package:absensi_enakko_flutter/widgets/attendance_policy_signal_chip.dart';
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

    final strictNotes = recap.detailNotes
        .map((note) => note.trim())
        .where((note) => note.isNotEmpty)
        .toList(growable: false);
    if (strictNotes.isNotEmpty) {
      return strictNotes.first;
    }
  }

  if (recap.lateKind == LateKind.breakFirstEligible) {
    return 'Masih dalam jendela break-first, menunggu konfirmasi.';
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

  if (recap.lateKind == LateKind.breakFirstConfirmed) {
    return 'Break-first: scan pertama ${_formatPolicyTime(recap.firstScanLocal)}, batas ${recap.lateCutoffLocal ?? '--:--'}';
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

const String payrollCompatibilityModeTitle = 'Mode kompatibilitas aktif';
const String payrollCompatibilityModeBody =
    'Sebagian hari payroll dihitung dari log absensi dan kontrak karena jadwal belum tersedia.';
const String policyRecapCompatibilityModeTitle = 'Mode kompatibilitas aktif';
const String policyRecapCompatibilityModeBody =
    'Sebagian hari admin recap dipulihkan dari log absensi dan kontrak karena jadwal belum tersedia.';

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
  bool _isPayrollCompatibilityMode = false;
  PolicyRecapFilter _selectedPolicyRecapFilter = PolicyRecapFilter.semua;
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
  final PayrollValidationBundleService _payrollValidationBundleService =
      PayrollValidationBundleService();

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
    // Kepala gerai: auto-set outlet sebelum load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = ref.read(appProvider);
      if (appState.isKepalaGerai && appState.managedOutletId != null) {
        setState(() => _selectedOutletId = appState.managedOutletId);
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
      final data = await SupabaseClientFactory.admin
          .from('outlets')
          .select('*')
          .eq('is_active', true)
          .order('name');
      if (mounted) {
        setState(() {
          _outlets = (data as List)
              .map((e) => Outlet.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
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
    _isPayrollCompatibilityMode = false;
    _selectedPolicyRecapFilter = PolicyRecapFilter.semua;
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

    if (_selectedOutletId != null) {
      query = query.eq('scan_outlet_id', _selectedOutletId!);
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
    final outletId = _selectedOutletId?.trim();
    final shouldLoadPolicyRecap = outletId != null && outletId.isNotEmpty;

    setState(() {
      _loadingDaily = true;
      _policyRecapError = null;
    });

    try {
      final allRowsFuture = _fetchAllRowsForExport(ascending: true);
      final employeesFuture = shouldLoadPolicyRecap
          ? _fetchPayrollRoster(outletId)
          : Future<List<Employee>>.value(const <Employee>[]);
      final recapFuture = () async {
        if (!shouldLoadPolicyRecap) {
          return (
            rows: const <AttendancePolicyRecapDay>[],
            error: null as String?,
          );
        }

        try {
          final rows =
              await _attendancePolicyRecapService.fetchAdminSchedulePolicyRecap(
            outletId: outletId,
            startDate: _startDate,
            endDate: _endDate,
          );
          return (rows: rows, error: null as String?);
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

      final payrollOutletContext = _resolvePayrollOutletContext(allRows);
      final recapDataset = shouldLoadPolicyRecap
          ? _adminPolicyRecapDatasetService.build(
              employees: employees,
              strictRows: recapResult.rows,
              attendanceLogs: allRows.map((row) => row.log),
              outletId: outletId,
              outletName: payrollOutletContext.outletName,
              outletOperatingMode: payrollOutletContext.operatingMode,
              now: DateTime.now(),
            )
          : const AdminPolicyRecapDatasetResult(
              mergedRows: <AttendancePolicyRecapDay>[],
              strictRows: <AttendancePolicyRecapDay>[],
              fallbackRows: <AttendancePolicyRecapDay>[],
            );
      final payrollDataset = shouldLoadPolicyRecap
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
        _isPayrollCompatibilityMode = recapDataset.isCompatibilityMode;
        _selectedPolicyRecapFilter = PolicyRecapFilter.semua;
        _policyRecapError = recapResult.error;
        _loadingDaily = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingDaily = false);
    }
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

  ({String outletName, OutletOperatingMode operatingMode})
      _resolvePayrollOutletContext(List<_ReportRow> sourceRows) {
    final selectedOutletId = _selectedOutletId?.trim();
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
    final hasSelectedOutlet =
        _selectedOutletId != null && _selectedOutletId!.trim().isNotEmpty;
    return hasSelectedOutlet &&
        _hasValidPayrollDateRange &&
        dataset != null &&
        !dataset.isEmpty &&
        !_exportingSpreadsheet &&
        !_loadingDaily;
  }

  bool get _canExportPayrollPdf {
    final dataset = _payrollMatrixDataset;
    final hasSelectedOutlet =
        _selectedOutletId != null && _selectedOutletId!.trim().isNotEmpty;
    return hasSelectedOutlet &&
        _hasValidPayrollDateRange &&
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
        isCompatibilityMode: _isPayrollCompatibilityMode,
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

  Future<void> _downloadPayrollValidationBundle(
    PayrollRolloutAcceptanceSummary summary,
  ) async {
    final outletName = _resolvedOutletName();

    try {
      final bundle =
          _payrollValidationBundleService.buildPayrollValidationBundle(
        outletName: outletName,
        startDate: _startDate,
        endDate: _endDate,
        summary: summary,
      );
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}${bundle.filename}',
      );
      await file.writeAsString(bundle.content, flush: true);

      await Share.shareXFiles(
        <XFile>[
          XFile(
            file.path,
            mimeType: 'text/markdown',
          ),
        ],
        subject: 'Bukti Validasi Payroll Enakko - $outletName',
      );

      if (!mounted) return;
      AppToast.success(context, 'Bukti validasi siap dibagikan.');
    } catch (_) {
      if (!mounted) return;
      AppToast.error(
        context,
        'Bukti validasi belum bisa dibuat. Coba lagi setelah review parity.',
      );
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
    if (_selectedOutletId == null) return 'Semua Outlet';
    for (final outlet in _outlets) {
      if (outlet.id == _selectedOutletId) return outlet.name;
    }
    return 'Outlet Terpilih';
  }

  List<PayrollScenarioReview> _buildPayrollRolloutReviews() {
    final logicalWorkdayLabel = _formatDate(_endDate);
    return requiredPayrollRolloutScenarioIds
        .map(
          (scenarioId) => PayrollScenarioReview(
            scenarioId: scenarioId,
            logicalWorkdayLabel: logicalWorkdayLabel,
            contextLabel: 'Menunggu bukti parity',
            evidenceBySource: const <PayrollEvidenceSource,
                PayrollEvidenceSnapshot>{},
          ),
        )
        .toList(growable: false);
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
                  final isKepalaGerai = ref.watch(appProvider).isKepalaGerai;
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
                            // Dropdown biasa untuk admin
                            : DropdownButtonFormField<String?>(
                                initialValue: _selectedOutletId,
                                isDense: true,
                                decoration: const InputDecoration(
                                  labelText: 'Outlet',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                items: [
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
    return PolicyRecapTab(
      isLoading: _loadingDaily,
      hasSelectedOutlet:
          _selectedOutletId != null && _selectedOutletId!.trim().isNotEmpty,
      policyError: _policyRecapError,
      rows: _policyRecapRows,
      fallbackRows: _policyRecapFallbackRows,
      selectedFilter: _selectedPolicyRecapFilter,
      onFilterChanged: (filter) {
        setState(() => _selectedPolicyRecapFilter = filter);
      },
      loadingBuilder: _buildReportShimmer,
      salaryOutputSection: _buildPayrollSupportSection(),
    );
  }

  Widget _buildPayrollSupportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PayrollRolloutAcceptancePanel(
          reviews: _buildPayrollRolloutReviews(),
          outletName: _resolvedOutletName(),
          startDate: _startDate,
          endDate: _endDate,
          onDownloadValidationBundle: _downloadPayrollValidationBundle,
          onMarkPayrollReady: () {},
        ),
        const SizedBox(height: 16),
        PolicyRecapPayrollSupportSection(
          reviews: _buildPayrollRolloutReviews(),
          outletName: _resolvedOutletName(),
          startDate: _startDate,
          endDate: _endDate,
          onDownloadValidationBundle: (_) async {},
          onMarkPayrollReady: null,
          canExportPayrollPdf: _canExportPayrollPdf,
          canExportPayrollSpreadsheet: _canExportPayrollSpreadsheet,
          exportingPayrollPdf: _exportingPayrollPdf,
          exportingSpreadsheet: _exportingSpreadsheet,
          onExportPayrollPdf: _canExportPayrollPdf ? _exportPayrollPdf : null,
          onExportPayrollSpreadsheet:
              _canExportPayrollSpreadsheet ? _exportPayrollSpreadsheet : null,
          payrollExportStatusMessage: _payrollExportStatusMessage,
          payrollExportStatusIsError: _payrollExportStatusIsError,
          previewSection: _buildPayrollMatrixPreviewSection(),
        ),
      ],
    );
  }

  Widget? _buildPayrollMatrixPreviewSection() {
    final dataset = _payrollMatrixDataset;
    if (dataset == null || dataset.isEmpty) {
      return null;
    }

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 12),
        title: const Text(
          'Pratinjau payroll matrix',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: const Text(
          'Tetap tersedia sebagai referensi pendukung gaji.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        children: [
          SizedBox(
            height: math.min(
              320.0,
              MediaQuery.of(context).size.height * 0.42,
            ),
            child: PayrollMatrixTable(
              dataset: dataset,
              dateHeaders: dataset.dates,
            ),
          ),
        ],
      ),
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
    this.salaryOutputSection,
    this.emptyNoDataSubtext = 'Tidak ada hari recap pada rentang waktu ini.',
  });

  final bool isLoading;
  final bool hasSelectedOutlet;
  final String? policyError;
  final List<AttendancePolicyRecapDay> rows;
  final List<AttendancePolicyRecapDay> fallbackRows;
  final PolicyRecapFilter selectedFilter;
  final ValueChanged<PolicyRecapFilter> onFilterChanged;
  final Widget Function() loadingBuilder;
  final String emptyNoDataSubtext;
  final Widget? salaryOutputSection;

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

    final filteredRows = filterPolicyRecapRows(rows, selectedFilter);
    final pendingBelumPulangCount =
        rows.where(_isBelumAbsenPulangPolicyRecapRow).length;
    final activeIncompleteCount =
        rows.where(_isActiveIncompletePolicyRecapRow).length;
    final pendingCount = pendingBelumPulangCount + activeIncompleteCount;

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
      if (fallbackRows.isNotEmpty)
        _PolicyMetaChip(
          icon: Icons.history_toggle_off_outlined,
          label: '${fallbackRows.length} kompatibilitas',
        ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        const Text(
          'Rekap Harian',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pantau recap harian per karyawan. PDF payroll dan spreadsheet tetap tersedia sebagai output gaji pendukung.',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
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
        if (fallbackRows.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFF475569),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        policyRecapCompatibilityModeTitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        policyRecapCompatibilityModeBody,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PolicyRecapFilter.values.map((filter) {
            final isSelected = filter == selectedFilter;
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
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              onSelected: (_) => onFilterChanged(filter),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 12),
        if (filteredRows.isEmpty)
          AppEmptyState(
            icon: Icons.event_busy_outlined,
            heading: 'Belum Ada Hari yang Cocok',
            subtext: selectedFilter == PolicyRecapFilter.semua
                ? emptyNoDataSubtext
                : 'Tidak ada hari yang cocok dengan filter ${selectedFilter.label.toLowerCase()} pada rentang ini.',
          )
        else
          ...filteredRows.map((row) => PolicyRecapTile(recap: row)),
        if (salaryOutputSection != null) ...[
          const SizedBox(height: 16),
          salaryOutputSection!,
        ],
      ],
    );
  }
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

  const PolicyRecapTile({super.key, required this.recap});

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

  String _requiredHours() {
    final minutes = recap.requiredWorkMinutes;
    if (minutes == null || minutes <= 0) return '-';
    return '${minutes ~/ 60}j';
  }

  String _policyContext() {
    if (recap.shiftBand == null) {
      return 'Tanpa jadwal';
    }

    return '${recap.shiftBand!.label} · ${_requiredHours()}';
  }

  String _cutoffContext() {
    if (recap.shiftBand == null) {
      return 'Hadir tanpa jadwal';
    }

    final cutoff = recap.lateCutoffLocal ?? '--:--';
    final breakFirst = recap.breakFirstDeadlineLocal;
    if (breakFirst == null || breakFirst.isEmpty) {
      return 'Batas telat $cutoff';
    }

    return 'Batas $cutoff · Break-first $breakFirst';
  }

  @override
  Widget build(BuildContext context) {
    final detailChips = recap.detailSignals
        .map((signal) => AttendancePolicySignalChip(signal: signal))
        .toList(growable: false);
    final metricChips = [
      _PolicyMetaChip(
        icon: Icons.schedule_outlined,
        label: _policyContext(),
      ),
      _PolicyMetaChip(
        icon: Icons.timer_outlined,
        label: _cutoffContext(),
      ),
      if (recap.netWorkMinutes != null)
        _PolicyMetaChip(
          icon: Icons.work_outline,
          label: 'Kerja ${_formatPolicyMinutes(recap.netWorkMinutes)}',
        ),
      if (recap.totalBreakMinutes != null)
        _PolicyMetaChip(
          icon: Icons.free_breakfast_outlined,
          label: 'Break ${_formatPolicyMinutes(recap.totalBreakMinutes)}',
        ),
      if ((recap.overtimeMinutes ?? 0) > 0)
        _PolicyMetaChip(
          icon: Icons.trending_up_outlined,
          label: 'Lembur ${_formatPolicyMinutes(recap.overtimeMinutes)}',
        ),
      if ((recap.shortWorkMinutes ?? 0) > 0)
        _PolicyMetaChip(
          icon: Icons.timer_off_outlined,
          label: 'Kurang ${_formatPolicyMinutes(recap.shortWorkMinutes)}',
        ),
      if ((recap.excessBreakMinutes ?? 0) > 0)
        _PolicyMetaChip(
          icon: Icons.hourglass_bottom_outlined,
          label:
              'Lebih break ${_formatPolicyMinutes(recap.excessBreakMinutes)}',
        ),
    ];

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recap.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${recap.outletName} · ${_formatDate(recap.logicalDate)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AttendancePolicyBadge(
                primaryStatus: recap.primaryStatus,
                primarySeverity: recap.primarySeverity,
                status: recap.attendanceStatus,
                lateKind: recap.lateKind,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: metricChips,
          ),
          if (detailChips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: detailChips,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            buildPolicyRecapReasonCopy(recap),
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

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
