import 'package:supabase_flutter/supabase_flutter.dart';

/// Factory for Supabase clients.
///
/// Auth model:
/// - Kiosk: uses anon key. Identity = outletId stored in SecureStorage.
///   Password was verified server-side via RPC [verify_kiosk_password] at
///   setup time — no per-device JWT needed.
/// - Admin: email/password auth via Supabase Auth (app_role = 'admin').
class SupabaseClientFactory {
  /// Shared Supabase client for all operations.
  static SupabaseClient get admin => Supabase.instance.client;
  static SupabaseClient get kiosk => Supabase.instance.client;
}
