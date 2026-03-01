import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/attendance_log.dart';
import '../../models/employee.dart';
import '../../models/outlet.dart';
import '../../providers/app_provider.dart';

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
  bool _exporting = false;
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

  Future<void> _loadReport({bool reset = true}) async {
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
      final start =
          DateTime(_startDate.year, _startDate.month, _startDate.day);
      final end = DateTime(
          _endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

      var baseQuery = SupabaseClientFactory.admin
          .from('attendance_logs')
          .select('*, employees(*), outlets(*)')
          .gte('scanned_at', start.toUtc().toIso8601String())
          .lte('scanned_at', end.toUtc().toIso8601String());

      if (_selectedOutletId != null) {
        baseQuery = baseQuery.eq('scan_outlet_id', _selectedOutletId!);
      }

      final data = await baseQuery
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
      final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final end = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

      var query = SupabaseClientFactory.admin
          .from('attendance_logs')
          .select('*, employees(*), outlets(*)')
          .gte('scanned_at', start.toUtc().toIso8601String())
          .lte('scanned_at', end.toUtc().toIso8601String());

      if (_selectedOutletId != null) {
        query = query.eq('scan_outlet_id', _selectedOutletId!);
      }

      // No .range() — fetch all records. .limit(5000) is a documented safety valve.
      final data = await query
          .order('scanned_at', ascending: true)
          .limit(5000);

      if (mounted) {
        setState(() {
          _dailyRows = (data as List)
              .map((e) => _ReportRow.fromJson(e as Map<String, dynamic>))
              .toList();
          _loadingDaily = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingDaily = false);
    }
  }

  // ── CSV export ───────────────────────────────────────────────────────────────

  Future<void> _exportCsv() async {
    if (_rows.isEmpty) return;
    setState(() => _exporting = true);

    try {
      final buffer = StringBuffer();
      buffer.writeln('Nama,Jabatan,Outlet,Jenis,Waktu,Latitude,Longitude');

      // Export per-scan (original order = reversed for export)
      final sorted = [..._rows]
        ..sort((a, b) => b.log.scannedAt.compareTo(a.log.scannedAt));

      for (final row in sorted) {
        final name = _escapeCsv(row.employee?.name ?? '-');
        final jabatan = _escapeCsv(row.employee?.position ?? '-');
        final outlet = _escapeCsv(row.outlet?.name ?? '-');
        final type = _escapeCsv(row.log.type.label);
        final time = _escapeCsv(row.log.scannedAt);
        final lat = row.log.lat?.toString() ?? '';
        final lng = row.log.lng?.toString() ?? '';
        buffer.writeln('$name,$jabatan,$outlet,$type,$time,$lat,$lng');
      }

      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final filename =
          'absensi_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Laporan Absensi Enakko',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengekspor laporan')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _escapeCsv(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
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
      });
    }
  }

  // ── Rekap Harian computation ──────────────────────────────────────────────

  /// Group raw rows by (employeeId, dateString) and compute daily summary.
  List<_DailySummary> _computeDailySummaries() {
    // Sort ascending by time for correct duration calc
    final sorted = [..._dailyRows]
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

    final summaries = <_DailySummary>[];

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

      summaries.add(_DailySummary(
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
                                onChanged: (v) =>
                                    setState(() => _selectedOutletId = v),
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
        if (_hasLoaded && _rows.isNotEmpty) ...[
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
                  '${_rows.length} data scan',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _exporting ? null : _exportCsv,
                  icon: _exporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary))
                      : const Icon(Icons.download_outlined,
                          size: 16, color: AppColors.primary),
                  label: Text(
                    _exporting ? 'Exporting...' : 'Export CSV',
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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bar_chart,
                          size: 56, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'Pilih rentang tanggal\nlalu klik Tampilkan',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : _rows.isEmpty
                      ? Center(
                          child: Text(
                            'Tidak ada data absensi\npada rentang waktu ini',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
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
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final summaries = _computeDailySummaries();

    if (summaries.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada data rekap',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: summaries.length,
      itemBuilder: (context, i) => _DailySummaryTile(summary: summaries[i]),
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

/// Status of a daily attendance summary entry.
/// Used to select the correct rendering path in _DailySummaryTile.
enum DailySummaryStatus { normal, sakit, izin, belumPulang }

class _DailySummary {
  final String dateLabel; // "YYYY-MM-DD"
  final Employee? employee;
  final Outlet? outlet;
  final DateTime? firstMasuk;
  final DateTime? lastPulang;
  final Duration? workDuration;
  final Duration totalBreak;
  final int scanCount;
  final DailySummaryStatus status;   // normal/sakit/izin — controls tile rendering
  final String? statusNotes;         // from attendance_logs.notes — shown below badge

  const _DailySummary({
    required this.dateLabel,
    required this.employee,
    required this.outlet,
    required this.firstMasuk,
    required this.lastPulang,
    required this.workDuration,
    required this.totalBreak,
    required this.scanCount,
    required this.status,
    this.statusNotes,
  });
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
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
  final _DailySummary summary;

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
    final initial =
        empName.isNotEmpty ? empName[0].toUpperCase() : '?';
    final outletName = summary.outlet?.name ?? '-';
    final hasWork = summary.firstMasuk != null;
    final hasPulang = summary.lastPulang != null;

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
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      fontSize: 16,
                    ),
                  ),
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
