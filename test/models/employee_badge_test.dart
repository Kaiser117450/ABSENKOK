import 'package:absensi_enakko_flutter/models/employee_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmployeeBadge color parsing', () {
    test('returns fallback color for malformed 6-digit hex strings', () {
      final badge = EmployeeBadge(
        id: 'badge-1',
        name: 'Test',
        emoji: '⭐',
        borderColor: '#GGGGGG',
        borderStyle: 'solid',
      );

      expect(badge.color1, const Color(0xFF9CA3AF));
    });

    test('returns fallback color for malformed 8-digit hex strings', () {
      final badge = EmployeeBadge(
        id: 'badge-2',
        name: 'Test',
        emoji: '⭐',
        borderColor: '#ZZZZZZZZ',
        borderStyle: 'gradient',
      );

      expect(badge.color1, const Color(0xFF9CA3AF));
    });

    test('returns null color2 when optional color is empty', () {
      final badge = EmployeeBadge(
        id: 'badge-3',
        name: 'Test',
        emoji: '⭐',
        borderColor: '#9CA3AF',
        borderColor2: '',
        borderStyle: 'gradient',
      );

      expect(badge.color2, isNull);
    });
  });
}
