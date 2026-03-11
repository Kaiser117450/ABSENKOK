import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_enakko_flutter/models/csv_import_result.dart';
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
      test('parses valid CSV with 3 rows', () {
        final csv = 'nama,jabatan,gerai,foto_url\n'
            'Ahmad Fauzi,Kasir,Enakko Sudirman,\n'
            'Budi Santoso,Koki,Enakko Margonda,https://example.com/b.jpg\n'
            'Citra Dewi,,Enakko Sudirman,\n';
        final rows = CsvImportService.parseBytes(_csvBytes(csv));
        expect(rows.length, 3);
        expect(rows[0].nama, 'Ahmad Fauzi');
        expect(rows[0].jabatan, 'Kasir');
        expect(rows[0].gerai, 'Enakko Sudirman');
        expect(rows[0].fotoUrl, isNull);
        expect(rows[0].rowNumber, 1);
        expect(rows[1].nama, 'Budi Santoso');
        expect(rows[1].fotoUrl, 'https://example.com/b.jpg');
        expect(rows[1].rowNumber, 2);
        expect(rows[2].jabatan, isNull);
        expect(rows[2].rowNumber, 3);
      });

      test('strips UTF-8 BOM from first header', () {
        final csv = 'nama,jabatan,gerai,foto_url\n'
            'Test Name,Kasir,Enakko Sudirman,\n';
        final rows = CsvImportService.parseBytes(_csvBytesWithBom(csv));
        expect(rows.length, 1);
        expect(rows[0].nama, 'Test Name');
      });

      test('handles quoted fields with commas', () {
        final csv = 'nama,jabatan,gerai,foto_url\n'
            '"Eko, Prasetyo",Kasir,Enakko Sudirman,\n';
        final rows = CsvImportService.parseBytes(_csvBytes(csv));
        expect(rows.length, 1);
        expect(rows[0].nama, 'Eko, Prasetyo');
      });

      test('filters trailing empty rows', () {
        final csv = 'nama,jabatan,gerai,foto_url\n'
            'Ahmad Fauzi,Kasir,Enakko Sudirman,\n'
            ',,,\n'
            '\n';
        final rows = CsvImportService.parseBytes(_csvBytes(csv));
        expect(rows.length, 1);
        expect(rows[0].nama, 'Ahmad Fauzi');
      });

      test('throws on CSV with no data rows', () {
        final csv = 'nama,jabatan,gerai,foto_url\n';
        expect(
          () => CsvImportService.parseBytes(_csvBytes(csv)),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on CSV with wrong headers', () {
        final csv = 'name,position,outlet,photo\n'
            'Ahmad,Kasir,Enakko,\n';
        expect(
          () => CsvImportService.parseBytes(_csvBytes(csv)),
          throwsA(isA<FormatException>()),
        );
      });

      test('headers are matched case-insensitively', () {
        final csv = 'Nama,Jabatan,Gerai,Foto_Url\n'
            'Ahmad Fauzi,Kasir,Enakko Sudirman,\n';
        final rows = CsvImportService.parseBytes(_csvBytes(csv));
        expect(rows.length, 1);
        expect(rows[0].nama, 'Ahmad Fauzi');
      });
    });

    // ================================================================
    // validate
    // ================================================================
    group('validate', () {
      test('valid row returns isValid=true with resolvedOutletId', () {
        final rows = [
          CsvRow(rowNumber: 1, nama: 'Ahmad Fauzi', gerai: 'Enakko Sudirman'),
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
      });

      test('empty nama returns error', () {
        final rows = [
          CsvRow(rowNumber: 1, nama: '', gerai: 'Enakko Sudirman'),
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
          CsvRow(rowNumber: 1, nama: 'Ab', gerai: 'Enakko Sudirman'),
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
          CsvRow(rowNumber: 1, nama: 'Ahmad Fauzi', gerai: ''),
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
          CsvRow(rowNumber: 1, nama: 'Ahmad Fauzi', gerai: 'Unknown Outlet'),
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
          ),
          CsvRow(
            rowNumber: 2,
            nama: 'Ahmad Fauzi',
            gerai: 'Enakko Sudirman',
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
        // Should have at least: nama error, gerai error, foto_url error
        expect(results[0].errors.length, greaterThanOrEqualTo(3));
      });
    });

    // ================================================================
    // buildInsertPayloads
    // ================================================================
    group('buildInsertPayloads', () {
      test('builds correct payload with all keys present', () {
        final validations = [
          CsvRowValidation(
            row: CsvRow(
              rowNumber: 1,
              nama: 'Ahmad Fauzi',
              jabatan: 'Kasir',
              gerai: 'Enakko Sudirman',
              fotoUrl: 'https://example.com/a.jpg',
            ),
            errors: [],
            resolvedOutletId: 'uuid-sudirman',
            resolvedOutletName: 'Enakko Sudirman',
          ),
        ];
        final payloads = CsvImportService.buildInsertPayloads(validations);
        expect(payloads.length, 1);
        expect(payloads[0]['name'], 'Ahmad Fauzi');
        expect(payloads[0]['position'], 'Kasir');
        expect(payloads[0]['home_outlet_id'], 'uuid-sudirman');
        expect(payloads[0]['photo_url'], 'https://example.com/a.jpg');
        expect(payloads[0]['is_active'], isTrue);
      });

      test('optional fields are null not omitted', () {
        final validations = [
          CsvRowValidation(
            row: CsvRow(
              rowNumber: 1,
              nama: 'Budi Santoso',
              gerai: 'Enakko Margonda',
            ),
            errors: [],
            resolvedOutletId: 'uuid-margonda',
            resolvedOutletName: 'Enakko Margonda',
          ),
        ];
        final payloads = CsvImportService.buildInsertPayloads(validations);
        expect(payloads.length, 1);
        // Keys must exist even if null
        expect(payloads[0].containsKey('position'), isTrue);
        expect(payloads[0].containsKey('photo_url'), isTrue);
        expect(payloads[0]['position'], isNull);
        expect(payloads[0]['photo_url'], isNull);
      });

      test('is_active is always true', () {
        final validations = [
          CsvRowValidation(
            row: CsvRow(
              rowNumber: 1,
              nama: 'Citra Dewi',
              jabatan: 'Manager',
              gerai: 'Enakko Sudirman',
            ),
            errors: [],
            resolvedOutletId: 'uuid-sudirman',
            resolvedOutletName: 'Enakko Sudirman',
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
      test('starts with correct header row', () {
        final csv = CsvImportService.generateTemplateCsv();
        final lines = csv.split('\n');
        expect(lines[0].trim(), 'nama,jabatan,gerai,foto_url');
      });

      test('contains sample data rows', () {
        final csv = CsvImportService.generateTemplateCsv();
        final lines =
            csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
        // Header + at least 2 sample rows
        expect(lines.length, greaterThanOrEqualTo(3));
      });
    });
  });
}
