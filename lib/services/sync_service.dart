import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../models/kiosk_scan_context.dart';
import '../models/pending_log.dart';
import 'kiosk_scan_authority_service.dart';
import 'photo_upload_service.dart';
import 'sqlite_service.dart';

typedef SyncResult = ({int synced, int failed});
typedef ConnectivityProbe = Future<List<ConnectivityResult>> Function();
typedef PendingLogsLoader = Future<List<PendingLog>> Function();
typedef PendingLogMarker = Future<void> Function(String localId);
typedef PendingLogCleaner = Future<void> Function();
typedef SavedPhotoRetryer = Future<int> Function();
typedef PendingPhotoUploader = Future<bool> Function({
  required String outletId,
  required String employeeId,
  required DateTime logDate,
  required String logId,
  required String localPhotoPath,
});

/// Background sync service: uploads local SQLite queue through the Phase 56
/// authority RPC in deterministic queue order.
class SyncService {
  static Future<SyncResult> syncPendingLogs({
    ConnectivityProbe? connectivityProbe,
    PendingLogsLoader? pendingLogsLoader,
    PendingLogMarker? markLogSynced,
    PendingLogMarker? markLogFailed,
    PendingLogCleaner? cleanOldSyncedLogs,
    KioskScanAuthorityService? authorityService,
    bool? attendancePhotoBetaEnabled,
    SavedPhotoRetryer? savedPhotoRetryer,
    PendingPhotoUploader? pendingPhotoUploader,
    PendingLogMarker? markPhotoUploadFailed,
  }) async {
    final photoBetaEnabled =
        attendancePhotoBetaEnabled ?? AppConstants.attendancePhotoBetaEnabled;
    final retrySavedPhotos =
        savedPhotoRetryer ?? PhotoUploadService.instance.retrySavedPhotos;
    final probe = connectivityProbe ?? () => Connectivity().checkConnectivity();
    final connectivity = await probe();
    if (connectivity.contains(ConnectivityResult.none) ||
        connectivity.isEmpty) {
      return (synced: 0, failed: 0);
    }

    final pending = await (pendingLogsLoader ?? SqliteService.getPendingLogs)();
    if (pending.isEmpty) {
      if (photoBetaEnabled) {
        await retrySavedPhotos();
      }
      await (cleanOldSyncedLogs ?? SqliteService.cleanOldSyncedLogs)();
      return (synced: 0, failed: 0);
    }

    final authority = authorityService ?? KioskScanAuthorityService();
    final onSynced = markLogSynced ?? SqliteService.markLogSynced;
    final onFailed = markLogFailed ?? SqliteService.markLogFailed;
    final onPhotoFailed =
        markPhotoUploadFailed ?? SqliteService.markPhotoUploadFailed;
    final cleanup = cleanOldSyncedLogs ?? SqliteService.cleanOldSyncedLogs;
    final uploadPendingPhoto =
        pendingPhotoUploader ?? PhotoUploadService.instance.uploadLocalPhoto;

    var synced = 0;
    var failed = 0;

    for (final log in pending) {
      try {
        final result = await authority.recordScan(_buildRequest(log));
        if (result.authorityState == KioskScanAuthorityState.duplicateLocalId) {
          await _uploadPendingPhotoIfNeeded(
            log,
            result,
            authority,
            photoBetaEnabled: photoBetaEnabled,
            uploadPendingPhoto: uploadPendingPhoto,
            markPhotoUploadFailed: onPhotoFailed,
          );
          await onSynced(log.localId);
          synced++;
          continue;
        }

        await _uploadPendingPhotoIfNeeded(
          log,
          result,
          authority,
          photoBetaEnabled: photoBetaEnabled,
          uploadPendingPhoto: uploadPendingPhoto,
          markPhotoUploadFailed: onPhotoFailed,
        );
        await onSynced(log.localId);
        synced++;
      } on PostgrestException catch (e) {
        if (_isDuplicateLocalIdError(e)) {
          await _uploadPendingPhotoIfNeeded(
            log,
            KioskScanRecordResult(
              authorityState: KioskScanAuthorityState.duplicateLocalId,
              scannedAtUtc: log.deviceCapturedAt,
              scannedAtWitaLabel: '',
              recordedType: log.type,
              initialScanIntent: log.initialScanIntent,
              requiresAdminReview: false,
            ),
            authority,
            photoBetaEnabled: photoBetaEnabled,
            uploadPendingPhoto: uploadPendingPhoto,
            markPhotoUploadFailed: onPhotoFailed,
          );
          await onSynced(log.localId);
          synced++;
        } else {
          // ignore: avoid_print
          print('[Sync] Authority error for ${log.localId}: ${e.message}');
          await onFailed(log.localId);
          failed++;
        }
      } catch (e, stack) {
        // ignore: avoid_print
        print('[Sync] Failed to sync ${log.localId}: $e\n$stack');
        await onFailed(log.localId);
        failed++;
      }
    }

    if (synced > 0) {
      if (photoBetaEnabled) {
        await retrySavedPhotos();
      }
      await cleanup();
    }

    // ignore: avoid_print
    print('[Sync] Done: $synced synced, $failed failed');
    return (synced: synced, failed: failed);
  }

  static KioskScanRecordRequest _buildRequest(PendingLog log) {
    return KioskScanRecordRequest(
      employeeId: log.employeeId,
      outletId: log.scanOutletId,
      deviceId: log.deviceId,
      type: log.type,
      localId: log.localId,
      captureMode: log.captureMode,
      deviceCapturedAt: log.deviceCapturedAt,
      queueOrder: log.queueOrder,
      initialScanIntent: log.initialScanIntent,
      isBackup: log.isBackup,
      notes: log.notes,
      lat: log.lat,
      lng: log.lng,
    );
  }

  static Future<void> _uploadPendingPhotoIfNeeded(
    PendingLog log,
    KioskScanRecordResult result,
    KioskScanAuthorityService authority, {
    required bool photoBetaEnabled,
    required PendingPhotoUploader uploadPendingPhoto,
    required PendingLogMarker markPhotoUploadFailed,
  }) async {
    if (!photoBetaEnabled) return;
    final localPhotoPath = log.localPhotoPath;
    if (localPhotoPath == null || localPhotoPath.trim().isEmpty) return;
    if (log.photoRetryCount >= AppConstants.attendancePhotoUploadMaxRetries) {
      throw StateError('Photo upload retry limit reached for ${log.localId}');
    }

    try {
      final ref = result.logId == null
          ? await authority.resolveAttendanceLogForLocalId(log.localId)
          : KioskRecordedLogRef(
              logId: result.logId!,
              scannedAtUtc: result.scannedAtUtc ??
                  log.deviceCapturedAt ??
                  DateTime.parse(log.scannedAt),
              logicalDate: _logicalDateFromLog(log),
            );

      await uploadPendingPhoto(
        outletId: log.scanOutletId,
        employeeId: log.employeeId,
        logDate: ref.logicalDate,
        logId: ref.logId,
        localPhotoPath: localPhotoPath,
      );
    } catch (_) {
      await markPhotoUploadFailed(log.localId);
      rethrow;
    }
  }

  static DateTime _logicalDateFromLog(PendingLog log) {
    final parsed = log.deviceCapturedAt ?? DateTime.tryParse(log.scannedAt);
    final value = parsed ?? DateTime.now();
    return DateTime(value.year, value.month, value.day);
  }

  static bool _isDuplicateLocalIdError(PostgrestException error) {
    return error.code == '23505' ||
        error.message.toLowerCase().contains('local_id');
  }
}
