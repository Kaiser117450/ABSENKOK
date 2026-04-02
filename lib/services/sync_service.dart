import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/kiosk_scan_context.dart';
import '../models/pending_log.dart';
import 'kiosk_scan_authority_service.dart';
import 'sqlite_service.dart';

typedef SyncResult = ({int synced, int failed});
typedef ConnectivityProbe = Future<List<ConnectivityResult>> Function();
typedef PendingLogsLoader = Future<List<PendingLog>> Function();
typedef PendingLogMarker = Future<void> Function(String localId);
typedef PendingLogCleaner = Future<void> Function();

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
  }) async {
    final probe = connectivityProbe ?? () => Connectivity().checkConnectivity();
    final connectivity = await probe();
    if (connectivity.contains(ConnectivityResult.none) ||
        connectivity.isEmpty) {
      return (synced: 0, failed: 0);
    }

    final pending = await (pendingLogsLoader ?? SqliteService.getPendingLogs)();
    if (pending.isEmpty) {
      await (cleanOldSyncedLogs ?? SqliteService.cleanOldSyncedLogs)();
      return (synced: 0, failed: 0);
    }

    final authority = authorityService ?? KioskScanAuthorityService();
    final onSynced = markLogSynced ?? SqliteService.markLogSynced;
    final onFailed = markLogFailed ?? SqliteService.markLogFailed;
    final cleanup = cleanOldSyncedLogs ?? SqliteService.cleanOldSyncedLogs;

    var synced = 0;
    var failed = 0;

    for (final log in pending) {
      try {
        final result = await authority.recordScan(_buildRequest(log));
        if (result.authorityState == KioskScanAuthorityState.duplicateLocalId) {
          await onSynced(log.localId);
          synced++;
          continue;
        }

        await onSynced(log.localId);
        synced++;
      } on PostgrestException catch (e) {
        if (_isDuplicateLocalIdError(e)) {
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

  static bool _isDuplicateLocalIdError(PostgrestException error) {
    return error.code == '23505' ||
        error.message.toLowerCase().contains('local_id');
  }
}
