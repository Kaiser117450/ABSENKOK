import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/outlet_operating_mode.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/outlet.dart';

void main() {
  group('EmployeeContract', () {
    test('parses canonical FULLTIME', () {
      expect(EmployeeContract.parse('FULLTIME'), EmployeeContract.fulltime);
    });

    test('parses canonical PARTTIME', () {
      expect(EmployeeContract.parse('PARTTIME'), EmployeeContract.parttime);
    });

    test('normalizes lowercase fulltime', () {
      expect(EmployeeContract.parse('fulltime'), EmployeeContract.fulltime);
    });

    test('normalizes mixed case PartTime', () {
      expect(EmployeeContract.parse('PartTime'), EmployeeContract.parttime);
    });

    test('normalizes common alias PARTIME (single T)', () {
      expect(EmployeeContract.parse('PARTIME'), EmployeeContract.parttime);
    });

    test('normalizes hyphenated part-time', () {
      expect(EmployeeContract.parse('part-time'), EmployeeContract.parttime);
    });

    test('normalizes hyphenated full-time', () {
      expect(EmployeeContract.parse('full-time'), EmployeeContract.fulltime);
    });

    test('falls back to fulltime for null', () {
      expect(EmployeeContract.parse(null), EmployeeContract.fulltime);
    });

    test('falls back to fulltime for unknown string', () {
      expect(EmployeeContract.parse('INTERN'), EmployeeContract.fulltime);
    });

    test('dbValue returns canonical uppercase', () {
      expect(EmployeeContract.fulltime.dbValue, 'FULLTIME');
      expect(EmployeeContract.parttime.dbValue, 'PARTTIME');
    });

    test('label returns human-readable text', () {
      expect(EmployeeContract.fulltime.label, 'Full-Time');
      expect(EmployeeContract.parttime.label, 'Part-Time');
    });
  });

  group('OutletOperatingMode', () {
    test('parses canonical NORMAL', () {
      expect(OutletOperatingMode.parse('NORMAL'), OutletOperatingMode.normal);
    });

    test('parses canonical TWENTY_FOUR_HOUR', () {
      expect(OutletOperatingMode.parse('TWENTY_FOUR_HOUR'),
          OutletOperatingMode.twentyFourHour);
    });

    test('normalizes lowercase', () {
      expect(
          OutletOperatingMode.parse('normal'), OutletOperatingMode.normal);
      expect(OutletOperatingMode.parse('twenty_four_hour'),
          OutletOperatingMode.twentyFourHour);
    });

    test('falls back to normal for null', () {
      expect(OutletOperatingMode.parse(null), OutletOperatingMode.normal);
    });

    test('falls back to normal for unknown string', () {
      expect(OutletOperatingMode.parse('EXTENDED'), OutletOperatingMode.normal);
    });

    test('dbValue returns canonical uppercase', () {
      expect(OutletOperatingMode.normal.dbValue, 'NORMAL');
      expect(OutletOperatingMode.twentyFourHour.dbValue, 'TWENTY_FOUR_HOUR');
    });

    test('label returns human-readable text', () {
      expect(OutletOperatingMode.normal.label, 'Normal');
      expect(OutletOperatingMode.twentyFourHour.label, '24 Jam');
    });
  });

  group('Employee with employmentContract', () {
    final baseJson = {
      'id': 'emp-1',
      'name': 'Budi',
      'is_active': true,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };

    test('fromJson parses employment_contract field', () {
      final json = {...baseJson, 'employment_contract': 'PARTTIME'};
      final emp = Employee.fromJson(json);
      expect(emp.employmentContract, EmployeeContract.parttime);
    });

    test('fromJson defaults to fulltime when field is null', () {
      final emp = Employee.fromJson(baseJson);
      expect(emp.employmentContract, EmployeeContract.fulltime);
    });

    test('toJson emits employment_contract', () {
      final json = {...baseJson, 'employment_contract': 'PARTTIME'};
      final emp = Employee.fromJson(json);
      final out = emp.toJson();
      expect(out['employment_contract'], 'PARTTIME');
    });

    test('round-trip preserves employment_contract', () {
      final json = {...baseJson, 'employment_contract': 'FULLTIME'};
      final emp = Employee.fromJson(json);
      final roundTripped = Employee.fromJson(emp.toJson());
      expect(roundTripped.employmentContract, EmployeeContract.fulltime);
    });

    test('copyWith can change employmentContract', () {
      final emp = Employee.fromJson(baseJson);
      final updated =
          emp.copyWith(employmentContract: EmployeeContract.parttime);
      expect(updated.employmentContract, EmployeeContract.parttime);
      expect(updated.name, 'Budi'); // other fields preserved
    });

    test('existing required fields still parse correctly', () {
      final emp = Employee.fromJson(baseJson);
      expect(emp.id, 'emp-1');
      expect(emp.name, 'Budi');
      expect(emp.isActive, true);
    });
  });

  group('Outlet with operatingMode', () {
    final baseJson = {
      'id': 'out-1',
      'name': 'Enakko Sudiang',
      'is_active': true,
      'created_at': '2026-01-01T00:00:00Z',
    };

    test('fromJson parses operating_mode field', () {
      final json = {...baseJson, 'operating_mode': 'TWENTY_FOUR_HOUR'};
      final outlet = Outlet.fromJson(json);
      expect(outlet.operatingMode, OutletOperatingMode.twentyFourHour);
    });

    test('fromJson defaults to normal when field is null', () {
      final outlet = Outlet.fromJson(baseJson);
      expect(outlet.operatingMode, OutletOperatingMode.normal);
    });

    test('toJson emits operating_mode', () {
      final json = {...baseJson, 'operating_mode': 'TWENTY_FOUR_HOUR'};
      final outlet = Outlet.fromJson(json);
      final out = outlet.toJson();
      expect(out['operating_mode'], 'TWENTY_FOUR_HOUR');
    });

    test('round-trip preserves operating_mode', () {
      final json = {...baseJson, 'operating_mode': 'NORMAL'};
      final outlet = Outlet.fromJson(json);
      final roundTripped = Outlet.fromJson(outlet.toJson());
      expect(roundTripped.operatingMode, OutletOperatingMode.normal);
    });

    test('existing required fields still parse correctly', () {
      final outlet = Outlet.fromJson(baseJson);
      expect(outlet.id, 'out-1');
      expect(outlet.name, 'Enakko Sudiang');
      expect(outlet.isActive, true);
    });
  });
}
