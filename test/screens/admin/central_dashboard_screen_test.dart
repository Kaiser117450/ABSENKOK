import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/screens/admin/central_dashboard_screen.dart';
import '../../../lib/services/analytics_service.dart';
import '../../../lib/widgets/outlet_control_card.dart';

void main() {
  // Fake data shared across tests
  const fakeSummary = CentralDashboardSummary(
    totalOutlets: 3,
    connectedDevices: 5,
    offlineDevices: 1,
    lowBatteryDevices: 2,
    pendingSyncDevices: 0,
    dailyAttendanceRate: 87.5,
  );

  final fakeRows = [
    const OutletControlCenterRow(
      outletId: 'outlet-a',
      outletName: 'Enakko Pusat',
      connectedDevices: 2,
      offlineDevices: 0,
      lowBatteryDevices: 1,
      pendingSyncDevices: 0,
      dailyAttendanceRate: 90.0,
    ),
    const OutletControlCenterRow(
      outletId: 'outlet-b',
      outletName: 'Enakko Cabang',
      connectedDevices: 3,
      offlineDevices: 1,
      lowBatteryDevices: 1,
      pendingSyncDevices: 0,
      dailyAttendanceRate: 85.0,
    ),
  ];

  Widget buildScreen({
    CentralDashboardSummary? summary = fakeSummary,
    List<OutletControlCenterRow>? rows,
    void Function(String outletId)? onOpenOutlet,
    bool loading = false,
  }) {
    return MaterialApp(
      home: CentralDashboardScreen.injected(
        summaryLoader: () async => summary,
        rowsLoader: () async => rows ?? fakeRows,
        onOpenOutlet: onOpenOutlet,
      ),
    );
  }

  testWidgets('renders summary heading', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Ringkasan Jaringan'), findsOneWidget);
  });

  testWidgets('renders summary KPI cards', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Connected devices
    expect(find.text('5'), findsWidgets);
    // Offline devices
    expect(find.text('1'), findsWidgets);
    // Attendance rate
    expect(find.textContaining('87'), findsWidgets);
  });

  testWidgets('renders outlet rollup cards from injected rows', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Outlet cards may be below fold — scroll to ensure they are rendered
    await tester.scrollUntilVisible(
      find.text('Enakko Pusat'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Enakko Pusat'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Enakko Cabang'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Enakko Cabang'), findsOneWidget);
  });

  testWidgets('tapping outlet card calls onOpenOutlet with correct id',
      (tester) async {
    String? tappedId;
    await tester.pumpWidget(buildScreen(
      onOpenOutlet: (id) => tappedId = id,
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Enakko Pusat'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enakko Pusat'));
    await tester.pump();

    expect(tappedId, equals('outlet-a'));
  });

  testWidgets('shows empty state when no rows returned', (tester) async {
    await tester.pumpWidget(buildScreen(rows: []));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Tidak ada gerai aktif'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tidak ada gerai aktif'), findsOneWidget);
  });

  testWidgets('OutletControlCard displays outlet metrics', (tester) async {
    String? tappedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OutletControlCard(
            row: fakeRows.first,
            onTap: () => tappedId = fakeRows.first.outletId,
          ),
        ),
      ),
    );

    expect(find.text('Enakko Pusat'), findsOneWidget);
    await tester.tap(find.byType(OutletControlCard));
    await tester.pump();
    expect(tappedId, equals('outlet-a'));
  });
}
