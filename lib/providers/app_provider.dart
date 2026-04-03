import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/admin_session_claims.dart';
import '../core/constants.dart';
import '../models/employee.dart';
import '../models/kiosk_session.dart';
import '../services/biometric_service.dart';
import '../services/device_identity_service.dart';

/// Global application state — mirrors appStore.ts from React Native
class AppState {
  final KioskSession? kioskSession;
  final bool isAdmin;

  /// true jika user login dengan role 'kepala_gerai'
  final bool isKepalaGerai;

  /// true when the user must change their password before accessing dashboard.
  /// Set from app_metadata.must_change_password on first login.
  final bool mustChangePassword;

  /// outlet_id yang dikelola oleh kepala_gerai (null untuk admin / kiosk)
  final String? managedOutletId;
  final bool isLoading;
  final Employee? detectedEmployee; // Set after NFC tap on kiosk idle screen
  final int pendingCount; // Unsynced SQLite records count
  final bool isBackupMode; // true jika karyawan backup di gerai lain
  final String? backupNotes; // keterangan backup
  final String? backupOutletId; // outlet ID tempat backup
  final bool keepOverlayInForeground;
  final bool biometricEnabled;
  final bool hasBiometricHardware;

  const AppState({
    this.kioskSession,
    this.isAdmin = false,
    this.isKepalaGerai = false,
    this.mustChangePassword = false,
    this.managedOutletId,
    this.isLoading = true,
    this.detectedEmployee,
    this.pendingCount = 0,
    this.isBackupMode = false,
    this.backupNotes,
    this.backupOutletId,
    this.keepOverlayInForeground = false,
    this.biometricEnabled = false,
    this.hasBiometricHardware = false,
  });

  /// true jika user sedang login sebagai admin atau kepala gerai
  bool get isAnyAdmin => isAdmin || isKepalaGerai;

  AppState copyWith({
    KioskSession? kioskSession,
    bool clearKiosk = false,
    bool? isAdmin,
    bool? isKepalaGerai,
    bool? mustChangePassword,
    String? managedOutletId,
    bool clearManagedOutlet = false,
    bool? isLoading,
    Employee? detectedEmployee,
    bool clearEmployee = false,
    int? pendingCount,
    bool? isBackupMode,
    String? backupNotes,
    String? backupOutletId,
    bool? keepOverlayInForeground,
    bool? biometricEnabled,
    bool? hasBiometricHardware,
    bool clearBackup = false,
  }) =>
      AppState(
        kioskSession: clearKiosk ? null : (kioskSession ?? this.kioskSession),
        isAdmin: isAdmin ?? this.isAdmin,
        isKepalaGerai: isKepalaGerai ?? this.isKepalaGerai,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
        managedOutletId: clearManagedOutlet
            ? null
            : (managedOutletId ?? this.managedOutletId),
        isLoading: isLoading ?? this.isLoading,
        detectedEmployee:
            clearEmployee ? null : (detectedEmployee ?? this.detectedEmployee),
        pendingCount: pendingCount ?? this.pendingCount,
        isBackupMode: clearBackup ? false : (isBackupMode ?? this.isBackupMode),
        backupNotes: clearBackup ? null : (backupNotes ?? this.backupNotes),
        backupOutletId:
            clearBackup ? null : (backupOutletId ?? this.backupOutletId),
        keepOverlayInForeground:
            keepOverlayInForeground ?? this.keepOverlayInForeground,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        hasBiometricHardware: hasBiometricHardware ?? this.hasBiometricHardware,
      );
}

class AppNotifier extends StateNotifier<AppState> {
  AppNotifier() : super(const AppState());

  /// Load persisted kiosk session from SharedPreferences on app start.
  /// KioskSession hanya berisi outlet_id, outlet_name, device_id — bukan data sensitif,
  /// jadi SharedPreferences lebih tepat dan tidak menyebabkan ANR seperti SecureStorage.
  Future<void> loadSession() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();

      // Ensure persistent installation identity exists (Phase 31)
      await DeviceIdentityService.getOrCreateDeviceUuid();

      final raw = prefs.getString(AppConstants.kioskSessionKey);
      final keepOverlayInForeground =
          prefs.getBool(AppConstants.overlayKeepForegroundKey) ?? false;
      if (raw != null) {
        try {
          final session = KioskSession.fromJsonString(raw);
          state = state.copyWith(kioskSession: session);
        } catch (_) {
          // Data lama / korup — hapus agar tidak crash terus.
          await prefs.remove(AppConstants.kioskSessionKey);
        }
      }
      state = state.copyWith(
        keepOverlayInForeground: keepOverlayInForeground,
      );

      // Load biometric preference
      await loadBiometricPreference();
    } catch (_) {
      // SharedPreferences gagal — lanjut tanpa session
    } finally {
      // SELALU set isLoading: false agar app tidak stuck di splash screen
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> setKioskSession(KioskSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.kioskSessionKey, session.toJsonString());
    state = state.copyWith(kioskSession: session);
  }

  Future<void> clearKioskSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.kioskSessionKey);
    // Verify removal
    final verify = prefs.getString(AppConstants.kioskSessionKey);
    debugPrint(
        '[AppNotifier] clearKioskSession: removed key, verify=${verify == null ? "OK (null)" : "FAILED (still exists)"}');
    state = state.copyWith(clearKiosk: true);
    debugPrint(
        '[AppNotifier] clearKioskSession: state.kioskSession=${state.kioskSession}');
  }

  Future<void> setKeepOverlayInForeground(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.overlayKeepForegroundKey, value);
    state = state.copyWith(keepOverlayInForeground: value);
  }

  /// Safety-net: force isLoading = false if loadSession() ever gets stuck.
  void forceUnblockLoading() => state = state.copyWith(isLoading: false);

  void setAdminMode(bool isAdmin) => state = state.copyWith(isAdmin: isAdmin);

  void clearAdminSessionMode() {
    state = state.copyWith(
      isAdmin: false,
      isKepalaGerai: false,
      mustChangePassword: false,
      clearManagedOutlet: true,
    );
  }

  void applyAdminSessionClaims(AdminSessionClaims? claims, {bool mustChangePassword = false}) {
    if (claims == null) {
      clearAdminSessionMode();
      return;
    }

    if (claims.isAdmin) {
      state = state.copyWith(
        isAdmin: true,
        isKepalaGerai: false,
        mustChangePassword: mustChangePassword,
        clearManagedOutlet: true,
      );
      return;
    }

    state = state.copyWith(
      isAdmin: false,
      isKepalaGerai: true,
      mustChangePassword: mustChangePassword,
      managedOutletId: claims.managedOutletId,
    );
  }

  /// Set kepala_gerai mode: aktifkan flag + simpan outlet yang dikelola.
  /// Panggil dengan outletId=null untuk clear (saat logout).
  void setKepalaGeraiMode(String? outletId) => state = state.copyWith(
        isKepalaGerai: outletId != null,
        managedOutletId: outletId,
        clearManagedOutlet: outletId == null,
      );

  void setDetectedEmployee(Employee? emp) => state = emp == null
      ? state.copyWith(clearEmployee: true)
      : state.copyWith(detectedEmployee: emp);

  void setPendingCount(int count) =>
      state = state.copyWith(pendingCount: count);

  void setBackupMode(bool isBackup, String? notes, String? outletId) =>
      state = state.copyWith(
        isBackupMode: isBackup,
        backupNotes: notes,
        backupOutletId: outletId,
      );

  void resetScanFlow() =>
      state = state.copyWith(clearEmployee: true, clearBackup: true);

  /// Load biometric preference from SharedPreferences + check hardware.
  Future<void> loadBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(AppConstants.biometricEnabledKey) ?? false;
    await _clearLegacyRememberedAdminSession(prefs);
    final hasHardware = await BiometricService.isAvailable();
    state = state.copyWith(
      biometricEnabled: enabled,
      hasBiometricHardware: hasHardware,
    );
  }

  /// Toggle biometric login on/off.
  Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.biometricEnabledKey, value);
    await _clearLegacyRememberedAdminSession(prefs);
    state = state.copyWith(biometricEnabled: value);
  }

  Future<void> clearLegacyRememberedAdminSession() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearLegacyRememberedAdminSession(prefs);
  }

  Future<void> _clearLegacyRememberedAdminSession(
    SharedPreferences prefs,
  ) async {
    await prefs.remove(AppConstants.rememberedUserRoleKey);
    await prefs.remove(AppConstants.rememberedManagedOutletKey);
  }
}

final appProvider = StateNotifierProvider<AppNotifier, AppState>(
  (ref) => AppNotifier(),
);
