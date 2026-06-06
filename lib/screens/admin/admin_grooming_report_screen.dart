import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../providers/grooming_filter_provider.dart';
import '../../services/grooming_qc_service.dart';
import '../../widgets/app_empty_state.dart';
import 'admin_grooming_rules_screen.dart';
import 'widgets/grooming_analytics_charts.dart';
import 'widgets/grooming_card.dart';
import 'widgets/grooming_csv_export.dart';
import 'widgets/grooming_filter_sheet.dart';
import 'widgets/grooming_override_dialog.dart';
import 'widgets/grooming_per_employee_card.dart';

class AdminGroomingReportScreen extends ConsumerStatefulWidget {
  const AdminGroomingReportScreen({super.key});

  @override
  ConsumerState<AdminGroomingReportScreen> createState() =>
      _AdminGroomingReportScreenState();
}

class _AdminGroomingReportScreenState
    extends ConsumerState<AdminGroomingReportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openFilter(List<GroomingRow> rows) {
    final appState = ref.read(appProvider);
    final outletSet = <String, String>{};
    for (final r in rows) {
      if (r.outletId.isNotEmpty) outletSet[r.outletId] = r.outletName;
    }
    final outlets = outletSet.entries
        .where((e) => appState.canAccessOutlet(e.key))
        .map((e) => (id: e.key, name: e.value))
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => GroomingFilterSheet(outlets: outlets),
    );
  }

  Future<void> _logoutQc() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Even if sign-out fails, drop the local session below.
    }
    ref.read(appProvider.notifier).clearAdminSessionMode();
    // GoRouter redirect handles navigation away from /qc/grooming.
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(groomingRowsProvider);
    final appState = ref.watch(appProvider);
    final isAdmin = appState.isAdmin;
    final isQc = appState.isQc;
    // Only a full admin may correct AI verdicts (the override RPC is
    // admin-only server-side). QC and scoped roles are strictly read-only.
    final readOnly = !isAdmin;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(isQc ? 'Grooming QC (Lihat)' : 'Grooming QC'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'List'),
            Tab(text: 'Per Karyawan'),
            Tab(text: 'Analytics'),
          ],
        ),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Aturan AI',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminGroomingRulesScreen(),
                ),
              ),
              icon: const Icon(Icons.auto_fix_high_rounded),
            ),
          IconButton(
            tooltip: 'Filter',
            onPressed: () => rowsAsync.maybeWhen(
              data: _openFilter,
              orElse: () => _openFilter(const []),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
          if (isQc)
            IconButton(
              tooltip: 'Keluar',
              onPressed: _logoutQc,
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      body: rowsAsync.when(
        data: (rows) => _Tabs(controller: _tabs, rows: rows, readOnly: readOnly),
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => const AppEmptyState(
          icon: Icons.error_outline_rounded,
          heading: 'Gagal memuat data',
          subtext: 'Coba refresh atau cek koneksi.',
        ),
      ),
      floatingActionButton: rowsAsync.maybeWhen(
        data: (rows) => GroomingCsvExportButton(rows: rows),
        orElse: () => null,
      ),
    );
  }
}

class _Tabs extends ConsumerWidget {
  final TabController controller;
  final List<GroomingRow> rows;
  final bool readOnly;
  const _Tabs({
    required this.controller,
    required this.rows,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TabBarView(controller: controller, children: [
      _ListTab(rows: rows, readOnly: readOnly),
      _PerEmployeeTab(
        rows: rows,
        onSelect: (employeeId) {
          ref
              .read(groomingFilterProvider.notifier)
              .setEmployeeQuery(rows
                  .firstWhere((r) => r.employeeId == employeeId)
                  .employeeName);
          controller.animateTo(0);
        },
      ),
      _AnalyticsTab(rows: rows),
    ]);
  }
}

class _ListTab extends StatelessWidget {
  final List<GroomingRow> rows;
  final bool readOnly;
  const _ListTab({required this.rows, this.readOnly = false});
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const AppEmptyState(
        icon: Icons.photo_camera_front_outlined,
        heading: 'Tidak ada foto sesuai filter',
        subtext: 'Ubah filter atau tunggu data baru masuk.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: rows.length,
      itemBuilder: (_, i) => GroomingCard(
        row: rows[i],
        onTapPhoto: () => _openPreview(context, rows[i]),
        // Read-only roles (QC, scoped admins) get no override affordance.
        onTapOverride: readOnly ? null : () => _openOverride(context, rows[i]),
      ),
    );
  }

  void _openPreview(BuildContext context, GroomingRow r) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                title: Text(r.employeeName),
              ),
              body: Center(
                  child: InteractiveViewer(
                      child: Image.network(r.photoUrl))),
            )));
  }

  void _openOverride(BuildContext context, GroomingRow r) {
    showDialog<bool>(
        context: context,
        builder: (_) => GroomingOverrideDialog(row: r));
  }
}

class _PerEmployeeTab extends StatelessWidget {
  final List<GroomingRow> rows;
  final void Function(String employeeId) onSelect;
  const _PerEmployeeTab({required this.rows, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final byEmployee = <String, List<GroomingRow>>{};
    for (final r in rows) {
      byEmployee.putIfAbsent(r.employeeId, () => []).add(r);
    }
    final list = byEmployee.entries
        .map((e) => GroomingPerEmployeeData.fromRows(
              e.key,
              e.value,
              onSelect: () => onSelect(e.key),
            ))
        .toList()
      ..sort((a, b) => a.avgScore.compareTo(b.avgScore));
    if (list.isEmpty) {
      return const AppEmptyState(
        icon: Icons.people_outline,
        heading: 'Belum ada data karyawan',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: list.length,
      itemBuilder: (_, i) => GroomingPerEmployeeCard(data: list[i]),
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  final List<GroomingRow> rows;
  const _AnalyticsTab({required this.rows});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        child: GroomingAnalyticsCharts(rows: rows),
      );
}
