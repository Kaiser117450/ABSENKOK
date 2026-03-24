import 'package:absensi_enakko_flutter/services/streak_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreakService', () {
    group('StreakLeaderEntry.fromJson', () {
      test('parses employee streak data correctly', () {
        final entry = StreakLeaderEntry.fromJson({
          'employee_id': 'emp-1',
          'employee_name': 'Alice',
          'current_streak': 12,
          'longest_streak': 30,
        });

        expect(entry.employeeId, 'emp-1');
        expect(entry.employeeName, 'Alice');
        expect(entry.currentStreak, 12);
        expect(entry.longestStreak, 30);
      });

      test('handles missing employee_name gracefully', () {
        final entry = StreakLeaderEntry.fromJson({
          'employee_id': 'emp-2',
          'current_streak': 4,
          'longest_streak': 10,
        });

        expect(entry.employeeName, 'Unknown');
      });
    });

    group('buildStreakLeaderboard', () {
      test('returns top 5 entries ordered by current_streak descending', () {
        final entries = buildStreakLeaderboard([
          {
            'employee_id': 'emp-1',
            'current_streak': 3,
            'longest_streak': 8,
            'employees': {'name': 'Charlie'},
          },
          {
            'employee_id': 'emp-2',
            'current_streak': 15,
            'longest_streak': 20,
            'employees': {'name': 'Alice'},
          },
          {
            'employee_id': 'emp-3',
            'current_streak': 9,
            'longest_streak': 12,
            'employees': {'name': 'Bob'},
          },
          {
            'employee_id': 'emp-4',
            'current_streak': 30,
            'longest_streak': 30,
            'employees': {'name': 'Dina'},
          },
          {
            'employee_id': 'emp-5',
            'current_streak': 1,
            'longest_streak': 5,
            'employees': {'name': 'Eko'},
          },
          {
            'employee_id': 'emp-6',
            'current_streak': 22,
            'longest_streak': 25,
            'employees': {'name': 'Fajar'},
          },
        ]);

        expect(entries.map((entry) => entry.employeeName).toList(), [
          'Dina',
          'Fajar',
          'Alice',
          'Bob',
          'Charlie',
        ]);
      });
    });

    group('getLeaderboard', () {
      test('returns empty list when supabaseReady is false', () async {
        final entries = await StreakService.instance.getLeaderboard(
          outletId: 'outlet-1',
        );

        expect(entries, isEmpty);
      });
    });
  });
}
