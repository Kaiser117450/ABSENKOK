import 'package:flutter_test/flutter_test.dart';

/// Wave 0 stubs for kiosk scan streak display (GAME-02)
/// These tests will FAIL until 25-02 modifies lib/screens/kiosk/kiosk_scan_screen.dart
void main() {
  group('KioskScanScreen streak display', () {
    test('shows streak count when streak >= 2 after masuk scan', () {
      // GAME-02: streak counter visible on kiosk scan result
      fail('WAVE 0 STUB: Streak display not yet added to KioskScanScreen');
    });

    test('hides streak count when streak < 2', () {
      // GAME-02: streak of 0 or 1 should not show fire icon
      fail('WAVE 0 STUB: Streak display not yet added to KioskScanScreen');
    });

    test('hides streak count for pulang scan type', () {
      // GAME-02: streak only shown for masuk, not pulang
      fail('WAVE 0 STUB: Streak display not yet added to KioskScanScreen');
    });

    test('shows milestone celebration text at 7-day streak', () {
      // GAME-03: milestone celebration text visible
      fail('WAVE 0 STUB: Streak display not yet added to KioskScanScreen');
    });

    test('shows milestone celebration text at 30-day streak', () {
      // GAME-03: 30-day milestone
      fail('WAVE 0 STUB: Streak display not yet added to KioskScanScreen');
    });

    test('shows special celebration text at 90-day streak', () {
      // GAME-03: 90-day milestone with "Luar Biasa!" text
      fail('WAVE 0 STUB: Streak display not yet added to KioskScanScreen');
    });
  });
}
