import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:absensi_enakko_flutter/models/outlet_operating_mode.dart';
import 'package:absensi_enakko_flutter/widgets/outlet_mode_badge.dart';

void main() {
  group('OutletModeBadge', () {
    testWidgets('renders "Normal" label for OutletOperatingMode.normal',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OutletModeBadge(mode: OutletOperatingMode.normal),
          ),
        ),
      );

      expect(find.text('Normal'), findsOneWidget);
      // Should NOT show 24 Jam text
      expect(find.text('24 Jam'), findsNothing);
    });

    testWidgets(
        'renders "24 Jam" label for OutletOperatingMode.twentyFourHour',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OutletModeBadge(mode: OutletOperatingMode.twentyFourHour),
          ),
        ),
      );

      expect(find.text('24 Jam'), findsOneWidget);
      expect(find.text('Normal'), findsNothing);
    });

    testWidgets('uses typed enum, not raw DB strings', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OutletModeBadge(mode: OutletOperatingMode.normal),
          ),
        ),
      );

      // Should not contain raw DB values
      expect(find.text('NORMAL'), findsNothing);
      expect(find.text('TWENTY_FOUR_HOUR'), findsNothing);
    });

    testWidgets('is compact — fits in a Row alongside other widgets',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: const [
                Text('Outlet Name'),
                SizedBox(width: 6),
                OutletModeBadge(mode: OutletOperatingMode.twentyFourHour),
              ],
            ),
          ),
        ),
      );

      // Both should render without overflow
      expect(find.text('Outlet Name'), findsOneWidget);
      expect(find.text('24 Jam'), findsOneWidget);
    });
  });
}
