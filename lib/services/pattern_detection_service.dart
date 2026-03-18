import 'package:flutter/foundation.dart';

import '../core/supabase_client.dart';
import '../main.dart' show supabaseReady;

// ─────────────────────────────────────────────────────────────────────────────
// PatternDetectionService
// ─────────────────────────────────────────────────────────────────────────────

/// Pattern detection service for identifying late-arrival patterns.
///
/// Compares an employee's current scan time against their historical median
/// arrival time for the same day of week. If the employee arrives significantly
/// later than their usual pattern, an admin notification is triggered.
///
/// Phase 24 scope: checkAndNotifyIfLate is a no-op stub.
/// Full implementation is in Phase 24 Plan 03 (pattern detection + notifications).
class PatternDetectionService {
  PatternDetectionService._();
  static final instance = PatternDetectionService._();

  /// Check if the employee arrived late relative to their historical pattern,
  /// and notify admin if a late pattern is detected.
  ///
  /// Currently a no-op stub — full implementation in Phase 24 Plan 03.
  Future<void> checkAndNotifyIfLate({
    required String employeeId,
    required String outletId,
    required DateTime scanTime,
  }) async {
    if (!supabaseReady) return;
    // TODO(Phase 24 Plan 03): implement pattern detection via get_arrival_patterns RPC
    debugPrint('[PatternDetectionService] checkAndNotifyIfLate: stub — not yet implemented');
  }

  /// Fetch arrival patterns for all employees in an outlet.
  /// Returns a map of employeeId -> {dayOfWeek -> medianArrivalSecondsFromMidnight}.
  ///
  /// Returns empty map if [supabaseReady] is false or on error.
  Future<Map<String, Map<int, int>>> getArrivalPatterns({
    required String outletId,
    int days = 30,
  }) async {
    if (!supabaseReady) return {};
    try {
      final result = await SupabaseClientFactory.admin.rpc(
        'get_arrival_patterns',
        params: {
          'p_outlet_id': outletId,
          'p_days': days,
        },
      );
      if (result == null) return {};
      // Parse the RPC result: list of {employee_id, day_of_week, median_seconds}
      final patterns = <String, Map<int, int>>{};
      for (final row in (result as List)) {
        final empId = row['employee_id'] as String;
        final dayOfWeek = (row['day_of_week'] as num).toInt();
        final medianSeconds = (row['median_seconds'] as num).toInt();
        patterns.putIfAbsent(empId, () => {})[dayOfWeek] = medianSeconds;
      }
      return patterns;
    } catch (e) {
      debugPrint('[PatternDetectionService] getArrivalPatterns failed: $e');
      return {};
    }
  }
}
