import 'package:supabase_flutter/supabase_flutter.dart';

enum CreateAdminAccountRole {
  kepalaGerai,
  areaSupervisor,
  qc,
}

extension CreateAdminAccountRoleX on CreateAdminAccountRole {
  String get value => switch (this) {
        CreateAdminAccountRole.kepalaGerai => 'kepala_gerai',
        CreateAdminAccountRole.areaSupervisor => 'area_supervisor',
        CreateAdminAccountRole.qc => 'qc',
      };

  String get label => switch (this) {
        CreateAdminAccountRole.kepalaGerai => 'Kepala Gerai',
        CreateAdminAccountRole.areaSupervisor => 'Area Supervisor',
        CreateAdminAccountRole.qc => 'QC Grooming',
      };

  /// QC and area supervisors may cover more than one outlet; a kepala gerai
  /// is bound to exactly one.
  bool get allowsMultipleOutlets => this != CreateAdminAccountRole.kepalaGerai;
}

CreateAdminAccountRole _roleFromValue(String? value) => switch (value) {
      'area_supervisor' => CreateAdminAccountRole.areaSupervisor,
      'qc' => CreateAdminAccountRole.qc,
      _ => CreateAdminAccountRole.kepalaGerai,
    };

/// Result model for admin user creation
class CreateUserResult {
  final String userId;
  final String email;
  final String name;
  final CreateAdminAccountRole role;
  final String outletId;
  final List<String> outletIds;
  final String password;
  final String createdAt;

  const CreateUserResult({
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    required this.outletId,
    required this.outletIds,
    required this.password,
    required this.createdAt,
  });

  factory CreateUserResult.fromJson(Map<String, dynamic> json) {
    final roleValue = json['role'] as String? ?? 'kepala_gerai';
    final outletIdsRaw = json['outlet_ids'];
    final outletIds = outletIdsRaw is List
        ? outletIdsRaw.whereType<String>().toList(growable: false)
        : <String>[];
    final outletId = json['outlet_id'] as String? ??
        (outletIds.isEmpty ? '' : outletIds.first);

    return CreateUserResult(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: _roleFromValue(roleValue),
      outletId: outletId,
      outletIds: outletIds.isEmpty ? <String>[outletId] : outletIds,
      password: json['password'] as String,
      createdAt: json['created_at'] as String,
    );
  }
}

/// Service for admin onboarding operations.
/// Uses Supabase Edge Function for secure server-side user creation.
/// The service_role key NEVER touches the Flutter app.
class AdminOnboardingService {
  AdminOnboardingService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Creates a new scoped admin user account via Edge Function.
  ///
  /// [name] — full name of the new user
  /// [email] — email address for login
  /// [role] — account type to create
  /// [outletIds] — UUIDs of outlets to assign
  ///
  /// Returns [CreateUserResult] with user details + generated password.
  /// Throws [Exception] with user-facing error message on failure.
  Future<CreateUserResult> createUser({
    required String name,
    required String email,
    required CreateAdminAccountRole role,
    required List<String> outletIds,
  }) async {
    final normalizedOutletIds = outletIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedOutletIds.isEmpty) {
      throw Exception('Minimal satu outlet harus dipilih');
    }

    // Refresh session to ensure JWT is fresh before calling Edge Function.
    // Stale/expired JWTs cause 401 "invalid JWT" at Supabase gateway level
    // (verify_jwt=true) before the function code even executes.
    try {
      await _client.auth.refreshSession();
    } catch (_) {
      // If refresh fails, proceed anyway — the existing token might still
      // be valid, and the Edge Function will return a clear 401 if not.
    }

    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'create-admin-user',
        body: {
          'email': email.trim().toLowerCase(),
          'name': name.trim(),
          'role': role.value,
          'outlet_id': normalizedOutletIds.first,
          'outlet_ids': normalizedOutletIds,
        },
      );
    } on FunctionException catch (e) {
      // FunctionException = transport-level error from Supabase SDK.
      // With verify_jwt=false on the gateway, this should be rare — most
      // errors come through as response.status != 200 instead.
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

    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] as String? ?? 'Gagal membuat akun');
    }

    return CreateUserResult.fromJson(data);
  }

  /// Fetches list of outlets for the dropdown.
  /// Returns list of maps with 'id' and 'name' keys.
  Future<List<Map<String, dynamic>>> getOutlets() async {
    final response =
        await _client.from('outlets').select('id, name').order('name');
    return List<Map<String, dynamic>>.from(response);
  }
}
