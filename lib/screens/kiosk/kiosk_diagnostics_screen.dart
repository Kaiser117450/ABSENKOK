import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:toastification/toastification.dart';

import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/sqlite_service.dart';
import '../../services/sync_service.dart';

class KioskDiagnosticsScreen extends ConsumerStatefulWidget {
  const KioskDiagnosticsScreen({super.key});

  @override
  ConsumerState<KioskDiagnosticsScreen> createState() =>
      _KioskDiagnosticsScreenState();
}

class _KioskDiagnosticsScreenState
    extends ConsumerState<KioskDiagnosticsScreen> {
  bool _isSyncing = false;
  int _pendingCount = 0;
  int _failedCount = 0;
  int? _batteryLevel;
  bool? _isCharging;
  bool _isOnline = false;
  String _appVersion = '';
  String? _lastSyncResult;
  Timer? _refreshTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _refreshPendingCount();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _refreshPendingCount());
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() {
          _isOnline = !results.contains(ConnectivityResult.none) &&
              results.isNotEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final battery = Battery();
      final level = await battery.batteryLevel;
      final batteryState = await battery.batteryState;
      final isCharging = batteryState == BatteryState.charging ||
          batteryState == BatteryState.full;

      final info = await PackageInfo.fromPlatform();
      final appVersion = '${info.version}+${info.buildNumber}';

      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = !connectivity.contains(ConnectivityResult.none) &&
          connectivity.isNotEmpty;

      if (mounted) {
        setState(() {
          _batteryLevel = level;
          _isCharging = isCharging;
          _appVersion = appVersion;
          _isOnline = isOnline;
        });
      }
    } catch (e) {
      debugPrint('[Diagnostics] _loadDeviceInfo error: $e');
    }
  }

  Future<void> _refreshPendingCount() async {
    try {
      final count = await SqliteService.countPendingLogs();
      final db = await SqliteService.getDatabase();
      final failedResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM pending_logs WHERE sync_status = 'failed'",
      );
      final failedCount = (failedResult.first['count'] as int?) ?? 0;

      if (mounted) {
        setState(() {
          _pendingCount = count;
          _failedCount = failedCount;
        });
        ref.read(appProvider.notifier).setPendingCount(count);
      }
    } catch (e) {
      debugPrint('[Diagnostics] _refreshPendingCount error: $e');
    }
  }

  Future<void> _forceSync() async {
    if (_isSyncing) return;

    if (!_isOnline) {
      _showToast(
        message: 'Tidak ada koneksi internet',
        icon: Icons.wifi_off,
        color: AppColors.danger,
      );
      return;
    }

    if (_pendingCount == 0) {
      _showToast(
        message: 'Tidak ada data pending',
        icon: Icons.check_circle,
        color: AppColors.success,
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final result = await SyncService.syncPendingLogs();
      await _refreshPendingCount();

      final now = TimeOfDay.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      if (result.synced > 0 && result.failed == 0) {
        _showToast(
          message: 'Berhasil — ${result.synced} data tersinkron',
          icon: Icons.cloud_done,
          color: AppColors.success,
        );
        if (mounted) setState(() => _lastSyncResult = 'Tersinkron pukul $timeStr');
      } else if (result.synced > 0 && result.failed > 0) {
        _showToast(
          message:
              'Sebagian berhasil — ${result.synced} terkirim, ${result.failed} gagal',
          icon: Icons.warning_amber,
          color: AppColors.accent,
        );
        if (mounted) setState(() => _lastSyncResult = 'Sebagian berhasil pukul $timeStr');
      } else if (result.synced == 0 && result.failed > 0) {
        _showToast(
          message:
              'Sinkronisasi gagal — ${result.failed} data tidak terkirim. Coba lagi nanti.',
          icon: Icons.error_outline,
          color: AppColors.danger,
        );
        if (mounted) setState(() => _lastSyncResult = 'Gagal pukul $timeStr');
      } else {
        _showToast(
          message: 'Tidak ada data pending',
          icon: Icons.check_circle,
          color: AppColors.success,
        );
        if (mounted) setState(() => _lastSyncResult = 'Selesai pukul $timeStr');
      }
    } catch (e) {
      _showToast(
        message: 'Sinkronisasi gagal — coba lagi nanti.',
        icon: Icons.error_outline,
        color: AppColors.danger,
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showToast({
    required String message,
    required IconData icon,
    required Color color,
  }) {
    if (!mounted) return;
    toastification.show(
      context: context,
      alignment: Alignment.topCenter,
      title: Text(
        message,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
      icon: Icon(icon, color: color, size: 20),
      style: ToastificationStyle.flat,
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: false,
      borderRadius: BorderRadius.circular(50),
      backgroundColor: const Color(0xFF111827),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }

  Color _batteryColor(int level) {
    if (level > 50) return AppColors.success;
    if (level >= 20) return AppColors.accent;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Diagnostik',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── PERANGKAT SECTION ─────────────────────────────────────────
            _buildSectionCard(
              heading: 'PERANGKAT',
              children: [
                _buildDiagRow(
                  label: 'Outlet',
                  value: appState.kioskSession?.outletName ?? '-',
                ),
                _buildDividerRow(),
                _buildDiagRow(
                  label: 'Versi Aplikasi',
                  value: _appVersion.isEmpty ? '-' : _appVersion,
                ),
                _buildDividerRow(),
                _buildBatteryRow(),
                _buildDividerRow(),
                _buildConnectivityRow(),
                _buildDividerRow(),
                _buildDiagRow(
                  label: 'Heartbeat Terakhir',
                  value: 'Aktif',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── SINKRONISASI SECTION ──────────────────────────────────────
            _buildSectionCard(
              heading: 'SINKRONISASI',
              children: [
                _buildDiagRow(
                  label: 'Data Pending',
                  value: '$_pendingCount',
                  valueColor: _pendingCount > 0
                      ? AppColors.accentDark
                      : AppColors.success,
                ),
                _buildDividerRow(),
                _buildDiagRow(
                  label: 'Gagal',
                  value: '$_failedCount',
                  valueColor:
                      _failedCount > 0 ? AppColors.danger : AppColors.success,
                ),
                const SizedBox(height: 24),
                // Force Sync button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSyncing ? null : _forceSync,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isSyncing ? AppColors.textMuted : AppColors.primary,
                      disabledBackgroundColor: AppColors.textMuted,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSyncing) ...[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          _isSyncing ? 'Menyinkronkan...' : 'Sinkronkan Sekarang',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_lastSyncResult != null)
                  Center(
                    child: Text(
                      _lastSyncResult!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String heading,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDiagRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDividerRow() {
    return const Divider(height: 1, thickness: 1, color: AppColors.border);
  }

  Widget _buildBatteryRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Baterai',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (_batteryLevel != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _batteryColor(_batteryLevel!),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$_batteryLevel%${_isCharging == true ? ' (Mengisi)' : ''}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ] else
            const Text(
              '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectivityRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Koneksi',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOnline ? AppColors.success : AppColors.danger,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
