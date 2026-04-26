import 'package:absensi_enakko_flutter/models/attendance_policy_recap_day.dart';
import 'package:absensi_enakko_flutter/models/attendance_policy_signal.dart';
import 'package:absensi_enakko_flutter/services/attendance_policy_recap_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendancePolicyRecapService', () {
    test('unwraps nested strict recap rows and maps arrays into typed enums',
        () {
      final rows = AttendancePolicyRecapService.parseRows({
        'data': {
          'data': [
            {
              'logical_date': '2026-03-26',
              'employee_id': 'emp-1',
              'employee_name': 'Ayu',
              'outlet_id': 'outlet-1',
              'outlet_name': 'Outlet 24 Jam',
              'shift_band': 'SORE',
              'required_work_minutes': 540,
              'late_cutoff_local': '15:00',
              'break_first_deadline_local': '17:00',
              'attendance_status': 'hadir',
              'late_kind': 'none',
              'is_late': false,
              'break_first_eligible': false,
              'break_first_confirmed': false,
              'first_scan_local': '2026-03-26T15:10:00',
              'first_break_local': '2026-03-26T21:00:00',
              'last_pulang_local': '2026-03-27T01:30:00',
              'primary_status': 'overtime',
              'primary_severity': 'yellow',
              'detail_signals': ['overtime'],
              'detail_notes': ['Lembur 60 menit di atas target kerja.'],
              'logical_day_complete': true,
              'net_work_minutes': 600,
              'total_break_minutes': 40,
              'overtime_minutes': 60,
              'short_work_minutes': 0,
              'excess_break_minutes': 0,
              'paired_break_count': 1,
            },
            {
              'logical_date': '2026-03-25',
              'employee_id': 'emp-2',
              'employee_name': 'Bima',
              'outlet_id': 'outlet-1',
              'outlet_name': 'Outlet Utama',
              'primary_status': 'exempt_manager',
              'primary_severity': 'info',
              'detail_signals': ['late', 'exempt_manager'],
              'detail_notes': [
                'Posisi kepala gerai exempt dari penalti merah telat, kurang jam, dan istirahat berlebih.',
              ],
              'is_manager_exempt': true,
              'manager_position': 'Kepala Gerai',
              'logical_day_complete': true,
              'net_work_minutes': 540,
              'total_break_minutes': 30,
              'overtime_minutes': 0,
              'short_work_minutes': 60,
              'excess_break_minutes': 0,
            },
            {
              'logical_date': '2026-03-24',
              'employee_id': 'emp-3',
              'employee_name': 'Cici',
              'outlet_id': 'outlet-1',
              'outlet_name': 'Outlet Utama',
              'primary_status': 'belum_absen_pulang',
              'primary_severity': 'red',
              'detail_signals': ['belum_absen_pulang'],
              'detail_notes': [
                'Chain selesai tanpa kembali atau clock-out yang cocok.'
              ],
              'logical_day_complete': true,
              'net_work_minutes': 0,
              'total_break_minutes': 15,
              'overtime_minutes': 0,
              'short_work_minutes': 0,
              'excess_break_minutes': 0,
            },
          ],
        },
      });

      expect(rows, hasLength(3));

      expect(rows[0].logicalDate.toIso8601String().startsWith('2026-03-26'),
          isTrue);
      expect(rows[0].primaryStatus, AttendancePolicyPrimaryStatus.overtime);
      expect(rows[0].detailSignals, [AttendancePolicySignal.overtime]);
      expect(rows[0].netWorkMinutes, 600);
      expect(rows[0].overtimeMinutes, 60);

      expect(rows[1].isManagerExempt, isTrue);
      expect(rows[1].managerPosition, 'Kepala Gerai');
      expect(
          rows[1].primaryStatus, AttendancePolicyPrimaryStatus.exemptManager);
      expect(rows[1].detailSignals, contains(AttendancePolicySignal.late));

      expect(
        rows[2].primaryStatus,
        AttendancePolicyPrimaryStatus.belumAbsenPulang,
      );
      expect(
        rows[2].detailSignals,
        contains(AttendancePolicySignal.belumAbsenPulang),
      );
    });

    test('supports single-row maps and legacy phase 56 rows', () {
      final strictSingle = AttendancePolicyRecapService.parseRows({
        'employee_id': 'emp-4',
        'employee_name': 'Dedi',
        'outlet_id': 'outlet-2',
        'outlet_name': 'Outlet Selatan',
        'logical_date': '2026-03-23',
        'primary_status': 'overtime',
        'primary_severity': 'yellow',
        'detail_signals': ['overtime', 'hadir_tanpa_jadwal'],
        'net_work_minutes': 690,
        'overtime_minutes': 150,
      });

      final legacyRows = AttendancePolicyRecapService.parseRows([
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

      expect(strictSingle, hasLength(1));
      expect(strictSingle.first.primaryStatus,
          AttendancePolicyPrimaryStatus.overtime);
      expect(
        strictSingle.first.detailSignals,
        contains(AttendancePolicySignal.hadirTanpaJadwal),
      );
      expect(strictSingle.first.attendanceStatus,
          AttendancePolicyStatus.hadirTanpaJadwal);

      expect(legacyRows, hasLength(1));
      expect(legacyRows.first.lateKind, LateKind.none);
      expect(
        legacyRows.first.primaryStatus,
        AttendancePolicyPrimaryStatus.hadir,
      );
    });
  });
}
