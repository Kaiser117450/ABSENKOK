import 'attendance_log.dart';
import 'employee_contract.dart';
import 'shift_band.dart';

enum KioskScanAuthorityState {
  liveConfirmed,
  queuedPending,
  queuedReconciled,
  duplicateLocalId,
  unknown,
}

extension KioskScanAuthorityStateExt on KioskScanAuthorityState {
  String get value {
    switch (this) {
      case KioskScanAuthorityState.liveConfirmed:
        return 'live_confirmed';
      case KioskScanAuthorityState.queuedPending:
        return 'queued_pending';
      case KioskScanAuthorityState.queuedReconciled:
        return 'queued_reconciled';
      case KioskScanAuthorityState.duplicateLocalId:
        return 'duplicate_local_id';
      case KioskScanAuthorityState.unknown:
        return 'unknown';
    }
  }

  static KioskScanAuthorityState fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'live_confirmed':
        return KioskScanAuthorityState.liveConfirmed;
      case 'queued_pending':
        return KioskScanAuthorityState.queuedPending;
      case 'queued_reconciled':
        return KioskScanAuthorityState.queuedReconciled;
      case 'duplicate_local_id':
        return KioskScanAuthorityState.duplicateLocalId;
      default:
        return KioskScanAuthorityState.unknown;
    }
  }
}

class KioskScanContext {
  final DateTime serverNowUtc;
  final String serverNowWitaLabel;
  final DateTime logicalDate;
  final AttendanceType? lastAuthoritativeType;
  final DateTime? lastAuthoritativeScannedAt;
  final ShiftBand? shiftBand;
  final EmployeeContract employmentContract;
  final String? lateCutoffLocal;

  const KioskScanContext({
    required this.serverNowUtc,
    required this.serverNowWitaLabel,
    required this.logicalDate,
    this.lastAuthoritativeType,
    this.lastAuthoritativeScannedAt,
    this.shiftBand,
    required this.employmentContract,
    this.lateCutoffLocal,
  });

  factory KioskScanContext.fromJson(Map<String, dynamic> json) {
    return KioskScanContext(
      serverNowUtc: _readRequiredDateTime(
        json['server_now_utc'] ?? json['server_now'],
        'server_now_utc',
      ),
      serverNowWitaLabel: _readRequiredString(
        json['server_now_wita_label'],
        'server_now_wita_label',
      ),
      logicalDate: _readRequiredDate(
        json['logical_date'],
        'logical_date',
      ),
      lastAuthoritativeType: _readAttendanceType(
        json['last_authoritative_type'],
      ),
      lastAuthoritativeScannedAt: _readDateTime(
        json['last_authoritative_scanned_at'],
      ),
      shiftBand: ShiftBand.tryParse(json['shift_band']?.toString()),
      employmentContract:
          EmployeeContract.parse(json['employment_contract']?.toString()),
      lateCutoffLocal: _readString(json['late_cutoff_local']),
    );
  }
}

class KioskScanRecordRequest {
  final String employeeId;
  final String outletId;
  final String deviceId;
  final AttendanceType type;
  final String? localId;
  final AttendanceCaptureMode captureMode;
  final DateTime? deviceCapturedAt;
  final int? queueOrder;
  final InitialScanIntent initialScanIntent;
  final bool isBackup;
  final String? notes;
  final double? lat;
  final double? lng;
  final bool photoRequired;
  final String? selfieUrl;

  const KioskScanRecordRequest({
    required this.employeeId,
    required this.outletId,
    required this.deviceId,
    required this.type,
    this.localId,
    this.captureMode = AttendanceCaptureMode.live,
    this.deviceCapturedAt,
    this.queueOrder,
    this.initialScanIntent = InitialScanIntent.none,
    this.isBackup = false,
    this.notes,
    this.lat,
    this.lng,
    this.photoRequired = false,
    this.selfieUrl,
  });

  Map<String, dynamic> toRpcParams({bool includePhotoParams = false}) {
    return {
      'p_employee_id': employeeId,
      'p_outlet_id': outletId,
      'p_device_id': deviceId,
      'p_type': type.value,
      if (_hasText(localId)) 'p_local_id': localId,
      'p_capture_mode': captureMode.value,
      if (deviceCapturedAt != null)
        'p_device_captured_at': deviceCapturedAt!.toUtc().toIso8601String(),
      if (queueOrder != null) 'p_queue_order': queueOrder,
      'p_initial_scan_intent': initialScanIntent.value,
      'p_is_backup': isBackup,
      if (_hasText(notes)) 'p_notes': notes!.trim(),
      if (lat != null) 'p_lat': lat,
      if (lng != null) 'p_lng': lng,
      if (includePhotoParams && photoRequired) 'p_photo_required': true,
      if (includePhotoParams && _hasText(selfieUrl))
        'p_selfie_url': selfieUrl!.trim(),
    };
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;
}

class KioskScanRecordResult {
  final String? logId;
  final KioskScanAuthorityState authorityState;
  final DateTime? scannedAtUtc;
  final String scannedAtWitaLabel;
  final AttendanceType recordedType;
  final InitialScanIntent initialScanIntent;
  final bool requiresAdminReview;

  const KioskScanRecordResult({
    this.logId,
    required this.authorityState,
    required this.scannedAtUtc,
    required this.scannedAtWitaLabel,
    required this.recordedType,
    required this.initialScanIntent,
    required this.requiresAdminReview,
  });

  factory KioskScanRecordResult.fromJson(Map<String, dynamic> json) {
    return KioskScanRecordResult(
      logId: _readString(
        json['log_id'] ?? json['attendance_log_id'] ?? json['id'],
      ),
      authorityState: KioskScanAuthorityStateExt.fromString(
        json['authority_state']?.toString(),
      ),
      scannedAtUtc: _readDateTime(
        json['scanned_at_utc'] ?? json['scanned_at'],
      ),
      scannedAtWitaLabel: _readString(
            json['scanned_at_wita_label'] ?? json['server_now_wita_label'],
          ) ??
          '',
      recordedType: AttendanceTypeExt.fromString(
        (json['recorded_type'] ?? json['type'])?.toString() ?? 'masuk',
      ),
      initialScanIntent: InitialScanIntentExt.fromString(
        json['initial_scan_intent']?.toString(),
      ),
      requiresAdminReview: _readBool(json['requires_admin_review']),
    );
  }
}

class KioskRecordedLogRef {
  final String logId;
  final DateTime scannedAtUtc;
  final DateTime logicalDate;

  const KioskRecordedLogRef({
    required this.logId,
    required this.scannedAtUtc,
    required this.logicalDate,
  });

  factory KioskRecordedLogRef.fromJson(Map<String, dynamic> json) {
    return KioskRecordedLogRef(
      logId: _readRequiredString(
        json['log_id'] ?? json['attendance_log_id'] ?? json['id'],
        'log_id',
      ),
      scannedAtUtc: _readRequiredDateTime(
        json['scanned_at_utc'] ?? json['scanned_at'],
        'scanned_at_utc',
      ),
      logicalDate: _readRequiredDate(
        json['logical_date'],
        'logical_date',
      ),
    );
  }
}

DateTime _readRequiredDateTime(Object? raw, String fieldName) {
  final parsed = _readDateTime(raw);
  if (parsed == null) {
    throw StateError('$fieldName is required');
  }
  return parsed;
}

DateTime _readRequiredDate(Object? raw, String fieldName) {
  final parsed = _readDateTime(raw);
  if (parsed == null) {
    throw StateError('$fieldName is required');
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? _readDateTime(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  final value = raw.toString().trim();
  if (value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String? _readString(Object? raw) {
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

String _readRequiredString(Object? raw, String fieldName) {
  final value = _readString(raw);
  if (value == null) {
    throw StateError('$fieldName is required');
  }
  return value;
}

AttendanceType? _readAttendanceType(Object? raw) {
  final value = _readString(raw);
  if (value == null) return null;
  return AttendanceTypeExt.fromString(value);
}

bool _readBool(Object? raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final value = raw?.toString().trim().toLowerCase();
  return value == 'true' || value == 't' || value == '1';
}
