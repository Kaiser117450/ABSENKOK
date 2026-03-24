import 'package:flutter/foundation.dart';

import '../core/supabase_client.dart';
import '../main.dart' show supabaseReady;

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

  factory StreakLeaderEntry.fromJson(Map<String, dynamic> json) {
    return StreakLeaderEntry(
      employeeId: json['employee_id'] as String,
      employeeName:
          json['employee_name'] as String? ?? json['name'] as String? ?? 'Unknown',
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
    );
  }
}

List<StreakLeaderEntry> buildStreakLeaderboard(
  List<dynamic> rows, {
  int limit = 5,
}) {
  final entries = rows.map((row) {
    final data = Map<String, dynamic>.from(row as Map);
    final employeeData = data['employees'];
    if (employeeData is Map<String, dynamic>) {
      data['employee_name'] ??= employeeData['name'];
    } else if (employeeData is Map) {
      data['employee_name'] ??= employeeData['name'];
    }
    return StreakLeaderEntry.fromJson(data);
  }).toList();

  entries.sort((a, b) => b.currentStreak.compareTo(a.currentStreak));
  return entries.take(limit).toList();
}

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
      return buildStreakLeaderboard(data as List, limit: limit);
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
