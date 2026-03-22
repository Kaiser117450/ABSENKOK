import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../main.dart' show supabaseReady;
import '../../services/analytics_service.dart';
import '../../widgets/outlet_control_card.dart';

/// Chain-wide control center screen for full admins.
///
/// Shows firm-wide device health and attendance KPIs, then one drilldown card
/// per active outlet. Injected loaders and [onOpenOutlet] let widget tests run
/// without a real Supabase connection.
class CentralDashboardScreen extends StatefulWidget {
  /// Optional injected summary loader (for tests).
  final Future<CentralDashboardSummary?> Function()? summaryLoader;

  /// Optional injected rows loader (for tests).
  final Future<List<OutletControlCenterRow>> Function()? rowsLoader;

  /// Called when an outlet card is tapped. If null the screen handles routing
  /// via GoRouter internally (see [_handleOpenOutlet]).
  final void Function(String outletId)? onOpenOutlet;

  const CentralDashboardScreen({super.key})
      : summaryLoader = null,
        rowsLoader = null,
        onOpenOutlet = null;

  /// Test-only constructor with injected dependencies.
  const CentralDashboardScreen.injected({
    super.key,
    this.summaryLoader,
    this.rowsLoader,
    this.onOpenOutlet,
  });

  @override
  State<CentralDashboardScreen> createState() => _CentralDashboardScreenState();
}

class _CentralDashboardScreenState extends State<CentralDashboardScreen> {
  CentralDashboardSummary? _summary;
  List<OutletControlCenterRow> _rows = [];
  bool _loading = true;
  String? _error;

  // Realtime subscriptions
  RealtimeChannel? _attendanceChannel;
  RealtimeChannel? _employeeChannel;
  RealtimeChannel? _deviceChannel;
  RealtimeChannel? _outletChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _attendanceChannel?.unsubscribe();
    _employeeChannel?.unsubscribe();
    _deviceChannel?.unsubscribe();
    _outletChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summaryFuture = widget.summaryLoader != null
          ? widget.summaryLoader!()
          : AnalyticsService.instance
              .getCentralDashboardSummary(date: DateTime.now());

      final rowsFuture = widget.rowsLoader != null
          ? widget.rowsLoader!()
          : AnalyticsService.instance
              .getOutletControlCenter(date: DateTime.now());

      final summary = await summaryFuture;
      final rows = await rowsFuture;
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat data: $e';
        _loading = false;
      });
    }
  }

  void _subscribeRealtime() {
    if (!supabaseReady || widget.summaryLoader != null) return;

    final client = SupabaseClientFactory.admin;

    void reload() {
      if (mounted) _load();
    }

    _attendanceChannel = client
        .channel('central_attendance_logs_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance_logs',
          callback: (_) => reload(),
        )
        .subscribe();

    _employeeChannel = client
        .channel('central_employees_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'employees',
          callback: (_) => reload(),
        )
        .subscribe();

    _deviceChannel = client
        .channel('central_kiosk_devices_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'kiosk_devices',
          callback: (_) => reload(),
        )
        .subscribe();

    _outletChannel = client
        .channel('central_outlets_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'outlets',
          callback: (_) => reload(),
        )
        .subscribe();
  }

  void _handleOpenOutlet(String outletId) {
    if (widget.onOpenOutlet != null) {
      widget.onOpenOutlet!(outletId);
    } else {
      // ignore: use_build_context_synchronously
      context.push('/admin/outlet-dashboard?outletId=$outletId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── Summary section ──────────────────────────────────
                      const Text(
                        'Ringkasan Jaringan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_summary != null)
                        _SummaryGrid(summary: _summary!)
                      else
                        const _EmptySummaryCard(),
                      const SizedBox(height: 20),

                      // ── Outlet cards section ─────────────────────────────
                      const Text(
                        'Status Per Gerai',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_rows.isEmpty)
                        const _EmptyOutletsView()
                      else
                        ..._rows.map(
                          (row) => OutletControlCard(
                            row: row,
                            onTap: () => _handleOpenOutlet(row.outletId),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

// ─── Summary grid ─────────────────────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  final CentralDashboardSummary summary;
  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      children: [
        _KpiCard(
          label: 'Perangkat Online',
          value: '${summary.connectedDevices}',
          icon: Icons.wifi_rounded,
          color: AppColors.success,
        ),
        _KpiCard(
          label: 'Perangkat Offline',
          value: '${summary.offlineDevices}',
          icon: Icons.wifi_off_rounded,
          color: summary.offlineDevices > 0
              ? AppColors.danger
              : AppColors.textMuted,
        ),
        _KpiCard(
          label: 'Baterai Rendah',
          value: '${summary.lowBatteryDevices}',
          icon: Icons.battery_alert_rounded,
          color: summary.lowBatteryDevices > 0
              ? AppColors.warning
              : AppColors.textMuted,
        ),
        _KpiCard(
          label: 'Kehadiran Hari Ini',
          value: '${summary.dailyAttendanceRate.toStringAsFixed(1)}%',
          icon: Icons.people_rounded,
          color: AppColors.primary,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _EmptySummaryCard extends StatelessWidget {
  const _EmptySummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'Data ringkasan tidak tersedia',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

class _EmptyOutletsView extends StatelessWidget {
  const _EmptyOutletsView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.store_outlined, size: 40, color: AppColors.textMuted),
          SizedBox(height: 10),
          Text(
            'Tidak ada gerai aktif',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
