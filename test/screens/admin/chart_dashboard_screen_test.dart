import 'package:absensi_enakko_flutter/providers/app_provider.dart';
import 'package:absensi_enakko_flutter/screens/admin/chart_dashboard_screen.dart';
import 'package:absensi_enakko_flutter/services/analytics_service.dart';
import 'package:absensi_enakko_flutter/services/streak_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChartDashboardScreen', () {
    Future<void> pumpDashboard(
      WidgetTester tester, {
      required bool isAdmin,
    }) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      if (isAdmin) {
        container.read(appProvider.notifier).setAdminMode(true);
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChartDashboardScreen.testable(
              outletId: 'outlet-1',
              debugData: ChartDashboardDebugData(
                rateData: const AttendanceRateData(
                  totalEmployees: 12,
                  daysInRange: 7,
                  totalPresent: 70,
                  rate: 83.3,
                ),
                weeklyTrend: const [
                  {'date': '2026-03-16', 'count': 10},
                  {'date': '2026-03-17', 'count': 11},
                  {'date': '2026-03-18', 'count': 9},
                  {'date': '2026-03-19', 'count': 12},
                  {'date': '2026-03-20', 'count': 8},
                  {'date': '2026-03-21', 'count': 7},
                  {'date': '2026-03-22', 'count': 6},
                ],
                overtimeFlags: const [
                  OvertimeFlag(
                    employeeId: 'emp-1',
                    employeeName: 'Ayu',
                    hoursWorked: 9.5,
                    overtimeHours: 1.5,
                  ),
                ],
                leaderboard: const [
                  StreakLeaderEntry(
                    employeeId: 'emp-1',
                    employeeName: 'Ayu',
                    currentStreak: 15,
                    longestStreak: 20,
                  ),
                  StreakLeaderEntry(
                    employeeId: 'emp-2',
                    employeeName: 'Budi',
                    currentStreak: 12,
                    longestStreak: 18,
                  ),
                  StreakLeaderEntry(
                    employeeId: 'emp-3',
                    employeeName: 'Cici',
                    currentStreak: 10,
                    longestStreak: 16,
                  ),
                  StreakLeaderEntry(
                    employeeId: 'emp-4',
                    employeeName: 'Deni',
                    currentStreak: 8,
                    longestStreak: 11,
                  ),
                  StreakLeaderEntry(
                    employeeId: 'emp-5',
                    employeeName: 'Eka',
                    currentStreak: 7,
                    longestStreak: 9,
                  ),
                ],
                outletComparison: const [
                  {'outlet_name': 'Braga', 'rate': 88.4},
                  {'outlet_name': 'Dago', 'rate': 81.2},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> scrollToText(WidgetTester tester, String text) async {
      await tester.scrollUntilVisible(
        find.text(text),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    group('DASH-01: Dashboard sections', () {
      testWidgets('renders attendance donut chart section', (tester) async {
        await pumpDashboard(tester, isAdmin: false);

        expect(find.text('Ringkasan Kehadiran'), findsOneWidget);
        expect(find.byType(PieChart), findsOneWidget);
      });

      testWidgets('renders weekly trend bar chart section', (tester) async {
        await pumpDashboard(tester, isAdmin: false);

        expect(find.text('Tren Mingguan'), findsOneWidget);
        expect(find.text('Sen'), findsOneWidget);
      });

      testWidgets('renders overtime alerts section', (tester) async {
        await pumpDashboard(tester, isAdmin: false);
        await scrollToText(tester, 'Lembur Hari Ini');

        expect(find.text('Lembur Hari Ini'), findsOneWidget);
        expect(find.text('Ayu +2j'), findsOneWidget);
      });

      testWidgets('renders streak leaderboard section with top 5', (
        tester,
      ) async {
        await pumpDashboard(tester, isAdmin: false);
        await scrollToText(tester, 'Top 5 Streak Kehadiran');

        expect(find.text('Top 5 Streak Kehadiran'), findsOneWidget);
        expect(find.text('Eka'), findsOneWidget);
      });
    });

    group('DASH-02: fl_chart rendering', () {
      testWidgets('uses PieChart widget for attendance donut', (tester) async {
        await pumpDashboard(tester, isAdmin: false);

        expect(find.byType(PieChart), findsOneWidget);
      });

      testWidgets('uses BarChart widget for weekly trend', (tester) async {
        await pumpDashboard(tester, isAdmin: false);

        expect(find.byType(BarChart), findsOneWidget);
      });
    });

    group('DASH-03: Admin-only outlet comparison', () {
      testWidgets('shows outlet comparison section for admin role', (
        tester,
      ) async {
        await pumpDashboard(tester, isAdmin: true);
        await scrollToText(tester, 'Perbandingan Outlet');

        expect(find.text('Perbandingan Outlet'), findsOneWidget);
        expect(find.byType(BarChart), findsOneWidget);
        expect(find.text('Braga'), findsAtLeastNWidgets(1));
      });

      testWidgets('hides outlet comparison section for kepala_gerai role', (
        tester,
      ) async {
        await pumpDashboard(tester, isAdmin: false);

        expect(find.text('Perbandingan Outlet'), findsNothing);
        expect(find.byType(BarChart), findsOneWidget);
      });
    });

    group('DASH-04: Memory safety', () {
      testWidgets('uses AutomaticKeepAliveClientMixin', (tester) async {
        await pumpDashboard(tester, isAdmin: false);

        final state = tester.state(find.byType(ChartDashboardScreen));
        expect((state as dynamic).wantKeepAlive, isTrue);
      });
    });
  });
}
