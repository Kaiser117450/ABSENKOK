import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/kiosk_scan_context.dart';

class KioskScanAuthorityService {
  KioskScanAuthorityService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<KioskScanContext> fetchContext({
    required String employeeId,
    required String outletId,
    required String deviceId,
  }) async {
    _requireValue(employeeId, 'employeeId');
    _requireValue(outletId, 'outletId');
    _requireValue(deviceId, 'deviceId');

    final result = await (_client ?? SupabaseClientFactory.kiosk).rpc(
      'get_kiosk_scan_context',
      params: {
        'p_employee_id': employeeId,
        'p_outlet_id': outletId,
        'p_device_id': deviceId,
      },
    );

    return parseContext(result);
  }

  Future<KioskScanRecordResult> recordScan(
    KioskScanRecordRequest request,
  ) async {
    _requireValue(request.employeeId, 'employeeId');
    _requireValue(request.outletId, 'outletId');
    _requireValue(request.deviceId, 'deviceId');

    final result = await (_client ?? SupabaseClientFactory.kiosk).rpc(
      'record_kiosk_scan',
      params: request.toRpcParams(),
    );

    return parseRecordResult(result);
  }

  static KioskScanContext parseContext(dynamic raw) {
    final row = _extractSingleRow(raw, 'get_kiosk_scan_context');
    return KioskScanContext.fromJson(row);
  }

  static KioskScanRecordResult parseRecordResult(dynamic raw) {
    final row = _extractSingleRow(raw, 'record_kiosk_scan');
    return KioskScanRecordResult.fromJson(row);
  }

  static Map<String, dynamic> _extractSingleRow(dynamic raw, String rpcName) {
    final unwrapped = _unwrapData(raw);
    if (unwrapped == null) {
      throw StateError('Unexpected empty response from $rpcName');
    }

    if (unwrapped is List) {
      if (unwrapped.isEmpty) {
        throw StateError('Unexpected empty row list from $rpcName');
      }
      return _asMap(unwrapped.first);
    }

    if (unwrapped is Map) {
      final map = _asMap(unwrapped);
      final nested = map['row'] ?? map['result'] ?? map['data'];
      if (nested is List) {
        if (nested.isEmpty) {
          throw StateError('Unexpected empty nested row list from $rpcName');
        }
        return _asMap(nested.first);
      }
      if (nested is Map) {
        return _asMap(nested);
      }
      return map;
    }

    throw StateError(
      'Unexpected response shape from $rpcName: ${unwrapped.runtimeType}',
    );
  }

  static dynamic _unwrapData(dynamic raw) {
    dynamic current = raw;
    while (current is Map &&
        current.containsKey('data') &&
        current['data'] != current) {
      current = current['data'];
    }
    return current;
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw StateError('Expected response map, found ${raw.runtimeType}');
  }

  static void _requireValue(String value, String fieldName) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName is required');
    }
  }
}
