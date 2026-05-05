import 'package:flutter/foundation.dart';

import '../core/supabase_client.dart';
import '../main.dart' show supabaseReady;

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

/// Attendance rate data returned by the get_attendance_rates RPC.
class AttendanceRateData {
  final int totalEmployees;
  final int daysInRange;
  final int totalPresent;
  final double rate;

  const AttendanceRateData({
    required this.totalEmployees,
    required this.daysInRange,
    required this.totalPresent,
    required this.rate,
  });

  factory AttendanceRateData.fromJson(Map<String, dynamic> json) {
    return AttendanceRateData(
      totalEmployees: (json['total_employees'] as num).toInt(),
      daysInRange: (json['days_in_range'] as num).toInt(),
      totalPresent: (json['total_present'] as num).toInt(),
      rate: (json['rate'] as num).toDouble(),
    );
  }
}

/// Overtime flag for an employee who worked beyond the threshold.
class OvertimeFlag {
  final String employeeId;
  final String employeeName;
  final double hoursWorked;
  final double overtimeHours;

  const OvertimeFlag({
    required this.employeeId,
    required this.employeeName,
    required this.hoursWorked,
    required this.overtimeHours,
  });

  factory OvertimeFlag.fromJson(Map<String, dynamic> json) {
    return OvertimeFlag(
      employeeId: json['employee_id'] as String,
      employeeName: json['employee_name'] as String,
      hoursWorked: (json['hours_worked'] as num).toDouble(),
      overtimeHours: (json['overtime_hours'] as num).toDouble(),
    );
  }
}

/// An employee who clocked in but has no subsequent clock-out.
class MissingClockout {
  final String employeeId;
  final String employeeName;
  final DateTime masukTime;

  const MissingClockout({
    required this.employeeId,
    required this.employeeName,
    required this.masukTime,
  });

  factory MissingClockout.fromJson(Map<String, dynamic> json) {
    return MissingClockout(
      employeeId: json['employee_id'] as String,
      employeeName: json['employee_name'] as String,
      masukTime: DateTime.parse(json['masuk_time'] as String),
    );
  }
}

/// Firm-wide central dashboard KPIs returned by get_central_dashboard_summary.
class CentralDashboardSummary {
  final int totalOutlets;
  final int connectedDevices;
  final int offlineDevices;
  final int lowBatteryDevices;
  final int pendingSyncDevices;
  final double dailyAttendanceRate;

  const CentralDashboardSummary({
    required this.totalOutlets,
    required this.connectedDevices,
    required this.offlineDevices,
    required this.lowBatteryDevices,
    required this.pendingSyncDevices,
    required this.dailyAttendanceRate,
  });

  factory CentralDashboardSummary.fromJson(Map<String, dynamic> json) {
    return CentralDashboardSummary(
      totalOutlets: (json['total_outlets'] as num).toInt(),
      connectedDevices: (json['connected_devices'] as num).toInt(),
      offlineDevices: (json['offline_devices'] as num).toInt(),
      lowBatteryDevices: (json['low_battery_devices'] as num).toInt(),
      pendingSyncDevices: (json['pending_sync_devices'] as num).toInt(),
      dailyAttendanceRate: (json['daily_attendance_rate'] as num).toDouble(),
    );
  }
}

/// One rollup row per active outlet returned by get_outlet_control_center.
class OutletControlCenterRow {
  final String outletId;
  final String outletName;
  final int connectedDevices;
  final int offlineDevices;
  final int lowBatteryDevices;
  final int pendingSyncDevices;
  final double dailyAttendanceRate;
  final DateTime? lastHeartbeatAt;

  const OutletControlCenterRow({
    required this.outletId,
    required this.outletName,
    required this.connectedDevices,
    required this.offlineDevices,
    required this.lowBatteryDevices,
    required this.pendingSyncDevices,
    required this.dailyAttendanceRate,
    this.lastHeartbeatAt,
  });

  factory OutletControlCenterRow.fromJson(Map<String, dynamic> json) {
    return OutletControlCenterRow(
      outletId: json['outlet_id'] as String,
      outletName: json['outlet_name'] as String,
      connectedDevices: (json['connected_devices'] as num).toInt(),
      offlineDevices: (json['offline_devices'] as num).toInt(),
      lowBatteryDevices: (json['low_battery_devices'] as num).toInt(),
      pendingSyncDevices: (json['pending_sync_devices'] as num).toInt(),
      dailyAttendanceRate: (json['daily_attendance_rate'] as num).toDouble(),
      lastHeartbeatAt: json['last_heartbeat_at'] == null
          ? null
          : DateTime.parse(json['last_heartbeat_at'] as String),
    );
  }
}

/// Employee insight data for chart dashboard showing attendance issues.
class EmployeeInsightData {
  final String employeeId;
  final String employeeName;
  final int lateCount;
  final int absenceCount;
  final int shortWorkCount;
  final int excessBreakCount;
  final int overtimeCount;
  final int safeCount; // days without issues

  const EmployeeInsightData({
    required this.employeeId,
    required this.employeeName,
    required this.lateCount,
    required this.absenceCount,
    required this.shortWorkCount,
    required this.excessBreakCount,
    required this.overtimeCount,
    required this.safeCount,
  });

  int get totalIssues => lateCount + absenceCount + shortWorkCount + excessBreakCount;

  factory EmployeeInsightData.fromJson(Map<String, dynamic> json) {
    return EmployeeInsightData(
      employeeId: json['employee_id'] as String,
      employeeName: json['employee_name'] as String,
      lateCount: (json['late_count'] as num?)?.toInt() ?? 0,
      absenceCount: (json['absence_count'] as num?)?.toInt() ?? 0,
      shortWorkCount: (json['short_work_count'] as num?)?.toInt() ?? 0,
      excessBreakCount: (json['excess_break_count'] as num?)?.toInt() ?? 0,
      overtimeCount: (json['overtime_count'] as num?)?.toInt() ?? 0,
      safeCount: (json['safe_count'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AnalyticsService
// ─────────────────────────────────────────────────────────────────────────────

/// Analytics service for admin/kepala gerai dashboard metrics.
///
/// Calls Supabase RPC functions for aggregated attendance data.
/// All methods guard on [supabaseReady] and return null/empty on failure
/// (non-throwing pattern matching [BadgeService]).
class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  /// Returns attendance rate data for an outlet over a date range.
  /// Returns null if [supabaseReady] is false or if the RPC fails.
  Future<AttendanceRateData?> getAttendanceRates({
    required String outletId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (!supabaseReady) return null;
    try {
      final result = await SupabaseClientFactory.admin.rpc(
        'get_attendance_rates',
        params: {
          'p_outlet_id': outletId,
          'p_start': start.toUtc().toIso8601String(),
          'p_end': end.toUtc().toIso8601String(),
        },
      );
      if (result == null) return null;
      return AttendanceRateData.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[AnalyticsService] getAttendanceRates failed: $e');
      return null;
    }
  }

  /// Returns employees who exceeded the work hours threshold on [date].
  /// Returns empty list if [supabaseReady] is false or if the RPC fails.
  Future<List<OvertimeFlag>> getOvertimeFlags({
    required String outletId,
    DateTime? date,
    double thresholdHours = 8,
  }) async {
    if (!supabaseReady) return [];
    try {
      final queryDate = date ?? DateTime.now();
      final dateStr =
          '${queryDate.year.toString().padLeft(4, '0')}-'
          '${queryDate.month.toString().padLeft(2, '0')}-'
          '${queryDate.day.toString().padLeft(2, '0')}';
      final result = await SupabaseClientFactory.admin.rpc(
        'get_overtime_flags',
        params: {
          'p_outlet_id': outletId,
          'p_date': dateStr,
          'p_threshold_hours': thresholdHours,
        },
      );
      if (result == null) return [];
      return (result as List)
          .map((e) => OvertimeFlag.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[AnalyticsService] getOvertimeFlags failed: $e');
      return [];
    }
  }

  /// Returns employees who clocked in today but have no clock-out after
  /// [thresholdHours] hours.
  /// Returns empty list if [supabaseReady] is false or if the RPC fails.
  Future<List<MissingClockout>> getMissingClockouts({
    required String outletId,
    double thresholdHours = 10,
  }) async {
    if (!supabaseReady) return [];
    try {
      final result = await SupabaseClientFactory.admin.rpc(
        'get_missing_clockouts',
        params: {
          'p_outlet_id': outletId,
          'p_threshold_hours': thresholdHours,
        },
      );
      if (result == null) return [];
      return (result as List)
          .map((e) => MissingClockout.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[AnalyticsService] getMissingClockouts failed: $e');
      return [];
    }
  }

  /// Returns firm-wide central dashboard KPIs for [date].
  /// Returns null if [supabaseReady] is false or if the RPC fails.
  Future<CentralDashboardSummary?> getCentralDashboardSummary({
    required DateTime date,
  }) async {
    if (!supabaseReady) return null;
    try {
      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final result = await SupabaseClientFactory.admin.rpc(
        'get_central_dashboard_summary',
        params: {'p_date': dateStr},
      );
      if (result == null) return null;
      return CentralDashboardSummary.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[AnalyticsService] getCentralDashboardSummary failed: $e');
      return null;
    }
  }

  /// Returns one rollup row per active outlet for [date].
  /// Returns empty list if [supabaseReady] is false or if the RPC fails.
  Future<List<OutletControlCenterRow>> getOutletControlCenter({
    required DateTime date,
  }) async {
    if (!supabaseReady) return [];
    try {
      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final result = await SupabaseClientFactory.admin.rpc(
        'get_outlet_control_center',
        params: {'p_date': dateStr},
      );
      if (result == null) return [];
      return (result as List)
          .map((e) => OutletControlCenterRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[AnalyticsService] getOutletControlCenter failed: $e');
      return [];
    }
  }

  /// Get employee insight data for the chart dashboard.
  ///
  /// Returns aggregated attendance signals per employee for the calendar
  /// month containing today, scoped to [outletId]. Backed by the
  /// `get_site_leaderboard` RPC, which already runs the strict Phase 57
  /// recap engine on the server (so issue/safe day counts here match the
  /// admin leaderboard exactly).
  ///
  /// Returns an empty list if [supabaseReady] is false or if the RPC fails.
  ///
  /// Previously this method tried to aggregate `attendance_logs` row-by-row
  /// in the client. That implementation referenced columns that do not
  /// exist on `attendance_logs` (`outlet_id`, `status`, `is_late`) — the
  /// real columns are `scan_outlet_id` plus a derived `type` (`masuk` /
  /// `pulang`). The per-row error was swallowed by the surrounding try
  /// block, which is why the chart dashboard "Employee Insights" section
  /// silently rendered as empty in production.
  Future<List<EmployeeInsightData>> getEmployeeInsights(String outletId) async {
    if (!supabaseReady) return [];
    try {
      final result = await SupabaseClientFactory.admin.rpc(
        'get_site_leaderboard',
      );
      if (result == null) return [];

      final rows = (result as List).cast<Map<String, dynamic>>();

      return rows
          .where((row) => row['home_outlet_id'] == outletId)
          .map((row) => EmployeeInsightData.fromJson({
                'employee_id': row['employee_id'],
                'employee_name': row['employee_name'],
                'late_count': row['late_count'],
                'absence_count': row['absence_count'],
                'short_work_count': row['short_work_count'],
                'excess_break_count': row['excess_break_count'],
                'overtime_count': row['overtime_count'],
                // safe_days from the recap = days the employee was on duty
                // and triggered no issue signals. Map onto our existing
                // safeCount field to keep the Insight UI unchanged.
                'safe_count': row['safe_days'],
              }))
          .toList();
    } catch (e) {
      debugPrint('[AnalyticsService] getEmployeeInsights failed: $e');
      return [];
    }
  }
}
