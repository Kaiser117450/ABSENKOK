import '../core/supabase_client.dart';

/// An outlet manager login (kepala gerai or area supervisor) and the outlets
/// it currently manages (from auth.users.raw_app_meta_data).
class OutletManager {
  final String userId;
  final String email;
  final String role; // 'kepala_gerai' | 'area_supervisor'
  final String? managedOutletId;
  final List<String> managedOutletIds;

  const OutletManager({
    required this.userId,
    required this.email,
    required this.role,
    required this.managedOutletId,
    required this.managedOutletIds,
  });

  bool get isAreaSupervisor => role == 'area_supervisor';

  /// Effective outlet ids — falls back to the primary if the array is empty
  /// (older promotion scripts only set managed_outlet_id).
  List<String> get effectiveOutletIds {
    if (managedOutletIds.isNotEmpty) return managedOutletIds;
    if (managedOutletId != null && managedOutletId!.isNotEmpty) {
      return [managedOutletId!];
    }
    return const [];
  }

  factory OutletManager.fromRow(Map<String, dynamic> j) {
    final ids = (j['managed_outlet_ids'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    return OutletManager(
      userId: (j['user_id'] ?? '').toString(),
      email: (j['email'] ?? '-').toString(),
      role: (j['role'] ?? 'kepala_gerai').toString(),
      managedOutletId: j['managed_outlet_id']?.toString(),
      managedOutletIds: ids,
    );
  }
}

class OutletOption {
  final String id;
  final String name;
  final bool isActive;
  const OutletOption(
      {required this.id, required this.name, required this.isActive});

  factory OutletOption.fromRow(Map<String, dynamic> j) => OutletOption(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '-').toString(),
        isActive: j['is_active'] != false,
      );
}

class OutletManagerService {
  OutletManagerService._();
  static final OutletManagerService instance = OutletManagerService._();

  Future<List<OutletManager>> listManagers() async {
    final res =
        await SupabaseClientFactory.admin.rpc('admin_list_outlet_managers');
    final list = (res as List?) ?? const [];
    return list
        .map((e) => OutletManager.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<List<OutletOption>> listOutlets() async {
    final res = await SupabaseClientFactory.admin
        .from('outlets')
        .select('id, name, is_active')
        .order('name');
    return (res as List)
        .map((e) => OutletOption.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<void> reassign({
    required String userId,
    required List<String> outletIds,
  }) async {
    await SupabaseClientFactory.admin.rpc('admin_reassign_outlet_manager',
        params: {'p_user_id': userId, 'p_outlet_ids': outletIds});
  }
}
