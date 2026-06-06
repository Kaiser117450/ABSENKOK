import 'package:supabase_flutter/supabase_flutter.dart';

/// A privileged app account (admin / kepala_gerai / area_supervisor / qc)
/// as returned by the `admin_list_app_users` RPC. Used by the admin
/// password-reset screen.
class AppUser {
  final String userId;
  final String email;
  final String name;
  final String role;
  final String? managedOutletId;
  final List<String> managedOutletIds;
  final bool mustChangePassword;

  const AppUser({
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    required this.managedOutletId,
    required this.managedOutletIds,
    required this.mustChangePassword,
  });

  bool get isAdmin => role == 'admin';

  String get roleLabel => switch (role) {
        'admin' => 'Admin',
        'kepala_gerai' => 'Kepala Gerai',
        'area_supervisor' => 'Area Supervisor',
        'qc' => 'QC Grooming',
        _ => role,
      };

  List<String> get effectiveOutletIds {
    if (managedOutletIds.isNotEmpty) return managedOutletIds;
    final id = managedOutletId;
    if (id != null && id.isNotEmpty) return [id];
    return const [];
  }

  factory AppUser.fromRow(Map<String, dynamic> j) {
    final ids = (j['managed_outlet_ids'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final rawName = (j['name'] ?? '').toString().trim();
    final email = (j['email'] ?? '-').toString();
    return AppUser(
      userId: (j['user_id'] ?? '').toString(),
      email: email,
      name: rawName.isEmpty ? email : rawName,
      role: (j['role'] ?? '').toString(),
      managedOutletId: j['managed_outlet_id']?.toString(),
      managedOutletIds: ids,
      mustChangePassword: j['must_change_password'] == true,
    );
  }
}

/// Result of an admin-driven password reset. The temporary password is
/// returned exactly once and must be relayed to the user immediately.
class ResetPasswordResult {
  final String userId;
  final String email;
  final String temporaryPassword;

  const ResetPasswordResult({
    required this.userId,
    required this.email,
    required this.temporaryPassword,
  });

  factory ResetPasswordResult.fromJson(Map<String, dynamic> j) =>
      ResetPasswordResult(
        userId: (j['user_id'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        temporaryPassword: (j['password'] ?? '').toString(),
      );
}

/// Admin-only user management: list privileged accounts and reset their
/// passwords. The actual password change runs server-side in the
/// `reset-user-password` Edge Function (service_role never touches the app).
class AdminUserService {
  AdminUserService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Lists all privileged accounts (admin, kepala_gerai, area_supervisor, qc).
  /// Server-side guard: only an admin caller succeeds.
  Future<List<AppUser>> listAppUsers() async {
    final res = await _client.rpc('admin_list_app_users');
    final list = (res as List?) ?? const [];
    return list
        .map((e) => AppUser.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  /// Resets [userId]'s password to a freshly generated temporary one and
  /// forces a change on next login. Returns the temporary password (shown
  /// once). Throws [Exception] with a user-facing message on failure.
  Future<ResetPasswordResult> resetPassword(String userId) async {
    // Refresh the JWT so the Edge Function's getUser(token) sees a fresh,
    // un-expired token (mirrors AdminOnboardingService.createUser).
    try {
      await _client.auth.refreshSession();
    } catch (_) {
      // Proceed anyway — the function returns a clear 401 if the token is bad.
    }

    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'reset-user-password',
        body: {'user_id': userId},
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final msg =
          details is Map ? (details['message'] ?? details['error']) : null;
      throw Exception(
        msg ?? 'Terjadi kesalahan koneksi ke server (status ${e.status})',
      );
    }

    if (response.status != 200) {
      final error = response.data is Map
          ? (response.data['error'] as String?) ?? 'Terjadi kesalahan server'
          : 'Terjadi kesalahan server. Hubungi tim teknis jika masalah berlanjut.';
      throw Exception(error);
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['success'] != true) {
      throw Exception(data['error'] as String? ?? 'Gagal mereset password');
    }
    return ResetPasswordResult.fromJson(data);
  }
}
