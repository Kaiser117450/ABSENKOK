import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_enakko_flutter/models/csv_import_result.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/services/csv_import_service.dart';

/// Helper: encode a CSV string into UTF-8 bytes.
Uint8List _csvBytes(String csv) => Uint8List.fromList(utf8.encode(csv));

/// Helper: encode a CSV string with BOM prefix.
Uint8List _csvBytesWithBom(String csv) =>
    Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);

void main() {
  // --- Outlet lookup maps used throughout tests ---
  final outletNameToId = {
    'enakko sudirman': 'uuid-sudirman',
    'enakko margonda': 'uuid-margonda',
  };
  final outletNameDisplay = {
    'enakko sudirman': 'Enakko Sudirman',
    'enakko margonda': 'Enakko Margonda',
  };

  group('CsvImportService', () {
    // ================================================================
    // parseBytes
    // ================================================================
    group('parseBytes', () {
      test('parses valid 5-column CSV with 3 rows', () {
        final csv = 'nama,jabatan,gerai,kontrak,foto_url\n'
            'Ahmad Fauzi,Kasir,Enakko Sudirman,FULLTIME,\n'
            'Budi Santoso,Koki,Enakko Margonda,PARTTIME,https://example.com/b.jpg\n'
            'Citra Dewi,,Enakko Sudirman,fulltime,\n';
        final rows = CsvImportService.parseBytes(_csvBytes(csv));
        expect(rows.length, 3);
        expect(rows[0].nama, 'Ahmad Fauzi');
        expect(rows[0].jabatan, 'Kasir');
        expect(rows[0].gerai, 'Enakko Sudirman');
        expect(rows[0].kontrak, 'FULLTIME');
        expect(rows[0].fotoUrl, isNull);
        expect(rows[0].rowNumber, 1);
        expect(rows[1].nama, 'Budi Santoso');
        expect(rows[1].kontrak, 'PARTTIME');
        expect(rows[1].fotoUrl, 'https://example.com/b.jpg');
        expect(rows[1].rowNumber, 2);
        expect(rows[2].jabatan, isNull);
        expect(rows[2].kontrak, 'fulltime');
        expect(rows[2].rowNumber, 3);
      });

      test('strips UTF-8 BOM from first header', () {
        final csv = 'nama,jabatan,gerai,kontrak,foto_url\n'
            'Test Name,Kasir,Enakko Sudirman,FULLTIME,\n';
        final rows = CsvImportService.parseBytes(_csvBytesWithBom(csv));
        expect(rows.length, 1);
        expect(rows[0].nama, 'Test Name');
      });

      test('handles quoted fields with commas', () {
        final csv = 'nama,jabatan,gerai,kontrak,foto_url\n'
            '"Eko, Prasetyo",Kasir,Enakko Sudirman,FULLTIME,\n';
        final rows = CsvImportService.parseBytes(_csvBytes(csv));
        expect(rows.length, 1);
        expect(rows[0].nama, 'Eko, Prasetyo');
      });

      test('filters trailing empty rows', () {
        final csv = 'nama,jabatan,gerai,kontrak,foto_url\n'
            'Ahmad Fauzi,Kasir,Enakko Sudirman,FULLTIME,\n'
            ',,,,\n'
            '\n';
        final rows = CsvImportService.parseBytes(_csvBytes(csv));
        expect(rows.length, 1);
        expect(rows[0].nama, 'Ahmad Fauzi');
      });

      test('throws on CSV with no data rows', () {
        final csv = 'nama,jabatan,gerai,kontrak,foto_url\n';
        expect(
          () => CsvImportService.parseBytes(_csvBytes(csv)),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on CSV with wrong headers', () {
        final csv = 'name,position,outlet,contract,photo\n'
            'Ahmad,Kasir,Enakko,FULLTIME,\n';
        expect(
          () => CsvImportService.parseBytes(_csvBytes(csv)),
          throwsA(isA<FormatException>()),
        );
      });

      test('rejects legacy 4-column CSV without kontrak', () {
        final csv = 'nama,jabatan,gerai,foto_url\n'
            'Ahmad Fauzi,Kasir,Enakko Sudirman,\n';
        expect(
          () => CsvImportService.parseBytes(_csvBytes(csv)),
          throwsA(isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('kontrak'),
          )),
        );
      });

      test('headers are matched case-insensitively', () {
        final csv = 'Nama,Jabatan,Gerai,Kontrak,Foto_Url\n'
            'Ahmad Fauzi,Kasir,Enakko Sudirman,FULLTIME,\n';
        final rows = CsvImportService.parseBytes(_csvBytes(csv));
        expect(rows.length, 1);
        expect(rows[0].nama, 'Ahmad Fauzi');
        expect(rows[0].kontrak, 'FULLTIME');
      });
    });

    // ================================================================
    // validate
    // ================================================================
    group('validate', () {
      test('valid row with contract returns isValid=true', () {
        final rows = [
          CsvRow(
            rowNumber: 1,
            nama: 'Ahmad Fauzi',
            gerai: 'Enakko Sudirman',
            kontrak: 'FULLTIME',
          ),
        ];
        final results = CsvImportService.validate(
          rows: rows,
          outletNameToId: outletNameToId,
          outletNameDisplay: outletNameDisplay,
          existingEmployeeKeys: {},
        );
        expect(results.length, 1);
        expect(results[0].isValid, isTrue);
        expect(results[0].resolvedOutletId, 'uuid-sudirman');
        expect(results[0].resolvedOutletName, 'Enakko Sudirman');
        expect(results[0].resolvedContract, EmployeeContract.fulltime);
      });

      test('normalizes contract aliases', () {
        final aliases = {
          'PARTIME': EmployeeContract.parttime,
          'part-time': EmployeeContract.parttime,
          'Part-Time': EmployeeContract.parttime,
          'PARTTIME': EmployeeContract.parttime,
          'full-time': EmployeeContract.fulltime,
          'FULLTIME': EmployeeContract.fulltime,
          'FullTime': EmployeeContract.fulltime,
        };
        for (final entry in aliases.entries) {
          final rows = [
            CsvRow(
              rowNumber: 1,
              nama: 'Test Employee',
              gerai: 'Enakko Sudirman',
              kontrak: entry.key,
            ),
          ];
          final results = CsvImportService.validate(
            rows: rows,
            outletNameToId: outletNameToId,
            outletNameDisplay: outletNameDisplay,
            existingEmployeeKeys: {},
          );
          expect(results[0].isValid, isTrue,
              reason: 'alias "${entry.key}" should be valid');
          expect(results[0].resolvedContract, entry.value,
              reason:
                  'alias "${entry.key}" should normalize to ${entry.value}');
        }
      });

      test('empty kontrak returns error', () {
        final rows = [
          CsvRow(
            rowNumber: 1,
            nama: 'Ahmad Fauzi',
            gerai: 'Enakko Sudirman',
            kontrak: '',
          ),
        ];
        final results = CsvImportService.validate(
          rows: rows,
          outletNameToId: outletNameToId,
          outletNameDisplay: outletNameDisplay,
          existingEmployeeKeys: {},
        );
        expect(results[0].isValid, isFalse);
        expect(results[0].errors, contains(contains('Kontrak')));
      });

      test('invalid kontrak returns error with accepted values', () {
        final rows = [
          CsvRow(
            rowNumber: 1,
            nama: 'Ahmad Fauzi',
            gerai: 'Enakko Sudirman',
            kontrak: 'FREELANCE',
          ),
        ];
        final results = CsvImportService.validate(
          rows: rows,
          outletNameToId: outletNameToId,
          outletNameDisplay: outletNameDisplay,
          existingEmployeeKeys: {},
        );
        expect(results[0].isValid, isFalse);
        expect(results[0].errors, contains(contains('FULLTIME')));
        expect(results[0].errors, contains(contains('PARTTIME')));
      });

      test('empty nama returns error', () {
        final rows = [
          CsvRow(
            rowNumber: 1,
            nama: '',
            gerai: 'Enakko Sudirman',
            kontrak: 'FULLTIME',
          ),
        ];
        final results = CsvImportService.validate(
          rows: rows,
          outletNameToId: outletNameToId,
          outletNameDisplay: outletNameDisplay,
          existingEmployeeKeys: {},
        );
        expect(results[0].isValid, isFalse);
        expect(results[0].errors, contains(contains('Nama wajib diisi')));
      });

      test('nama less than 3 chars returns error', () {
        final rows = [
          CsvRow(
            rowNumber: 1,
            nama: 'Ab',
            gerai: 'Enakko Sudirman',
            kontrak: 'FULLTIME',
          ),
        ];
        final results = CsvImportService.validate(
          rows: rows,
          outletNameToId: outletNameToId,
          outletNameDisplay: outletNameDisplay,
          existingEmployeeKeys: {},
        );
        expect(results[0].isValid, isFalse);
        expect(results[0].errors, contains(contains('minimal 3 karakter')));
      });

      test('empty gerai returns error', () {
        final rows = [
          CsvRow(
            rowNumber: 1,
            nama: 'Ahmad Fauzi',
            gerai: '',
            kontrak: 'FULLTIME',
          ),
        ];
        final results = CsvImportService.validate(
          rows: rows,
          outletNameToId: outletNameToId,
          outletNameDisplay: outletNameDisplay,
          existingEmployeeKeys: {},
        );
        expect(results[0].isValid, isFalse);
        expect(results[0].errors, contains(contains('Gerai wajib diisi')));
      });

      test('unknown outlet returns error with outlet name', () {
        final rows = [
          CsvRow(
            rowNumber: 1,
            nama: 'Ahmad Fauzi',
            gerai: 'Unknown Outlet',
            kontrak: 'FULLTIME',
          ),
        ];
        final results = CsvImportService.validate(
          rows: rows,
          outletNameToId: outletNameToId,
          outletNameDisplay: outletNameDisplay,
          existingEmployeeKeys: {},
        );
        expect(results[0].isValid, isFalse);
        expect(
          results[0].errors,
          contains(contains('Unknown Outlet')),
        );
        expect(
          results[0].errors,
          contains(contains('tidak ditemukan')),
        );
      });

      test('outlet matching is case-insensitive', () {
        final rows = [
          CsvRow(
            rowNumber: 1,
            nama: 'Ahmad Fauzi',
            gerai: 'ENAKKO SUDIRMAN',
            kontrak: 'FULLTIME',
          ),
        ];
        final results = CsvImportService.validate(
          rows: rows,
          outletNameToId: outletNameToId,
          outletNameDisplay: outletNameDisplay,
          existingEmployeeKeys: {},
        );
        expect(results[0].isValid, isTrue);
        expect(results[0].resolvedOutletId, 'uuid-sudirman');
      });

      test('duplicate within CSV flags second row', () {
        final rows = [
          CsvRow(
            rowNumber: 1,
            nama: 'Ahmad Fauzi',
            gerai: 'Enakko Sudirman',
            kontrak: 'FULLTIME',
          ),
          CsvRow(
            rowNumber: 2,
            nama: 'Ahmad Fauzi',
            gerai: 'Enakko Sudirman',
            kontrak: 'FULLTIME',
          ),
        ];
        final results = CsvImportService.validate(
          rows: rows,
          outletNameToId: outletNameToId,
          outletNameDisplay: outletNameDisplay,
          existingEmployeeKeys: {},
        );
        expect(results[0].isValid, isTrue);
        expect(results[1].isValid, isFalse);
        expect(results[1].errors, contains(contains('duplikat')));
      });

      test('duplicate against existing employees flags row', () {
        final rows = [
          CsvRow(
            rowNumber: 1,
            nama: 'Ahmad Fauzi',
            gerai: 'Enakko Sudirman',
            kontrak: 'FULLTIME',
          ),
        ];
        final results = CsvImportService.validate(
          rows: rows,
          outletNameToId: outletNameToId,
          outletNameDisplay: outletNameDisplay,
          existingEmployeeKeys: {'ahmad fauzi|uuid-sudirman'},
        );
        expect(results[0].isValid, isFalse);
        expect(results[0].errors, contains(contains('sudah terdaftar')));
      });

      test('foto_url without http/https returns error', () {
        final rows = [
          CsvRow(
            rowNumber: 1,
            nama: 'Ahmad Fauzi',
            gerai: 'Enakko Sudirman',
            kontrak: 'FULLTIME',
            fotoUrl: 'ftp://example.com/photo.jpg',
          ),
        ];
        final results = CsvImportService.validate(
          rows: rows,
          outletNameToId: outletNameToId,
          outletNameDisplay: outletNameDisplay,
          existingEmployeeKeys: {},
        );
        expect(results[0].isValid, isFalse);
        expect(results[0].errors, contains(contains('http')));
      });

      test('empty foto_url is valid', () {
        final rows = [
          CsvRow(
            rowNumber: 1,
            nama: 'Ahmad Fauzi',
            gerai: 'Enakko Sudirman',
            kontrak: 'FULLTIME',
            fotoUrl: null,
          ),
        ];
        final results = CsvImportService.validate(
          rows: rows,
          outletNameToId: outletNameToId,
          outletNameDisplay: outletNameDisplay,
          existingEmployeeKeys: {},
        );
        expect(results[0].isValid, isTrue);
      });

      test('multiple errors on same row are aggregated', () {
        final rows = [
          CsvRow(
            rowNumber: 1,
            nama: '',
            gerai: '',
            kontrak: 'INVALID',
            fotoUrl: 'bad-url',
          ),
        ];
        final results = CsvImportService.validate(
          rows: rows,
          outletNameToId: outletNameToId,
          outletNameDisplay: outletNameDisplay,
          existingEmployeeKeys: {},
        );
        expect(results[0].isValid, isFalse);
        // Should have at least: nama error, gerai error, kontrak error, foto_url error
        expect(results[0].errors.length, greaterThanOrEqualTo(4));
      });
    });

    // ================================================================
    // buildInsertPayloads
    // ================================================================
    group('buildInsertPayloads', () {
      test('builds correct payload with employment_contract', () {
        final validations = [
          CsvRowValidation(
            row: CsvRow(
              rowNumber: 1,
              nama: 'Ahmad Fauzi',
              jabatan: 'Kasir',
              gerai: 'Enakko Sudirman',
              kontrak: 'FULLTIME',
              fotoUrl: 'https://example.com/a.jpg',
            ),
            errors: [],
            resolvedOutletId: 'uuid-sudirman',
            resolvedOutletName: 'Enakko Sudirman',
            resolvedContract: EmployeeContract.fulltime,
          ),
        ];
        final payloads = CsvImportService.buildInsertPayloads(validations);
        expect(payloads.length, 1);
        expect(payloads[0]['name'], 'Ahmad Fauzi');
        expect(payloads[0]['position'], 'Kasir');
        expect(payloads[0]['home_outlet_id'], 'uuid-sudirman');
        expect(payloads[0]['photo_url'], 'https://example.com/a.jpg');
        expect(payloads[0]['is_active'], isTrue);
        expect(payloads[0]['employment_contract'], 'FULLTIME');
      });

      test('parttime contract persists correctly', () {
        final validations = [
          CsvRowValidation(
            row: CsvRow(
              rowNumber: 1,
              nama: 'Budi Santoso',
              gerai: 'Enakko Margonda',
              kontrak: 'part-time',
            ),
            errors: [],
            resolvedOutletId: 'uuid-margonda',
            resolvedOutletName: 'Enakko Margonda',
            resolvedContract: EmployeeContract.parttime,
          ),
        ];
        final payloads = CsvImportService.buildInsertPayloads(validations);
        expect(payloads[0]['employment_contract'], 'PARTTIME');
      });

      test('optional fields keep stable defaults and are not omitted', () {
        final validations = [
          CsvRowValidation(
            row: CsvRow(
              rowNumber: 1,
              nama: 'Budi Santoso',
              gerai: 'Enakko Margonda',
              kontrak: 'FULLTIME',
            ),
            errors: [],
            resolvedOutletId: 'uuid-margonda',
            resolvedOutletName: 'Enakko Margonda',
            resolvedContract: EmployeeContract.fulltime,
          ),
        ];
        final payloads = CsvImportService.buildInsertPayloads(validations);
        expect(payloads.length, 1);
        // Keys must exist even if null
        expect(payloads[0].containsKey('position'), isTrue);
        expect(payloads[0].containsKey('photo_url'), isTrue);
        expect(payloads[0]['position'], 'Crew');
        expect(payloads[0]['photo_url'], isNull);
        expect(payloads[0].containsKey('employment_contract'), isTrue);
      });

      test('is_active is always true', () {
        final validations = [
          CsvRowValidation(
            row: CsvRow(
              rowNumber: 1,
              nama: 'Citra Dewi',
              jabatan: 'Manager',
              gerai: 'Enakko Sudirman',
              kontrak: 'PARTTIME',
            ),
            errors: [],
            resolvedOutletId: 'uuid-sudirman',
            resolvedOutletName: 'Enakko Sudirman',
            resolvedContract: EmployeeContract.parttime,
          ),
        ];
        final payloads = CsvImportService.buildInsertPayloads(validations);
        expect(payloads[0]['is_active'], isTrue);
      });
    });

    // ================================================================
    // generateTemplateCsv
    // ================================================================
    group('generateTemplateCsv', () {
      test('starts with correct 5-column header row', () {
        final csv = CsvImportService.generateTemplateCsv();
        final lines = csv.split('\n');
        expect(lines[0].trim(), 'nama,jabatan,gerai,kontrak,foto_url');
      });

      test('contains sample data rows with contract values', () {
        final csv = CsvImportService.generateTemplateCsv();
        final lines =
            csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
        // Header + at least 2 sample rows
        expect(lines.length, greaterThanOrEqualTo(3));
        // Sample rows should contain contract values
        expect(csv, contains('FULLTIME'));
        expect(csv, contains('PARTTIME'));
      });
    });
  });
}
