import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';
import 'package:absensi_enakko_flutter/models/shift_schedule.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';

/// Phase 8 — Schedule System Validation Tests
/// Tests model serialization, date handling, and entry logic
/// that underpin the Supabase-first load / SQLite cache architecture.

Employee _makeEmployee(String id, String name) => Employee(
      id: id,
      name: name,
      isActive: true,
      createdAt: '2024-01-01',
      updatedAt: '2024-01-01',
    );

OutletSchedule _makeSchedule({
  String id = 'sched-1',
  String outletId = 'outlet-1',
  DateTime? start,
  DateTime? end,
  List<ScheduleEntry>? entries,
  DateTime? syncedAt,
}) {
  return OutletSchedule(
    id: id,
    outletId: outletId,
    startDate: start ?? DateTime(2024, 3, 4),
    endDate: end ?? DateTime(2024, 3, 10),
    template: ShiftTemplate.standard(outletId),
    entries: entries ?? [],
    createdAt: DateTime(2024, 3, 1),
    syncedAt: syncedAt,
  );
}

void main() {
  group('ShiftSlot factories', () {
    test('pagi shift has correct name and time range', () {
      final pagi = ShiftSlot.pagi();
      expect(pagi.name, 'Pagi');
      expect(pagi.startTime, const TimeOfDay(hour: 7, minute: 0));
      expect(pagi.endTime, const TimeOfDay(hour: 19, minute: 0));
    });

    test('siang shift has correct name and time range', () {
      final siang = ShiftSlot.siang();
      expect(siang.name, 'Siang');
      expect(siang.startTime, const TimeOfDay(hour: 10, minute: 0));
      expect(siang.endTime, const TimeOfDay(hour: 22, minute: 0));
    });

    test('sore shift has correct name and time range', () {
      final sore = ShiftSlot.sore();
      expect(sore.name, 'Sore');
      expect(sore.startTime, const TimeOfDay(hour: 13, minute: 0));
      expect(sore.endTime, const TimeOfDay(hour: 1, minute: 0));
    });

    test('malam shift has correct name and time range', () {
      final malam = ShiftSlot.malam();
      expect(malam.name, 'Malam');
      expect(malam.startTime, const TimeOfDay(hour: 15, minute: 0));
      expect(malam.endTime, const TimeOfDay(hour: 3, minute: 0));
    });

    test('libur shift has name Libur and zero times', () {
      final libur = ShiftSlot.libur();
      expect(libur.name, 'Libur');
      expect(libur.startTime, const TimeOfDay(hour: 0, minute: 0));
      expect(libur.endTime, const TimeOfDay(hour: 0, minute: 0));
    });
  });

  group('ShiftSlot serialization', () {
    test('toJson → fromJson round-trips correctly', () {
      final original = ShiftSlot.pagi();
      final json = original.toJson();
      final restored = ShiftSlot.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.startTime, original.startTime);
      expect(restored.endTime, original.endTime);
    });
  });

  group('ScheduleEntry factories', () {
    test('fromEmployee creates entry with correct employee binding', () {
      final emp = _makeEmployee('emp-1', 'Alice');
      final entry = ScheduleEntry.fromEmployee(
        id: 'entry-1',
        date: DateTime(2024, 3, 4),
        employee: emp,
        shift: ShiftSlot.pagi(),
      );

      expect(entry.employeeId, 'emp-1');
      expect(entry.displayName, 'Alice');
      expect(entry.isCustomName, false);
      expect(entry.isDayOff, false);
      expect(entry.status, ScheduleStatus.normal);
    });

    test('sakit entry has correct status and display name', () {
      final emp = _makeEmployee('emp-1', 'Alice');
      final entry = ScheduleEntry.sakit(
        id: 'entry-2',
        date: DateTime(2024, 3, 5),
        employee: emp,
        shift: ShiftSlot.pagi(),
        notes: 'Demam',
      );

      expect(entry.status, ScheduleStatus.sakit);
      expect(entry.displayName, 'Alice (SAKIT)');
      expect(entry.isDayOff, true);
      expect(entry.notes, 'Demam');
    });

    test('izin entry has correct status and display name', () {
      final emp = _makeEmployee('emp-2', 'Bob');
      final entry = ScheduleEntry.izin(
        id: 'entry-3',
        date: DateTime(2024, 3, 6),
        employee: emp,
        shift: ShiftSlot.siang(),
      );

      expect(entry.status, ScheduleStatus.izin);
      expect(entry.displayName, 'Bob (IZIN)');
      expect(entry.isDayOff, true);
    });

    test('dayOff entry has libur status', () {
      final entry = ScheduleEntry.dayOff(
        id: 'entry-4',
        date: DateTime(2024, 3, 7),
        shift: ShiftSlot.libur(),
      );

      expect(entry.status, ScheduleStatus.libur);
      expect(entry.displayName, 'LIBUR');
      expect(entry.isDayOff, true);
    });
  });

  group('ScheduleEntry serialization', () {
    test('toJson → fromJson round-trips for normal entry', () {
      final emp = _makeEmployee('emp-1', 'Alice');
      final original = ScheduleEntry.fromEmployee(
        id: 'entry-1',
        date: DateTime(2024, 3, 4),
        employee: emp,
        shift: ShiftSlot.pagi(),
      );

      final json = original.toJson();
      final restored = ScheduleEntry.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.employeeId, original.employeeId);
      expect(restored.displayName, original.displayName);
      expect(restored.shift.name, original.shift.name);
      expect(restored.status, ScheduleStatus.normal);
    });

    test('toJson → fromJson preserves sakit status', () {
      final emp = _makeEmployee('emp-1', 'Alice');
      final original = ScheduleEntry.sakit(
        id: 'entry-2',
        date: DateTime(2024, 3, 5),
        employee: emp,
        shift: ShiftSlot.pagi(),
        notes: 'Flu',
      );

      final json = original.toJson();
      final restored = ScheduleEntry.fromJson(json);

      expect(restored.status, ScheduleStatus.sakit);
      expect(restored.notes, 'Flu');
      expect(restored.isDayOff, true);
    });

    test('fromJson with null status defaults to normal', () {
      final json = {
        'id': 'entry-x',
        'date': '2024-03-04T00:00:00.000',
        'employee_id': 'emp-1',
        'custom_name': null,
        'display_name': 'Alice',
        'is_custom_name': false,
        'shift': ShiftSlot.pagi().toJson(),
        'is_day_off': false,
        'status': null,
        'notes': null,
      };
      final entry = ScheduleEntry.fromJson(json);
      expect(entry.status, ScheduleStatus.normal);
    });
  });

  group('OutletSchedule', () {
    test('24 hour template includes malam slot', () {
      final template = ShiftTemplate.twentyFourHour('outlet-24');
      expect(
        template.slots.map((slot) => slot.band).toList(),
        [ShiftBand.pagi, ShiftBand.siang, ShiftBand.sore, ShiftBand.malam],
      );
    });

    test('isDraft returns true when syncedAt is null', () {
      final schedule = _makeSchedule(syncedAt: null);
      expect(schedule.isDraft, true);
    });

    test('isDraft returns false when syncedAt is set', () {
      final schedule = _makeSchedule(syncedAt: DateTime(2024, 3, 2));
      expect(schedule.isDraft, false);
    });

    test('isWeekly returns true for 7-day range', () {
      final schedule = _makeSchedule(
        start: DateTime(2024, 3, 4),
        end: DateTime(2024, 3, 10),
      );
      expect(schedule.isWeekly, true);
    });

    test('isWeekly returns false for 14-day range', () {
      final schedule = _makeSchedule(
        start: DateTime(2024, 3, 1),
        end: DateTime(2024, 3, 14),
      );
      expect(schedule.isWeekly, false);
    });

    test('getEntriesForDate filters by date correctly', () {
      final emp = _makeEmployee('emp-1', 'Alice');
      final entries = [
        ScheduleEntry.fromEmployee(
          id: 'e1',
          date: DateTime(2024, 3, 4),
          employee: emp,
          shift: ShiftSlot.pagi(),
        ),
        ScheduleEntry.fromEmployee(
          id: 'e2',
          date: DateTime(2024, 3, 5),
          employee: emp,
          shift: ShiftSlot.siang(),
        ),
        ScheduleEntry.fromEmployee(
          id: 'e3',
          date: DateTime(2024, 3, 4),
          employee: _makeEmployee('emp-2', 'Bob'),
          shift: ShiftSlot.sore(),
        ),
      ];

      final schedule = _makeSchedule(entries: entries);
      final march4 = schedule.getEntriesForDate(DateTime(2024, 3, 4));

      expect(march4.length, 2);
      expect(march4.map((e) => e.id).toList()..sort(), ['e1', 'e3']);
    });

    test('toJson → fromJson round-trips OutletSchedule', () {
      final emp = _makeEmployee('emp-1', 'Alice');
      final original = _makeSchedule(
        entries: [
          ScheduleEntry.fromEmployee(
            id: 'e1',
            date: DateTime(2024, 3, 4),
            employee: emp,
            shift: ShiftSlot.pagi(),
          ),
        ],
        syncedAt: DateTime(2024, 3, 2),
      );

      final json = original.toJson();
      final restored = OutletSchedule.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.outletId, original.outletId);
      expect(restored.entries.length, 1);
      expect(restored.isDraft, false);
      expect(restored.isActive, true);
    });
  });

  group('Date normalization — SQLite split(T)[0] pattern', () {
    test('toIso8601String().split(T)[0] produces yyyy-MM-dd', () {
      // Validates the date normalization pattern used in
      // schedule_sqlite_service.dart saveSchedule and getSchedule
      final date = DateTime(2024, 3, 4, 15, 30, 45);
      final normalized = date.toIso8601String().split('T')[0];
      expect(normalized, '2024-03-04');
    });

    test('DateTime.parse can parse date-only string from SQLite', () {
      // Validates that _mapToSchedule can parse stored yyyy-MM-dd
      final dateStr = '2024-03-04';
      final parsed = DateTime.parse(dateStr);
      expect(parsed.year, 2024);
      expect(parsed.month, 3);
      expect(parsed.day, 4);
    });

    test('round-trip: DateTime → split(T)[0] → parse matches original date',
        () {
      final original = DateTime(2024, 12, 31, 23, 59, 59);
      final normalized = original.toIso8601String().split('T')[0];
      final parsed = DateTime.parse(normalized);

      expect(parsed.year, original.year);
      expect(parsed.month, original.month);
      expect(parsed.day, original.day);
    });

    test('two DateTimes on same day normalize to same string', () {
      final morning = DateTime(2024, 3, 4, 8, 0);
      final evening = DateTime(2024, 3, 4, 22, 0);

      final normMorning = morning.toIso8601String().split('T')[0];
      final normEvening = evening.toIso8601String().split('T')[0];

      expect(normMorning, normEvening);
      expect(normMorning, '2024-03-04');
    });
  });

  group('ScheduleStatus extension', () {
    test('label returns correct Indonesian labels', () {
      expect(ScheduleStatus.normal.label, 'Masuk');
      expect(ScheduleStatus.sakit.label, 'Sakit');
      expect(ScheduleStatus.izin.label, 'Izin');
      expect(ScheduleStatus.libur.label, 'Libur');
      expect(ScheduleStatus.cuti.label, 'Cuti');
    });

    test('color returns distinct Color for each status', () {
      final colors = ScheduleStatus.values.map((s) => s.color).toSet();
      // All 5 statuses should have unique colors
      expect(colors.length, 5);
    });
  });
}
