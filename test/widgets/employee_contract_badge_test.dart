import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/widgets/employee_contract_badge.dart';

void main() {
  group('EmployeeContractBadge', () {
    testWidgets('renders Full-Time label for fulltime', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmployeeContractBadge(contract: EmployeeContract.fulltime),
          ),
        ),
      );

      expect(find.text('Full-Time'), findsOneWidget);
    });

    testWidgets('renders Part-Time label for parttime', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmployeeContractBadge(contract: EmployeeContract.parttime),
          ),
        ),
      );

      expect(find.text('Part-Time'), findsOneWidget);
    });

    testWidgets('does not render raw DB strings', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmployeeContractBadge(contract: EmployeeContract.fulltime),
          ),
        ),
      );

      expect(find.text('FULLTIME'), findsNothing);
      expect(find.text('PARTTIME'), findsNothing);
    });
  });
}
