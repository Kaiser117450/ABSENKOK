import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/providers/app_provider.dart';
import 'package:absensi_enakko_flutter/screens/kiosk/kiosk_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KioskScanScreen streak display', () {
    Future<void> pumpSuccessScreen(
      WidgetTester tester, {
      required AttendanceType submittedType,
      required int currentStreak,
      int? milestoneCelebration,
    }) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appProvider.notifier).setDetectedEmployee(
            const Employee(
              id: 'emp-1',
              name: 'Ayu',
              isActive: true,
              createdAt: '2026-03-01T00:00:00.000Z',
              updatedAt: '2026-03-01T00:00:00.000Z',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: KioskScanScreen.testable(
              debugSuccessState: KioskScanSuccessDebugState(
                submittedType: submittedType,
                currentStreak: currentStreak,
                milestoneCelebration: milestoneCelebration,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows streak count when streak >= 2 after masuk scan', (
      tester,
    ) async {
      await pumpSuccessScreen(
        tester,
        submittedType: AttendanceType.masuk,
        currentStreak: 2,
      );

      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      expect(find.text('2 hari berturut-turut!'), findsOneWidget);
    });

    testWidgets('hides streak count when streak < 2', (tester) async {
      await pumpSuccessScreen(
        tester,
        submittedType: AttendanceType.masuk,
        currentStreak: 1,
      );

      expect(find.byIcon(Icons.local_fire_department), findsNothing);
      expect(find.textContaining('hari berturut-turut!'), findsNothing);
    });

    testWidgets('hides streak count for pulang scan type', (tester) async {
      await pumpSuccessScreen(
        tester,
        submittedType: AttendanceType.pulang,
        currentStreak: 7,
      );

      expect(find.byIcon(Icons.local_fire_department), findsNothing);
      expect(find.textContaining('Streak'), findsNothing);
    });

    testWidgets('shows milestone celebration text at 7-day streak', (
      tester,
    ) async {
      await pumpSuccessScreen(
        tester,
        submittedType: AttendanceType.masuk,
        currentStreak: 7,
        milestoneCelebration: 7,
      );

      expect(find.text('Streak 7 Hari!'), findsOneWidget);
    });

    testWidgets('shows milestone celebration text at 30-day streak', (
      tester,
    ) async {
      await pumpSuccessScreen(
        tester,
        submittedType: AttendanceType.masuk,
        currentStreak: 30,
        milestoneCelebration: 30,
      );

      expect(find.text('Streak 30 Hari!'), findsOneWidget);
    });

    testWidgets('shows special celebration text at 90-day streak', (
      tester,
    ) async {
      await pumpSuccessScreen(
        tester,
        submittedType: AttendanceType.masuk,
        currentStreak: 90,
        milestoneCelebration: 90,
      );

      expect(find.text('Streak 90 Hari! Luar Biasa!'), findsOneWidget);
    });
  });
}
