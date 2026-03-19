import 'package:flutter_test/flutter_test.dart';

/// Wave 0 stubs for StreakService (GAME-04: leaderboard top 5 by current_streak)
/// These tests will FAIL until 25-01 creates lib/services/streak_service.dart
void main() {
  group('StreakService', () {
    group('StreakLeaderEntry.fromJson', () {
      test('parses employee streak data correctly', () {
        // GAME-04: leaderboard entry deserialization
        // Will fail until StreakLeaderEntry class exists
        fail('WAVE 0 STUB: StreakLeaderEntry not yet implemented');
      });

      test('handles missing employee_name gracefully', () {
        // GAME-04: defensive parsing for null name
        fail('WAVE 0 STUB: StreakLeaderEntry not yet implemented');
      });
    });

    group('getLeaderboard', () {
      test('returns top 5 entries ordered by current_streak descending', () {
        // GAME-04: leaderboard ordering verification
        fail('WAVE 0 STUB: StreakService.getLeaderboard not yet implemented');
      });

      test('returns empty list when supabaseReady is false', () {
        // GAME-04: guard behavior
        fail('WAVE 0 STUB: StreakService.getLeaderboard not yet implemented');
      });
    });
  });
}
