import 'package:absensi_enakko_flutter/core/admin_session_claims.dart';
import 'package:absensi_enakko_flutter/providers/app_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppState scoped admin roles', () {
    test('area supervisor can access only assigned outlets', () {
      const state = AppState(
        isAreaSupervisor: true,
        managedOutletId: 'outlet-1',
        managedOutletIds: ['outlet-1', 'outlet-2'],
        isLoading: false,
      );

      expect(state.isAnyAdmin, isTrue);
      expect(state.isScopedOutletAdmin, isTrue);
      expect(state.primaryScopedOutletId, 'outlet-1');
      expect(state.canAccessOutlet('outlet-1'), isTrue);
      expect(state.canAccessOutlet('outlet-2'), isTrue);
      expect(state.canAccessOutlet('outlet-3'), isFalse);
      expect(state.canAccessOutlet(null), isFalse);
    });

    test('applyAdminSessionClaims maps area supervisor outlet list', () {
      final notifier = AppNotifier();

      notifier.applyAdminSessionClaims(
        AdminSessionClaims.areaSupervisor(['outlet-1', 'outlet-2']),
      );

      final state = notifier.state;
      expect(state.isAdmin, isFalse);
      expect(state.isKepalaGerai, isFalse);
      expect(state.isAreaSupervisor, isTrue);
      expect(state.managedOutletId, 'outlet-1');
      expect(state.managedOutletIds, ['outlet-1', 'outlet-2']);
    });
  });
}
