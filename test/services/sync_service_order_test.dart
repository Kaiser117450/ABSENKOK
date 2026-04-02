import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/kiosk_scan_context.dart';
import 'package:absensi_enakko_flutter/models/pending_log.dart';
import 'package:absensi_enakko_flutter/services/kiosk_scan_authority_service.dart';
import 'package:absensi_enakko_flutter/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeKioskScanAuthorityService extends KioskScanAuthorityService {
  _FakeKioskScanAuthorityService({
    Set<String>? failingLocalIds,
    Set<String>? duplicateLocalIds,
  })  : failingLocalIds = failingLocalIds ?? <String>{},
        duplicateLocalIds = duplicateLocalIds ?? <String>{};

  final Set<String> failingLocalIds;
  final Set<String> duplicateLocalIds;
  final List<KioskScanRecordRequest> requests = <KioskScanRecordRequest>[];

  @override
  Future<KioskScanRecordResult> recordScan(
    KioskScanRecordRequest request,
  ) async {
    requests.add(request);

    if (failingLocalIds.contains(request.localId)) {
      throw Exception('Failed replay for ${request.localId}');
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
      authorityState: KioskScanAuthorityState.queuedReconciled,
      scannedAtUtc: request.deviceCapturedAt,
      scannedAtWitaLabel: '',
      recordedType: request.type,
      initialScanIntent: request.initialScanIntent,
      requiresAdminReview: false,
    );
  }
}

void main() {
  group('SyncService queue replay order', () {
    test(
        'queued rows replay in ascending queueOrder and keep break_first intent',
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
            initialScanIntent: InitialScanIntent.breakFirst,
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
        'break_first',
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
  });
}

PendingLog _pendingLog({
  required String localId,
  required int queueOrder,
  InitialScanIntent initialScanIntent = InitialScanIntent.none,
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
  );
}
