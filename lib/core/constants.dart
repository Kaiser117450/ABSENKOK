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
  static const int dbVersion = 7; // v7: attendance photo beta local queue

  // NFC
  static const int nfcDebounceMs = 1500;

  // Sync settings
  static const int syncMaxRetries = 5;
  static const int syncBatchSize = 50;

  // Attendance photo beta — enabled at build time via
  // --dart-define=ATTENDANCE_PHOTO_BETA=true. Default stays false so older
  // builds and tests keep the legacy non-photo flow.
  static const bool attendancePhotoBetaEnabled =
      bool.fromEnvironment('ATTENDANCE_PHOTO_BETA');
  static const String attendancePhotoBucket = 'attendance-photos';
  static const int attendancePhotoMaxDimensionPx = 640;
  static const int attendancePhotoJpegQuality = 60;
  static const int attendancePhotoStableFaceMs = 1000;
  static const int attendancePhotoBlinkWindowMs = 3000;
  static const double attendancePhotoEyeClosedThreshold = 0.30;
  static const double attendancePhotoEyeOpenThreshold = 0.70;
  static const int attendancePhotoPreviewMs = 300;
  static const int attendancePhotoFaceThrottleMs = 140;
  static const double attendancePhotoMaxHeadEulerY = 18;
  static const double attendancePhotoMinFaceFrameRatio = 0.15;
  // ML Kit boundingBox excludes hair/forehead, so it is ~60-70% of the visible
  // face. When the visible face fills the oval guide (oval ~0.68 of preview
  // width), the bbox width is roughly 0.30-0.45 of frame width. These bounds
  // let users hold the phone at a natural arm's length.
  static const double attendancePhotoOvalFillMin = 0.30;
  static const double attendancePhotoOvalFillMax = 0.80;
  static const double attendancePhotoOffCenterMax = 0.22;
  static const int attendancePhotoMaxBlinkAttempts = 3;
  static const int attendancePhotoUploadMaxRetries = 3;

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
