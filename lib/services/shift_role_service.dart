import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shift_role.dart';

/// Fetches shift roles from Supabase with in-memory caching and offline fallback.
class ShiftRoleService {
  static List<ShiftRole>? _cachedRoles;

  /// Fetch all active roles from Supabase. Returns cached if available.
  static Future<List<ShiftRole>> getRoles({bool forceRefresh = false}) async {
    if (_cachedRoles != null && !forceRefresh) return _cachedRoles!;

    try {
      final response = await Supabase.instance.client
          .from('shift_roles')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      _cachedRoles = (response as List)
          .map((e) => ShiftRole.fromJson(e as Map<String, dynamic>))
          .toList();
      return _cachedRoles!;
    } catch (e) {
      debugPrint('[ShiftRoleService] Failed to fetch roles: $e');
      return ShiftRole.fallbackRoles;
    }
  }

  /// Get role name strings filtered by outlet operating mode.
  ///
  /// [outletOperatingMode] should be 'NORMAL' or 'TWENTY_FOUR_HOUR'.
  static Future<List<String>> getRoleNames({
    required String outletOperatingMode,
    bool forceRefresh = false,
  }) async {
    final roles = await getRoles(forceRefresh: forceRefresh);
    return roles
        .where((r) =>
            r.outletModeFilter == null ||
            r.outletModeFilter == outletOperatingMode)
        .map((r) => r.name)
        .toList();
  }

  /// Clear cache (call when navigating away or on manual refresh).
  static void clearCache() => _cachedRoles = null;
}
