import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:toastification/toastification.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/employee.dart';
import '../../providers/app_provider.dart';
import '../../services/employee_cache_service.dart';
import '../../services/kiosk_background_service.dart';
import '../../services/kiosk_scan_authority_service.dart';
import '../../services/nfc_service.dart';
import '../../services/sqlite_service.dart';
import '../../services/sync_service.dart';

enum _KioskState { idle, detecting, notFound, nfcError, offlineUnavailable }

class KioskIdleScreen extends ConsumerStatefulWidget {
  final bool debugOfflineUnavailable;
  final bool? debugNfcAvailable;

  const KioskIdleScreen({super.key})
      : debugOfflineUnavailable = false,
        debugNfcAvailable = null;

  @visibleForTesting
  const KioskIdleScreen.testable({
    super.key,
    this.debugOfflineUnavailable = false,
    this.debugNfcAvailable,
  });

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

  // Subtle ambient glow animation for white background
  late final AnimationController _glowController;

  // Sync indicator slide animation
  late final AnimationController _syncSlideController;
  late final Animation<Offset> _syncSlideAnim;

  // Periodic pending count refresh timer
  Timer? _pendingRefreshTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final KioskScanAuthorityService _authorityService =
      KioskScanAuthorityService();

  @override
  void initState() {
    super.initState();
    _initAnimations();

    final debugMode =
        widget.debugOfflineUnavailable || widget.debugNfcAvailable != null;
    if (debugMode) {
      _nfcAvailable = widget.debugNfcAvailable ?? true;
      if (widget.debugOfflineUnavailable) {
        _kioskState = _KioskState.offlineUnavailable;
      }
      return;
    }

    _checkNfcThenListen();
    _syncOnMount();
    _startBackgroundService();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
    _pendingRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshPendingCount(),
    );
  }

  /// Start foreground service notification so kiosk is visible in notification bar.
  Future<void> _startBackgroundService() async {
    final session = ref.read(appProvider).kioskSession;
    if (session == null) return;
    try {
      await KioskBackgroundService.start(session);
    } catch (e) {
      debugPrint('[KioskIdle] start background service error: $e');
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

  Future<void> _refreshPendingCount() async {
    try {
      final count = await SqliteService.countPendingLogs();
      if (mounted) {
        ref.read(appProvider.notifier).setPendingCount(count);
      }
    } catch (_) {}
  }

  Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return;
    }

    try {
      final pendingCount = await SqliteService.countPendingLogs();
      if (pendingCount <= 0) {
        return;
      }

      await SyncService.syncPendingLogs();
    } catch (_) {
      // Passive reconnect sync is best-effort only.
    } finally {
      await _refreshPendingCount();
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

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _syncSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _syncSlideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _syncSlideController, curve: Curves.easeOut));
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

  Future<bool> _ensureScanContext(Employee employee) async {
    final session = ref.read(appProvider).kioskSession;
    if (session == null) return false;

    try {
      final context = await _authorityService.fetchContext(
        employeeId: employee.id,
        outletId: session.outletId,
        deviceId: session.deviceId,
      );
      await EmployeeCacheService.instance.putScanContext(employee.id, context);
      return true;
    } catch (error) {
      debugPrint('[KioskIdle] authority context fetch failed: $error');
      final cachedContext =
          await EmployeeCacheService.instance.getScanContext(employee.id);
      return cachedContext != null;
    }
  }

  void _showOfflineUnavailableState() {
    if (!mounted) return;

    setState(() => _kioskState = _KioskState.offlineUnavailable);
    Future<void>.delayed(
      Duration(milliseconds: AppConstants.errorResetDurationMs),
      () {
        if (mounted && _kioskState == _KioskState.offlineUnavailable) {
          setState(() => _kioskState = _KioskState.idle);
        }
      },
    );
  }

  Future<void> _continueToScan(Employee employee, int transitionDelayMs) async {
    final hasContext = await _ensureScanContext(employee);
    if (!hasContext) {
      ref.read(appProvider.notifier).resetScanFlow();
      _showOfflineUnavailableState();
      return;
    }

    _showEmployeeToast(employee.name);
    await Future<void>.delayed(Duration(milliseconds: transitionDelayMs));
    if (mounted) {
      context.push('/kiosk/scan');
    }
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
        await _continueToScan(cached, AppConstants.cacheFastPathDelayMs);
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
      final activeEmployee = ref.read(appProvider).detectedEmployee;
      if (activeEmployee != null) {
        await _continueToScan(
          activeEmployee,
          AppConstants.cacheFastPathDelayMs,
        );
      }
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
        final activeEmployee = ref.read(appProvider).detectedEmployee;
        if (activeEmployee != null) {
          await _continueToScan(
            activeEmployee,
            AppConstants.scanTransitionDelayMs,
          );
        }
      }
    } catch (e) {
      ref.read(appProvider.notifier).resetScanFlow();
      _showOfflineUnavailableState();
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
                color: AppColors.danger.withValues(alpha: 0.08),
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
              debugPrint('[Logout] starting logout flow');

              // Step 1: Stop background services (best-effort, never blocks logout)
              try {
                await KioskBackgroundService.stop()
                    .timeout(const Duration(seconds: 5));
                debugPrint('[Logout] background service stopped');
              } catch (e) {
                debugPrint('[Logout] stop() failed/timed out: $e');
              }

              // Step 2: ALWAYS clear kiosk session (the critical step)
              try {
                await ref.read(appProvider.notifier).clearKioskSession();
                debugPrint('[Logout] kiosk session cleared');
              } catch (e) {
                debugPrint('[Logout] clearKioskSession error: $e');
              }

              // Step 3: Explicit navigation (belt-and-suspenders with GoRouter redirect)
              if (mounted) {
                debugPrint('[Logout] navigating to /setup');
                context.go('/setup');
              } else {
                debugPrint(
                    '[Logout] widget already unmounted (GoRouter redirect handled it)');
              }
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
                color: AppColors.primary.withValues(alpha: 0.08),
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
    _pulseController.dispose();
    _fadeController.dispose();
    _glowController.dispose();
    _syncSlideController.dispose();
    _connectivitySubscription?.cancel();
    _pendingRefreshTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appProvider);
    final session = appState.kioskSession;
    final pendingCount = appState.pendingCount;

    // Trigger slide animation based on pending count
    if (pendingCount > 0) {
      _syncSlideController.forward();
    } else {
      _syncSlideController.reverse();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Layer 0: Subtle ambient glow — soft breathing radial gradient
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) {
                final t = _glowController.value;
                return CustomPaint(
                  painter: _AmbientGlowPainter(phase: t),
                );
              },
            ),
          ),
          // Layer 1: Main UI
          FadeTransition(
            opacity: _fadeAnim,
            child: SafeArea(
              child: Column(
                children: [
                  // ── TOP HEADER ─────────────────────────────────────────────
                  _buildHeader(session?.outletName, pendingCount),

                  const Divider(
                      height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

                  // ── SYNC INDICATOR (hanya muncul jika ada pending) ─────────
                  _buildSyncIndicator(pendingCount),

                  // ── NFC WARNING BANNER (hanya muncul jika NFC mati) ────────
                  if (!_nfcAvailable) _buildNfcOffBanner(),

                  // ── CLOCK ──────────────────────────────────────────────────
                  const SizedBox(height: 32),
                  _buildClock(),

                  // ── NFC ZONE ───────────────────────────────────────────────
                  const Spacer(),
                  _buildNfcZone(),
                  const Spacer(),

                  // ── BOTTOM BAR ─────────────────────────────────────────────
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
  // Sync Indicator Strip
  // ---------------------------------------------------------------------------

  Widget _buildSyncIndicator(int pendingCount) {
    if (pendingCount <= 0) return const SizedBox.shrink();

    return SlideTransition(
      position: _syncSlideAnim,
      child: Container(
        width: double.infinity,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_upload_outlined,
                size: 14, color: Color(0xFFD97706)),
            const SizedBox(width: 6),
            Text(
              '$pendingCount data belum tersinkron',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ],
        ),
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
          // Brand (long-press opens diagnostics screen)
          GestureDetector(
            onLongPress: () {
              HapticFeedback.mediumImpact();
              context.push('/kiosk/diagnostics');
            },
            child: Column(
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
                            color: AppColors.primaryLight,
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
                    padding: const EdgeInsets.only(left: 30),
                    child: Text(
                      outletName,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ), // end GestureDetector

          const Spacer(),

          // Pending sync badge
          if (pendingCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
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

          // Logout gerai button — icon only
          GestureDetector(
            onTap: _confirmLogoutGerai,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.25),
                ),
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
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.admin_panel_settings_outlined,
                  size: 16, color: AppColors.textSecondary),
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
        color: const Color(0xFFFFF7ED), // warm amber bg
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
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
    return const _DigitalClock();
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
      case _KioskState.offlineUnavailable:
        return _buildResultState(
          icon: Icons.cloud_off_rounded,
          iconColor: AppColors.danger,
          ringColor: AppColors.danger,
          title: 'Belum Bisa Diproses Offline',
          subtitle:
              'Karyawan ini belum tersimpan di perangkat. Sambungkan internet lalu coba lagi.',
        );
    }
  }

  Widget _buildIdleState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated NFC rings
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing ring — yellow accent
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 208,
                  height: 208,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // Middle ring — red brand
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                ),
              ),

              // Inner filled circle with gradient ring
              SizedBox(
                width: 136,
                height: 136,
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) => CustomPaint(
                    painter: _GradientRingPainter(
                        pulseValue: _pulseAnim.value - 1.0),
                    child: child,
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.kioskNfcGlowRed,
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

        // Main instruction
        const Text(
          'Tempelkan Kartu NFC',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'di belakang perangkat ini',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
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
                  color: AppColors.accentLight,
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
            color: ringColor.withValues(alpha: 0.08),
            border: Border.all(
              color: ringColor.withValues(alpha: 0.25),
              width: 2,
            ),
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
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
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
        Container(height: 1, color: const Color(0xFFF0F0F0)),
        Container(
          width: double.infinity,
          color: const Color(0xFFFAFAFA),
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
                      color: dotColor.withValues(alpha: 0.5),
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
              const Icon(Icons.nfc_outlined,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 4),
              const Text(
                'NFC',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
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
  const _DigitalClock();

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
    return Column(
      children: [
        Text(
          _formattedTime,
          style: const TextStyle(
            fontSize: 58,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -1.5,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _formattedDate,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
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
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
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
              'Kamu sebelumnya absen di:\n$homeOutletName',
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
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
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
                  color: color.withValues(alpha: 0.8),
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
// Subtle ambient glow painter — soft breathing radial gradient on white
// ---------------------------------------------------------------------------
class _AmbientGlowPainter extends CustomPainter {
  final double phase; // 0.0 - 1.0

  _AmbientGlowPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.55);

    // Soft red/warm glow that breathes gently
    final glowRadius = size.width * (0.6 + 0.15 * phase);
    final glowOpacity = 0.03 + 0.025 * phase;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          Color.fromRGBO(220, 38, 38, glowOpacity), // brand red, very subtle
          Color.fromRGBO(220, 38, 38, glowOpacity * 0.3),
          const Color.fromRGBO(220, 38, 38, 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

    canvas.drawCircle(center, glowRadius, glowPaint);

    // Secondary warm accent — top-right, very faint
    final accent = Offset(size.width * 0.8, size.height * 0.15);
    final accentRadius = size.width * 0.35;
    final accentOpacity = 0.015 + 0.01 * (1.0 - phase);
    final accentPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          Color.fromRGBO(245, 158, 11, accentOpacity), // warm amber
          const Color.fromRGBO(245, 158, 11, 0),
        ],
      ).createShader(Rect.fromCircle(center: accent, radius: accentRadius));

    canvas.drawCircle(accent, accentRadius, accentPaint);
  }

  @override
  bool shouldRepaint(_AmbientGlowPainter old) => old.phase != phase;
}

// ---------------------------------------------------------------------------
// Gradient ring painter for NFC idle circle — SweepGradient with pulse glow
// ---------------------------------------------------------------------------
class _GradientRingPainter extends CustomPainter {
  final double pulseValue; // 0.0-0.16 from _pulseAnim (1.0-1.16 minus 1.0)

  _GradientRingPainter({this.pulseValue = 0.0});

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
      final glowOpacity = 0.08 + (0.12 * pulseValue / 0.16); // subtle 8-20%
      final glowPaint = Paint()
        ..color = Color.fromRGBO(220, 38, 38, glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(center, radius * 0.7, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_GradientRingPainter old) => old.pulseValue != pulseValue;
}
