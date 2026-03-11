import 'package:absensi_enakko_flutter/services/live_content_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveContentProvider break detection', () {
    test('poll() with one employee having break log and no kembali → breakNames contains that employee', () async {
      final provider = LiveContentProvider(
        fetchLogs: (outletId) async => [
          {
            'employee_id': 'emp1',
            'type': 'masuk',
            'scanned_at': '2026-03-12T01:00:00Z',
            'employees': {'name': 'Budi'},
          },
          {
            'employee_id': 'emp1',
            'type': 'break',
            'scanned_at': '2026-03-12T04:00:00Z',
            'employees': {'name': 'Budi'},
          },
        ],
        fetchActiveCount: (outletId) async => 5,
      );

      await provider.poll('outlet1');

      expect(provider.hasActiveBreaks, isTrue);
      final text = provider.nextDisplayText();
      expect(text, contains('Budi'));
      expect(text, contains('istirahat'));
      expect(text, contains('🍽️'));
    });

    test('poll() with employee having break then kembali → breakNames is empty', () async {
      final provider = LiveContentProvider(
        fetchLogs: (outletId) async => [
          {
            'employee_id': 'emp1',
            'type': 'break',
            'scanned_at': '2026-03-12T04:00:00Z',
            'employees': {'name': 'Budi'},
          },
          {
            'employee_id': 'emp1',
            'type': 'kembali',
            'scanned_at': '2026-03-12T04:30:00Z',
            'employees': {'name': 'Budi'},
          },
        ],
        fetchActiveCount: (outletId) async => 5,
      );

      await provider.poll('outlet1');

      expect(provider.hasActiveBreaks, isFalse);
    });

    test('poll() with multiple employees on break → breakNames has all names', () async {
      final provider = LiveContentProvider(
        fetchLogs: (outletId) async => [
          {
            'employee_id': 'emp1',
            'type': 'break',
            'scanned_at': '2026-03-12T04:00:00Z',
            'employees': {'name': 'Budi'},
          },
          {
            'employee_id': 'emp2',
            'type': 'break',
            'scanned_at': '2026-03-12T04:05:00Z',
            'employees': {'name': 'Sari'},
          },
        ],
        fetchActiveCount: (outletId) async => 5,
      );

      await provider.poll('outlet1');

      expect(provider.hasActiveBreaks, isTrue);
      // Collect two calls to get both names
      final texts = <String>[
        provider.nextDisplayText(),
        provider.nextDisplayText(),
      ];
      expect(texts.any((t) => t.contains('Budi')), isTrue);
      expect(texts.any((t) => t.contains('Sari')), isTrue);
    });
  });

  group('LiveContentProvider nextDisplayText', () {
    test('when breakNames not empty → returns "🍽️ {name} istirahat" format', () async {
      final provider = LiveContentProvider(
        fetchLogs: (outletId) async => [
          {
            'employee_id': 'emp1',
            'type': 'break',
            'scanned_at': '2026-03-12T04:00:00Z',
            'employees': {'name': 'Budi'},
          },
        ],
        fetchActiveCount: (outletId) async => 5,
      );

      await provider.poll('outlet1');
      final text = provider.nextDisplayText();

      expect(text, '🍽️ Budi istirahat');
    });

    test('rotates through multiple break names on successive calls', () async {
      final provider = LiveContentProvider(
        fetchLogs: (outletId) async => [
          {
            'employee_id': 'emp1',
            'type': 'break',
            'scanned_at': '2026-03-12T04:00:00Z',
            'employees': {'name': 'Budi'},
          },
          {
            'employee_id': 'emp2',
            'type': 'break',
            'scanned_at': '2026-03-12T04:05:00Z',
            'employees': {'name': 'Sari'},
          },
          {
            'employee_id': 'emp3',
            'type': 'break',
            'scanned_at': '2026-03-12T04:10:00Z',
            'employees': {'name': 'Dewi'},
          },
        ],
        fetchActiveCount: (outletId) async => 5,
      );

      await provider.poll('outlet1');
      final first = provider.nextDisplayText();
      final second = provider.nextDisplayText();
      final third = provider.nextDisplayText();
      // Should cycle back
      final fourth = provider.nextDisplayText();

      // All three names should appear in the first three calls
      final names = [first, second, third];
      expect(names.any((t) => t.contains('Budi')), isTrue);
      expect(names.any((t) => t.contains('Sari')), isTrue);
      expect(names.any((t) => t.contains('Dewi')), isTrue);
      // Fourth should cycle back to first
      expect(fourth, first);
    });

    test('when no breaks → returns fun fact / motivational message', () async {
      final provider = LiveContentProvider(
        fetchLogs: (outletId) async => [
          {
            'employee_id': 'emp1',
            'type': 'masuk',
            'scanned_at': '2026-03-12T01:00:00Z',
            'employees': {'name': 'Budi'},
          },
        ],
        fetchActiveCount: (outletId) async => 5,
      );

      await provider.poll('outlet1');

      expect(provider.hasActiveBreaks, isFalse);
      final text = provider.nextDisplayText();
      // Should be a non-empty string (stat or motivational)
      expect(text, isNotEmpty);
      // Should NOT contain break format
      expect(text, isNot(contains('istirahat')));
    });

    test('in idle mode → interleaves live stats with motivational messages', () async {
      final provider = LiveContentProvider(
        fetchLogs: (outletId) async => [
          {
            'employee_id': 'emp1',
            'type': 'masuk',
            'scanned_at': '2026-03-12T01:00:00Z',
            'employees': {'name': 'Budi'},
          },
          {
            'employee_id': 'emp2',
            'type': 'masuk',
            'scanned_at': '2026-03-12T01:30:00Z',
            'employees': {'name': 'Sari'},
          },
        ],
        fetchActiveCount: (outletId) async => 5,
      );

      await provider.poll('outlet1');

      // Collect several display texts
      final texts = <String>[];
      for (int i = 0; i < 8; i++) {
        texts.add(provider.nextDisplayText());
      }

      // Should have both stat-like messages and motivational messages
      final hasStats = texts.any((t) => t.contains('hadir') || t.contains('%') || t.contains('pertama'));
      final hasMotivational = texts.any((t) =>
          t.contains('💪') || t.contains('🙏') || t.contains('🍯') || t.contains('⭐') || t.contains('🤝'));
      expect(hasStats, isTrue, reason: 'Should have at least one stat');
      expect(hasMotivational, isTrue, reason: 'Should have at least one motivational');
    });
  });

  group('LiveContentProvider hasActiveBreaks', () {
    test('true when breakNames not empty, false when empty', () async {
      final provider = LiveContentProvider(
        fetchLogs: (outletId) async => [
          {
            'employee_id': 'emp1',
            'type': 'break',
            'scanned_at': '2026-03-12T04:00:00Z',
            'employees': {'name': 'Budi'},
          },
        ],
        fetchActiveCount: (outletId) async => 5,
      );

      // Before polling — no breaks
      expect(provider.hasActiveBreaks, isFalse);

      await provider.poll('outlet1');
      expect(provider.hasActiveBreaks, isTrue);
    });
  });

  group('LiveContentProvider error handling', () {
    test('poll() error → keeps last cached data (does not clear breakNames)', () async {
      int callCount = 0;
      final provider = LiveContentProvider(
        fetchLogs: (outletId) async {
          callCount++;
          if (callCount == 1) {
            return [
              {
                'employee_id': 'emp1',
                'type': 'break',
                'scanned_at': '2026-03-12T04:00:00Z',
                'employees': {'name': 'Budi'},
              },
            ];
          }
          throw Exception('Network error');
        },
        fetchActiveCount: (outletId) async {
          if (callCount > 1) throw Exception('Network error');
          return 5;
        },
      );

      // First poll succeeds
      await provider.poll('outlet1');
      expect(provider.hasActiveBreaks, isTrue);

      // Second poll fails — should keep cached data
      await provider.poll('outlet1');
      expect(provider.hasActiveBreaks, isTrue);
      expect(provider.nextDisplayText(), contains('Budi'));
    });
  });

  group('LiveContentProvider fun facts computation', () {
    test('generates "Hari ini X/Y hadir 🎉" stat from masuk logs', () async {
      final provider = LiveContentProvider(
        fetchLogs: (outletId) async => [
          {
            'employee_id': 'emp1',
            'type': 'masuk',
            'scanned_at': '2026-03-12T01:00:00Z',
            'employees': {'name': 'Budi'},
          },
          {
            'employee_id': 'emp2',
            'type': 'masuk',
            'scanned_at': '2026-03-12T01:30:00Z',
            'employees': {'name': 'Sari'},
          },
        ],
        fetchActiveCount: (outletId) async => 5,
      );

      await provider.poll('outlet1');

      // Collect all fun facts by rotating
      final texts = <String>[];
      for (int i = 0; i < 10; i++) {
        texts.add(provider.nextDisplayText());
      }

      expect(texts.any((t) => t.contains('2/5 hadir') && t.contains('🎉')), isTrue,
          reason: 'Should have "Hari ini 2/5 hadir 🎉" stat');
    });

    test('generates "Kehadiran hari ini N% 📊" percentage stat', () async {
      final provider = LiveContentProvider(
        fetchLogs: (outletId) async => [
          {
            'employee_id': 'emp1',
            'type': 'masuk',
            'scanned_at': '2026-03-12T01:00:00Z',
            'employees': {'name': 'Budi'},
          },
          {
            'employee_id': 'emp2',
            'type': 'masuk',
            'scanned_at': '2026-03-12T01:30:00Z',
            'employees': {'name': 'Sari'},
          },
        ],
        fetchActiveCount: (outletId) async => 5,
      );

      await provider.poll('outlet1');

      final texts = <String>[];
      for (int i = 0; i < 10; i++) {
        texts.add(provider.nextDisplayText());
      }

      expect(texts.any((t) => t.contains('40%') && t.contains('📊')), isTrue,
          reason: 'Should have "Kehadiran hari ini 40% 📊" stat');
    });

    test('generates "{name} datang pertama {time} 🏆" earliest arrival stat', () async {
      final provider = LiveContentProvider(
        fetchLogs: (outletId) async => [
          {
            'employee_id': 'emp1',
            'type': 'masuk',
            'scanned_at': '2026-03-12T01:00:00Z',
            'employees': {'name': 'Budi'},
          },
          {
            'employee_id': 'emp2',
            'type': 'masuk',
            'scanned_at': '2026-03-12T02:30:00Z',
            'employees': {'name': 'Sari'},
          },
        ],
        fetchActiveCount: (outletId) async => 5,
      );

      await provider.poll('outlet1');

      final texts = <String>[];
      for (int i = 0; i < 10; i++) {
        texts.add(provider.nextDisplayText());
      }

      expect(texts.any((t) => t.contains('Budi') && t.contains('pertama') && t.contains('🏆')), isTrue,
          reason: 'Should have earliest arrival stat for Budi');
    });
  });
}
