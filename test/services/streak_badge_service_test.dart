import 'package:flutter_test/flutter_test.dart';

/// Wave 0 stubs for StreakBadgeService (GAME-02: milestone detection, GAME-03: auto-badge)
/// These tests will FAIL until 25-02 creates lib/services/streak_badge_service.dart
void main() {
  group('StreakBadgeService', () {
    group('checkAndAwardMilestone', () {
      test('returns 7 when currentStreak is exactly 7', () {
        // GAME-03: 7-day milestone detection
        fail('WAVE 0 STUB: StreakBadgeService not yet implemented');
      });

      test('returns 30 when currentStreak is exactly 30', () {
        // GAME-03: 30-day milestone detection
        fail('WAVE 0 STUB: StreakBadgeService not yet implemented');
      });

      test('returns 90 when currentStreak is exactly 90', () {
        // GAME-03: 90-day milestone detection
        fail('WAVE 0 STUB: StreakBadgeService not yet implemented');
      });

      test('returns null when currentStreak is not a milestone (e.g. 8)', () {
        // GAME-02: non-milestone streaks do not trigger badge
        fail('WAVE 0 STUB: StreakBadgeService not yet implemented');
      });

      test('returns null when currentStreak is 1 (below threshold)', () {
        // GAME-02: streak of 1 is not a milestone
        fail('WAVE 0 STUB: StreakBadgeService not yet implemented');
      });
    });
  });
}
