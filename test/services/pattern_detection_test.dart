import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_enakko_flutter/services/pattern_detection_service.dart';

void main() {
  group('PatternDetection', () {
    group('computeMedian', () {
      test('odd count returns middle value', () {
        expect(
          computeMedian([480.0, 485.0, 490.0, 495.0, 500.0]),
          equals(490.0),
        );
      });

      test('even count returns average of two middle values', () {
        expect(computeMedian([480.0, 490.0]), equals(485.0));
      });

      test('single value returns that value', () {
        expect(computeMedian([100.0]), equals(100.0));
      });

      test('empty list returns 0', () {
        expect(computeMedian([]), equals(0.0));
      });
    });

    group('analyzePatterns', () {
      test('builds employee-day map from RPC data', () {
        final rpcData = [
          {
            'employee_id': 'emp-1',
            'employee_name': 'Budi',
            'day_of_week': 1,
            'median_seconds': 28800.0, // 08:00
            'data_points': 8,
          },
          {
            'employee_id': 'emp-1',
            'employee_name': 'Budi',
            'day_of_week': 2,
            'median_seconds': 29400.0, // 08:10
            'data_points': 6,
          },
        ];

        final result = analyzePatterns(rpcData);
        expect(result.containsKey('emp-1'), isTrue);
        expect(result['emp-1']![1], equals(28800.0));
        expect(result['emp-1']![2], equals(29400.0));
      });

      test('multiple employees are separated correctly', () {
        final rpcData = [
          {
            'employee_id': 'emp-1',
            'employee_name': 'Budi',
            'day_of_week': 1,
            'median_seconds': 28800.0,
            'data_points': 7,
          },
          {
            'employee_id': 'emp-2',
            'employee_name': 'Citra',
            'day_of_week': 1,
            'median_seconds': 30600.0, // 08:30
            'data_points': 5,
          },
        ];

        final result = analyzePatterns(rpcData);
        expect(result.keys.length, equals(2));
        expect(result['emp-1']![1], equals(28800.0));
        expect(result['emp-2']![1], equals(30600.0));
      });

      test('empty RPC data returns empty map', () {
        final result = analyzePatterns([]);
        expect(result.isEmpty, isTrue);
      });
    });

    group('isLate', () {
      test('returns true when arrival is more than 5 minutes after median', () {
        // 8:30 (30600s) vs median 8:25 (30300s) = 5 min exactly → NOT late (> 5, not >=)
        // Use 8:31 (30660s) vs 8:25 (30300s) = 6 min → late
        expect(isLate(30660.0, 30300.0), isTrue);
      });

      test('returns false when arrival is exactly 5 minutes after median', () {
        // Exactly 5 minutes (300 seconds) → NOT late (must be > 5)
        expect(isLate(30600.0, 30300.0), isFalse);
      });

      test('returns false when arrival is within 5 minutes of median', () {
        // 8:28 (30480s) vs 8:25 (30300s) = 3 min → not late
        expect(isLate(30480.0, 30300.0), isFalse);
      });

      test('returns false when no pattern exists (null median)', () {
        expect(isLate(30600.0, null), isFalse);
      });

      test('returns false when employee arrives early', () {
        // 8:20 (30000s) vs 8:25 (30300s) → early, not late
        expect(isLate(30000.0, 30300.0), isFalse);
      });
    });

    group('formatLateNotification', () {
      test('formats notification body correctly', () {
        expect(
          formatLateNotification('Budi', 12, 'Senin'),
          equals('Budi tiba 12 menit lebih lambat dari biasanya di Senin'),
        );
      });

      test('handles different employee names and days', () {
        expect(
          formatLateNotification('Citra', 7, 'Jumat'),
          equals('Citra tiba 7 menit lebih lambat dari biasanya di Jumat'),
        );
      });
    });
  });
}
