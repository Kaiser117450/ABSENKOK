import 'attendance_log.dart';

enum SyncStatus { pending, uploading, synced, failed }

extension SyncStatusExt on SyncStatus {
  String get value {
    switch (this) {
      case SyncStatus.pending:
        return 'pending';
      case SyncStatus.uploading:
        return 'uploading';
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.failed:
        return 'failed';
    }
  }

  static SyncStatus fromString(String s) {
    switch (s) {
      case 'uploading':
        return SyncStatus.uploading;
      case 'synced':
        return SyncStatus.synced;
      case 'failed':
        return SyncStatus.failed;
      default:
        return SyncStatus.pending;
    }
  }
}

/// Represents an attendance log waiting to be synced to Supabase.
/// Stored in local SQLite database.
class PendingLog {
  final String localId;
  final String employeeId;
  final String scanOutletId;
  final AttendanceType type;
  final double? lat;
  final double? lng;
  final String deviceId;
  final String scannedAt;
  final DateTime? deviceCapturedAt;
  final AttendanceCaptureMode captureMode;
  final int queueOrder;
  final InitialScanIntent initialScanIntent;
  final SyncStatus syncStatus;
  final int retryCount;
  final String createdAt;
  final bool isBackup;
  final String? notes;
  final String? localPhotoPath;
  final int photoRetryCount;

  const PendingLog({
    required this.localId,
    required this.employeeId,
    required this.scanOutletId,
    required this.type,
    this.lat,
    this.lng,
    required this.deviceId,
    required this.scannedAt,
    this.deviceCapturedAt,
    this.captureMode = AttendanceCaptureMode.queued,
    required this.queueOrder,
    this.initialScanIntent = InitialScanIntent.none,
    required this.syncStatus,
    required this.retryCount,
    required this.createdAt,
    this.isBackup = false,
    this.notes,
    this.localPhotoPath,
    this.photoRetryCount = 0,
  });

  factory PendingLog.fromMap(Map<String, dynamic> map) => PendingLog(
        localId: map['local_id'] as String,
        employeeId: map['employee_id'] as String,
        scanOutletId: map['scan_outlet_id'] as String,
        type: AttendanceTypeExt.fromString(map['type'] as String),
        lat: map['lat'] as double?,
        lng: map['lng'] as double?,
        deviceId: map['device_id'] as String,
        scannedAt: map['scanned_at'] as String,
        deviceCapturedAt: _readDateTime(map['device_captured_at']),
        captureMode: AttendanceCaptureModeExt.fromString(
          map['capture_mode']?.toString(),
        ),
        queueOrder: _readInt(map['queue_order']) ?? 0,
        initialScanIntent: InitialScanIntentExt.fromString(
          map['initial_scan_intent']?.toString(),
        ),
        syncStatus: SyncStatusExt.fromString(map['sync_status'] as String),
        retryCount: map['retry_count'] as int? ?? 0,
        createdAt: map['created_at'] as String? ?? '',
        isBackup: (map['is_backup'] as int? ?? 0) == 1,
        notes: map['notes'] as String?,
        localPhotoPath: map['local_photo_path'] as String?,
        photoRetryCount: map['photo_retry_count'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'local_id': localId,
        'employee_id': employeeId,
        'scan_outlet_id': scanOutletId,
        'type': type.value,
        'lat': lat,
        'lng': lng,
        'device_id': deviceId,
        'scanned_at': scannedAt,
        'device_captured_at': deviceCapturedAt?.toUtc().toIso8601String(),
        'capture_mode': captureMode.value,
        'queue_order': queueOrder,
        'initial_scan_intent': initialScanIntent.value,
        'sync_status': syncStatus.value,
        'retry_count': retryCount,
        'created_at': createdAt,
        'is_backup': isBackup ? 1 : 0,
        'notes': notes,
        'local_photo_path': localPhotoPath,
        'photo_retry_count': photoRetryCount,
      };

  static DateTime? _readDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final value = raw.toString().trim();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static int? _readInt(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }
}
