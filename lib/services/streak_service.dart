import 'package:flutter/foundation.dart';

import '../core/supabase_client.dart';
import '../main.dart' show supabaseReady;

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

/// A single entry in the streak leaderboard.
class StreakLeaderEntry {
  final String employeeId;
  final String employeeName;
  final int currentStreak;
  final int longestStreak;

  const StreakLeaderEntry({
    required this.employeeId,
    required this.employeeName,
    required this.currentStreak,
    required this.longestStreak,
  });

  factory StreakLeaderEntry.fromJson(Map<String, dynamic> json) =>
      StreakLeaderEntry(
        employeeId: json['employee_id'] as String,
        employeeName:
            json['employee_name'] as String? ?? json['name'] as String? ?? 'Unknown',
        currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
        longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// StreakService
// ─────────────────────────────────────────────────────────────────────────────

/// Streak service for attendance streak leaderboard and updates.
///
/// Calls Supabase queries/RPC for streak data.
/// All methods guard on [supabaseReady] and return null/empty on failure
/// (non-throwing pattern matching [AnalyticsService]).
class StreakService {
  StreakService._();
  static final instance = StreakService._();

  /// Get top N employees by current_streak for a given outlet.
  /// Returns empty list if [supabaseReady] is false or query fails.
  Future<List<StreakLeaderEntry>> getLeaderboard({
    required String outletId,
    int limit = 5,
  }) async {
    if (!supabaseReady) return [];
    try {
      final data = await SupabaseClientFactory.admin
          .from('employee_streaks')
          .select('employee_id, current_streak, longest_streak, employees!inner(name)')
          .eq('employees.home_outlet_id', outletId)
          .gt('current_streak', 0)
          .order('current_streak', ascending: false)
          .limit(limit);
      return (data as List).map((e) {
        final empData = e['employees'] as Map<String, dynamic>?;
        return StreakLeaderEntry(
          employeeId: e['employee_id'] as String,
          employeeName: empData?['name'] as String? ?? 'Unknown',
          currentStreak: (e['current_streak'] as num?)?.toInt() ?? 0,
          longestStreak: (e['longest_streak'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('[StreakService] getLeaderboard failed: $e');
      return [];
    }
  }

  /// Call update_employee_streak RPC, returns {current_streak, longest_streak}.
  /// Returns null if [supabaseReady] is false or RPC fails.
  Future<Map<String, dynamic>?> updateStreak(String employeeId) async {
    if (!supabaseReady) return null;
    try {
      final result = await SupabaseClientFactory.admin.rpc(
        'update_employee_streak',
        params: {'p_employee_id': employeeId},
      );
      return result as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[StreakService] updateStreak failed: $e');
      return null;
    }
  }
}
