/// App-wide constants for Absensi Enakko
class AppConstants {
  // Secure storage keys
  static const String kioskSessionKey = 'kiosk_session_v1';
  static const String overlayKeepForegroundKey = 'overlay_keep_foreground_v1';

  // SQLite
  static const String dbName = 'absensi_enakko.db';
  static const int dbVersion = 5; // v5: added sakit/izin attendance types

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
}
