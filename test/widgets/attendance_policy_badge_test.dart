import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/widgets/attendance_policy_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPrimaryBadge(
    WidgetTester tester, {
    required AttendancePolicyPrimaryStatus primaryStatus,
    required AttendancePolicySeverity primarySeverity,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AttendancePolicyBadge(
              primaryStatus: primaryStatus,
              primarySeverity: primarySeverity,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpLegacyBadge(
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
    testWidgets('renders Kurang jam kerja badge', (tester) async {
      await pumpPrimaryBadge(
        tester,
        primaryStatus: AttendancePolicyPrimaryStatus.shortWork,
        primarySeverity: AttendancePolicySeverity.red,
      );

      expect(find.text('Kurang jam kerja'), findsOneWidget);
    });

    testWidgets('renders Istirahat berlebih badge', (tester) async {
      await pumpPrimaryBadge(
        tester,
        primaryStatus: AttendancePolicyPrimaryStatus.excessBreak,
        primarySeverity: AttendancePolicySeverity.red,
      );

      expect(find.text('Istirahat berlebih'), findsOneWidget);
    });

    testWidgets('renders Lembur badge', (tester) async {
      await pumpPrimaryBadge(
        tester,
        primaryStatus: AttendancePolicyPrimaryStatus.overtime,
        primarySeverity: AttendancePolicySeverity.yellow,
      );

      expect(find.text('Lembur'), findsOneWidget);
    });

    testWidgets('renders Manager exempt badge', (tester) async {
      await pumpPrimaryBadge(
        tester,
        primaryStatus: AttendancePolicyPrimaryStatus.exemptManager,
        primarySeverity: AttendancePolicySeverity.info,
      );

      expect(find.text('Manager exempt'), findsOneWidget);
    });

    testWidgets('renders Belum absen pulang badge', (tester) async {
      await pumpPrimaryBadge(
        tester,
        primaryStatus: AttendancePolicyPrimaryStatus.belumAbsenPulang,
        primarySeverity: AttendancePolicySeverity.red,
      );

      expect(find.text('Belum absen pulang'), findsOneWidget);
    });

    testWidgets('keeps legacy late rendering for old call sites',
        (tester) async {
      await pumpLegacyBadge(
        tester,
        status: AttendancePolicyStatus.hadir,
        lateKind: LateKind.normal,
      );

      expect(find.text('Terlambat'), findsOneWidget);
    });
  });
}
