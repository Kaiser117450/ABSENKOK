import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/employee.dart';
import '../../models/outlet.dart';
import '../../providers/app_provider.dart';
import '../../services/nfc_service.dart';
import '../../services/badge_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/badge_avatar.dart';
import '../../widgets/shimmer_skeleton.dart';
import 'badge_management_screen.dart';
import 'sakit_izin_dialog.dart';
import 'sakit_izin_list_screen.dart';

class AdminEmployeesScreen extends ConsumerStatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  ConsumerState<AdminEmployeesScreen> createState() =>
      _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends ConsumerState<AdminEmployeesScreen> {
  List<Employee> _employees = [];
  List<Outlet> _outlets = [];
  bool _loading = true;
  String _searchQuery = '';
  String? _filterOutletId;
  RealtimeChannel? _channel;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Kepala gerai: auto-set filter ke outlet mereka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = ref.read(appProvider);
      if (appState.isKepalaGerai && appState.managedOutletId != null) {
        setState(() => _filterOutletId = appState.managedOutletId);
      }
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    _channel = SupabaseClientFactory.admin
        .channel('employees:realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'employees',
          callback: (_) => _loadData(),
        )
        .subscribe();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final appState = ref.read(appProvider);
      final isKepalaGerai = appState.isKepalaGerai;
      final managedOutletId = appState.managedOutletId;

      // Query karyawan — filter SEBELUM order() agar .eq() tersedia
      // (PostgrestTransformBuilder tidak punya .eq(), hanya PostgrestFilterBuilder)
      var empFilter = SupabaseClientFactory.admin
          .from('employees')
          .select('*')
          .eq('is_active', true);
      if (isKepalaGerai && managedOutletId != null) {
        empFilter = empFilter.eq('home_outlet_id', managedOutletId);
      }
      final empData = await empFilter.order('name');

      // Query outlet — kepala_gerai hanya load outletnya sendiri
      var outFilter = SupabaseClientFactory.admin
          .from('outlets')
          .select('*')
          .eq('is_active', true);
      if (isKepalaGerai && managedOutletId != null) {
        outFilter = outFilter.eq('id', managedOutletId);
      }
      final outData = await outFilter.order('name');

      // Ensure badge cache is warm for BadgeAvatar rendering
      BadgeService.instance.fetchAll();

      if (mounted) {
        setState(() {
          _employees = (empData as List)
              .map((e) => Employee.fromJson(e as Map<String, dynamic>))
              .toList();
          _outlets = (outData as List)
              .map((e) => Outlet.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
        _subscribeRealtime();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Employee> get _filtered {
    var list = _employees;
    if (_filterOutletId != null) {
      list = list.where((e) => e.homeOutletId == _filterOutletId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((e) =>
              e.name.toLowerCase().contains(q) ||
              (e.position?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  void _showEmployeeSheet(Employee? existing) {
    final appState = ref.read(appProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EmployeeSheet(
        employee: existing,
        outlets: _outlets,
        // Kepala gerai: saat tambah karyawan baru, auto-set ke outletnya
        forcedOutletId: appState.isKepalaGerai ? appState.managedOutletId : null,
        onSaved: _loadData,
      ),
    );
  }

  void _showAssignNfcDialog(Employee employee) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AssignNfcDialog(
        employee: employee,
        onAssigned: _loadData,
      ),
    );
  }

  void _showSakitIzinDialog(Employee employee) {
    final outletInfo = _resolveSakitIzinOutlet(employee);
    if (outletInfo == null) {
      AppToast.error(context, 'Outlet tidak tersedia untuk karyawan ini');
      return;
    }

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SakitIzinDialog(
        employee: employee,
        outletId: outletInfo.id,
        outletName: outletInfo.name,
      ),
    ).then((result) {
      if (result == true) {
        _loadData(); // Refresh data jika berhasil
      }
    });
  }

  void _showSakitIzinHistory(Employee employee) {
    final outletInfo = _resolveSakitIzinOutlet(employee);
    if (outletInfo == null) {
      AppToast.error(context, 'Outlet tidak tersedia untuk karyawan ini');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SakitIzinListScreen(
          employee: employee,
          outletId: outletInfo.id,
          outletName: outletInfo.name,
        ),
      ),
    );
  }

  ({String id, String name})? _resolveSakitIzinOutlet(Employee employee) {
    final appState = ref.read(appProvider);
    final outletId = appState.isKepalaGerai
        ? appState.managedOutletId
        : employee.homeOutletId ?? _outlets.firstOrNull?.id;

    if (outletId == null) {
      return null;
    }

    final outletName = _outlets
            .where((o) => o.id == outletId)
            .map((o) => o.name)
            .firstOrNull ??
        'Unknown';

    return (id: outletId, name: outletName);
  }

  Future<void> _showBadgePicker(Employee employee) async {
    final changed = await BadgeManagementScreen.showBadgePicker(
      context,
      employee: employee,
    );
    if (changed) {
      _loadData();
    }
  }

  void _openBadgeManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BadgeManagementScreen(),
      ),
    );
  }

  Widget _buildEmployeeListShimmer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Column(
        children: List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: const [
                  ShimmerSkeleton(width: 52, height: 52, borderRadius: 26),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerSkeleton(width: 140, height: 14, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerSkeleton(width: 100, height: 12, borderRadius: 4),
                        SizedBox(height: 4),
                        ShimmerSkeleton(width: 80, height: 11, borderRadius: 4),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  ShimmerSkeleton(width: 34, height: 34, borderRadius: 17),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final activeCount = _employees.where((e) => e.isActive).length;
    final noNfcCount = _employees.where((e) => e.nfcUid == null).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: Column(
        children: [
          // ── SUMMARY STRIP ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _MiniStat(
                          label: 'Total',
                          value: '${_employees.length}',
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        _MiniStat(
                          label: 'Aktif',
                          value: '$activeCount',
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        _MiniStat(
                          label: 'Tanpa Kartu',
                          value: '$noNfcCount',
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        // Archive navigation button
                        GestureDetector(
                          onTap: () => context.push('/admin/archived-employees'),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.textMuted.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.textMuted.withOpacity(0.2)),
                            ),
                            child: const Tooltip(
                              message: 'Riwayat Karyawan',
                              child: Icon(Icons.archive_outlined,
                                  size: 16, color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // CSV Import navigation button
                        GestureDetector(
                          onTap: () => context.push('/admin/csv-import'),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.textMuted.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.textMuted.withValues(alpha: 0.2)),
                            ),
                            child: const Tooltip(
                              message: 'Import CSV',
                              child: Icon(Icons.upload_file_outlined,
                                  size: 16, color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showEmployeeSheet(null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 16, color: Color(0xFF1A0A00)),
                        SizedBox(width: 4),
                        Text(
                          'Tambah',
                          style: TextStyle(
                            color: Color(0xFF1A0A00),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── SEARCH BAR + BADGE MANAGEMENT ─────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari nama atau jabatan...',
                prefixIcon: const Icon(Icons.search,
                    size: 20, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8F5F0),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 10),
                // Badge management button — compact circle
                GestureDetector(
                  onTap: _openBadgeManagement,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.18)),
                    ),
                    child: const Icon(Icons.workspace_premium,
                        size: 20, color: Color(0xFFF59E0B)),
                  ),
                ),
              ],
            ),
          ),

          // ── OUTLET FILTER CHIPS ──────────────────────────────────────────
          if (_outlets.isNotEmpty)
            Builder(builder: (context) {
              final isKepalaGerai = ref.watch(appProvider).isKepalaGerai;
              return Container(
                color: Colors.white,
                child: Column(
                  children: [
                    const Divider(
                        height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                    SizedBox(
                      height: 48,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        scrollDirection: Axis.horizontal,
                        children: [
                          // "Semua" chip hanya tampil untuk admin penuh
                          if (!isKepalaGerai)
                            _FilterChip2(
                              label: 'Semua',
                              selected: _filterOutletId == null,
                              onTap: () =>
                                  setState(() => _filterOutletId = null),
                            ),
                          ..._outlets.map((o) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _FilterChip2(
                                  label: o.name,
                                  selected: _filterOutletId == o.id,
                                  // Kepala gerai tidak bisa ganti filter outlet
                                  onTap: isKepalaGerai
                                      ? null
                                      : () => setState(
                                          () => _filterOutletId = o.id),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

          // ── LIST ─────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? _buildEmployeeListShimmer()
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _loadData,
                    child: filtered.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(
                                height: 300,
                                child: AppEmptyState(
                                  icon: Icons.people_outline,
                                  heading: 'Belum Ada Karyawan',
                                  subtext: 'Tambahkan karyawan untuk memulai',
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final emp = filtered[i];
                              final outletName = _outlets
                                  .where((o) => o.id == emp.homeOutletId)
                                  .map((o) => o.name)
                                  .firstOrNull;
                              return _EmployeeCard(
                                employee: emp,
                                outletName: outletName,
                                onEdit: () => _showEmployeeSheet(emp),
                                onAssignNfc: () => _showAssignNfcDialog(emp),
                                onSakitIzin: () => _showSakitIzinDialog(emp),
                                onSakitIzinHistory: () => _showSakitIzinHistory(emp),
                                onAssignBadge: () => _showBadgePicker(emp),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Archive confirmation dialog
// ---------------------------------------------------------------------------

class _ArchiveConfirmDialog extends StatelessWidget {
  final String employeeName;
  final int upcomingShifts;

  const _ArchiveConfirmDialog({
    required this.employeeName,
    required this.upcomingShifts,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.archive_outlined,
                color: AppColors.danger, size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Arsipkan Karyawan?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Karyawan "$employeeName" akan dipindahkan ke arsip.',
            style:
                const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (upcomingShifts > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$upcomingShifts jadwal mendatang akan dihapus',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Karyawan tidak akan bisa absen via NFC. Riwayat absensi tetap tersimpan.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child:
              const Text('Arsipkan', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mini stat pill
// ---------------------------------------------------------------------------

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Employee Card
// ---------------------------------------------------------------------------

class _EmployeeCard extends StatelessWidget {
  final Employee employee;
  final String? outletName;
  final VoidCallback onEdit;
  final VoidCallback onAssignNfc;
  final VoidCallback onSakitIzin;
  final VoidCallback onSakitIzinHistory;
  final VoidCallback onAssignBadge;

  const _EmployeeCard({
    required this.employee,
    required this.outletName,
    required this.onEdit,
    required this.onAssignNfc,
    required this.onSakitIzin,
    required this.onSakitIzinHistory,
    required this.onAssignBadge,
  });

  @override
  Widget build(BuildContext context) {
    final hasNfc = employee.nfcUid != null;
    final isActive = employee.isActive;
    final badge = BadgeService.instance.getBadgeByIdSync(employee.activeBadgeId);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          // Left color bar (red if active, gray if inactive)
          Container(
            width: 5,
            height: 80,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.textMuted,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),

          // Avatar circle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Stack(
              children: [
                BadgeAvatar(
                  photoUrl: employee.photoUrl,
                  name: employee.name,
                  size: 52,
                  badge: badge,
                ),
                // NFC badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: hasNfc ? AppColors.success : AppColors.textMuted,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      hasNfc ? Icons.nfc : Icons.nfc_outlined,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          employee.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: isActive
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Non-aktif',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
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
                  // Outlet info - tampilkan nama gerai atau "Belum punya gerai"
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.store_outlined,
                          size: 11,
                          color: outletName != null ? AppColors.textMuted : const Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        outletName ?? 'Belum punya gerai',
                        style: TextStyle(
                          fontSize: 11,
                          color: outletName != null ? AppColors.textMuted : const Color(0xFFD97706),
                          fontStyle: outletName != null ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // NFC Button (primary action)
                _ActionBtn(
                  icon: Icons.nfc,
                  color: hasNfc ? AppColors.success : AppColors.accent,
                  tooltip: hasNfc ? 'NFC Tersedia' : 'Assign NFC',
                  onTap: onAssignNfc,
                ),
                const SizedBox(width: 8),
                // More options menu (contains Edit, Sakit/Izin, Badge)
                PopupMenuButton<String>(
                  offset: const Offset(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'sakit_izin') {
                      onSakitIzin();
                    } else if (value == 'sakit_izin_history') {
                      onSakitIzinHistory();
                    } else if (value == 'assign_badge') {
                      onAssignBadge();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 12),
                          const Text('Edit Karyawan'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'sakit_izin',
                      child: Row(
                        children: [
                          Icon(Icons.medical_services_outlined,
                              size: 18, color: const Color(0xFFDC2626)),
                          const SizedBox(width: 12),
                          const Text('Input Sakit/Izin'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'sakit_izin_history',
                      child: Row(
                        children: [
                          Icon(Icons.history,
                              size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          const Text('Riwayat Sakit/Izin'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'assign_badge',
                      child: Row(
                        children: [
                          Icon(Icons.workspace_premium_outlined,
                              size: 18, color: const Color(0xFFF59E0B)),
                          const SizedBox(width: 12),
                          const Text('Assign Badge'),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: Colors.grey.shade700,
                    ),
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

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip 2
// ---------------------------------------------------------------------------

class _FilterChip2 extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap; // nullable: null = chip non-interaktif (locked)

  const _FilterChip2({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF8F5F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Assign NFC Dialog
// ---------------------------------------------------------------------------

enum _NfcDialogState { waiting, scanning, success, error }

class _AssignNfcDialog extends StatefulWidget {
  final Employee employee;
  final VoidCallback onAssigned;

  const _AssignNfcDialog(
      {required this.employee, required this.onAssigned});

  @override
  State<_AssignNfcDialog> createState() => _AssignNfcDialogState();
}

class _AssignNfcDialogState extends State<_AssignNfcDialog> {
  _NfcDialogState _state = _NfcDialogState.waiting;
  String? _scannedUid;
  String? _errorMsg;
  void Function()? _nfcCleanup;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startNfc();
  }

  void _startNfc() {
    setState(() => _state = _NfcDialogState.scanning);
    _nfcCleanup = NfcService.startListener(
      (uid) async {
        if (_state != _NfcDialogState.scanning) return;
        if (mounted) {
          setState(() {
            _scannedUid = uid;
            _state = _NfcDialogState.waiting;
          });
        }
        _stopNfc();
      },
      (err) {
        if (mounted) {
          setState(() {
            _errorMsg = 'Gagal membaca kartu. Coba lagi.';
            _state = _NfcDialogState.error;
          });
        }
      },
    ) as void Function()?;
  }

  void _stopNfc() {
    final cleanup = _nfcCleanup;
    if (cleanup != null) {
      cleanup();
      _nfcCleanup = null;
    }
  }

  @override
  void dispose() {
    _stopNfc();
    super.dispose();
  }

  Future<void> _saveUid() async {
    if (_scannedUid == null) return;
    setState(() => _saving = true);

    try {
      await SupabaseClientFactory.admin
          .from('employees')
          .update({'nfc_uid': _scannedUid})
          .eq('id', widget.employee.id);

      if (mounted) {
        setState(() => _state = _NfcDialogState.success);
        widget.onAssigned();
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMsg = 'Gagal menyimpan ke database';
          _state = _NfcDialogState.error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.nfc, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Assign Kartu NFC',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ],
      ),
      content: SizedBox(
        width: 260,
        child: _buildContent(),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _NfcDialogState.scanning:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tempelkan kartu untuk\n${widget.employee.name}',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.contactless,
                  size: 52, color: AppColors.accent),
            ),
            const SizedBox(height: 12),
            const Text(
              'Menunggu kartu...',
              style: TextStyle(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const LinearProgressIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.accentLight,
            ),
          ],
        );

      case _NfcDialogState.waiting:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 48, color: AppColors.success),
            const SizedBox(height: 12),
            const Text('Kartu terdeteksi!',
                style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _scannedUid ?? '',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Simpan kartu ini untuk ${widget.employee.name}?',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        );

      case _NfcDialogState.success:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 56, color: AppColors.success),
            SizedBox(height: 12),
            Text(
              'Kartu berhasil disimpan!',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.success,
                fontSize: 16,
              ),
            ),
          ],
        );

      case _NfcDialogState.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              _errorMsg ?? 'Terjadi kesalahan',
              style: const TextStyle(color: AppColors.danger),
              textAlign: TextAlign.center,
            ),
          ],
        );
    }
  }

  List<Widget> _buildActions() {
    switch (_state) {
      case _NfcDialogState.scanning:
        return [
          TextButton(
            onPressed: () {
              _stopNfc();
              Navigator.of(context).pop();
            },
            child: const Text('Batal'),
          ),
        ];

      case _NfcDialogState.waiting:
        return [
          TextButton(
            onPressed: () {
              setState(() {
                _scannedUid = null;
                _state = _NfcDialogState.scanning;
              });
              _startNfc();
            },
            child: const Text('Scan Ulang'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            onPressed: _saving ? null : _saveUid,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Simpan'),
          ),
        ];

      case _NfcDialogState.success:
        return [];

      case _NfcDialogState.error:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _errorMsg = null;
                _state = _NfcDialogState.scanning;
              });
              _startNfc();
            },
            child: const Text('Coba Lagi'),
          ),
        ];
    }
  }
}

// ---------------------------------------------------------------------------
// Employee add/edit bottom sheet
// ---------------------------------------------------------------------------

class _EmployeeSheet extends StatefulWidget {
  final Employee? employee;
  final List<Outlet> outlets;
  final VoidCallback onSaved;
  /// Jika diisi, outlet dropdown akan di-lock ke nilai ini (untuk kepala_gerai)
  final String? forcedOutletId;

  const _EmployeeSheet({
    required this.employee,
    required this.outlets,
    required this.onSaved,
    this.forcedOutletId,
  });

  @override
  State<_EmployeeSheet> createState() => _EmployeeSheetState();
}

class _EmployeeSheetState extends State<_EmployeeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _positionCtrl;
  late final TextEditingController _empCodeCtrl;
  String? _selectedOutletId;
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final emp = widget.employee;
    _nameCtrl = TextEditingController(text: emp?.name ?? '');
    _positionCtrl = TextEditingController(text: emp?.position ?? '');
    _empCodeCtrl = TextEditingController(text: emp?.employeeCode ?? '');
    // forcedOutletId: kepala_gerai yang tambah karyawan baru → auto-set outlet mereka
    _selectedOutletId = widget.forcedOutletId ??
        emp?.homeOutletId ??
        widget.outlets.firstOrNull?.id;
    _isActive = emp?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _positionCtrl.dispose();
    _empCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'position': _positionCtrl.text.trim().isEmpty
            ? null
            : _positionCtrl.text.trim(),
        'employee_code': _empCodeCtrl.text.trim().isEmpty
            ? null
            : _empCodeCtrl.text.trim(),
        'home_outlet_id': _selectedOutletId,
        'is_active': _isActive,
      };

      if (widget.employee == null) {
        await SupabaseClientFactory.admin.from('employees').insert(payload);
      } else {
        await SupabaseClientFactory.admin
            .from('employees')
            .update(payload)
            .eq('id', widget.employee!.id);
      }

      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal menyimpan data karyawan';
          _saving = false;
        });
      }
    }
  }

  Future<void> _archiveEmployee() async {
    if (widget.employee == null) return;

    // Count upcoming shifts
    final today = DateTime.now().toIso8601String().split('T')[0];
    final upcomingData = await SupabaseClientFactory.admin
        .from('schedule_entries')
        .select('id')
        .eq('employee_id', widget.employee!.id)
        .gte('date', today);
    final upcomingShifts = (upcomingData as List).length;

    // Show confirmation dialog
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ArchiveConfirmDialog(
        employeeName: widget.employee!.name,
        upcomingShifts: upcomingShifts,
      ),
    );

    if (confirmed != true) return;

    // Execute archive
    setState(() => _saving = true);
    try {
      // Update employee record
      await SupabaseClientFactory.admin
          .from('employees')
          .update({
            'is_active': false,
            'archived_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.employee!.id);

      // Delete future schedule entries
      if (upcomingShifts > 0) {
        await SupabaseClientFactory.admin
            .from('schedule_entries')
            .delete()
            .eq('employee_id', widget.employee!.id)
            .gte('date', today);
      }

      // Close sheet and refresh list
      widget.onSaved();
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, 'Karyawan berhasil diarsipkan');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.error(context, 'Gagal mengarsipkan karyawan');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.employee != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 2 yellow lines at top of sheet
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit_outlined : Icons.person_add_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isEdit ? 'Edit Karyawan' : 'Tambah Karyawan',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nama Lengkap',
                            prefixIcon:
                                Icon(Icons.person_outline, size: 20),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Nama wajib diisi';
                            if (v.trim().length < 3) return 'Nama minimal 3 karakter';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _positionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Jabatan / Posisi (opsional)',
                            prefixIcon: Icon(Icons.work_outline, size: 20),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _empCodeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Kode Karyawan (opsional)',
                            prefixIcon:
                                Icon(Icons.badge_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 14),

                        DropdownButtonFormField<String>(
                          value: _selectedOutletId,
                          decoration: InputDecoration(
                            labelText: 'Outlet',
                            prefixIcon:
                                const Icon(Icons.store_outlined, size: 20),
                            // Tunjukkan lock icon jika outlet dikunci (kepala_gerai)
                            suffixIcon: widget.forcedOutletId != null
                                ? const Icon(Icons.lock_outline,
                                    size: 16, color: Colors.grey)
                                : null,
                          ),
                          items: widget.outlets
                              .map((o) => DropdownMenuItem(
                                    value: o.id,
                                    child: Text(o.name),
                                  ))
                              .toList(),
                          // null = read-only (kepala_gerai tidak bisa ganti outlet)
                          onChanged: widget.forcedOutletId != null
                              ? null
                              : (v) => setState(() => _selectedOutletId = v),
                        ),
                        const SizedBox(height: 14),

                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            title: const Text(
                              'Karyawan Aktif',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              'Dapat melakukan absensi',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _isActive,
                            onChanged: (v) =>
                                setState(() => _isActive = v),
                            activeColor: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.danger.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: AppColors.danger, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isEdit
                            ? AppColors.primary
                            : AppColors.accent,
                        foregroundColor: isEdit
                            ? Colors.white
                            : const Color(0xFF1A0A00),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: isEdit
                                      ? Colors.white
                                      : const Color(0xFF1A0A00)),
                            )
                          : Text(
                              isEdit ? 'Simpan Perubahan' : '+ Tambah Karyawan',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),

                  // Archive section (only for existing employees, not create mode)
                  if (isEdit)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1, thickness: 1),
                          const SizedBox(height: 16),
                          const Text(
                            'ZONA BERBAHAYA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _archiveEmployee,
                              icon: const Icon(Icons.archive_outlined, size: 18),
                              label: const Text('Arsipkan Karyawan'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(color: AppColors.danger),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Karyawan akan dipindahkan ke arsip dan tidak bisa absen via NFC. Riwayat absensi tetap tersimpan.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
