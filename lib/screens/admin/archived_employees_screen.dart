import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:absensi_enakko_flutter/core/supabase_client.dart';
import 'package:absensi_enakko_flutter/core/theme.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/outlet.dart';
import 'package:absensi_enakko_flutter/providers/app_provider.dart';
import 'package:absensi_enakko_flutter/widgets/app_card.dart';
import 'package:absensi_enakko_flutter/widgets/app_empty_state.dart';
import 'package:absensi_enakko_flutter/widgets/app_toast.dart';
import 'package:absensi_enakko_flutter/widgets/employee_contract_badge.dart';
import 'package:absensi_enakko_flutter/widgets/shimmer_skeleton.dart';

class ArchivedEmployeesScreen extends ConsumerStatefulWidget {
  const ArchivedEmployeesScreen({super.key});

  @override
  ConsumerState<ArchivedEmployeesScreen> createState() =>
      _ArchivedEmployeesScreenState();
}

class _ArchivedEmployeesScreenState
    extends ConsumerState<ArchivedEmployeesScreen> {
  List<Employee> _archivedEmployees = [];
  List<Outlet> _outlets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final appState = ref.read(appProvider);
      final isScopedAdmin = appState.isScopedOutletAdmin;
      final scopedOutletIds = appState.scopedOutletIds;

      if (isScopedAdmin && scopedOutletIds.isEmpty) {
        if (mounted) {
          setState(() {
            _archivedEmployees = const <Employee>[];
            _outlets = const <Outlet>[];
            _loading = false;
          });
        }
        return;
      }

      // Query archived employees only
      var empFilter = SupabaseClientFactory.admin
          .from('employees')
          .select('*')
          .eq('is_active', false)
          .not('archived_at', 'is', null);
      if (isScopedAdmin) {
        empFilter = empFilter.inFilter('home_outlet_id', scopedOutletIds);
      }
      final empData = await empFilter.order('archived_at', ascending: false);

      // Load outlets for display
      var outFilter = SupabaseClientFactory.admin.from('outlets').select('*');
      if (isScopedAdmin) {
        outFilter = outFilter.inFilter('id', scopedOutletIds);
      }
      final outData = await outFilter.order('name');

      if (mounted) {
        setState(() {
          _archivedEmployees = (empData as List)
              .map((e) => Employee.fromJson(e as Map<String, dynamic>))
              .toList();
          _outlets = (outData as List)
              .map((e) => Outlet.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppToast.error(context, 'Gagal memuat data arsip');
      }
    }
  }

  Future<void> _restoreEmployee(Employee employee) async {
    try {
      final appState = ref.read(appProvider);
      final isScopedAdmin = appState.isScopedOutletAdmin;

      var updateFilter = SupabaseClientFactory.admin.from('employees').update({
        'is_active': true,
        'archived_at': null,
      }).eq('id', employee.id);
      if (isScopedAdmin) {
        if (!appState.canAccessOutlet(employee.homeOutletId)) {
          throw Exception('Outlet tidak diizinkan');
        }
        updateFilter =
            updateFilter.eq('home_outlet_id', employee.homeOutletId!);
      }
      await updateFilter;

      if (mounted) {
        AppToast.success(context, '${employee.name} berhasil dipulihkan');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Gagal memulihkan karyawan');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        title: const Text('Riwayat Karyawan'),
      ),
      body: _loading
          ? _buildShimmer()
          : _archivedEmployees.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(
                      height: 300,
                      child: AppEmptyState(
                        icon: Icons.archive_outlined,
                        heading: 'Belum Ada Karyawan Diarsipkan',
                        subtext: 'Karyawan yang diarsipkan akan muncul di sini',
                      ),
                    ),
                  ],
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _archivedEmployees.length,
                    itemBuilder: (context, i) {
                      final emp = _archivedEmployees[i];
                      final outletName = _outlets
                          .where((o) => o.id == emp.homeOutletId)
                          .map((o) => o.name)
                          .firstOrNull;
                      return _ArchivedEmployeeCard(
                        employee: emp,
                        outletName: outletName,
                        onRestore: () => _restoreEmployee(emp),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          5,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Row(
                children: const [
                  ShimmerSkeleton(width: 52, height: 52, borderRadius: 26),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerSkeleton(
                            width: 140, height: 14, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerSkeleton(
                            width: 100, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchivedEmployeeCard extends StatelessWidget {
  final Employee employee;
  final String? outletName;
  final VoidCallback onRestore;

  const _ArchivedEmployeeCard({
    required this.employee,
    required this.outletName,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.surfaceVariant,
            child: Text(
              employee.initial,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                EmployeeContractBadge(contract: employee.employmentContract),
                const SizedBox(height: 4),
                if (outletName != null)
                  Text(
                    outletName!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 4),
                if (employee.archivedAt != null)
                  Text(
                    'Diarsipkan ${DateFormat('d MMM yyyy', 'id_ID').format(employee.archivedAt!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),

          // Restore button
          ElevatedButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Pulihkan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
