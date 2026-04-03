import 'package:supabase_flutter/supabase_flutter.dart';

/// Result model for admin user creation
class CreateUserResult {
  final String userId;
  final String email;
  final String name;
  final String outletId;
  final String password;
  final String createdAt;

  const CreateUserResult({
    required this.userId,
    required this.email,
    required this.name,
    required this.outletId,
    required this.password,
    required this.createdAt,
  });

  factory CreateUserResult.fromJson(Map<String, dynamic> json) {
    return CreateUserResult(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      outletId: json['outlet_id'] as String,
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

  /// Creates a new Kepala Gerai user account via Edge Function.
  ///
  /// [name] — full name of the new user
  /// [email] — email address for login
  /// [outletId] — UUID of the outlet to assign
  ///
  /// Returns [CreateUserResult] with user details + generated password.
  /// Throws [Exception] with user-facing error message on failure.
  Future<CreateUserResult> createUser({
    required String name,
    required String email,
    required String outletId,
  }) async {
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
          'outlet_id': outletId,
        },
      );
    } on FunctionException catch (e) {
      // FunctionException with 401 = JWT rejected by Supabase gateway.
      // This means the session is invalid even after refresh attempt.
      final status = e.status;
      if (status == 401) {
        throw Exception(
          'Sesi login telah berakhir. Silakan logout dan login kembali.',
        );
      }
      final details = e.details;
      final msg = details is Map ? (details['message'] ?? details['error']) : null;
      throw Exception(msg ?? 'Terjadi kesalahan server (status $status)');
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
    final response = await _client
        .from('outlets')
        .select('id, name')
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }
}
