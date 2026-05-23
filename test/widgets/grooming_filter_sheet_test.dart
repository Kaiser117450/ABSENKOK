import 'package:absensi_enakko_flutter/providers/grooming_filter_provider.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/grooming_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) =>
    ProviderScope(child: MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('reset clears outlet and query', (tester) async {
    await tester.pumpWidget(_wrap(GroomingFilterSheet(
      outlets: const [(id: 'o1', name: 'Bali'), (id: 'o2', name: 'Lombok')],
    )));
    await tester.tap(find.text('Bali'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'budi');
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('budi'), findsNothing);
  });

  testWidgets('Terapkan dispatches to filter provider', (tester) async {
    final container = ProviderContainer();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: GroomingFilterSheet(
            outlets: const [(id: 'o1', name: 'Bali')],
          ),
        ),
      ),
    ));
    await tester.tap(find.text('7 hari'));
    await tester.pump();
    await tester.tap(find.text('Bali'));
    await tester.pump();
    await tester.tap(find.text('Hanya butuh review'));
    await tester.pump();
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();
    final state = container.read(groomingFilterProvider);
    expect(state.outletIds.contains('o1'), isTrue);
    expect(state.needsReviewOnly, isTrue);
    expect(state.until.difference(state.since).inDays, lessThanOrEqualTo(7));
  });
}
