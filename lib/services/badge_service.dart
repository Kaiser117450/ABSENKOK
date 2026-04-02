import 'package:flutter/foundation.dart';
import '../core/supabase_client.dart';
import '../models/employee_badge.dart';

/// Service for managing employee badges.
/// Loads all badge definitions from Supabase, caches in memory.
/// Badges table is small (<20 rows) so full cache is efficient.
class BadgeService {
  BadgeService._();
  static final instance = BadgeService._();

  /// In-memory cache: badge ID -> EmployeeBadge
  final Map<String, EmployeeBadge> _cache = {};
  bool _loaded = false;

  /// Fetch all badges from Supabase and populate cache.
  /// Call on first access or when admin modifies badges.
  Future<List<EmployeeBadge>> fetchAll({bool forceRefresh = false}) async {
    if (_loaded && !forceRefresh && _cache.isNotEmpty) {
      return _cache.values.toList();
    }

    try {
      final data = await SupabaseClientFactory.admin
          .from('badges')
          .select('*')
          .order('name');

      final badges = (data as List)
          .map((e) => EmployeeBadge.fromJson(e as Map<String, dynamic>))
          .toList();

      _cache.clear();
      for (final badge in badges) {
        _cache[badge.id] = badge;
      }
      _loaded = true;
      return badges;
    } catch (e) {
      debugPrint('[BadgeService] fetchAll failed: $e');
      // Return cached data if available, empty list otherwise
      return _cache.values.toList();
    }
  }

  /// Get a badge by ID from cache. Returns null if not found.
  /// Loads cache on first call if not loaded yet.
  Future<EmployeeBadge?> getBadgeById(String? badgeId) async {
    if (badgeId == null || badgeId.isEmpty) return null;

    if (!_loaded) {
      await fetchAll();
    }
    return _cache[badgeId];
  }

  /// Synchronous getter for badge by ID (from cache only).
  /// Returns null if cache not loaded or badge not found.
  EmployeeBadge? getBadgeByIdSync(String? badgeId) {
    if (badgeId == null || badgeId.isEmpty) return null;
    return _cache[badgeId];
  }

  /// Assign a badge to an employee.
  /// Updates employees.active_badge_id in Supabase.
  Future<void> assignBadge(String employeeId, String badgeId) async {
    await SupabaseClientFactory.admin
        .from('employees')
        .update({'active_badge_id': badgeId})
        .eq('id', employeeId);
  }

  /// Remove badge from an employee (set active_badge_id to null).
  Future<void> unassignBadge(String employeeId) async {
    await SupabaseClientFactory.admin
        .from('employees')
        .update({'active_badge_id': null})
        .eq('id', employeeId);
  }

  /// Create a new badge definition.
  Future<EmployeeBadge> createBadge({
    required String name,
    String? description,
    required String emoji,
    required String borderColor,
    String? borderColor2,
    required String borderStyle,
  }) async {
    final data = await SupabaseClientFactory.admin
        .from('badges')
        .insert({
          'name': name,
          'description': description,
          'emoji': emoji,
          'border_color': borderColor,
          'border_color2': borderColor2,
          'border_style': borderStyle,
        })
        .select()
        .single();

    final badge = EmployeeBadge.fromJson(data);
    _cache[badge.id] = badge;
    return badge;
  }

  /// Update an existing badge definition.
  Future<EmployeeBadge> updateBadge({
    required String id,
    required String name,
    String? description,
    required String emoji,
    required String borderColor,
    String? borderColor2,
    required String borderStyle,
  }) async {
    final data = await SupabaseClientFactory.admin
        .from('badges')
        .update({
          'name': name,
          'description': description,
          'emoji': emoji,
          'border_color': borderColor,
          'border_color2': borderColor2,
          'border_style': borderStyle,
        })
        .eq('id', id)
        .select()
        .single();

    final badge = EmployeeBadge.fromJson(data);
    _cache[badge.id] = badge;
    return badge;
  }

  /// Delete a badge definition.
  Future<void> deleteBadge(String badgeId) async {
    await SupabaseClientFactory.admin
        .from('badges')
        .delete()
        .eq('id', badgeId);

    _cache.remove(badgeId);
  }

  /// Check if any employees currently have this badge assigned.
  Future<int> getAssignedCount(String badgeId) async {
    final data = await SupabaseClientFactory.admin
        .from('employees')
        .select('id')
        .eq('active_badge_id', badgeId);
    return (data as List).length;
  }

  /// Clear the cache (call on logout/session reset).
  void clearCache() {
    _cache.clear();
    _loaded = false;
  }

  /// Whether cache has been loaded.
  bool get isLoaded => _loaded;
}
