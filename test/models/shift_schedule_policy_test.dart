import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';
import 'package:absensi_enakko_flutter/models/shift_schedule.dart';
import 'package:absensi_enakko_flutter/services/schedule_policy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShiftBand', () {
    test('parses legacy title-case and canonical uppercase values', () {
      expect(ShiftBand.parse('Pagi'), ShiftBand.pagi);
      expect(ShiftBand.parse('PAGI'), ShiftBand.pagi);
      expect(ShiftBand.parse('SIANG'), ShiftBand.siang);
      expect(ShiftBand.parse('MALAM'), ShiftBand.malam);
      expect(ShiftBand.parse('Libur'), ShiftBand.libur);
    });
  });

  group('ShiftSlot policy parsing', () {
    test('parses legacy JSON into a band-first shift slot', () {
      final slot = ShiftSlot.fromJson(const {
        'name': 'Pagi',
        'start_hour': 7,
        'start_minute': 0,
        'end_hour': 19,
        'end_minute': 0,
        'color': 4282098230,
      });

      expect(slot.band, ShiftBand.pagi);
      expect(slot.requiredWorkMinutes, 600);
      expect(slot.lateCutoffHour, 7);
      expect(slot.lateCutoffMinute, 0);
      expect(slot.breakFirstDeadlineHour, 9);
      expect(slot.breakFirstDeadlineMinute, 0);
      expect(slot.startTime, const TimeOfDay(hour: 7, minute: 0));
      expect(slot.endTime, const TimeOfDay(hour: 19, minute: 0));
    });

    test('promotes legacy sore 15:00 entries into malam band', () {
      final slot = ShiftSlot.fromJson(const {
        'name': 'Sore',
        'band': 'SORE',
        'start_hour': 15,
        'start_minute': 0,
        'end_hour': 3,
        'end_minute': 0,
      });

      expect(slot.band, ShiftBand.malam);
      expect(slot.lateCutoffHour, 15);
      expect(slot.breakFirstDeadlineHour, 17);
    });

    test('round-trips new JSON policy keys while keeping legacy keys', () {
      final slot = ShiftSlot.fromJson(const {
        'name': 'Siang',
        'band': 'SIANG',
        'required_work_minutes': 540,
        'late_cutoff_hour': 10,
        'late_cutoff_minute': 0,
        'break_first_deadline_hour': 11,
        'break_first_deadline_minute': 0,
        'start_hour': 10,
        'start_minute': 0,
        'end_hour': 21,
        'end_minute': 0,
        'color': 4294283531,
      });

      final json = slot.toJson();
      final restored = ShiftSlot.fromJson(json);

      expect(json['band'], 'SIANG');
      expect(json['required_work_minutes'], 540);
      expect(json['late_cutoff_hour'], 10);
      expect(json['break_first_deadline_hour'], 11);
      expect(json['start_hour'], 10);
      expect(json['end_hour'], 21);
      expect(restored.band, ShiftBand.siang);
      expect(restored.requiredWorkMinutes, 540);
      expect(restored.lateCutoffHour, 10);
      expect(restored.breakFirstDeadlineHour, 11);
    });
  });

  group('SchedulePolicyService', () {
    test('returns the exact locked WITA cutoffs', () {
      expect(
        SchedulePolicyService.lateCutoff(ShiftBand.pagi),
        const TimeOfDay(hour: 7, minute: 0),
      );
      expect(
        SchedulePolicyService.lateCutoff(ShiftBand.siang),
        const TimeOfDay(hour: 10, minute: 0),
      );
      expect(
        SchedulePolicyService.lateCutoff(ShiftBand.sore),
        const TimeOfDay(hour: 13, minute: 0),
      );
      expect(
        SchedulePolicyService.lateCutoff(ShiftBand.malam),
        const TimeOfDay(hour: 15, minute: 0),
      );
      expect(SchedulePolicyService.lateCutoff(ShiftBand.libur), isNull);
    });

    test('returns default required minutes by contract', () {
      expect(
        SchedulePolicyService.defaultRequiredWorkMinutes(
          EmployeeContract.fulltime,
        ),
        600,
      );
      expect(
        SchedulePolicyService.defaultRequiredWorkMinutes(
          EmployeeContract.parttime,
        ),
        480,
      );
    });

    test('calculates break-first deadline and minute-precision lateness', () {
      expect(
        SchedulePolicyService.breakFirstDeadline(
          band: ShiftBand.pagi,
          contract: EmployeeContract.fulltime,
        ),
        const TimeOfDay(hour: 9, minute: 0),
      );
      expect(
        SchedulePolicyService.breakFirstDeadline(
          band: ShiftBand.sore,
          contract: EmployeeContract.parttime,
        ),
        const TimeOfDay(hour: 14, minute: 0),
      );
      expect(
        SchedulePolicyService.isLate(
          logicalDate: DateTime(2026, 3, 26),
          scannedAt: DateTime(2026, 3, 26, 7, 0, 59),
          band: ShiftBand.pagi,
        ),
        isFalse,
      );
      expect(
        SchedulePolicyService.isLate(
          logicalDate: DateTime(2026, 3, 26),
          scannedAt: DateTime(2026, 3, 26, 7, 1),
          band: ShiftBand.pagi,
        ),
        isTrue,
      );
    });
  });
}
