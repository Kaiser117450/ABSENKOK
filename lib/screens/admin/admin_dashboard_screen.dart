import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:absensi_enakko_flutter/core/supabase_client.dart';
import 'package:absensi_enakko_flutter/core/theme.dart';
import 'package:absensi_enakko_flutter/main.dart' show supabaseReady;
import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/kiosk_device.dart';
import 'package:absensi_enakko_flutter/models/outlet.dart';
import 'package:absensi_enakko_flutter/models/schedule_gap_notice.dart';
import 'package:absensi_enakko_flutter/providers/app_provider.dart';
import 'package:absensi_enakko_flutter/screens/admin/shift_scheduler_screen.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/admin_schedule_gap_notice_sheet.dart';
import 'package:absensi_enakko_flutter/services/attendance_policy_recap_service.dart';
import 'package:absensi_enakko_flutter/services/badge_service.dart';
import 'package:absensi_enakko_flutter/services/schedule_gap_notice_service.dart';
import 'package:absensi_enakko_flutter/widgets/badge_avatar.dart';
import 'package:absensi_enakko_flutter/widgets/kiosk_device_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Admin Dashboard Screen
// ─────────────────────────────────────────────────────────────────────────────

class AdminDashboardScreen extends ConsumerStatefulWidget {
  /// Optional outlet pre-selection for full admin drilldown from
  /// [CentralDashboardScreen]. Scoped outlet roles can only preselect one of
  /// their managed outlets.
  final String? initialOutletId;

  const AdminDashboardScreen({super.key, this.initialOutletId});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  static const int _scheduleGapLookbackDays = 13;

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
  RealtimeChannel? _employeeChannel;

  List<_OpenShift> _openShifts = [];
  final AttendancePolicyRecapService _attendancePolicyRecapService =
      const AttendancePolicyRecapService();
  final ScheduleGapNoticeService _scheduleGapNoticeService =
      const ScheduleGapNoticeService();
  ScheduleGapNoticeResult _scheduleGapNotices =
      const ScheduleGapNoticeResult(entries: <ScheduleGapNoticeEntry>[]);
  bool _loadingScheduleGapNotices = false;

  List<KioskDevice> _kioskDevices = [];
  RealtimeChannel? _kioskDevicesChannel;
  bool _showAllDevices = false;

  @override
  void initState() {
    super.initState();
    // Auto-set outlet filter untuk role scoped sebelum load data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = ref.read(appProvider);
      if (appState.isScopedOutletAdmin) {
        final initialScopedOutletId =
            appState.canAccessOutlet(widget.initialOutletId)
                ? widget.initialOutletId
                : appState.primaryScopedOutletId;
        setState(() => _selectedOutletId = initialScopedOutletId);
      } else if (appState.isAdmin && widget.initialOutletId != null) {
        // Full admin arriving from CentralDashboardScreen drilldown
        setState(() => _selectedOutletId = widget.initialOutletId);
      }
      _initialLoad();
    });
  }

  Future<void> _initialLoad() async {
    // Warm badge cache for BadgeAvatar rendering
    BadgeService.instance.fetchAll();
    await Future.wait([
      _loadOutlets(),
      _loadEmployeeCount(),
      _loadOpenShifts(),
      _loadKioskDevices()
    ]);
  }

  Future<void> _loadOutlets() async {
    try {
      final appState = ref.read(appProvider);
      if (appState.isScopedOutletAdmin && appState.scopedOutletIds.isEmpty) {
        if (mounted) {
          setState(() {
            _outlets = const <Outlet>[];
            _loading = false;
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

      final outlets = (data as List)
          .map((e) => Outlet.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _outlets = outlets;
          if (appState.isScopedOutletAdmin &&
              !appState.canAccessOutlet(_selectedOutletId)) {
            _selectedOutletId = outlets.firstOrNull?.id;
          }
        });
        await Future.wait([
          _loadLogs(),
          _loadScheduleGapNotices(),
        ]);
        _subscribeRealtime();
        _subscribeEmployeeRealtime();
        _subscribeKioskDevicesRealtime();
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

  Future<void> _loadKioskDevices() async {
    try {
      final appState = ref.read(appProvider);
      if (appState.isScopedOutletAdmin && appState.scopedOutletIds.isEmpty) {
        if (mounted) setState(() => _kioskDevices = const <KioskDevice>[]);
        return;
      }

      var query = SupabaseClientFactory.admin
          .from('kiosk_devices')
          .select('*')
          .eq('is_active', true);
      if (appState.isScopedOutletAdmin) {
        query = query.inFilter('outlet_id', appState.scopedOutletIds);
      }
      final data = await query.order('outlet_id').order('created_at');
      final devices = <KioskDevice>[];
      for (final rawRow in data as List) {
        try {
          final row = Map<String, dynamic>.from(rawRow as Map);
          devices.add(KioskDevice.fromJson(row));
        } catch (e) {
          debugPrint(
            '[Dashboard] Skipping malformed kiosk device row: $rawRow ($e)',
          );
        }
      }
      // Auto-archive devices yang offline > 4 hari
      await _autoArchiveStaleDevices(devices);
      final activeDevices = devices.where((d) => !d.isStale).toList();
      if (mounted) {
        setState(() {
          _kioskDevices = activeDevices;
        });
      }
    } catch (e) {
      debugPrint('[Dashboard] Failed to load kiosk devices: $e');
    }
  }

  Future<void> _autoArchiveStaleDevices(List<KioskDevice> devices) async {
    final stale = devices.where((d) => d.isStale).toList();
    if (stale.isEmpty) return;
    for (final d in stale) {
      try {
        await SupabaseClientFactory.admin.rpc('archive_device', params: {
          'p_device_id': d.id,
        });
        debugPrint('[Dashboard] Auto-archived stale device: ${d.displayName}');
      } catch (e) {
        debugPrint('[Dashboard] Failed to auto-archive ${d.id}: $e');
      }
    }
  }

  void _subscribeKioskDevicesRealtime() {
    _kioskDevicesChannel?.unsubscribe();
    _kioskDevicesChannel = SupabaseClientFactory.admin
        .channel('kiosk_devices_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'kiosk_devices',
          callback: (payload) => _loadKioskDevices(),
        )
        .subscribe();
  }

  Future<void> _showNicknameDialog(KioskDevice device) async {
    final controller = TextEditingController(text: device.nickname ?? '');
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Beri Nama Kiosk',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Kiosk Pintu Depan'),
            autofocus: true,
            maxLength: 40,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Batal',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan Nama'),
            ),
          ],
        ),
      );
      if (confirmed == true && controller.text.trim().isNotEmpty) {
        final newNickname = controller.text.trim();
        final oldNickname = device.nickname;
        // Optimistic update
        setState(() {
          _kioskDevices = _kioskDevices
              .map((d) =>
                  d.id == device.id ? d.copyWith(nickname: newNickname) : d)
              .toList();
        });
        try {
          await SupabaseClientFactory.admin.rpc('set_device_nickname', params: {
            'p_device_id': device.id,
            'p_nickname': newNickname,
          });
        } catch (e) {
          // Revert on error
          if (mounted) {
            setState(() {
              _kioskDevices = _kioskDevices
                  .map((d) =>
                      d.id == device.id ? d.copyWith(nickname: oldNickname) : d)
                  .toList();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
            );
          }
        }
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showArchiveDialog(KioskDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arsipkan Kiosk?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        content: const Text(
          'Kiosk ini tidak akan muncul lagi di dashboard. Hubungi admin pusat jika perlu dipulihkan.',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('Ya, Arsipkan', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Optimistic remove
      setState(() {
        _kioskDevices = _kioskDevices.where((d) => d.id != device.id).toList();
      });
      try {
        await SupabaseClientFactory.admin.rpc('archive_device', params: {
          'p_device_id': device.id,
        });
      } catch (e) {
        debugPrint('[Dashboard] Archive device failed: $e');
        // Device reappears on next data load — acceptable per UI-SPEC
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
      if (appState.isScopedOutletAdmin) {
        if (appState.scopedOutletIds.isEmpty) return;
        q = q.inFilter('home_outlet_id', appState.scopedOutletIds);
      }
      await q;
    } catch (_) {}
  }

  Future<void> _loadLogs() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day)
          .toUtc()
          .toIso8601String();
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59)
          .toUtc()
          .toIso8601String();

      var q = SupabaseClientFactory.admin
          .from('attendance_logs')
          .select(
              '*, employees(id, name, photo_url, active_badge_id), outlets(id, name)')
          .gte('scanned_at', startOfDay)
          .lte('scanned_at', endOfDay);

      final activeOutletId = _activeOutletFilterId();
      if (activeOutletId != null) {
        q = q.eq('scan_outlet_id', activeOutletId);
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
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  Future<void> _loadOpenShifts() async {
    if (!supabaseReady) return;
    try {
      // 32h window catches overnight shifts from yesterday evening
      final cutoff = DateTime.now()
          .subtract(const Duration(hours: 32))
          .toUtc()
          .toIso8601String();

      var q = SupabaseClientFactory.admin
          .from('attendance_logs')
          .select(
              'employee_id, type, scanned_at, scan_outlet_id, employees(id, name, photo_url, active_badge_id)')
          .gte('scanned_at', cutoff);

      // Scoped roles: strictly limited to one selected managed outlet.
      // Full admin: follow selected outlet filter if any.
      final activeOutletId = _activeOutletFilterId();
      if (activeOutletId != null) {
        q = q.eq('scan_outlet_id', activeOutletId);
      }

      final data = await q.order('scanned_at', ascending: true);

      // Group by employee_id, detect open sessions (masuk with no subsequent pulang)
      final Map<String, List<Map<String, dynamic>>> byEmployee = {};
      for (final row in (data as List)) {
        final empId = row['employee_id'] as String;
        byEmployee
            .putIfAbsent(empId, () => [])
            .add(row as Map<String, dynamic>);
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
        });
      }
    } catch (e) {
      debugPrint('[OpenShifts] Error: $e');
    }
  }

  Future<void> _loadScheduleGapNotices() async {
    final outletContext = _resolveActiveDashboardOutletContext();
    if (mounted) {
      setState(() => _loadingScheduleGapNotices = true);
    }

    if (outletContext == null) {
      if (mounted) {
        setState(() {
          _scheduleGapNotices = const ScheduleGapNoticeResult(
              entries: <ScheduleGapNoticeEntry>[]);
          _loadingScheduleGapNotices = false;
        });
      }
      return;
    }

    try {
      final now = DateTime.now();
      final endDate = DateTime(now.year, now.month, now.day);
      final startDate =
          endDate.subtract(const Duration(days: _scheduleGapLookbackDays));
      final startIso = startDate.toUtc().toIso8601String();
      final endIso = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();

      final employeeData = await SupabaseClientFactory.admin
          .from('employees')
          .select('*')
          .eq('home_outlet_id', outletContext.outletId)
          .eq('is_active', true)
          .order('name');
      final employees = (employeeData as List)
          .map((row) => Employee.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);

      final strictRows = await _loadStrictPolicyRecapRows(
        outletId: outletContext.outletId,
        startDate: startDate,
        endDate: endDate,
      );

      final attendanceData = await SupabaseClientFactory.admin
          .from('attendance_logs')
          .select('*')
          .eq('scan_outlet_id', outletContext.outletId)
          .gte('scanned_at', startIso)
          .lte('scanned_at', endIso)
          .order('scanned_at', ascending: true);
      final attendanceLogs = (attendanceData as List)
          .map((row) => AttendanceLog.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);

      final notices = _scheduleGapNoticeService.build(
        employees: employees,
        strictRows: strictRows,
        attendanceLogs: attendanceLogs,
        outletId: outletContext.outletId,
        outletName: outletContext.outlet.name,
        outletOperatingMode: outletContext.outlet.operatingMode,
        now: now,
      );

      if (mounted) {
        setState(() {
          _scheduleGapNotices = notices;
          _loadingScheduleGapNotices = false;
        });
      }
    } catch (e) {
      debugPrint('[Dashboard] Failed to load schedule-gap notices: $e');
      if (mounted) {
        setState(() {
          _scheduleGapNotices = const ScheduleGapNoticeResult(
              entries: <ScheduleGapNoticeEntry>[]);
          _loadingScheduleGapNotices = false;
        });
      }
    }
  }

  Future<List<AttendancePolicyRecapDay>> _loadStrictPolicyRecapRows({
    required String outletId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      return await _attendancePolicyRecapService.fetchAdminSchedulePolicyRecap(
        outletId: outletId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      debugPrint('[Dashboard] Failed to load strict recap rows: $e');
      return const <AttendancePolicyRecapDay>[];
    }
  }

  Future<void> _refreshDashboardData(
      {bool includeEmployeeCount = false}) async {
    await Future.wait([
      _loadLogs(),
      _loadOpenShifts(),
      _loadScheduleGapNotices(),
      if (includeEmployeeCount) _loadEmployeeCount(),
    ]);
  }

  Future<void> _manualPulang(_OpenShift shift) async {
    final appState = ref.read(appProvider);
    if (appState.isScopedOutletAdmin &&
        !appState.canAccessOutlet(shift.outletId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak diizinkan menutup shift di outlet lain.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    // Show dialog for notes input
    final notesCtrl = TextEditingController();
    try {
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
        await SupabaseClientFactory.admin.from('attendance_logs').insert({
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
    } finally {
      notesCtrl.dispose();
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
          callback: (_) => _refreshDashboardData(),
        )
        .subscribe();
  }

  void _subscribeEmployeeRealtime() {
    _employeeChannel?.unsubscribe();
    // Hanya admin penuh yang subscribe semua karyawan
    // Kepala gerai hanya subscribe karyawan di outletnya
    var builder = SupabaseClientFactory.admin
        .channel('dashboard:employees')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'employees',
          callback: (_) {
            // Refresh employee count dan list saat ada perubahan
            _refreshDashboardData(includeEmployeeCount: true);
          },
        );
    _employeeChannel = builder.subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _employeeChannel?.unsubscribe();
    _kioskDevicesChannel?.unsubscribe();
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
        onRefresh: _refreshDashboardData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── HERO HEADER ────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeroHeader()),

            // ── STAT GRID 2×2 ──────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildStatGrid()),

            // ── KIOSK HEALTH STATUS ────────────────────────────────────────
            SliverToBoxAdapter(child: _buildKioskHealthSection()),

            // ── INSIGHT / NETWORK ACTIONS ────────────────────────────────
            SliverToBoxAdapter(child: _buildInsightButtons()),

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
    final appState = ref.watch(appProvider);
    final isFullAdmin = appState.isAdmin;
    final roleTitle = appState.isAreaSupervisor
        ? 'Area Supervisor'
        : appState.isKepalaGerai
            ? 'Kepala Gerai'
            : 'Admin Enakko';
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
                    Container(
                      width: 58,
                      height: 58,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'src/assets/images/logogoenakko.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
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
                            roleTitle,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isFullAdmin
                                ? 'Operasional harian, grafik gerai, dan kontrol jaringan dipisah agar dashboard utama tetap fokus.'
                                : 'Pantau absensi gerai Anda secara real-time tanpa meninggalkan dashboard utama.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.84),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
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

  // ─── Kiosk Health Section ──────────────────────────────────────────────────

  Widget _buildKioskHealthSection() {
    // Filter devices by selected outlet
    final devicesForOutlet = _selectedOutletId != null
        ? _kioskDevices.where((d) => d.outletId == _selectedOutletId).toList()
        : _kioskDevices;

    // Count offline devices (excludes "never connected" devices)
    final offlineCount = devicesForOutlet
        .where((d) => !d.isOnline && d.lastHeartbeatAt != null)
        .length;

    final hasIssues = offlineCount > 0;

    // Limit to 5 when collapsed
    const maxCollapsed = 5;
    final shouldCollapse = devicesForOutlet.length > maxCollapsed;
    final visibleDevices = shouldCollapse && !_showAllDevices
        ? devicesForOutlet.take(maxCollapsed).toList()
        : devicesForOutlet;
    final hiddenCount = devicesForOutlet.length - maxCollapsed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with optional issue count
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Text(
                'Status Kiosk',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              if (hasIssues) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$offlineCount offline',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // One card per physical device
          if (devicesForOutlet.isEmpty)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.devices_outlined,
                    size: 40, color: AppColors.textMuted),
                SizedBox(height: 8),
                Text(
                  'Tidak ada kiosk aktif',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Belum ada perangkat terdaftar untuk gerai ini.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          else ...[
            ...visibleDevices.map(
              (d) => KioskDeviceCard(
                device: d,
                onNickname: () => _showNicknameDialog(d),
                onArchive: () => _showArchiveDialog(d),
              ),
            ),
            // Show more / show less button
            if (shouldCollapse)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Center(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _showAllDevices = !_showAllDevices),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showAllDevices
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showAllDevices
                                ? 'Sembunyikan'
                                : 'Tampilkan $hiddenCount lainnya',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ─── Insight / Navigation Buttons ──────────────────────────────────────────

  Widget _buildInsightButtons() {
    final isFullAdmin = ref.watch(appProvider.select((s) => s.isAdmin));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          if (isFullAdmin) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/admin/network-summary'),
                icon: const Icon(Icons.hub_rounded, size: 18),
                label: const Text(
                  'Ringkasan Jaringan & Status Gerai',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedOutletId == null
                  ? null
                  : () {
                      context.push(
                          '/admin/chart-dashboard?outletId=$_selectedOutletId');
                    },
              icon: const Icon(Icons.bar_chart_rounded, size: 18),
              label: Text(
                isFullAdmin
                    ? 'Dashboard Grafik Gerai'
                    : 'Lihat Dashboard Grafik',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    final isScopedAdmin = ref.watch(appProvider).isScopedOutletAdmin;
    final hasResolvedScheduleGapOutlet =
        _resolveActiveDashboardOutletContext() != null;
    final showScheduleGapAction =
        hasResolvedScheduleGapOutlet && _scheduleGapNotices.hasNotices;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Tombol "Jadwal Shift" - tersedia untuk role operasional
            _QuickActionBtn(
              icon: Icons.calendar_month_rounded,
              label: 'Jadwal',
              color: const Color(0xFF7C3AED),
              textColor: Colors.white,
              onTap: _openShiftScheduler,
            ),
            const SizedBox(width: 10),
            // Tombol hanya untuk admin penuh
            if (!isScopedAdmin) ...[
              _QuickActionBtn(
                icon: Icons.add_business_rounded,
                label: 'Gerai',
                color: AppColors.accent,
                textColor: const Color(0xFF1A0A00),
                onTap: _showAddOutletSheet,
              ),
              const SizedBox(width: 10),
              _QuickActionBtn(
                icon: Icons.person_add_rounded,
                label: 'Kep.\nGerai',
                color: const Color(0xFF0369A1),
                textColor: Colors.white,
                onTap: () => context.push('/admin/create-account'),
              ),
              const SizedBox(width: 10),
            ],
            _QuickActionBtn(
              icon: Icons.refresh_rounded,
              label: 'Refresh',
              color: AppColors.primary,
              textColor: Colors.white,
              onTap: _refreshDashboardData,
            ),
            if (showScheduleGapAction) ...[
              const SizedBox(width: 10),
              AdminDashboardScheduleGapQuickAction(
                hasResolvedOutlet:
                    !_loadingScheduleGapNotices && hasResolvedScheduleGapOutlet,
                notices: _scheduleGapNotices,
                onTap: _showScheduleGapNoticeSheet,
              ),
            ],
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
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

  Future<void> _openShiftScheduler() async {
    final outletContext = _resolveActiveDashboardOutletContext();
    if (outletContext == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih outlet terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShiftSchedulerScreen(
          outletId: outletContext.outletId,
          outletName: outletContext.outlet.name,
        ),
      ),
    );

    if (!mounted) return;
    await _refreshDashboardData();
  }

  void _showScheduleGapNoticeSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return AdminScheduleGapNoticeSheet(
          notices: _scheduleGapNotices,
          onOpenScheduler: () {
            Navigator.of(sheetContext).pop();
            _openShiftScheduler();
          },
        );
      },
    );
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

  ({String outletId, Outlet outlet})? _resolveActiveDashboardOutletContext() {
    final outletId = _activeOutletFilterId();
    if (outletId == null || outletId.trim().isEmpty) {
      return null;
    }

    final outlet = _outlets.where((item) => item.id == outletId).firstOrNull;
    if (outlet == null) {
      return null;
    }

    return (outletId: outletId, outlet: outlet);
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
                          badge: BadgeService.instance
                              .getBadgeByIdSync(shift.activeBadgeId),
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
    final appState = ref.watch(appProvider);

    // Kepala gerai: tampilkan nama outlet sebagai label statis (tidak bisa ganti)
    if (appState.isKepalaGerai) {
      final outletName = _outlets
              .where((o) => o.id == _selectedOutletId)
              .map((o) => o.name)
              .firstOrNull ??
          'Memuat outlet...';
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
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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

    // Admin penuh bisa melihat semua; area supervisor hanya memilih gerai assigned.
    final showAllChip = appState.isAdmin;
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
              if (showAllChip)
                _FilterChip(
                  label: 'Semua',
                  selected: _selectedOutletId == null,
                  onTap: () {
                    setState(() => _selectedOutletId = null);
                    _refreshDashboardData();
                  },
                ),
              ..._outlets.map((o) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _FilterChip(
                      label: o.name,
                      selected: _selectedOutletId == o.id,
                      onTap: () {
                        setState(() => _selectedOutletId = o.id);
                        _refreshDashboardData();
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
            20,
            16,
            20,
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
                              passwordCtrl.text.isEmpty) {
                            return;
                          }
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
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            await _loadOutlets();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      const Text('Gerai berhasil ditambahkan'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
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
                                      borderRadius: BorderRadius.circular(10)),
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
    ).whenComplete(() {
      nameCtrl.dispose();
      addressCtrl.dispose();
      passwordCtrl.dispose();
    });
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

  @override
  Widget build(BuildContext context) {
    final empName = item.employee?.name ?? 'Karyawan';
    final outletName = item.outlet?.name ?? '';
    final empBadge =
        BadgeService.instance.getBadgeByIdSync(item.employee?.activeBadgeId);

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
                              color: const Color(0xFF0891B2)
                                  .withValues(alpha: 0.3)),
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
                      fontWeight: item.log.isBackup
                          ? FontWeight.w600
                          : FontWeight.normal,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
