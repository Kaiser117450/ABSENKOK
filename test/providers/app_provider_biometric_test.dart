import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:absensi_enakko_flutter/providers/app_provider.dart';
import 'package:absensi_enakko_flutter/core/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppState biometric fields', () {
    test('defaults to biometricEnabled=false', () {
      const state = AppState();
      expect(state.biometricEnabled, isFalse);
    });

    test('defaults to hasBiometricHardware=false', () {
      const state = AppState();
      expect(state.hasBiometricHardware, isFalse);
    });

    test('copyWith updates biometricEnabled', () {
      const state = AppState();
      final updated = state.copyWith(biometricEnabled: true);
      expect(updated.biometricEnabled, isTrue);
    });

    test('copyWith updates hasBiometricHardware', () {
      const state = AppState();
      final updated = state.copyWith(hasBiometricHardware: true);
      expect(updated.hasBiometricHardware, isTrue);
    });
  });

  group('AppNotifier biometric methods', () {
    test('setBiometricEnabled(true) saves to prefs and updates state',
        () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.rememberedUserRoleKey: 'admin',
        AppConstants.rememberedManagedOutletKey: 'outlet-1',
      });
      final notifier = AppNotifier();
      await notifier.setBiometricEnabled(true);
      expect(notifier.debugState.biometricEnabled, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppConstants.biometricEnabledKey), isTrue);
      expect(prefs.getString(AppConstants.rememberedUserRoleKey), isNull);
      expect(prefs.getString(AppConstants.rememberedManagedOutletKey), isNull);
    });

    test('setBiometricEnabled(false) clears remembered role', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.biometricEnabledKey: true,
        AppConstants.rememberedUserRoleKey: 'admin',
        AppConstants.rememberedManagedOutletKey: 'outlet-1',
      });
      final notifier = AppNotifier();
      await notifier.setBiometricEnabled(false);
      expect(notifier.debugState.biometricEnabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.rememberedUserRoleKey), isNull);
      expect(prefs.getString(AppConstants.rememberedManagedOutletKey), isNull);
    });

    test('clearLegacyRememberedAdminSession removes stored privilege keys',
        () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.biometricEnabledKey: true,
        AppConstants.rememberedUserRoleKey: 'kepala_gerai',
        AppConstants.rememberedManagedOutletKey: 'outlet-abc',
      });
      final notifier = AppNotifier();
      await notifier.clearLegacyRememberedAdminSession();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppConstants.biometricEnabledKey), isTrue);
      expect(prefs.getString(AppConstants.rememberedUserRoleKey), isNull);
      expect(prefs.getString(AppConstants.rememberedManagedOutletKey), isNull);
    });
  });
}
