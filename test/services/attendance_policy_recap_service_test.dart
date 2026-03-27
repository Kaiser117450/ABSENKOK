import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/services/attendance_policy_recap_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendancePolicyRecapService', () {
    test('parses belum_masuk vs tidak_hadir and preserves policy payload', () {
      final rows = AttendancePolicyRecapService.parseRows([
        {
          'logical_date': '2026-03-27',
          'employee_id': 'emp-1',
          'employee_name': 'Ayu',
          'outlet_id': 'outlet-1',
          'outlet_name': 'Outlet Utama',
          'shift_band': 'PAGI',
          'required_work_minutes': 600,
          'late_cutoff_local': '07:00',
          'break_first_deadline_local': '09:00',
          'attendance_status': 'belum_masuk',
          'late_kind': 'none',
          'is_late': false,
          'break_first_eligible': false,
          'break_first_confirmed': false,
          'first_scan_local': null,
          'first_break_local': null,
          'last_pulang_local': null,
          'notes': null,
        },
        {
          'logical_date': '2026-03-26',
          'employee_id': 'emp-2',
          'employee_name': 'Bima',
          'outlet_id': 'outlet-1',
          'outlet_name': 'Outlet Utama',
          'shift_band': 'SIANG',
          'required_work_minutes': 540,
          'late_cutoff_local': '10:00',
          'break_first_deadline_local': '12:00',
          'attendance_status': 'tidak_hadir',
          'late_kind': 'none',
          'is_late': false,
          'break_first_eligible': false,
          'break_first_confirmed': false,
          'first_scan_local': null,
          'first_break_local': null,
          'last_pulang_local': null,
          'notes': 'shift policy',
        },
      ]);

      expect(rows, hasLength(2));
      expect(rows.first.attendanceStatus, AttendancePolicyStatus.belumMasuk);
      expect(rows.last.attendanceStatus, AttendancePolicyStatus.tidakHadir);
      expect(rows.first.requiredWorkMinutes, 600);
      expect(rows.first.lateCutoffLocal, '07:00');
      expect(rows.last.requiredWorkMinutes, 540);
      expect(rows.last.breakFirstDeadlineLocal, '12:00');
      expect(rows.last.notes, 'shift policy');
    });

    test('parses late_kind values and keeps break-first eligible distinct', () {
      final rows = AttendancePolicyRecapService.parseRows([
        {
          'logical_date': '2026-03-27',
          'employee_id': 'emp-3',
          'employee_name': 'Cici',
          'outlet_id': 'outlet-2',
          'outlet_name': 'Outlet Selatan',
          'shift_band': 'SIANG',
          'required_work_minutes': 540,
          'late_cutoff_local': '10:00',
          'break_first_deadline_local': '12:00',
          'attendance_status': 'hadir',
          'late_kind': 'normal',
          'is_late': true,
          'break_first_eligible': false,
          'break_first_confirmed': false,
          'first_scan_local': '2026-03-27T10:15:00',
          'first_break_local': null,
          'last_pulang_local': '2026-03-27T18:00:00',
          'notes': null,
        },
        {
          'logical_date': '2026-03-27',
          'employee_id': 'emp-4',
          'employee_name': 'Dedi',
          'outlet_id': 'outlet-2',
          'outlet_name': 'Outlet Selatan',
          'shift_band': 'SIANG',
          'required_work_minutes': 540,
          'late_cutoff_local': '10:00',
          'break_first_deadline_local': '12:00',
          'attendance_status': 'hadir',
          'late_kind': 'break_first_eligible',
          'is_late': true,
          'break_first_eligible': true,
          'break_first_confirmed': false,
          'first_scan_local': '2026-03-27T11:59:00',
          'first_break_local': null,
          'last_pulang_local': '2026-03-27T19:00:00',
          'notes': null,
        },
        {
          'logical_date': '2026-03-27',
          'employee_id': 'emp-5',
          'employee_name': 'Eka',
          'outlet_id': 'outlet-2',
          'outlet_name': 'Outlet Selatan',
          'shift_band': 'SIANG',
          'required_work_minutes': 540,
          'late_cutoff_local': '10:00',
          'break_first_deadline_local': '12:00',
          'attendance_status': 'hadir',
          'late_kind': 'break_first_confirmed',
          'is_late': true,
          'break_first_eligible': false,
          'break_first_confirmed': true,
          'first_scan_local': '2026-03-27T11:45:00',
          'first_break_local': null,
          'last_pulang_local': '2026-03-27T19:15:00',
          'notes': null,
        },
      ]);

      expect(rows[0].lateKind, LateKind.normal);
      expect(rows[1].lateKind, LateKind.breakFirstEligible);
      expect(rows[1].breakFirstEligible, isTrue);
      expect(rows[1].breakFirstConfirmed, isFalse);
      expect(rows[2].lateKind, LateKind.breakFirstConfirmed);
      expect(rows[2].breakFirstConfirmed, isTrue);
      expect(rows[1].isLate, isTrue);
      expect(rows[2].requiredWorkMinutes, 540);
      expect(rows[2].lateCutoffLocal, '10:00');
    });
  });
}
