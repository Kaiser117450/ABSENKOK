import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/attendance_log.dart';
import '../../models/daily_summary.dart';
import '../../models/employee.dart';
import '../../models/outlet.dart';
import '../../providers/app_provider.dart';
import '../../services/badge_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/badge_avatar.dart';
import '../../widgets/shimmer_skeleton.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Admin Reports Screen
// ─────────────────────────────────────────────────────────────────────────────

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
  bool _hasLoaded = false;
  
  // Pagination
  static const int _limit = 50;
  int _currentOffset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Rekap Harian — independent full-dataset fetch (no pagination)
  List<_ReportRow> _dailyRows = [];
  bool _loadingDaily = false;

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
    _currentOffset = 0;
    _hasMore = true;
    _isLoadingMore = false;
    _loading = false;
    _loadingDaily = false;
  }

  dynamic _buildAttendanceBaseQuery() {
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

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
  }) async {
    final allRows = <_ReportRow>[];
    var offset = 0;

    while (true) {
      final data = await _buildAttendanceBaseQuery()
          .order('scanned_at', ascending: ascending)
          .range(offset, offset + batchSize - 1);

      final batch = (data as List)
          .map((e) => _ReportRow.fromJson(e as Map<String, dynamic>))
          .toList();
      allRows.addAll(batch);

      if (batch.length < batchSize) break;
      offset += batchSize;
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
    setState(() => _loadingDaily = true);
    try {
      final allRows = await _fetchAllRowsForExport(ascending: true);
      if (!mounted) return;
      setState(() {
        _dailyRows = allRows;
        _loadingDaily = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingDaily = false);
    }
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
        buffer.writeln('Tanggal,Nama,Outlet,Status,Masuk,Pulang,Kerja,Istirahat,Jumlah Scan,Catatan');
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
          buffer.writeln('$date,$name,$outlet,$status,$masuk,$pulang,$kerja,$istirahat,$scanCount,$notes');
        }
      } else {
        buffer.writeln('Nama,Jabatan,Outlet,Jenis,Waktu Lokal,Latitude,Longitude,Catatan');
        final sorted = [...allRows]
          ..sort((a, b) => _safeDateTime(b.log.scannedAt).compareTo(_safeDateTime(a.log.scannedAt)));

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
        subject: isRekap ? 'Laporan Rekap Harian Enakko' : 'Laporan Per Scan Enakko',
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
        final sorted = [...allRows]
          ..sort((a, b) => _safeDateTime(b.log.scannedAt).compareTo(_safeDateTime(a.log.scannedAt)));

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

  String _escapeCsv(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
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
      if (hasMasuk) continue; // Group already has masuk — no re-attachment needed

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
      groups[entry.key]!.sort((a, b) => a.log.scannedAt.compareTo(b.log.scannedAt));
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
    int globalHadir = 0;
    int globalSakit = 0;
    int globalScan = 0;
    Duration globalWork = Duration.zero;

    for (final entry in byEmployee.entries) {
      final empSummaries = entry.value;
      final name = empSummaries.first.employee?.name ?? 'Tidak Diketahui';

      final hadirDays = empSummaries
          .where((s) =>
              s.status == DailySummaryStatus.normal && s.firstMasuk != null)
          .toList();
      final sakitDays = empSummaries
          .where((s) => s.status == DailySummaryStatus.sakit)
          .toList();

      // Avg masuk
      final masukTimes = hadirDays
          .where((s) => s.firstMasuk != null)
          .map((s) => s.firstMasuk!.hour * 60 + s.firstMasuk!.minute)
          .toList();
      final avgMasukStr =
          masukTimes.isEmpty ? '--:--' : _avgMinutesToHm(masukTimes);

      // Avg pulang
      final pulangTimes = hadirDays
          .where((s) => s.lastPulang != null)
          .map((s) => s.lastPulang!.hour * 60 + s.lastPulang!.minute)
          .toList();
      final avgPulangStr =
          pulangTimes.isEmpty ? '--:--' : _avgMinutesToHm(pulangTimes);

      // Total kerja
      Duration totalKerja = Duration.zero;
      for (final s in hadirDays) {
        if (s.workDuration != null && !s.workDuration!.isNegative) {
          totalKerja += s.workDuration!;
        }
      }
      final totalKerjaStr =
          _durationText(totalKerja.inMinutes > 0 ? totalKerja : null);

      employeeRows.add(AttendanceDailyPdfEmployeeRow(
        nama: name,
        hadirCount: hadirDays.length,
        avgMasukStr: avgMasukStr,
        avgPulangStr: avgPulangStr,
        totalKerjaStr: totalKerjaStr,
        sakitCount: sakitDays.length,
      ));

      globalHadir += hadirDays.length;
      globalSakit += sakitDays.length;
      globalScan += empSummaries.fold(0, (sum, s) => sum + s.scanCount);
      globalWork += totalKerja;
    }

    // Sort by name
    employeeRows
        .sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));

    // Attendance rate
    final totalDays = summaries.map((s) => s.dateLabel).toSet().length;
    final totalEmployees = byEmployee.keys.length;
    final attendanceRate = (totalEmployees > 0 && totalDays > 0)
        ? (globalHadir / (totalDays * totalEmployees) * 100)
        : 0.0;

    // Avg work
    final avgWorkMinutes =
        globalHadir > 0 ? globalWork.inMinutes ~/ globalHadir : 0;
    final avgH = avgWorkMinutes ~/ 60;
    final avgM = avgWorkMinutes % 60;
    final avgWorkStr = avgWorkMinutes > 0 ? '${avgH}j ${avgM}m' : '-';

    return AttendanceDailyPdfStats(
      totalKaryawan: totalEmployees,
      attendanceRate: attendanceRate,
      avgWorkStr: avgWorkStr,
      totalSakit: globalSakit,
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
                                value: _selectedOutletId,
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
                                  ..._outlets.map(
                                      (o) => DropdownMenuItem<String?>(
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
                          onPressed: _loading ? null : () {
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
                                      strokeWidth: 2,
                                      color: Colors.white))
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
        if (_hasLoaded && (_rows.isNotEmpty || _dailyRows.isNotEmpty)) ...[
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: 'Per Scan'),
                Tab(text: 'Rekap Harian'),
              ],
            ),
          ),

          // ── EXPORT BAR ────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  _tabCtrl.index == 1
                      ? '${_computeDailySummaries().length} data rekap'
                      : '${_rows.length} data scan',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: (_exportingCsv || _exportingPdf || _loading || _loadingDaily)
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
                    _exportingCsv
                        ? 'Exporting...'
                        : (_tabCtrl.index == 1 ? 'Export CSV Rekap' : 'Export CSV Scan'),
                    style: const TextStyle(
                        color: AppColors.primary, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: (_exportingPdf || _exportingCsv || _loading || _loadingDaily)
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
                    _exportingPdf
                        ? 'Exporting...'
                        : (_tabCtrl.index == 1 ? 'Export PDF Rekap' : 'Export PDF Scan'),
                    style: const TextStyle(
                        color: AppColors.primary, fontSize: 13),
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
              : _loading
                  ? _buildReportShimmer()
                  : _rows.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.bar_chart_outlined,
                          heading: 'Belum Ada Data',
                          subtext: 'Tidak ada data absensi pada rentang waktu ini',
                        )
                      : TabBarView(
                          controller: _tabCtrl,
                          children: [
                            // Tab 0: Per Scan
                            ListView.builder(
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
                            ),

                            // Tab 1: Rekap Harian
                            _buildRekapHarian(),
                          ],
                        ),
        ),
      ],
    );
  }

  Widget _buildRekapHarian() {
    if (_loadingDaily) {
      return _buildReportShimmer();
    }
    final summaries = _computeDailySummaries();

    if (summaries.isEmpty) {
      return const AppEmptyState(
        icon: Icons.bar_chart_outlined,
        heading: 'Belum Ada Data',
        subtext: 'Tidak ada data rekap pada rentang waktu ini',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: summaries.length,
      itemBuilder: (context, i) => _DailySummaryTile(summary: summaries[i]),
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
                        ShimmerSkeleton(width: 120, height: 13, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerSkeleton(width: 180, height: 11, borderRadius: 4),
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
              color: _typeColor.withOpacity(0.12),
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
// Daily Summary Tile — Rekap Harian
// ─────────────────────────────────────────────────────────────────────────────

class _DailySummaryTile extends StatelessWidget {
  final DailySummary summary;

  const _DailySummaryTile({required this.summary});

  String _hm(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateLabel(String raw) {
    // "YYYY-MM-DD" → "Sen, 20 Feb 2026"
    try {
      final dt = DateTime.parse(raw);
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
    } catch (_) {
      return raw;
    }
  }

  String _durationStr(Duration? d) {
    if (d == null || d.inMinutes <= 0) return '-';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}j';
    return '${h}j ${m}m';
  }

  Widget _buildStatusBadge() {
    final Color color;
    final String emoji;
    final String label;

    if (summary.status == DailySummaryStatus.sakit) {
      color = const Color(0xFFDC2626);
      emoji = '🤒';
      label = 'Sakit';
    } else if (summary.status == DailySummaryStatus.izin) {
      color = const Color(0xFF2563EB);
      emoji = '📋';
      label = 'Izin';
    } else {
      // belumPulang — amber/orange indicator
      assert(summary.status == DailySummaryStatus.belumPulang);
      color = const Color(0xFFD97706);
      emoji = '⚠️';
      label = 'Belum Pulang';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.30)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (summary.statusNotes != null && summary.statusNotes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                summary.statusNotes!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empName = summary.employee?.name ?? '-';
    final outletName = summary.outlet?.name ?? '-';
    final hasWork = summary.firstMasuk != null;
    final hasPulang = summary.lastPulang != null;
    final badge = BadgeService.instance.getBadgeByIdSync(summary.employee?.activeBadgeId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                // Avatar
                BadgeAvatar(
                  photoUrl: summary.employee?.photoUrl,
                  name: empName,
                  size: 40,
                  badge: badge,
                ),
                const SizedBox(width: 12),

                // Name + outlet + date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        empName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$outletName · ${_formatDateLabel(summary.dateLabel)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Scan count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${summary.scanCount} scan',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

          // Conditional: badge for sakit/izin, 4-cell row for normal days
          if (summary.status == DailySummaryStatus.sakit ||
              summary.status == DailySummaryStatus.izin)
            _buildStatusBadge()
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  // Masuk
                  _InfoCell(
                    icon: Icons.login_rounded,
                    label: 'Masuk',
                    value: _hm(summary.firstMasuk),
                    color: AppColors.success,
                    flex: 2,
                  ),
                  const SizedBox(width: 8),

                  // Pulang
                  if (summary.status == DailySummaryStatus.belumPulang)
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.logout_rounded, size: 12,
                                  color: Color(0xFFD97706)),
                              const SizedBox(width: 4),
                              Text('Pulang',
                                  style: TextStyle(fontSize: 10,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFD97706)
                                      .withOpacity(0.35)),
                            ),
                            child: const Text('Belum\nPulang',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706),
                                  height: 1.3,
                                )),
                          ),
                        ],
                      ),
                    )
                  else
                    _InfoCell(
                      icon: Icons.logout_rounded,
                      label: 'Pulang',
                      value: _hm(summary.lastPulang),
                      color: hasPulang ? AppColors.danger : AppColors.textMuted,
                      flex: 2,
                    ),
                  const SizedBox(width: 8),

                  // Durasi kerja
                  _InfoCell(
                    icon: Icons.timelapse_rounded,
                    label: 'Kerja',
                    value: hasWork && hasPulang
                        ? _durationStr(summary.workDuration)
                        : '-',
                    color: AppColors.primary,
                    flex: 2,
                  ),
                  const SizedBox(width: 8),

                  // Durasi istirahat
                  _InfoCell(
                    icon: Icons.coffee_rounded,
                    label: 'Istirahat',
                    value: summary.totalBreak.inMinutes > 0
                        ? _durationStr(summary.totalBreak)
                        : '-',
                    color: const Color(0xFFF59E0B),
                    flex: 2,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final int flex;

  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.flex,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 10, color: color),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
