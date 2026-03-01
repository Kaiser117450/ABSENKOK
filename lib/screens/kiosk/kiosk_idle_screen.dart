import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/employee.dart';
import '../../providers/app_provider.dart';
import '../../services/employee_cache_service.dart';
import '../../services/kiosk_background_service.dart';
import '../../services/nfc_service.dart';
import '../../services/sqlite_service.dart';
import '../../services/sync_service.dart';

enum _KioskState { idle, detecting, notFound, nfcError }

class KioskIdleScreen extends ConsumerStatefulWidget {
  const KioskIdleScreen({super.key});

  @override
  ConsumerState<KioskIdleScreen> createState() => _KioskIdleScreenState();
}

class _KioskIdleScreenState extends ConsumerState<KioskIdleScreen>
    with TickerProviderStateMixin {
  // NFC availability — checked on init and periodically re-checked
  bool _nfcAvailable = false;
  Timer? _nfcCheckTimer;

  // NFC scan state
  _KioskState _kioskState = _KioskState.idle;
  Future<void> Function()? _nfcCleanup;

  // Pulse animation for NFC ring
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  // Fade-in animation for page load
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  // Ambient background animation controllers
  late final AnimationController _bgGradientCtrl;
  late final AnimationController _breatheCtrl;
  late final AnimationController _shimmerCtrl;

  // Theme toggle: false = white (default), true = dark animated
  bool _isDarkMode = false;
  static const String _darkModeKey = 'kiosk_dark_mode';

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadDarkModePref();
    _checkNfcThenListen();
    _syncOnMount();
    _startBackgroundService();
  }

  Future<void> _loadDarkModePref() async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool(_darkModeKey) ?? false;
    if (mounted) {
      setState(() => _isDarkMode = dark);
      _syncBgAnimations();
    }
  }

  Future<void> _toggleDarkMode() async {
    final newVal = !_isDarkMode;
    setState(() => _isDarkMode = newVal);
    _syncBgAnimations();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, newVal);
  }

  /// Start or stop background animation controllers based on dark mode.
  void _syncBgAnimations() {
    if (_isDarkMode) {
      if (!_bgGradientCtrl.isAnimating) _bgGradientCtrl.repeat();
      if (!_breatheCtrl.isAnimating) _breatheCtrl.repeat(reverse: true);
      if (!_shimmerCtrl.isAnimating) _shimmerCtrl.repeat();
    } else {
      _bgGradientCtrl.stop();
      _breatheCtrl.stop();
      _shimmerCtrl.stop();
    }
  }

  /// Start foreground service notification so kiosk is visible in notification bar.
  Future<void> _startBackgroundService() async {
    final session = ref.read(appProvider).kioskSession;
    if (session == null) return;
    try {
      if (Platform.isAndroid) {
        await _requestOverlayPermission();
      }
      await KioskBackgroundService.start(session);
    } catch (e) {
      debugPrint('[KioskIdle] start background service error: $e');
    }
  }

  /// Cek dan minta izin SYSTEM_ALERT_WINDOW untuk Dynamic Island overlay.
  /// Menampilkan instruksi khusus untuk MIUI/HyperOS (Xiaomi) yang punya
  /// dua lapisan permission terpisah untuk floating window.
  Future<bool> _requestOverlayPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      debugPrint('[KioskIdle] overlay permission granted: $granted');
      if (granted) return true; // sudah ada izin, langsung lanjut

      if (!mounted) return false;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.layers_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Izin Overlay Diperlukan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Agar indikator kiosk mengambang (Dynamic Island) bisa tampil '
                'di atas semua aplikasi, ikuti langkah berikut:',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              _StepRow(step: '1', text: 'Tap "Buka Pengaturan" di bawah'),
              SizedBox(height: 6),
              _StepRow(
                  step: '2', text: 'Cari "Absensi Enakko" → aktifkan toggle'),
              SizedBox(height: 6),
              _StepRow(step: '3', text: 'Kembali ke aplikasi ini'),
              SizedBox(height: 12),
              Text(
                '📱 HP Xiaomi / MIUI / HyperOS:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626)),
              ),
              SizedBox(height: 4),
              Text(
                'Setelah langkah di atas, buka juga:\n'
                'Pengaturan → Aplikasi → Absensi Enakko\n'
                '→ Izin Lainnya → Tampil di atas aplikasi lain → Izinkan',
                style: TextStyle(fontSize: 12, color: Color(0xFF555555)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Lewati'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                // Di Xiaomi/MIUI: buka halaman izin per-app MIUI secara langsung
                // (menampilkan toggle "Tampil di latar belakang" yang sering terlewat).
                // Di non-Xiaomi: fallback ke standard SYSTEM_ALERT_WINDOW settings.
                bool openedMiui = false;
                try {
                  final miuiCh = MethodChannel('com.enakko.kiosk/miui_perms');
                  openedMiui =
                      await miuiCh.invokeMethod<bool>('openMiuiPermissions') ??
                          false;
                } catch (_) {}
                if (!openedMiui) {
                  await FlutterOverlayWindow.requestPermission();
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626)),
              child: const Text('Buka Pengaturan',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (e) {
      debugPrint('[KioskIdle] overlay permission error: $e');
      return false;
    }
  }

  /// Check NFC availability first. If off → show warning banner.
  /// If on → start listener. Re-checks every 5s so user can enable NFC
  /// from settings and come back without restarting the app.
  Future<void> _checkNfcThenListen() async {
    await _refreshNfcState();

    // Periodically re-check so if user enables NFC mid-session, it auto-starts
    _nfcCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _refreshNfcState();
    });
  }

  Future<void> _refreshNfcState() async {
    bool available = false;
    try {
      available = await NfcManager.instance.isAvailable().timeout(
            const Duration(seconds: 2),
            onTimeout: () => false,
          );
    } catch (_) {
      available = false;
    }

    if (!mounted) return;

    final wasAvailable = _nfcAvailable;
    setState(() => _nfcAvailable = available);

    if (available && !wasAvailable) {
      // NFC just turned ON → start listener
      _startNfcListener();
    } else if (!available && wasAvailable) {
      // NFC just turned OFF → stop listener
      final cleanup = _nfcCleanup;
      if (cleanup != null) {
        await cleanup();
        _nfcCleanup = null;
      }
    }
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.16).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    // Background animation controllers — started/stopped by _syncBgAnimations()
    _bgGradientCtrl = AnimationController(
      vsync: this, duration: Duration(seconds: AppConstants.kioskBgGradientDurationSec),
    );
    _breatheCtrl = AnimationController(
      vsync: this, duration: Duration(seconds: AppConstants.kioskBreatheDurationSec),
    );
    _shimmerCtrl = AnimationController(
      vsync: this, duration: Duration(seconds: AppConstants.kioskShimmerDurationSec),
    );
  }

  void _startNfcListener() {
    // Don't start a second listener if one is already running
    if (_nfcCleanup != null) return;

    _nfcCleanup = NfcService.startListener(
      _onNfcTag,
      (err) {
        if (mounted) {
          setState(() => _kioskState = _KioskState.nfcError);
          Future<void>.delayed(
            Duration(milliseconds: AppConstants.errorResetDurationMs),
            () {
              if (mounted) setState(() => _kioskState = _KioskState.idle);
            },
          );
        }
      },
    );
  }

  Future<void> _syncOnMount() async {
    final session = ref.read(appProvider).kioskSession;
    if (session == null) return;
    try {
      await SyncService.syncPendingLogs();
      final count = await SqliteService.countPendingLogs();
      ref.read(appProvider.notifier).setPendingCount(count);
    } catch (_) {}
  }

  Future<void> _onNfcTag(String uid) async {
    if (_kioskState != _KioskState.idle) return;
    final session = ref.read(appProvider).kioskSession;
    if (session == null) return;

    // ── CHECK BACKUP CACHE TTL 5 JAM ─────────────────────────────────────────
    // Jika karyawan sudah pilih backup dalam 5 jam terakhir, skip konfirmasi
    final cachedBackupOutletId =
        await EmployeeCacheService.instance.getBackupOutletId(uid);
    if (cachedBackupOutletId != null &&
        cachedBackupOutletId == session.outletId) {
      final cached = await EmployeeCacheService.instance.get(uid);
      if (cached != null && mounted) {
        ref.read(appProvider.notifier).setDetectedEmployee(cached);
        ref.read(appProvider.notifier).setBackupMode(
              true,
              'Backup di ${session.outletName}',
              session.outletId,
            );
        _showEmployeeToast(cached.name);
        await Future<void>.delayed(
            const Duration(milliseconds: AppConstants.cacheFastPathDelayMs));
        if (mounted) context.push('/kiosk/scan');
        return;
      }
    }

    // ── FAST PATH: NFC UID cache (skip Supabase jika sudah ada dalam 5 menit) ──
    final cached = await EmployeeCacheService.instance.get(uid);
    if (cached != null && mounted) {
      // Cek jika outlet berbeda
      if (cached.homeOutletId != null &&
          cached.homeOutletId != session.outletId) {
        final result =
            await _showOutletConfirmationDialog(cached, session.outletName);
        if (result == null || !mounted) {
          setState(() => _kioskState = _KioskState.idle);
          return;
        }
        // result = (isBackup: bool)
        if (!result['isBackup']) {
          // Pindah outlet - update home_outlet_id di database dan cache
          final success = await _moveEmployeeToOutlet(cached, session.outletId);
          if (success) {
            // Update cached employee dengan outlet baru
            final updatedEmployee =
                cached.copyWith(homeOutletId: session.outletId);
            await EmployeeCacheService.instance.put(uid, updatedEmployee);
            ref.read(appProvider.notifier).setDetectedEmployee(updatedEmployee);
            ref.read(appProvider.notifier).setBackupMode(false, null, null);
            // Clear backup cache jika ada
            await EmployeeCacheService.instance.clearBackupMode(uid);
          } else {
            // Jika gagal pindah, tetap lanjut tapi tetap di mode backup
            ref.read(appProvider.notifier).setDetectedEmployee(cached);
            ref.read(appProvider.notifier).setBackupMode(
                true, 'Backup di ${session.outletName}', session.outletId);
            await EmployeeCacheService.instance.setBackupMode(
                uid, session.outletId, 'Backup di ${session.outletName}');
          }
        } else {
          // Backup mode - tetap gunakan outlet lama di profil
          ref.read(appProvider.notifier).setDetectedEmployee(cached);
          ref.read(appProvider.notifier).setBackupMode(
              true, 'Backup di ${session.outletName}', session.outletId);
          // Simpan ke cache backup dengan TTL 5 jam
          await EmployeeCacheService.instance.setBackupMode(
              uid, session.outletId, 'Backup di ${session.outletName}');
        }
      } else {
        ref.read(appProvider.notifier).setDetectedEmployee(cached);
        ref.read(appProvider.notifier).setBackupMode(false, null, null);
        await EmployeeCacheService.instance.clearBackupMode(uid);
      }
      _showEmployeeToast(cached.name);
      await Future<void>.delayed(
          const Duration(milliseconds: AppConstants.cacheFastPathDelayMs));
      if (mounted) context.push('/kiosk/scan');
      return;
    }

    // ── SLOW PATH: query Supabase ─────────────────────────────────────────────
    if (mounted) setState(() => _kioskState = _KioskState.detecting);

    try {
      final client = SupabaseClientFactory.kiosk;
      final data = await client
          .from('employees')
          .select('*')
          .eq('nfc_uid', uid)
          .eq('is_active', true)
          .maybeSingle();

      if (data == null) {
        if (mounted) {
          setState(() => _kioskState = _KioskState.notFound);
          Future<void>.delayed(
            Duration(milliseconds: AppConstants.errorResetDurationMs),
            () {
              if (mounted) setState(() => _kioskState = _KioskState.idle);
            },
          );
        }
        return;
      }

      final employee = _mapEmployee(data);
      // Simpan ke cache agar scan berikutnya dalam 5 menit instant
      await EmployeeCacheService.instance.put(uid, employee);

      if (mounted) {
        // Cek jika outlet berbeda
        if (employee.homeOutletId != null &&
            employee.homeOutletId != session.outletId) {
          final result =
              await _showOutletConfirmationDialog(employee, session.outletName);
          if (result == null || !mounted) {
            setState(() => _kioskState = _KioskState.idle);
            return;
          }
          if (!result['isBackup']) {
            // Pindah outlet - update home_outlet_id permanen
            final success =
                await _moveEmployeeToOutlet(employee, session.outletId);
            if (success) {
              final updatedEmployee =
                  employee.copyWith(homeOutletId: session.outletId);
              await EmployeeCacheService.instance.put(uid, updatedEmployee);
              ref
                  .read(appProvider.notifier)
                  .setDetectedEmployee(updatedEmployee);
              ref.read(appProvider.notifier).setBackupMode(false, null, null);
            } else {
              // Gagal pindah, fallback ke backup mode
              ref.read(appProvider.notifier).setDetectedEmployee(employee);
              ref.read(appProvider.notifier).setBackupMode(
                  true, 'Backup di ${session.outletName}', session.outletId);
              await EmployeeCacheService.instance.setBackupMode(
                  uid, session.outletId, 'Backup di ${session.outletName}');
            }
          } else {
            // Backup mode
            ref.read(appProvider.notifier).setDetectedEmployee(employee);
            ref.read(appProvider.notifier).setBackupMode(
                true, 'Backup di ${session.outletName}', session.outletId);
            // Simpan ke cache backup dengan TTL 5 jam
            await EmployeeCacheService.instance.setBackupMode(
                uid, session.outletId, 'Backup di ${session.outletName}');
          }
        } else {
          ref.read(appProvider.notifier).setDetectedEmployee(employee);
          ref.read(appProvider.notifier).setBackupMode(false, null, null);
        }

        setState(() => _kioskState = _KioskState.idle);
        _showEmployeeToast(employee.name);
        await Future<void>.delayed(
            const Duration(milliseconds: AppConstants.scanTransitionDelayMs));
        if (mounted) context.push('/kiosk/scan');
      }
    } catch (e) {
      if (mounted) setState(() => _kioskState = _KioskState.idle);
    }
  }

  Future<bool> _moveEmployeeToOutlet(
      Employee employee, String newOutletId) async {
    try {
      debugPrint(
          '[MoveEmployee] Moving ${employee.name} (${employee.id}) to outlet $newOutletId');

      // Gunanon_key untuk bypass RLS jika perlu, atau pastikan RLS allow update
      final result = await SupabaseClientFactory.admin
          .from('employees')
          .update({
            'home_outlet_id': newOutletId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', employee.id)
          .select(); // Tambah select untuk confirm update berhasil

      debugPrint('[MoveEmployee] Update result: $result');

      if (result.isEmpty) {
        debugPrint('[MoveEmployee] WARNING: No rows updated!');
        return false;
      }

      debugPrint('[MoveEmployee] Success! Rows updated: ${result.length}');
      return true;
    } catch (e, stack) {
      debugPrint('[MoveEmployee] ERROR: $e');
      debugPrint('[MoveEmployee] Stack: $stack');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _showOutletConfirmationDialog(
    Employee employee,
    String currentOutletName,
  ) async {
    if (!mounted) return null;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OutletConfirmationDialog(
        employee: employee,
        currentOutletName: currentOutletName,
      ),
    );
  }

  /// Toast "Halo, [Nama]! 👋" dipakai di fast path maupun slow path.
  void _showEmployeeToast(String empName) {
    if (!mounted) return;
    toastification.show(
      context: context,
      alignment: Alignment.topCenter,
      title: Text(
        'Halo, $empName! 👋',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          color: Colors.white,
        ),
      ),
      description: const Text(
        'Kartu terdeteksi — pilih absensi',
        style: TextStyle(fontSize: 12, color: Color(0xFFD1FAE5)),
      ),
      type: ToastificationType.success,
      style: ToastificationStyle.flat,
      autoCloseDuration:
          const Duration(milliseconds: AppConstants.toastDurationMs),
      showProgressBar: false,
      borderRadius: BorderRadius.circular(50),
      backgroundColor: const Color(0xFF111827),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.nfc_rounded, color: Color(0xFF4ADE80), size: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      margin: const EdgeInsets.only(top: 12),
    );
  }

  Employee _mapEmployee(Map<String, dynamic> json) {
    return Employee.fromJson(json);
  }

  void _confirmLogoutGerai() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded,
                  color: AppColors.danger, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Reset Perangkat?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Gerai ini akan di-logout dari perangkat. Kamu perlu scan password gerai lagi untuk menggunakannya.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await KioskBackgroundService.stop();
              await ref.read(appProvider.notifier).clearKioskSession();
              if (mounted) context.go('/setup');
            },
            child: const Text('Reset',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _goToAdmin() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.admin_panel_settings_outlined,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Mode Admin',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Akses ini khusus administrator. Lanjutkan ke halaman login admin?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/admin/login');
            },
            child: const Text('Login Admin',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bgGradientCtrl.dispose();
    _breatheCtrl.dispose();
    _shimmerCtrl.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _nfcCheckTimer?.cancel();
    final cleanup = _nfcCleanup;
    if (cleanup != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => cleanup());
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  // Convenience color getters based on current theme mode
  Color get _bgColor => _isDarkMode ? AppColors.kioskDarkBase : Colors.white;
  Color get _textPrimary => _isDarkMode ? AppColors.kioskTextPrimary : AppColors.textPrimary;
  Color get _textSecondary => _isDarkMode ? AppColors.kioskTextSecondary : AppColors.textSecondary;
  Color get _textMuted => _isDarkMode ? AppColors.kioskTextMuted : AppColors.textMuted;
  Color get _surfaceDim => _isDarkMode ? AppColors.kioskSurfaceDim : AppColors.surfaceVariant;
  Color get _dividerColor => _isDarkMode ? AppColors.kioskDivider : AppColors.divider;
  Color get _nfcCircleBg => _isDarkMode ? AppColors.kioskSurfaceDim : AppColors.surfaceVariant;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appProvider);
    final session = appState.kioskSession;
    final pendingCount = appState.pendingCount;
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // Layer 0: Animated background (only when dark mode)
          if (_isDarkMode)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_bgGradientCtrl, _breatheCtrl, _shimmerCtrl]),
                builder: (context, _) => CustomPaint(
                  painter: _AmbientBackgroundPainter(
                    gradientPhase: _bgGradientCtrl.value,
                    breathePhase: _breatheCtrl.value,
                    shimmerPhase: _shimmerCtrl.value,
                  ),
                ),
              ),
            ),
          // Layer 1: UI content
          FadeTransition(
            opacity: _fadeAnim,
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(session?.outletName, pendingCount),
                  Divider(height: 1, thickness: 1, color: _dividerColor),
                  if (!_nfcAvailable) _buildNfcOffBanner(),
                  const SizedBox(height: 32),
                  _buildClock(),
                  const Spacer(),
                  _buildNfcZone(),
                  const Spacer(),
                  _buildBottomBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(String? outletName, int pendingCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Row(
        children: [
          // Brand logo + title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/logo_enakko.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 32,
                        height: 32,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.restaurant,
                            color: AppColors.primary, size: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Absensi Enakko',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              if (outletName != null) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: Text(
                    outletName,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const Spacer(),

          // Pending sync badge
          if (pendingCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined,
                      size: 12, color: Color(0xFFD97706)),
                  const SizedBox(width: 4),
                  Text(
                    '$pendingCount pending',
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Theme toggle button
          GestureDetector(
            onTap: _toggleDarkMode,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _isDarkMode ? AppColors.kioskSurfaceDim : AppColors.surfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(color: _isDarkMode ? AppColors.kioskDivider : AppColors.border),
              ),
              child: Icon(
                _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                size: 16,
                color: _isDarkMode ? AppColors.kioskTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Logout gerai button — icon only
          GestureDetector(
            onTap: _confirmLogoutGerai,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0x26DC2626),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x40DC2626)),
              ),
              child: const Icon(Icons.logout_rounded,
                  size: 16, color: AppColors.danger),
            ),
          ),

          const SizedBox(width: 6),

          // Admin button — icon only, subtle
          GestureDetector(
            onTap: _goToAdmin,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _surfaceDim,
                shape: BoxShape.circle,
                border: Border.all(color: _dividerColor),
              ),
              child: Icon(Icons.admin_panel_settings_outlined,
                  size: 16, color: _textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NFC Off Banner
  // ---------------------------------------------------------------------------

  Widget _buildNfcOffBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2A2010) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.nfc_outlined, color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NFC tidak aktif',
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Aktifkan NFC di Pengaturan ponsel untuk mulai absensi',
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Refresh button — re-check NFC now
          GestureDetector(
            onTap: _refreshNfcState,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Cek ulang',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Clock
  // ---------------------------------------------------------------------------

  Widget _buildClock() {
    return _DigitalClock(isDarkMode: _isDarkMode);
  }

  // ---------------------------------------------------------------------------
  // NFC Zone
  // ---------------------------------------------------------------------------

  Widget _buildNfcZone() {
    // If NFC is disabled on the device, show a clear "NFC off" state
    if (!_nfcAvailable) {
      return _buildResultState(
        icon: Icons.mobile_off_outlined,
        iconColor: const Color(0xFFD97706),
        ringColor: const Color(0xFFF59E0B),
        title: 'NFC Tidak Aktif',
        subtitle: 'Aktifkan NFC di Pengaturan, lalu tekan "Cek ulang"',
      );
    }

    switch (_kioskState) {
      case _KioskState.idle:
        return _buildIdleState();
      case _KioskState.detecting:
        return _buildDetectingState();
      case _KioskState.notFound:
        return _buildResultState(
          icon: Icons.credit_card_off_outlined,
          iconColor: AppColors.danger,
          ringColor: AppColors.danger,
          title: 'Kartu Tidak Terdaftar',
          subtitle: 'Hubungi admin untuk mendaftarkan kartu Anda',
        );
      case _KioskState.nfcError:
        return _buildResultState(
          icon: Icons.nfc_outlined,
          iconColor: const Color(0xFFD97706),
          ringColor: const Color(0xFFF59E0B),
          title: 'Gagal Membaca Kartu',
          subtitle: 'Coba tempelkan kembali',
        );
    }
  }

  Widget _buildIdleState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated NFC rings with gradient ring painter
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing ring
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 208,
                  height: 208,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isDarkMode
                          ? AppColors.kioskNfcRingOuter
                          : AppColors.accent.withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // Middle ring
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isDarkMode
                        ? AppColors.kioskNfcRingMiddle
                        : AppColors.primary.withOpacity(0.10),
                    width: 1.5,
                  ),
                ),
              ),

              // Inner circle with gradient ring painter
              SizedBox(
                width: 136,
                height: 136,
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) => CustomPaint(
                    painter: _GradientRingPainter(
                      pulseValue: _pulseAnim.value - 1.0,
                      isDarkMode: _isDarkMode,
                    ),
                    child: child,
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _nfcCircleBg,
                      boxShadow: [
                        BoxShadow(
                          color: _isDarkMode
                              ? AppColors.kioskNfcGlowRed
                              : AppColors.primary.withOpacity(0.06),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.contactless_rounded,
                        size: 56,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Main instruction — light weight for premium feel
        Text(
          'Tempelkan Kartu NFC',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: _textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'di belakang perangkat ini',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildDetectingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 3,
              ),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _nfcCircleBg,
                ),
                child: const Center(
                  child: Icon(Icons.hourglass_top_rounded,
                      size: 44, color: AppColors.accent),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Mencari data karyawan...',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildResultState({
    required IconData icon,
    required Color iconColor,
    required Color ringColor,
    required String title,
    required String subtitle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ringColor.withOpacity(0.12),
            border: Border.all(color: ringColor.withOpacity(0.30), width: 2),
          ),
          child: Center(
            child: Icon(icon, size: 52, color: iconColor),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: iconColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: _textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom bar
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar() {
    final isIdle = _kioskState == _KioskState.idle && _nfcAvailable;

    // Determine dot color & label based on combined state
    final Color dotColor;
    final String statusLabel;
    if (!_nfcAvailable) {
      dotColor = const Color(0xFFD97706);
      statusLabel = 'NFC tidak aktif';
    } else if (_kioskState == _KioskState.detecting) {
      dotColor = AppColors.accent;
      statusLabel = 'Memproses...';
    } else if (_kioskState == _KioskState.idle) {
      dotColor = AppColors.success;
      statusLabel = 'NFC siap memindai';
    } else {
      dotColor = AppColors.danger;
      statusLabel = 'Coba lagi';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: _dividerColor),
        Container(
          width: double.infinity,
          color: _surfaceDim,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dotColor,
                ),
              ),
              const Spacer(),
              Icon(Icons.nfc_outlined,
                  size: 16, color: _textMuted),
              const SizedBox(width: 4),
              Text(
                'NFC',
                style: TextStyle(
                  fontSize: 11,
                  color: _textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DigitalClock extends StatefulWidget {
  final bool isDarkMode;
  const _DigitalClock({this.isDarkMode = false});

  @override
  State<_DigitalClock> createState() => _DigitalClockState();
}

class _DigitalClockState extends State<_DigitalClock> {
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get _formattedDate {
    const days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu'
    ];
    const months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return '${days[_now.weekday % 7]}, ${_now.day} ${months[_now.month]} ${_now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final timeColor = widget.isDarkMode
        ? AppColors.kioskTextPrimary
        : AppColors.textPrimary;
    final dateColor = widget.isDarkMode
        ? AppColors.kioskTextSecondary
        : AppColors.textSecondary;

    return Column(
      children: [
        Text(
          _formattedTime,
          style: GoogleFonts.robotoMono(
            fontSize: 52,
            fontWeight: FontWeight.w300,
            color: timeColor,
            letterSpacing: 2.0,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _formattedDate,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: dateColor,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
} // ---------------------------------------------------------------------------

// Dialog Konfirmasi Outlet - Muncul saat karyawan scan di gerai berbeda
// ---------------------------------------------------------------------------
class _OutletConfirmationDialog extends StatelessWidget {
  final Employee employee;
  final String currentOutletName;

  const _OutletConfirmationDialog({
    required this.employee,
    required this.currentOutletName,
  });

  @override
  Widget build(BuildContext context) {
    final homeOutletName = employee.homeOutletId != null
        ? 'Gerai sebelumnya'
        : 'Belum punya gerai';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon alert
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
                border:
                    Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: Color(0xFFD97706),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Konfirmasi Outlet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              'Kamu sebelumnya absen di:\n${homeOutletName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sekarang scan di: $currentOutletName',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),

            // Employee Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  // Avatar
                  _buildAvatar(),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (employee.position != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            employee.position!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Question
            const Text(
              'Kamu lagi backup atau sudah pindah gerai?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Buttons
            Row(
              children: [
                // Backup Button
                Expanded(
                  child: _ActionButton(
                    icon: Icons.support_agent_rounded,
                    label: 'Backup',
                    subtitle: 'Sementara di sini',
                    color: const Color(0xFF0891B2), // Cyan
                    onTap: () => Navigator.of(context).pop({'isBackup': true}),
                  ),
                ),
                const SizedBox(width: 12),
                // Pindah Button
                Expanded(
                  child: _ActionButton(
                    icon: Icons.move_down_rounded,
                    label: 'Pindah',
                    subtitle: 'Pindah permanen',
                    color: AppColors.success,
                    onTap: () => Navigator.of(context).pop({'isBackup': false}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Cancel
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text(
                'Batal',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (employee.photoUrl != null && employee.photoUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: employee.photoUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              Container(width: 48, height: 48, color: Colors.grey.shade200),
          errorWidget: (context, url, error) => _initialAvatar(),
        ),
      );
    }
    return _initialAvatar();
  }

  Widget _initialAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widget untuk dialog instruksi overlay permission
// ---------------------------------------------------------------------------
class _StepRow extends StatelessWidget {
  final String step;
  final String text;
  const _StepRow({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFFDC2626),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Gradient ring painter — SweepGradient stroke for premium NFC ring
// ---------------------------------------------------------------------------
class _GradientRingPainter extends CustomPainter {
  final double pulseValue; // 0.0-0.16 range from _pulseAnim
  final bool isDarkMode;

  _GradientRingPainter({this.pulseValue = 0.0, this.isDarkMode = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Gradient ring stroke (SweepGradient around the circle)
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFDC2626), // brand red
          Color(0xFFF87171), // lighter red
          Color(0xFFFCA5A5), // even lighter
          Color(0xFFDC2626), // back to brand
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, ringPaint);

    // Inner glow tied to pulse animation
    if (pulseValue > 0) {
      final glowOpacity = isDarkMode
          ? 0.08 + (0.12 * (pulseValue / 0.16))
          : 0.04 + (0.06 * (pulseValue / 0.16));
      final glowPaint = Paint()
        ..color = const Color(0xFFDC2626).withOpacity(glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(center, radius * 0.7, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_GradientRingPainter old) =>
      old.pulseValue != pulseValue || old.isDarkMode != isDarkMode;
}

// ---------------------------------------------------------------------------
// Ambient background painter — 3-layer animated CustomPainter for kiosk idle
// ---------------------------------------------------------------------------
class _AmbientBackgroundPainter extends CustomPainter {
  final double gradientPhase;
  final double breathePhase;
  final double shimmerPhase;

  _AmbientBackgroundPainter({
    required this.gradientPhase,
    required this.breathePhase,
    required this.shimmerPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Layer 1: Slow-shifting base gradient (warm-dark <-> neutral-dark)
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(AppColors.kioskDarkWarm, AppColors.kioskDarkNeutral, gradientPhase)!,
        Color.lerp(AppColors.kioskDarkNeutral, AppColors.kioskDarkBase, gradientPhase)!,
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Layer 2: Breathing radial glow at center (near NFC zone)
    final centerX = size.width / 2;
    final centerY = size.height * 0.55;
    final scale = 0.8 + (0.3 * breathePhase);
    final glowRadius = size.width * 0.4 * scale;
    // Opacity range: 0.05 -> 0.12 (very subtle)
    final opacity = 0.05 + (0.07 * breathePhase);
    final glowGradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        AppColors.kioskGlowCenter.withValues(alpha: opacity),
        Colors.transparent,
      ],
    );
    final glowRect = Rect.fromCircle(center: Offset(centerX, centerY), radius: glowRadius);
    canvas.drawOval(glowRect, Paint()..shader = glowGradient.createShader(glowRect));

    // Layer 3: Diagonal shimmer sweep
    final shimmerWidth = size.width * 0.3;
    final shimmerX = -shimmerWidth + (size.width + shimmerWidth * 2) * shimmerPhase;
    final shimmerGradient = LinearGradient(
      colors: [
        Colors.transparent,
        AppColors.kioskShimmerMid,
        AppColors.kioskShimmerPeak,
        AppColors.kioskShimmerMid,
        Colors.transparent,
      ],
    );
    canvas.save();
    // Slight diagonal rotation for premium feel
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(0.25);
    canvas.translate(-size.width / 2, -size.height / 2);
    final shimmerRect = Rect.fromLTWH(shimmerX, -size.height * 0.2, shimmerWidth, size.height * 1.4);
    canvas.drawRect(shimmerRect, Paint()..shader = shimmerGradient.createShader(shimmerRect));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AmbientBackgroundPainter old) =>
      gradientPhase != old.gradientPhase ||
      breathePhase != old.breathePhase ||
      shimmerPhase != old.shimmerPhase;
}
