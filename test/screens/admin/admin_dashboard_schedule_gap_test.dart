import 'package:absensi_enakko_flutter/models/schedule_gap_notice.dart';
import 'package:absensi_enakko_flutter/screens/admin/admin_dashboard_screen.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/admin_schedule_gap_notice_sheet.dart';
import 'package:absensi_enakko_flutter/services/schedule_gap_notice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ScheduleGapNoticeEntry buildEntry({
    required String employeeId,
    required String employeeName,
    required DateTime logicalDate,
    String outletId = 'outlet-1',
    String outletName = 'Outlet Utama',
  }) {
    return ScheduleGapNoticeEntry(
      employeeId: employeeId,
      employeeName: employeeName,
      outletId: outletId,
      outletName: outletName,
      logicalDate: logicalDate,
      statusLabel: kScheduleGapNoticeStatusLabel,
      helperText: kScheduleGapNoticeHelperText,
    );
  }

  Future<void> pumpQuickAction(
    WidgetTester tester, {
    required bool hasResolvedOutlet,
    required ScheduleGapNoticeResult notices,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AdminDashboardScheduleGapQuickAction(
              hasResolvedOutlet: hasResolvedOutlet,
              notices: notices,
              onTap: onTap ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpSheet(
    WidgetTester tester, {
    required ScheduleGapNoticeResult notices,
    required VoidCallback onOpenScheduler,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminScheduleGapNoticeSheet(
            notices: notices,
            onOpenScheduler: onOpenScheduler,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('admin dashboard schedule-gap notice widgets', () {
    test('AdminDashboardScreen stays constructible after notice wiring', () {
      expect(const AdminDashboardScreen(), isNotNull);
    });

    testWidgets('quick action renders with a count when notice entries exist',
        (tester) async {
      await pumpQuickAction(
        tester,
        hasResolvedOutlet: true,
        notices: ScheduleGapNoticeResult(
          entries: <ScheduleGapNoticeEntry>[
            buildEntry(
              employeeId: 'emp-1',
              employeeName: 'Ayu',
              logicalDate: DateTime(2026, 3, 31),
            ),
            buildEntry(
              employeeId: 'emp-2',
              employeeName: 'Budi',
              logicalDate: DateTime(2026, 3, 30),
            ),
          ],
        ),
      );

      expect(find.text('Jadwal\nKosong'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('quick action is hidden when notice entries are empty',
        (tester) async {
      await pumpQuickAction(
        tester,
        hasResolvedOutlet: true,
        notices: const ScheduleGapNoticeResult(
          entries: <ScheduleGapNoticeEntry>[],
        ),
      );

      expect(find.text('Jadwal\nKosong'), findsNothing);
    });

    testWidgets(
        'full admin without a selected outlet does not show the quick action',
        (tester) async {
      await pumpQuickAction(
        tester,
        hasResolvedOutlet: false,
        notices: ScheduleGapNoticeResult(
          entries: <ScheduleGapNoticeEntry>[
            buildEntry(
              employeeId: 'emp-1',
              employeeName: 'Ayu',
              logicalDate: DateTime(2026, 3, 31),
            ),
          ],
        ),
      );

      expect(find.text('Jadwal\nKosong'), findsNothing);
      expect(find.text('1'), findsNothing);
    });

    testWidgets(
        'kepala gerai scoped sheet content shows only the active outlet notice rows',
        (tester) async {
      await pumpSheet(
        tester,
        notices: ScheduleGapNoticeResult(
          entries: <ScheduleGapNoticeEntry>[
            buildEntry(
              employeeId: 'emp-1',
              employeeName: 'Ayu',
              logicalDate: DateTime(2026, 3, 31),
              outletName: 'Outlet Utama',
            ),
          ],
        ),
        onOpenScheduler: () {},
      );

      expect(find.textContaining('Outlet Utama'), findsOneWidget);
      expect(find.text('Outlet Cadangan'), findsNothing);
      expect(find.text(kScheduleGapNoticeHelperText), findsOneWidget);
    });

    testWidgets(
        'sheet shows Jadwal Kosong, locked helper copy, and Buka Jadwal',
        (tester) async {
      var openedScheduler = false;
      await pumpSheet(
        tester,
        notices: ScheduleGapNoticeResult(
          entries: <ScheduleGapNoticeEntry>[
            buildEntry(
              employeeId: 'emp-1',
              employeeName: 'Ayu',
              logicalDate: DateTime(2026, 3, 31),
            ),
          ],
        ),
        onOpenScheduler: () {
          openedScheduler = true;
        },
      );

      expect(find.text('Jadwal Kosong'), findsOneWidget);
      expect(find.text(kScheduleGapNoticeHelperText), findsOneWidget);
      expect(find.text('Buka Jadwal'), findsOneWidget);

      await tester.tap(find.text('Buka Jadwal'));
      await tester.pumpAndSettle();

      expect(openedScheduler, isTrue);
    });
  });
}
