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

  // Master beta-features gate. All Phase-74 features (admin password reset,
  // read-only QC viewer role) ship behind the SAME beta flag so a single beta
  // build — `flutter build apk --dart-define=ATTENDANCE_PHOTO_BETA=true` —
  // turns everything on. Kept as a semantic alias so feature guards read
  // clearly without re-deciding the flag at every call site.
  static const bool betaFeaturesEnabled = attendancePhotoBetaEnabled;
  static const String attendancePhotoBucket = 'attendance-photos';
  static const int attendancePhotoMaxDimensionPx = 640;
  static const int attendancePhotoJpegQuality = 60;
  static const int attendancePhotoStableFaceMs = 500;
  static const int attendancePhotoBlinkWindowMs = 3500;
  static const double attendancePhotoEyeClosedThreshold = 0.35;
  static const double attendancePhotoEyeOpenThreshold = 0.60;
  static const int attendancePhotoPreviewMs = 300;
  static const int attendancePhotoFaceThrottleMs = 120;
  static const double attendancePhotoMaxHeadEulerY = 25;
  static const double attendancePhotoMinFaceFrameRatio = 0.12;
  // ML Kit boundingBox excludes hair/forehead, so it is ~60-70% of the visible
  // face. The lower bound is intentionally loose so users barely need to
  // position themselves — once a face is detected with reasonable size and
  // roughly centered, capture begins.
  static const double attendancePhotoOvalFillMin = 0.22;
  static const double attendancePhotoOvalFillMax = 0.85;
  static const double attendancePhotoOffCenterMax = 0.30;
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
