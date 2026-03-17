import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/attendance_log.dart';
import '../../models/employee.dart';
import '../../models/outlet.dart';
import '../../providers/app_provider.dart';
import '../../services/badge_service.dart';
import '../../widgets/badge_avatar.dart';
import 'shift_scheduler_screen.dart';
import '../../main.dart' show supabaseReady;

// ─────────────────────────────────────────────────────────────────────────────
// Admin Dashboard Screen
// ─────────────────────────────────────────────────────────────────────────────

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  List<Outlet> _outlets = [];
  String? _selectedOutletId;
  List<_LogWithJoins> _logs = [];
  bool _loading = true;
  String? _loadError;
  RealtimeChannel? _channel;

  int _todayMasuk = 0;
  int _todayBreak = 0;
  int _todayPulang = 0;
  int _todayBackup = 0; // Total backup hari ini
  int _totalEmployees = 0;
    RealtimeChannel? _employeeChannel;

  List<_OpenShift> _openShifts = [];
  bool _loadingOpenShifts = false;

  @override
  void initState() {
    super.initState();
    // Auto-set outlet filter untuk kepala_gerai sebelum load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = ref.read(appProvider);
      if (appState.isKepalaGerai && appState.managedOutletId != null) {
        setState(() => _selectedOutletId = appState.managedOutletId);
      }
      _initialLoad();
    });
  }

  Future<void> _initialLoad() async {
    // Warm badge cache for BadgeAvatar rendering
    BadgeService.instance.fetchAll();
    await Future.wait([_loadOutlets(), _loadEmployeeCount(), _loadOpenShifts()]);
  }

  Future<void> _loadOutlets() async {
    try {
      final data = await SupabaseClientFactory.admin
          .from('outlets')
          .select('*')
          .eq('is_active', true)
          .order('name');

      final outlets = (data as List)
          .map((e) => Outlet.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() => _outlets = outlets);
        await _loadLogs();
        _subscribeRealtime();
        _subscribeEmployeeRealtime();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  Future<void> _loadEmployeeCount() async {
    try {
      final appState = ref.read(appProvider);
      var q = SupabaseClientFactory.admin
          .from('employees')
          .select('id')
          .eq('is_active', true);
      // Kepala gerai: hitung hanya karyawan di outletnya
      if (appState.isKepalaGerai && appState.managedOutletId != null) {
        q = q.eq('home_outlet_id', appState.managedOutletId!);
      }
      final data = await q;
      if (mounted) {
        setState(() => _totalEmployees = (data as List).length);
      }
    } catch (_) {}
  }

  Future<void> _loadLogs() async {
    if (mounted) setState(() { _loading = true; _loadError = null; });
    try {
      final today = DateTime.now();
      final startOfDay =
          DateTime(today.year, today.month, today.day).toUtc().toIso8601String();
      final endOfDay =
          DateTime(today.year, today.month, today.day, 23, 59, 59)
              .toUtc().toIso8601String();

      var q = SupabaseClientFactory.admin
          .from('attendance_logs')
          .select('*, employees(id, name, photo_url, active_badge_id), outlets(id, name)')
          .gte('scanned_at', startOfDay)
          .lte('scanned_at', endOfDay);

      if (_selectedOutletId != null) {
        q = q.eq('scan_outlet_id', _selectedOutletId!);
      }

      final data = await q.order('scanned_at', ascending: false).limit(200);

      final logs = (data as List)
          .map((e) => _LogWithJoins.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _logs = logs;
          _loading = false;
          _recalcStats();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _loadError = e.toString(); });
      }
    }
  }

  Future<void> _loadOpenShifts() async {
    if (!supabaseReady) return;
    if (mounted) setState(() => _loadingOpenShifts = true);
    try {
      final appState = ref.read(appProvider);
      // 32h window catches overnight shifts from yesterday evening
      final cutoff = DateTime.now()
          .subtract(const Duration(hours: 32))
          .toUtc()
          .toIso8601String();

      var q = SupabaseClientFactory.admin
          .from('attendance_logs')
          .select('employee_id, type, scanned_at, scan_outlet_id, employees(id, name, photo_url, active_badge_id)')
          .gte('scanned_at', cutoff);

      // Kepala gerai hanya boleh melihat shift outlet yang dikelola.
      if (appState.isKepalaGerai && appState.managedOutletId != null) {
        q = q.eq('scan_outlet_id', appState.managedOutletId!);
      } else if (_selectedOutletId != null) {
        q = q.eq('scan_outlet_id', _selectedOutletId!);
      }

      final data = await q.order('scanned_at', ascending: true);

      // Group by employee_id, detect open sessions (masuk with no subsequent pulang)
      final Map<String, List<Map<String, dynamic>>> byEmployee = {};
      for (final row in (data as List)) {
        final empId = row['employee_id'] as String;
        byEmployee.putIfAbsent(empId, () => []).add(row as Map<String, dynamic>);
      }

      final openShifts = <_OpenShift>[];
      byEmployee.forEach((empId, logs) {
        // Logs are already sorted ascending by time from Supabase
        Map<String, dynamic>? lastMasuk;
        bool hasPulangAfterMasuk = false;
        for (final log in logs) {
          if (log['type'] == 'masuk') {
            lastMasuk = log;
            hasPulangAfterMasuk = false;
          } else if (log['type'] == 'pulang' && lastMasuk != null) {
            hasPulangAfterMasuk = true;
          }
        }
        if (lastMasuk != null && !hasPulangAfterMasuk) {
          final emp = lastMasuk['employees'] as Map<String, dynamic>?;
          openShifts.add(_OpenShift(
            employeeId: empId,
            employeeName: emp?['name'] as String? ?? '-',
            photoUrl: emp?['photo_url'] as String?,
            masukTime: lastMasuk['scanned_at'] as String,
            outletId: lastMasuk['scan_outlet_id'] as String,
            activeBadgeId: emp?['active_badge_id'] as String?,
          ));
        }
      });

      if (mounted) {
        setState(() {
          _openShifts = openShifts;
          _loadingOpenShifts = false;
        });
      }
    } catch (e) {
      debugPrint('[OpenShifts] Error: $e');
      if (mounted) setState(() => _loadingOpenShifts = false);
    }
  }

  Future<void> _manualPulang(_OpenShift shift) async {
    final appState = ref.read(appProvider);
    if (appState.isKepalaGerai && appState.managedOutletId != shift.outletId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak diizinkan menutup shift outlet lain.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    // Show dialog for notes input
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tutup Shift Manual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Karyawan: ${shift.employeeName}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Masuk: ${_formatTime(shift.masukTime)}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Contoh: Lupa absen pulang',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Simpan Pulang'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final notes = notesCtrl.text.trim();
      await SupabaseClientFactory.admin
          .from('attendance_logs')
          .insert({
            'employee_id': shift.employeeId,
            'scan_outlet_id': shift.outletId,
            'type': 'pulang',
            'scanned_at': DateTime.now().toUtc().toIso8601String(),
            'notes': notes.isNotEmpty
                ? notes
                : 'Lupa absen pulang — diinput manual oleh admin',
            'is_backup': false,
          });

      // Refresh open shifts list
      await _loadOpenShifts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _recalcStats() {
    _todayMasuk = _logs.where((l) => l.log.type == AttendanceType.masuk).length;
    _todayBreak =
        _logs.where((l) => l.log.type == AttendanceType.breakTime).length;
    _todayPulang =
        _logs.where((l) => l.log.type == AttendanceType.pulang).length;
    // Hitung jumlah karyawan UNIK yang backup (bukan jumlah absensi backup)
    _todayBackup = _logs
        .where((l) => l.log.isBackup)
        .map((l) => l.log.employeeId)
        .toSet()
        .length;
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    _channel = SupabaseClientFactory.admin
        .channel('dashboard:attendance_logs')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'attendance_logs',
          callback: (_) => _loadLogs(),
        )
        .subscribe();
  }

  void _subscribeEmployeeRealtime() {
    _employeeChannel?.unsubscribe();
    final appState = ref.read(appProvider);
    // Hanya admin penuh yang subscribe semua karyawan
    // Kepala gerai hanya subscribe karyawan di outletnya
    var builder = SupabaseClientFactory.admin
        .channel('dashboard:employees')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'employees',
          callback: (payload) {
            // Refresh employee count dan list saat ada perubahan
            _loadEmployeeCount();
            _loadLogs();
          },
        );
    _employeeChannel = builder.subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _employeeChannel?.unsubscribe();
    super.dispose();
  }

  // ─── helpers ───────────────────────────────────────────────────────────────

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String get _greetingLabel {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat Pagi';
    if (h < 15) return 'Selamat Siang';
    if (h < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String get _todayLabel {
    const days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final n = DateTime.now();
    return '${days[n.weekday % 7]}, ${n.day} ${months[n.month]} ${n.year}';
  }

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadLogs,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── HERO HEADER ────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeroHeader()),

            // ── STAT GRID 2×2 ──────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildStatGrid()),

            // ── QUICK ACTIONS ──────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildQuickActions()),

            // ── OUTLET FILTER ──────────────────────────────────────────────
            if (_outlets.isNotEmpty)
              SliverToBoxAdapter(child: _buildOutletFilter()),

            // ── SECTION HEADER ─────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildSectionHeader()),

            // ── ERROR ──────────────────────────────────────────────────────
            if (_loadError != null)
              SliverToBoxAdapter(child: _buildErrorBanner()),

            // ── LOG LIST ──────────────────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              )
            else if (_logs.isEmpty && _loadError == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _LogCard(
                      item: _logs[i],
                      timeString: _formatTime(_logs[i].log.scannedAt),
                    ),
                    childCount: _logs.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Hero Header ───────────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greetingLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.75),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ref.watch(appProvider).isKepalaGerai
                                ? 'Kepala Gerai'
                                : 'Admin Enakko',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Date badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            _todayLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Live indicator
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4ADE80),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x664ADE80),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live — update otomatis',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── 2×2 Stat Grid ─────────────────────────────────────────────────────────

  Widget _buildStatGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Masuk',
                  value: '$_todayMasuk',
                  icon: Icons.login_rounded,
                  accent: const Color(0xFF22C55E),
                  textColor: const Color(0xFF14532D),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Istirahat',
                  value: '$_todayBreak',
                  icon: Icons.coffee_outlined,
                  accent: const Color(0xFFF59E0B),
                  textColor: const Color(0xFF78350F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Pulang',
                  value: '$_todayPulang',
                  icon: Icons.logout_rounded,
                  accent: const Color(0xFFEF4444),
                  textColor: const Color(0xFF7F1D1D),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Backup',
                  value: '$_todayBackup',
                  icon: Icons.support_agent_rounded,
                  accent: const Color(0xFF0891B2),
                  textColor: const Color(0xFF0E7490),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
 final isKepalaGerai = ref.watch(appProvider).isKepalaGerai;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Tombol "Jadwal Shift" - tersedia untuk Admin & Kepala Gerai
            _QuickActionBtn(
              icon: Icons.calendar_month_rounded,
              label: 'Jadwal',
              color: const Color(0xFF7C3AED),
              textColor: Colors.white,
              onTap: _openShiftScheduler,
            ),
            const SizedBox(width: 10),
            // Tombol "Tambah Gerai" hanya untuk admin penuh
            if (!isKepalaGerai) ...[
              _QuickActionBtn(
                icon: Icons.add_business_rounded,
                label: 'Gerai',
                color: AppColors.accent,
                textColor: const Color(0xFF1A0A00),
                onTap: _showAddOutletSheet,
              ),
              const SizedBox(width: 10),
            ],
            _QuickActionBtn(
              icon: Icons.refresh_rounded,
              label: 'Refresh',
              color: AppColors.primary,
              textColor: Colors.white,
              onTap: _loadLogs,
            ),
            // Belum Pulang button — only visible when open shifts exist
            if (_openShifts.isNotEmpty) ...[
              const SizedBox(width: 10),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _QuickActionBtn(
                    icon: Icons.warning_amber_rounded,
                    label: 'Belum\nPulang',
                    color: const Color(0xFFF59E0B),
                    textColor: Colors.white,
                    onTap: _showOpenShiftsSheet,
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        '${_openShifts.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openShiftScheduler() {
    final appState = ref.read(appProvider);
    final outletId = appState.isKepalaGerai 
        ? appState.managedOutletId 
        : _selectedOutletId;
    
    if (outletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih outlet terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final outletName = _outlets
        .where((o) => o.id == outletId)
        .map((o) => o.name)
        .firstOrNull ?? 'Unknown';
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShiftSchedulerScreen(
          outletId: outletId,
          outletName: outletName,
        ),
      ),
    );
  }

  void _showOpenShiftsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFD97706), size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Belum Absen Pulang (${_openShifts.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Scrollable list
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _openShifts.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 60),
                    itemBuilder: (context, index) {
                      final shift = _openShifts[index];
                      final masukLocal =
                          DateTime.tryParse(shift.masukTime)?.toLocal();
                      final masukStr = masukLocal != null
                          ? '${masukLocal.hour.toString().padLeft(2, '0')}:${masukLocal.minute.toString().padLeft(2, '0')}'
                          : '-';
                      final hoursAgo = masukLocal != null
                          ? DateTime.now().difference(masukLocal).inHours
                          : 0;

                      return ListTile(
                        leading: BadgeAvatar(
                          photoUrl: shift.photoUrl,
                          name: shift.employeeName,
                          size: 36,
                          badge: BadgeService.instance.getBadgeByIdSync(shift.activeBadgeId),
                        ),
                        title: Text(
                          shift.employeeName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Masuk $masukStr · ${hoursAgo}j lalu',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _manualPulang(shift);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Tutup Shift',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Outlet Filter ─────────────────────────────────────────────────────────

  Widget _buildOutletFilter() {
 final isKepalaGerai = ref.watch(appProvider).isKepalaGerai;

    // Kepala gerai: tampilkan nama outlet sebagai label statis (tidak bisa ganti)
    if (isKepalaGerai) {
      final outletName = _outlets
          .where((o) => o.id == _selectedOutletId)
          .map((o) => o.name)
          .firstOrNull ?? 'Memuat outlet...';
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Row(
          children: [
            Text(
              'OUTLET',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store_rounded,
                      size: 13, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Text(
                    outletName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Admin: chip filter biasa
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            'FILTER OUTLET',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: 34,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'Semua',
                selected: _selectedOutletId == null,
                onTap: () {
                  setState(() => _selectedOutletId = null);
                  _loadLogs();
                },
              ),
              ..._outlets.map((o) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _FilterChip(
                      label: o.name,
                      selected: _selectedOutletId == o.id,
                      onTap: () {
                        setState(() => _selectedOutletId = o.id);
                        _loadLogs();
                      },
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Section Header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Absensi Hari Ini',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          if (!_loading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_logs.length} scan',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _loadError!,
              style: const TextStyle(fontSize: 11, color: AppColors.danger),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _loadLogs,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Coba lagi',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.event_note_outlined,
                  size: 38, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada absensi hari ini',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tarik ke bawah untuk refresh',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Add Outlet Sheet ──────────────────────────────────────────────────────

  void _showAddOutletSheet() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool saving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 16, 20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 18),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_business_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Tambah Gerai Baru',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _SheetField(
                controller: nameCtrl,
                label: 'Nama Gerai',
                hint: 'Contoh: Outlet Sudirman',
                icon: Icons.store_outlined,
              ),
              const SizedBox(height: 12),
              _SheetField(
                controller: addressCtrl,
                label: 'Alamat (opsional)',
                hint: 'Jl. Sudirman No. 1, Jakarta',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 12),
              _SheetField(
                controller: passwordCtrl,
                label: 'Password Kiosk',
                hint: 'Min. 6 karakter',
                icon: Icons.lock_outline,
                obscure: true,
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 13, color: Color(0xFFD97706)),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Password digunakan untuk aktivasi kiosk di gerai ini.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty ||
                              passwordCtrl.text.isEmpty) return;
                          setSheetState(() => saving = true);
                          try {
                            await SupabaseClientFactory.admin.rpc(
                              'create_outlet_with_password',
                              params: {
                                'outlet_name': nameCtrl.text.trim(),
                                'outlet_address':
                                    addressCtrl.text.trim().isEmpty
                                        ? null
                                        : addressCtrl.text.trim(),
                                'password': passwordCtrl.text,
                              },
                            );
                            if (ctx.mounted) { Navigator.pop(ctx); }
                            await _loadOutlets();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      'Gerai berhasil ditambahkan'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              );
                            }
                          } catch (e) {
                            setSheetState(() => saving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: AppColors.danger,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: const Color(0xFF1A0A00),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Color(0xFF1A0A00), strokeWidth: 2.5),
                        )
                      : const Text(
                          'Simpan Gerai',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Card — icon + large number layout
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Color textColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Icon(icon, size: 21, color: accent)),
          ),
          const SizedBox(width: 12),
          // Value + label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      height: 1,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent.withValues(alpha: 0.8),
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Action Button
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 70,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: textColor),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Chip
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Log Card — avatar initial + name/outlet + badge pill + time
// ─────────────────────────────────────────────────────────────────────────────

class _LogCard extends StatelessWidget {
  final _LogWithJoins item;
  final String timeString;

  const _LogCard({required this.item, required this.timeString});

  Color get _typeColor {
    switch (item.log.type) {
      case AttendanceType.masuk:
        return const Color(0xFF22C55E);
      case AttendanceType.kembali:
        return const Color(0xFF0891B2);
      case AttendanceType.breakTime:
        return const Color(0xFFF59E0B);
      case AttendanceType.pulang:
        return const Color(0xFFEF4444);
      case AttendanceType.sakit:
        return const Color(0xFFDC2626);
      case AttendanceType.izin:
        return const Color(0xFF2563EB);
    }
  }

  String get _typeLabel {
    switch (item.log.type) {
      case AttendanceType.masuk:
        return 'MASUK';
      case AttendanceType.kembali:
        return 'KEMBALI';
      case AttendanceType.breakTime:
        return 'ISTIRAHAT';
      case AttendanceType.pulang:
        return 'PULANG';
      case AttendanceType.sakit:
        return 'SAKIT';
      case AttendanceType.izin:
        return 'IZIN';
    }
  }

  Widget _buildAvatar(String? photoUrl, String initial, Color bg) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(width: 40, height: 40, color: Colors.grey.shade200),
          errorWidget: (context, url, error) => _initialBox(initial, bg),
        ),
      );
    }
    return _initialBox(initial, bg);
  }

  Widget _initialBox(String initial, Color bg) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, height: 1),
        ),
      ),
    );
  }

  Color _avatarColor(String name) {
    const palette = [
      Color(0xFFDC2626),
      Color(0xFF2563EB),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
      Color(0xFF0891B2),
    ];
    if (name.isEmpty) return palette[0];
    return palette[name.codeUnitAt(0) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final empName = item.employee?.name ?? 'Karyawan';
    final outletName = item.outlet?.name ?? '';
    final empBadge = BadgeService.instance.getBadgeByIdSync(item.employee?.activeBadgeId);

    return Container(
      height: 70,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left color bar
          Container(
            width: 4,
            height: double.infinity,
            decoration: BoxDecoration(
              color: _typeColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Avatar
          BadgeAvatar(
            photoUrl: item.employee?.photoUrl,
            name: empName,
            size: 40,
            badge: empBadge,
          ),

          const SizedBox(width: 12),

          // Name + outlet + backup badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        empName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    // Backup badge
                    if (item.log.isBackup) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: const Color(0xFF0891B2).withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'BACKUP',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0891B2),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (outletName.isNotEmpty || item.log.isBackup) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.log.isBackup
                        ? (item.log.notes ?? 'Backup di $outletName')
                        : outletName,
                    style: TextStyle(
                      fontSize: 11,
                      color: item.log.isBackup
                          ? const Color(0xFF0891B2)
                          : AppColors.textMuted,
                      height: 1.2,
                      fontWeight: item.log.isBackup ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Badge + time
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _typeLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _typeColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeString,
                  style: TextStyle(
                    color: _typeColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet Field Helper
// ─────────────────────────────────────────────────────────────────────────────

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;

  const _SheetField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 13, color: AppColors.textMuted),
            prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _LogWithJoins {
  final AttendanceLog log;
  final Employee? employee;
  final Outlet? outlet;

  _LogWithJoins({required this.log, this.employee, this.outlet});

  factory _LogWithJoins.fromJson(Map<String, dynamic> json) {
    final empJson = json['employees'] as Map<String, dynamic>?;
    final outJson = json['outlets'] as Map<String, dynamic>?;
    return _LogWithJoins(
      log: AttendanceLog.fromJson(json),
      employee: empJson != null ? Employee.fromJson(empJson) : null,
      outlet: outJson != null ? Outlet.fromJson(outJson) : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Open Shift data model
// ─────────────────────────────────────────────────────────────────────────────

/// Represents an employee with an open (unclosed) shift.
class _OpenShift {
  final String employeeId;
  final String employeeName;
  final String? photoUrl;
  final String masukTime; // UTC ISO string
  final String outletId;
  final String? activeBadgeId;

  const _OpenShift({
    required this.employeeId,
    required this.employeeName,
    this.photoUrl,
    required this.masukTime,
    required this.outletId,
    this.activeBadgeId,
  });
}
