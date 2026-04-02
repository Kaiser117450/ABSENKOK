/// App-wide constants for Absensi Enakko
class AppConstants {
  // Secure storage keys
  static const String kioskSessionKey = 'kiosk_session_v1';
  static const String overlayKeepForegroundKey = 'overlay_keep_foreground_v1';

  // Biometric login
  static const String biometricEnabledKey = 'biometric_enabled_v1';
  static const String rememberedUserRoleKey = 'remembered_user_role_v1';
  static const String rememberedManagedOutletKey =
      'remembered_managed_outlet_v1';

  // Device identity (Phase 31) — survives kiosk logout
  static const String installationDeviceUuidKey = 'installation_device_uuid_v1';

  // SQLite
  static const String dbName = 'absensi_enakko.db';
  static const int dbVersion = 6; // v6: Phase 56 queue authority metadata

  // NFC
  static const int nfcDebounceMs = 1500;

  // Sync settings
  static const int syncMaxRetries = 5;
  static const int syncBatchSize = 50;

  // UI timings
  static const int successScreenDurationMs = 3000;
  static const int errorResetDurationMs = 2500;
  static const int scanTransitionDelayMs = 600;
  static const int toastDurationMs = 1800;
  static const int cacheFastPathDelayMs = 300;

  // Kiosk background animation timings
  static const int kioskBgGradientDurationSec = 20;
  static const int kioskBreatheDurationSec = 8;
  static const int kioskShimmerDurationSec = 15;
}
