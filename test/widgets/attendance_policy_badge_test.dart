import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/widgets/attendance_policy_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpBadge(
    WidgetTester tester, {
    required AttendancePolicyStatus status,
    required LateKind lateKind,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AttendancePolicyBadge(
              status: status,
              lateKind: lateKind,
            ),
          ),
        ),
      ),
    );
  }

  group('AttendancePolicyBadge', () {
    testWidgets('renders normal late badge', (tester) async {
      await pumpBadge(
        tester,
        status: AttendancePolicyStatus.hadir,
        lateKind: LateKind.normal,
      );

      expect(find.text('Terlambat'), findsOneWidget);
    });

    testWidgets('renders candidate break-first badge', (tester) async {
      await pumpBadge(
        tester,
        status: AttendancePolicyStatus.hadir,
        lateKind: LateKind.breakFirstEligible,
      );

      expect(find.text('Kandidat break-first'), findsOneWidget);
      expect(find.text('Break-first'), findsNothing);
    });

    testWidgets('renders confirmed break-first badge', (tester) async {
      await pumpBadge(
        tester,
        status: AttendancePolicyStatus.hadir,
        lateKind: LateKind.breakFirstConfirmed,
      );

      expect(find.text('Break-first'), findsOneWidget);
      expect(find.text('Kandidat break-first'), findsNothing);
    });

    testWidgets('renders no-show badge', (tester) async {
      await pumpBadge(
        tester,
        status: AttendancePolicyStatus.tidakHadir,
        lateKind: LateKind.none,
      );

      expect(find.text('Tidak hadir'), findsOneWidget);
    });

    testWidgets('renders current-day belum masuk badge', (tester) async {
      await pumpBadge(
        tester,
        status: AttendancePolicyStatus.belumMasuk,
        lateKind: LateKind.none,
      );

      expect(find.text('Belum masuk'), findsOneWidget);
    });
  });
}
