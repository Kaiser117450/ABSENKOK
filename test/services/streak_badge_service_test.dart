import 'package:absensi_enakko_flutter/services/streak_badge_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreakBadgeService', () {
    group('streakMilestoneFor', () {
      test('returns 7 when currentStreak is exactly 7', () {
        expect(streakMilestoneFor(7), 7);
      });

      test('returns 30 when currentStreak is exactly 30', () {
        expect(streakMilestoneFor(30), 30);
      });

      test('returns 90 when currentStreak is exactly 90', () {
        expect(streakMilestoneFor(90), 90);
      });

      test('returns null when currentStreak is not a milestone (e.g. 8)', () {
        expect(streakMilestoneFor(8), isNull);
      });

      test('returns null when currentStreak is 1 (below threshold)', () {
        expect(streakMilestoneFor(1), isNull);
      });
    });
  });
}
