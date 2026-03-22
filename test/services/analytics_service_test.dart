import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_enakko_flutter/services/analytics_service.dart';

void main() {
  group('AnalyticsService', () {
    group('AttendanceRateData.fromJson', () {
      test('parses standard response correctly', () {
        final json = {
          'total_employees': 10,
          'days_in_range': 5,
          'total_present': 40,
          'rate': 80.0,
        };
        final data = AttendanceRateData.fromJson(json);
        expect(data.totalEmployees, 10);
        expect(data.daysInRange, 5);
        expect(data.totalPresent, 40);
        expect(data.rate, 80.0);
      });

      test('handles zero rate (no attendance)', () {
        final json = {
          'total_employees': 5,
          'days_in_range': 3,
          'total_present': 0,
          'rate': 0.0,
        };
        final data = AttendanceRateData.fromJson(json);
        expect(data.totalEmployees, 5);
        expect(data.daysInRange, 3);
        expect(data.totalPresent, 0);
        expect(data.rate, 0.0);
      });

      test('handles perfect attendance (100%)', () {
        final json = {
          'total_employees': 4,
          'days_in_range': 5,
          'total_present': 20,
          'rate': 100.0,
        };
        final data = AttendanceRateData.fromJson(json);
        expect(data.rate, 100.0);
        expect(data.totalPresent, 20);
      });

      test('handles integer rate from JSON (int coerced to double)', () {
        final json = {
          'total_employees': 10,
          'days_in_range': 1,
          'total_present': 8,
          'rate': 80,
        };
        final data = AttendanceRateData.fromJson(json);
        expect(data.rate, 80.0);
      });
    });

    group('OvertimeFlag.fromJson', () {
      test('parses standard overtime flag', () {
        final json = {
          'employee_id': 'uuid-123',
          'employee_name': 'Budi',
          'hours_worked': 10.5,
          'overtime_hours': 2.5,
        };
        final flag = OvertimeFlag.fromJson(json);
        expect(flag.employeeId, 'uuid-123');
        expect(flag.employeeName, 'Budi');
        expect(flag.hoursWorked, 10.5);
        expect(flag.overtimeHours, 2.5);
      });

      test('handles integer hours (int coerced to double)', () {
        final json = {
          'employee_id': 'uuid-456',
          'employee_name': 'Andi',
          'hours_worked': 9,
          'overtime_hours': 1,
        };
        final flag = OvertimeFlag.fromJson(json);
        expect(flag.hoursWorked, 9.0);
        expect(flag.overtimeHours, 1.0);
      });

      test('handles minimum overtime (just over threshold)', () {
        final json = {
          'employee_id': 'uuid-789',
          'employee_name': 'Sari',
          'hours_worked': 8.1,
          'overtime_hours': 0.1,
        };
        final flag = OvertimeFlag.fromJson(json);
        expect(flag.overtimeHours, closeTo(0.1, 0.001));
      });
    });

    group('MissingClockout.fromJson', () {
      test('parses standard missing clockout', () {
        final json = {
          'employee_id': 'uuid-abc',
          'employee_name': 'Andi',
          'masuk_time': '2026-03-18T08:00:00Z',
        };
        final mc = MissingClockout.fromJson(json);
        expect(mc.employeeId, 'uuid-abc');
        expect(mc.employeeName, 'Andi');
        expect(mc.masukTime, DateTime.parse('2026-03-18T08:00:00Z'));
      });

      test('parses masuk_time with timezone offset', () {
        final json = {
          'employee_id': 'uuid-def',
          'employee_name': 'Citra',
          'masuk_time': '2026-03-18T09:30:00+07:00',
        };
        final mc = MissingClockout.fromJson(json);
        expect(mc.masukTime.isUtc || mc.masukTime.timeZoneOffset.inHours == 7,
            isTrue);
      });

      test('handles empty employee name gracefully', () {
        final json = {
          'employee_id': 'uuid-ghi',
          'employee_name': '',
          'masuk_time': '2026-03-18T07:00:00Z',
        };
        final mc = MissingClockout.fromJson(json);
        expect(mc.employeeName, '');
        expect(mc.employeeId, 'uuid-ghi');
      });
    });

    group('CentralDashboardSummary.fromJson', () {
      test('parses standard central dashboard summary', () {
        final json = {
          'total_outlets': 4,
          'connected_devices': 7,
          'offline_devices': 1,
          'low_battery_devices': 2,
          'pending_sync_devices': 1,
          'daily_attendance_rate': 84.6,
        };
        final summary = CentralDashboardSummary.fromJson(json);
        expect(summary.totalOutlets, 4);
        expect(summary.connectedDevices, 7);
        expect(summary.offlineDevices, 1);
        expect(summary.lowBatteryDevices, 2);
        expect(summary.pendingSyncDevices, 1);
        expect(summary.dailyAttendanceRate, closeTo(84.6, 0.001));
      });

      test('handles zero attendance rate (no scans today)', () {
        final json = {
          'total_outlets': 4,
          'connected_devices': 3,
          'offline_devices': 0,
          'low_battery_devices': 0,
          'pending_sync_devices': 0,
          'daily_attendance_rate': 0.0,
        };
        final summary = CentralDashboardSummary.fromJson(json);
        expect(summary.dailyAttendanceRate, 0.0);
        expect(summary.connectedDevices, 3);
      });

      test('coerces integer daily_attendance_rate to double', () {
        final json = {
          'total_outlets': 2,
          'connected_devices': 4,
          'offline_devices': 0,
          'low_battery_devices': 0,
          'pending_sync_devices': 0,
          'daily_attendance_rate': 100,
        };
        final summary = CentralDashboardSummary.fromJson(json);
        expect(summary.dailyAttendanceRate, 100.0);
        expect(summary.dailyAttendanceRate, isA<double>());
      });
    });

    group('OutletControlCenterRow.fromJson', () {
      test('parses standard outlet control center row', () {
        final json = {
          'outlet_id': 'outlet-uuid-001',
          'outlet_name': 'Gerai Panakkukang',
          'connected_devices': 2,
          'offline_devices': 0,
          'low_battery_devices': 1,
          'pending_sync_devices': 0,
          'daily_attendance_rate': 91.7,
          'last_heartbeat_at': '2026-03-22T06:10:00Z',
        };
        final row = OutletControlCenterRow.fromJson(json);
        expect(row.outletId, 'outlet-uuid-001');
        expect(row.outletName, 'Gerai Panakkukang');
        expect(row.connectedDevices, 2);
        expect(row.offlineDevices, 0);
        expect(row.lowBatteryDevices, 1);
        expect(row.pendingSyncDevices, 0);
        expect(row.dailyAttendanceRate, closeTo(91.7, 0.001));
        expect(row.lastHeartbeatAt, DateTime.parse('2026-03-22T06:10:00Z'));
      });

      test('handles nullable last_heartbeat_at', () {
        final json = {
          'outlet_id': 'outlet-uuid-002',
          'outlet_name': 'Gerai Makassar',
          'connected_devices': 0,
          'offline_devices': 0,
          'low_battery_devices': 0,
          'pending_sync_devices': 0,
          'daily_attendance_rate': 0.0,
          'last_heartbeat_at': null,
        };
        final row = OutletControlCenterRow.fromJson(json);
        expect(row.lastHeartbeatAt, isNull);
        expect(row.outletId, 'outlet-uuid-002');
      });

      test('coerces integer daily_attendance_rate to double', () {
        final json = {
          'outlet_id': 'outlet-uuid-003',
          'outlet_name': 'Gerai Gowa',
          'connected_devices': 1,
          'offline_devices': 0,
          'low_battery_devices': 0,
          'pending_sync_devices': 0,
          'daily_attendance_rate': 80,
          'last_heartbeat_at': null,
        };
        final row = OutletControlCenterRow.fromJson(json);
        expect(row.dailyAttendanceRate, 80.0);
        expect(row.dailyAttendanceRate, isA<double>());
      });
    });

    group('AnalyticsService central dashboard methods', () {
      test('getCentralDashboardSummary returns null when supabaseReady is false', () async {
        final result = await AnalyticsService.instance.getCentralDashboardSummary(
          date: DateTime(2026, 3, 22),
        );
        expect(result, isNull);
      });

      test('getOutletControlCenter returns empty list when supabaseReady is false', () async {
        final result = await AnalyticsService.instance.getOutletControlCenter(
          date: DateTime(2026, 3, 22),
        );
        expect(result, isEmpty);
      });
    });

    group('AnalyticsService singleton', () {
      test('instance is a singleton', () {
        final a = AnalyticsService.instance;
        final b = AnalyticsService.instance;
        expect(identical(a, b), isTrue);
      });

      test('getAttendanceRates returns null when supabaseReady is false', () async {
        // supabaseReady defaults to false in test environment (no Supabase.initialize)
        final result = await AnalyticsService.instance.getAttendanceRates(
          outletId: 'test-outlet',
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 3, 7),
        );
        expect(result, isNull);
      });

      test('getOvertimeFlags returns empty list when supabaseReady is false', () async {
        final result = await AnalyticsService.instance.getOvertimeFlags(
          outletId: 'test-outlet',
        );
        expect(result, isEmpty);
      });

      test('getMissingClockouts returns empty list when supabaseReady is false', () async {
        final result = await AnalyticsService.instance.getMissingClockouts(
          outletId: 'test-outlet',
        );
        expect(result, isEmpty);
      });
    });
  });
}
