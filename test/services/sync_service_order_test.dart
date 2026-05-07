import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/kiosk_scan_context.dart';
import 'package:absensi_enakko_flutter/models/pending_log.dart';
import 'package:absensi_enakko_flutter/services/kiosk_scan_authority_service.dart';
import 'package:absensi_enakko_flutter/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeKioskScanAuthorityService extends KioskScanAuthorityService {
  _FakeKioskScanAuthorityService({
    Set<String>? failingLocalIds,
    Set<String>? duplicateExceptionLocalIds,
    Set<String>? duplicateLocalIds,
    Map<String, String>? logIdsByLocalId,
    Map<String, KioskRecordedLogRef>? resolvedRefsByLocalId,
  })  : failingLocalIds = failingLocalIds ?? <String>{},
        duplicateExceptionLocalIds = duplicateExceptionLocalIds ?? <String>{},
        duplicateLocalIds = duplicateLocalIds ?? <String>{},
        logIdsByLocalId = logIdsByLocalId ?? const <String, String>{},
        resolvedRefsByLocalId =
            resolvedRefsByLocalId ?? const <String, KioskRecordedLogRef>{};

  final Set<String> failingLocalIds;
  final Set<String> duplicateExceptionLocalIds;
  final Set<String> duplicateLocalIds;
  final Map<String, String> logIdsByLocalId;
  final Map<String, KioskRecordedLogRef> resolvedRefsByLocalId;
  final List<KioskScanRecordRequest> requests = <KioskScanRecordRequest>[];
  final List<String> resolveRequests = <String>[];

  @override
  Future<KioskScanRecordResult> recordScan(
    KioskScanRecordRequest request,
  ) async {
    requests.add(request);

    if (failingLocalIds.contains(request.localId)) {
      throw Exception('Failed replay for ${request.localId}');
    }

    if (duplicateExceptionLocalIds.contains(request.localId)) {
      throw PostgrestException(
        message: 'duplicate key value violates unique constraint local_id',
        code: '23505',
      );
    }

    if (duplicateLocalIds.contains(request.localId)) {
      return KioskScanRecordResult(
        authorityState: KioskScanAuthorityState.duplicateLocalId,
        scannedAtUtc: request.deviceCapturedAt,
        scannedAtWitaLabel: '',
        recordedType: request.type,
        initialScanIntent: request.initialScanIntent,
        requiresAdminReview: false,
      );
    }

    return KioskScanRecordResult(
      logId: logIdsByLocalId[request.localId],
      authorityState: KioskScanAuthorityState.queuedReconciled,
      scannedAtUtc: request.deviceCapturedAt,
      scannedAtWitaLabel: '',
      recordedType: request.type,
      initialScanIntent: request.initialScanIntent,
      requiresAdminReview: false,
    );
  }

  @override
  Future<KioskRecordedLogRef> resolveAttendanceLogForLocalId(
    String localId,
  ) async {
    resolveRequests.add(localId);
    return resolvedRefsByLocalId[localId] ??
        KioskRecordedLogRef(
          logId: 'resolved-$localId',
          scannedAtUtc: DateTime.parse('2026-03-27T01:00:00Z'),
          logicalDate: DateTime(2026, 3, 27),
        );
  }
}

void main() {
  group('SyncService queue replay order', () {
    test('queued rows replay in ascending queueOrder and keep scan intent',
        () async {
      final fakeAuthority = _FakeKioskScanAuthorityService();
      final synced = <String>[];
      final failed = <String>[];

      final result = await SyncService.syncPendingLogs(
        connectivityProbe: () async => [ConnectivityResult.wifi],
        pendingLogsLoader: () async => [
          _pendingLog(
            localId: 'queue-1',
            queueOrder: 1,
          ),
          _pendingLog(localId: 'queue-2', queueOrder: 2),
        ],
        markLogSynced: (localId) async => synced.add(localId),
        markLogFailed: (localId) async => failed.add(localId),
        cleanOldSyncedLogs: () async {},
        authorityService: fakeAuthority,
      );

      expect(result.synced, 2);
      expect(result.failed, 0);
      expect(synced, ['queue-1', 'queue-2']);
      expect(failed, isEmpty);
      expect(
        fakeAuthority.requests.map((request) => request.queueOrder),
        orderedEquals([1, 2]),
      );
      expect(
        fakeAuthority.requests.first.initialScanIntent.value,
        'none',
      );
    });

    test('a failure on row N does not reorder later rows before it', () async {
      final fakeAuthority = _FakeKioskScanAuthorityService(
        failingLocalIds: {'queue-2'},
      );
      final synced = <String>[];
      final failed = <String>[];

      final result = await SyncService.syncPendingLogs(
        connectivityProbe: () async => [ConnectivityResult.mobile],
        pendingLogsLoader: () async => [
          _pendingLog(localId: 'queue-1', queueOrder: 1),
          _pendingLog(localId: 'queue-2', queueOrder: 2),
          _pendingLog(localId: 'queue-3', queueOrder: 3),
        ],
        markLogSynced: (localId) async => synced.add(localId),
        markLogFailed: (localId) async => failed.add(localId),
        cleanOldSyncedLogs: () async {},
        authorityService: fakeAuthority,
      );

      expect(result.synced, 2);
      expect(result.failed, 1);
      expect(
        fakeAuthority.requests.map((request) => request.localId),
        orderedEquals(['queue-1', 'queue-2', 'queue-3']),
      );
      expect(synced, ['queue-1', 'queue-3']);
      expect(failed, ['queue-2']);
    });

    test('duplicate local_id responses still mark rows synced', () async {
      final fakeAuthority = _FakeKioskScanAuthorityService(
        duplicateLocalIds: {'queue-duplicate'},
      );
      final synced = <String>[];
      final failed = <String>[];

      final result = await SyncService.syncPendingLogs(
        connectivityProbe: () async => [ConnectivityResult.ethernet],
        pendingLogsLoader: () async => [
          _pendingLog(localId: 'queue-duplicate', queueOrder: 1),
        ],
        markLogSynced: (localId) async => synced.add(localId),
        markLogFailed: (localId) async => failed.add(localId),
        cleanOldSyncedLogs: () async {},
        authorityService: fakeAuthority,
      );

      expect(result.synced, 1);
      expect(result.failed, 0);
      expect(synced, ['queue-duplicate']);
      expect(failed, isEmpty);
      expect(
        fakeAuthority.requests.single.localId,
        'queue-duplicate',
      );
    });

    test('beta photo sync uploads local photo after authority replay',
        () async {
      final fakeAuthority = _FakeKioskScanAuthorityService(
        logIdsByLocalId: {'queue-photo': 'log-photo-1'},
      );
      final synced = <String>[];
      final failed = <String>[];
      final photoFailed = <String>[];
      final uploaded = <String, Object?>{};
      var savedRetryCalls = 0;

      final result = await SyncService.syncPendingLogs(
        attendancePhotoBetaEnabled: true,
        connectivityProbe: () async => [ConnectivityResult.wifi],
        pendingLogsLoader: () async => [
          _pendingLog(
            localId: 'queue-photo',
            queueOrder: 1,
            localPhotoPath: 'attendance_photo_queue/outlet-1/photo.jpg',
          ),
        ],
        markLogSynced: (localId) async => synced.add(localId),
        markLogFailed: (localId) async => failed.add(localId),
        markPhotoUploadFailed: (localId) async => photoFailed.add(localId),
        cleanOldSyncedLogs: () async {},
        savedPhotoRetryer: () async {
          savedRetryCalls++;
          return 0;
        },
        pendingPhotoUploader: ({
          required outletId,
          required employeeId,
          required logDate,
          required logId,
          required localPhotoPath,
        }) async {
          uploaded.addAll({
            'outletId': outletId,
            'employeeId': employeeId,
            'logDate': logDate,
            'logId': logId,
            'localPhotoPath': localPhotoPath,
          });
          return true;
        },
        authorityService: fakeAuthority,
      );

      expect(result, (synced: 1, failed: 0));
      expect(synced, ['queue-photo']);
      expect(failed, isEmpty);
      expect(photoFailed, isEmpty);
      expect(uploaded['outletId'], 'outlet-1');
      expect(uploaded['employeeId'], 'employee-1');
      expect(uploaded['logDate'], DateTime(2026, 3, 27));
      expect(uploaded['logId'], 'log-photo-1');
      expect(
        uploaded['localPhotoPath'],
        'attendance_photo_queue/outlet-1/photo.jpg',
      );
      expect(savedRetryCalls, 1);
    });

    test('beta photo sync resolves log id for duplicate local id replay',
        () async {
      final fakeAuthority = _FakeKioskScanAuthorityService(
        duplicateLocalIds: {'queue-duplicate-photo'},
        resolvedRefsByLocalId: {
          'queue-duplicate-photo': KioskRecordedLogRef(
            logId: 'resolved-log-id',
            scannedAtUtc: DateTime.parse('2026-03-27T01:00:00Z'),
            logicalDate: DateTime(2026, 3, 27),
          ),
        },
      );
      final uploaded = <String, Object?>{};

      final result = await SyncService.syncPendingLogs(
        attendancePhotoBetaEnabled: true,
        connectivityProbe: () async => [ConnectivityResult.wifi],
        pendingLogsLoader: () async => [
          _pendingLog(
            localId: 'queue-duplicate-photo',
            queueOrder: 1,
            localPhotoPath: 'attendance_photo_queue/outlet-1/photo.jpg',
          ),
        ],
        markLogSynced: (_) async {},
        markLogFailed: (_) async {},
        markPhotoUploadFailed: (_) async {},
        cleanOldSyncedLogs: () async {},
        savedPhotoRetryer: () async => 0,
        pendingPhotoUploader: ({
          required outletId,
          required employeeId,
          required logDate,
          required logId,
          required localPhotoPath,
        }) async {
          uploaded['logId'] = logId;
          return true;
        },
        authorityService: fakeAuthority,
      );

      expect(result, (synced: 1, failed: 0));
      expect(fakeAuthority.resolveRequests, ['queue-duplicate-photo']);
      expect(uploaded['logId'], 'resolved-log-id');
    });

    test('beta photo sync resolves log id for duplicate local id exception',
        () async {
      final fakeAuthority = _FakeKioskScanAuthorityService(
        duplicateExceptionLocalIds: {'queue-duplicate-exception-photo'},
        resolvedRefsByLocalId: {
          'queue-duplicate-exception-photo': KioskRecordedLogRef(
            logId: 'resolved-exception-log-id',
            scannedAtUtc: DateTime.parse('2026-03-27T01:00:00Z'),
            logicalDate: DateTime(2026, 3, 27),
          ),
        },
      );
      final synced = <String>[];
      final failed = <String>[];
      final uploaded = <String, Object?>{};

      final result = await SyncService.syncPendingLogs(
        attendancePhotoBetaEnabled: true,
        connectivityProbe: () async => [ConnectivityResult.wifi],
        pendingLogsLoader: () async => [
          _pendingLog(
            localId: 'queue-duplicate-exception-photo',
            queueOrder: 1,
            localPhotoPath: 'attendance_photo_queue/outlet-1/photo.jpg',
          ),
        ],
        markLogSynced: (localId) async => synced.add(localId),
        markLogFailed: (localId) async => failed.add(localId),
        markPhotoUploadFailed: (_) async {},
        cleanOldSyncedLogs: () async {},
        savedPhotoRetryer: () async => 0,
        pendingPhotoUploader: ({
          required outletId,
          required employeeId,
          required logDate,
          required logId,
          required localPhotoPath,
        }) async {
          uploaded['logId'] = logId;
          return true;
        },
        authorityService: fakeAuthority,
      );

      expect(result, (synced: 1, failed: 0));
      expect(synced, ['queue-duplicate-exception-photo']);
      expect(failed, isEmpty);
      expect(
        fakeAuthority.resolveRequests,
        ['queue-duplicate-exception-photo'],
      );
      expect(uploaded['logId'], 'resolved-exception-log-id');
    });

    test('beta photo retryer runs when queue is empty', () async {
      var savedRetryCalls = 0;
      var cleanupCalls = 0;

      final result = await SyncService.syncPendingLogs(
        attendancePhotoBetaEnabled: true,
        connectivityProbe: () async => [ConnectivityResult.wifi],
        pendingLogsLoader: () async => const [],
        cleanOldSyncedLogs: () async => cleanupCalls++,
        savedPhotoRetryer: () async {
          savedRetryCalls++;
          return 0;
        },
      );

      expect(result, (synced: 0, failed: 0));
      expect(savedRetryCalls, 1);
      expect(cleanupCalls, 1);
    });
  });
}

PendingLog _pendingLog({
  required String localId,
  required int queueOrder,
  InitialScanIntent initialScanIntent = InitialScanIntent.none,
  String? localPhotoPath,
  int photoRetryCount = 0,
}) {
  return PendingLog(
    localId: localId,
    employeeId: 'employee-1',
    scanOutletId: 'outlet-1',
    type: AttendanceType.masuk,
    lat: null,
    lng: null,
    deviceId: 'device-1',
    scannedAt: '2026-03-27T01:00:00Z',
    deviceCapturedAt: DateTime.parse('2026-03-27T01:00:00Z'),
    captureMode: AttendanceCaptureMode.queued,
    queueOrder: queueOrder,
    initialScanIntent: initialScanIntent,
    syncStatus: SyncStatus.pending,
    retryCount: 0,
    createdAt: '2026-03-27T01:00:00Z',
    isBackup: false,
    notes: null,
    localPhotoPath: localPhotoPath,
    photoRetryCount: photoRetryCount,
  );
}
