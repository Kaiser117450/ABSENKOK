import 'package:supabase_flutter/supabase_flutter.dart';

/// Result model for employee portal provisioning.
/// The password is NOT returned from the server — the admin supplies it and
/// stores it locally for handoff. The server confirms success with employee metadata.
class EmployeePortalProvisionResult {
  final String employeeId;
  final String employeeName;
  final String authUserId;
  final String createdAt;

  const EmployeePortalProvisionResult({
    required this.employeeId,
    required this.employeeName,
    required this.authUserId,
    required this.createdAt,
  });

  factory EmployeePortalProvisionResult.fromJson(Map<String, dynamic> json) {
    return EmployeePortalProvisionResult(
      employeeId: json['employee_id'] as String,
      employeeName: json['employee_name'] as String,
      authUserId: json['auth_user_id'] as String,
      createdAt: json['created_at'] as String,
    );
  }
}

/// Service for provisioning employee portal access.
/// Wraps the `provision-employee-portal-user` Edge Function.
/// The service_role key NEVER touches the Flutter app.
class EmployeePortalProvisioningService {
  EmployeePortalProvisioningService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Minimum password length enforced client-side before the network call.
  static const int minPasswordLength = 6;

  /// Provisions portal access for [employeeId] with the given [password].
  ///
  /// Throws [Exception] with a user-facing Indonesian message on:
  /// - blank or too-short password (client-side guard)
  /// - non-200 Edge Function responses
  /// - missing/malformed response data
  ///
  /// Returns [EmployeePortalProvisionResult] on success.
  Future<EmployeePortalProvisionResult> provisionAccess({
    required String employeeId,
    required String password,
  }) async {
    // Client-side guard — reject trivially bad passwords before hitting the network
    if (password.trim().isEmpty) {
      throw Exception('Password tidak boleh kosong');
    }
    if (password.length < minPasswordLength) {
      throw Exception('Password minimal $minPasswordLength karakter');
    }

    final response = await _client.functions.invoke(
      'provision-employee-portal-user',
      body: {
        'employee_id': employeeId,
        'password': password,
      },
    );

    if (response.status != 200) {
      final error = response.data is Map
          ? (response.data['error'] as String?) ?? 'Terjadi kesalahan server'
          : 'Terjadi kesalahan server. Hubungi tim teknis jika masalah berlanjut.';
      throw Exception(error);
    }

    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] as String? ?? 'Gagal membuat akses portal');
    }

    return EmployeePortalProvisionResult.fromJson(data);
  }
}
