import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendancePolicyRecapDay', () {
    test('parses a full strict row with metrics and detail signals', () {
      final recap = AttendancePolicyRecapDay.fromJson({
        'logical_date': '2026-03-26',
        'employee_id': 'emp-1',
        'employee_name': 'Ayu',
        'outlet_id': 'outlet-1',
        'outlet_name': 'Outlet Utama',
        'shift_band': 'PAGI',
        'required_work_minutes': 600,
        'late_cutoff_local': '07:00',
        'break_first_deadline_local': '09:00',
        'attendance_status': 'hadir',
        'late_kind': 'normal',
        'is_late': true,
        'break_first_eligible': false,
        'break_first_confirmed': true,
        'first_scan_local': '2026-03-26T07:14:00',
        'first_break_local': '2026-03-26T12:00:00',
        'last_pulang_local': '2026-03-26T17:10:00',
        'primary_status': 'short_work',
        'primary_severity': 'red',
        'detail_signals': ['late', 'short_work', 'break_first_confirmed'],
        'detail_notes': ['Kurang 45 menit dari target kerja.'],
        'is_manager_exempt': false,
        'manager_position': 'Crew',
        'logical_day_complete': true,
        'incomplete_reason': null,
        'net_work_minutes': 555,
        'total_break_minutes': 45,
        'overtime_minutes': 0,
        'short_work_minutes': 45,
        'excess_break_minutes': 0,
        'paired_break_count': 1,
      });

      expect(recap.primaryStatus, AttendancePolicyPrimaryStatus.shortWork);
      expect(recap.primarySeverity, AttendancePolicySeverity.red);
      expect(recap.detailSignals, contains(AttendancePolicySignal.late));
      expect(
        recap.detailSignals,
        contains(AttendancePolicySignal.breakFirstConfirmed),
      );
      expect(recap.breakFirstConfirmed, isTrue);
      expect(recap.netWorkMinutes, 555);
      expect(recap.shortWorkMinutes, 45);
      expect(recap.pairedBreakCount, 1);
      expect(recap.hasSignal(AttendancePolicySignal.shortWork), isTrue);
      expect(recap.isRedPrimary, isTrue);
      expect(recap.hasAnyPenaltySignals, isTrue);
    });

    test('parses a manager exempt row and keeps suppressed context visible',
        () {
      final recap = AttendancePolicyRecapDay.fromJson({
        'logical_date': '2026-03-25',
        'employee_id': 'emp-2',
        'employee_name': 'Bima',
        'outlet_id': 'outlet-1',
        'outlet_name': 'Outlet Utama',
        'primary_status': 'exempt_manager',
        'primary_severity': 'info',
        'detail_signals': ['late', 'short_work', 'exempt_manager'],
        'detail_notes': [
          'Posisi kepala gerai exempt dari penalti merah telat, kurang jam, dan istirahat berlebih.',
        ],
        'is_manager_exempt': true,
        'manager_position': 'Kepala Gerai',
        'logical_day_complete': true,
        'net_work_minutes': 540,
        'short_work_minutes': 60,
      });

      expect(recap.primaryStatus, AttendancePolicyPrimaryStatus.exemptManager);
      expect(recap.primarySeverity, AttendancePolicySeverity.info);
      expect(recap.isManagerExempt, isTrue);
      expect(recap.managerPosition, 'Kepala Gerai');
      expect(recap.detailSignals, contains(AttendancePolicySignal.late));
      expect(
        recap.detailSignals,
        contains(AttendancePolicySignal.exemptManager),
      );
      expect(recap.attendanceStatus, AttendancePolicyStatus.hadir);
      expect(recap.lateKind, LateKind.normal);
      expect(recap.isRedPrimary, isFalse);
    });

    test('derives legacy compatibility values from a strict-only row', () {
      final recap = AttendancePolicyRecapDay.fromJson({
        'logical_date': '2026-03-24',
        'employee_id': 'emp-3',
        'employee_name': 'Cici',
        'outlet_id': 'outlet-2',
        'outlet_name': 'Outlet Selatan',
        'primary_status': 'overtime',
        'primary_severity': 'yellow',
        'detail_signals': ['overtime', 'hadir_tanpa_jadwal'],
        'detail_notes': [
          'Hadir tanpa jadwal; threshold kontrak tetap diterapkan.'
        ],
        'logical_day_complete': true,
        'net_work_minutes': 690,
        'overtime_minutes': 150,
        'total_break_minutes': 30,
      });

      expect(recap.attendanceStatus, AttendancePolicyStatus.hadirTanpaJadwal);
      expect(recap.primaryStatus, AttendancePolicyPrimaryStatus.overtime);
      expect(recap.primarySeverity, AttendancePolicySeverity.yellow);
      expect(recap.lateKind, LateKind.none);
      expect(recap.breakFirstEligible, isFalse);
      expect(recap.breakFirstConfirmed, isFalse);
      expect(recap.detailSignals, contains(AttendancePolicySignal.overtime));
      expect(
        recap.detailSignals,
        contains(AttendancePolicySignal.hadirTanpaJadwal),
      );
      expect(recap.isYellowPrimary, isTrue);
    });

    test('still parses a legacy phase 56 row without strict fields', () {
      final recap = AttendancePolicyRecapDay.fromJson({
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
        'first_scan_local': '2026-03-27T11:30:00',
        'first_break_local': null,
        'last_pulang_local': '2026-03-27T19:30:00',
        'notes': 'legacy payload',
      });

      expect(recap.primaryStatus, AttendancePolicyPrimaryStatus.hadir);
      expect(recap.attendanceStatus, AttendancePolicyStatus.hadir);
      expect(recap.lateKind, LateKind.breakFirstEligible);
      expect(recap.isLate, isTrue);
      expect(recap.detailNotes, ['legacy payload']);
      expect(recap.requiredWorkMinutes, 540);
    });
  });
}
