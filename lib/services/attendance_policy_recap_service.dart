import 'package:absensi_enakko_flutter/core/supabase_client.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';

class AttendancePolicyRecapService {
  const AttendancePolicyRecapService();

  Future<List<AttendancePolicyRecapDay>> fetchAdminSchedulePolicyRecap({
    required String outletId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (outletId.trim().isEmpty) {
      throw ArgumentError.value(outletId, 'outletId', 'Outlet id is required');
    }

    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    if (end.isBefore(start)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'End date must not be before start date',
      );
    }

    final result = await SupabaseClientFactory.admin.rpc(
      'get_admin_schedule_policy_recap',
      params: {
        'p_outlet_id': outletId,
        'p_start_date': _formatDate(start),
        'p_end_date': _formatDate(end),
      },
    );

    return parseRows(result);
  }

  /// Fetch recap for ALL outlets by calling the RPC once per outlet and
  /// merging the results. Duplicates (same employee+date from multiple
  /// outlets) are kept — the RPC already scopes by outlet schedule.
  Future<List<AttendancePolicyRecapDay>> fetchAllOutletsPolicyRecap({
    required List<String> outletIds,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (outletIds.isEmpty) {
      return const <AttendancePolicyRecapDay>[];
    }

    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    if (end.isBefore(start)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'End date must not be before start date',
      );
    }

    final futures = outletIds.map(
      (outletId) => fetchAdminSchedulePolicyRecap(
        outletId: outletId,
        startDate: start,
        endDate: end,
      ),
    );

    final results = await Future.wait(futures);
    final merged = <AttendancePolicyRecapDay>[];
    for (final rows in results) {
      merged.addAll(rows);
    }
    return merged;
  }

  static List<AttendancePolicyRecapDay> parseRows(dynamic raw) {
    final rows = _extractRows(raw);
    return rows
        .map((row) => AttendancePolicyRecapDay.fromJson(row))
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _extractRows(dynamic raw) {
    final unwrapped = _unwrapData(raw);
    if (unwrapped == null) {
      return const [];
    }

    if (unwrapped is List) {
      return unwrapped.map(_asMap).toList(growable: false);
    }

    if (unwrapped is Map) {
      final map = _asMap(unwrapped);
      final nestedList = map['rows'] ?? map['data'] ?? map['result'];
      if (nestedList is List) {
        return nestedList.map(_asMap).toList(growable: false);
      }
      if (map.containsKey('employee_id') &&
          (map.containsKey('primary_status') ||
              map.containsKey('attendance_status'))) {
        return [map];
      }
    }

    throw StateError(
      'Unexpected response shape from get_admin_schedule_policy_recap',
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
    throw StateError('Expected recap row map, found ${raw.runtimeType}');
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static String _formatDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
