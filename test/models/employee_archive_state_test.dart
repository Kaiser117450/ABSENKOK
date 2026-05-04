import 'package:absensi_enakko_flutter/models/employee_archive_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildEmployeeArchiveStatePayload', () {
    test('clears archived_at when employee is active', () {
      final payload = buildEmployeeArchiveStatePayload(
        isActive: true,
        existingArchivedAt: DateTime.utc(2026, 4, 28, 10),
        archivedAtWhenInactive: DateTime.utc(2026, 5, 4, 8),
      );

      expect(payload, {
        'is_active': true,
        'archived_at': null,
      });
    });

    test('sets archived_at when employee is saved as inactive', () {
      final archivedAt = DateTime.utc(2026, 5, 4, 8, 30);

      final payload = buildEmployeeArchiveStatePayload(
        isActive: false,
        archivedAtWhenInactive: archivedAt,
      );

      expect(payload, {
        'is_active': false,
        'archived_at': archivedAt.toIso8601String(),
      });
    });

    test('preserves existing archived_at for already archived employees', () {
      final existingArchivedAt = DateTime.utc(2026, 4, 28, 12);

      final payload = buildEmployeeArchiveStatePayload(
        isActive: false,
        existingArchivedAt: existingArchivedAt,
        archivedAtWhenInactive: DateTime.utc(2026, 5, 4, 8, 30),
      );

      expect(payload, {
        'is_active': false,
        'archived_at': existingArchivedAt.toIso8601String(),
      });
    });
  });
}
