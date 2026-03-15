import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_enakko_flutter/models/csv_import_result.dart';

void main() {
  group('CsvRow', () {
    test('stores all fields correctly', () {
      final row = CsvRow(
        rowNumber: 1,
        nama: 'Ahmad Fauzi',
        jabatan: 'Kasir',
        gerai: 'Enakko Sudirman',
        fotoUrl: 'https://example.com/photo.jpg',
      );
      expect(row.rowNumber, 1);
      expect(row.nama, 'Ahmad Fauzi');
      expect(row.jabatan, 'Kasir');
      expect(row.gerai, 'Enakko Sudirman');
      expect(row.fotoUrl, 'https://example.com/photo.jpg');
    });

    test('jabatan and fotoUrl are optional (nullable)', () {
      final row = CsvRow(
        rowNumber: 2,
        nama: 'Budi Santoso',
        gerai: 'Enakko Margonda',
      );
      expect(row.jabatan, isNull);
      expect(row.fotoUrl, isNull);
    });

    test('toString returns debug-friendly string', () {
      final row = CsvRow(
        rowNumber: 1,
        nama: 'Ahmad',
        gerai: 'Enakko Sudirman',
      );
      final str = row.toString();
      expect(str, contains('Ahmad'));
      expect(str, contains('1'));
    });
  });

  group('CsvRowValidation', () {
    test('isValid returns true when errors is empty', () {
      final validation = CsvRowValidation(
        row: CsvRow(rowNumber: 1, nama: 'Test', gerai: 'Outlet'),
        errors: [],
        resolvedOutletId: 'uuid-123',
        resolvedOutletName: 'Outlet',
      );
      expect(validation.isValid, isTrue);
    });

    test('isValid returns false when errors is non-empty', () {
      final validation = CsvRowValidation(
        row: CsvRow(rowNumber: 1, nama: '', gerai: ''),
        errors: ['Nama wajib diisi'],
      );
      expect(validation.isValid, isFalse);
    });

    test('resolvedOutletId is null when outlet not found', () {
      final validation = CsvRowValidation(
        row: CsvRow(rowNumber: 1, nama: 'Test', gerai: 'Unknown'),
        errors: ['Outlet "Unknown" tidak ditemukan'],
      );
      expect(validation.resolvedOutletId, isNull);
      expect(validation.resolvedOutletName, isNull);
    });
  });

  group('CsvImportResult', () {
    test('stores totalImported and employeesByOutlet', () {
      final result = CsvImportResult(
        totalImported: 5,
        employeesByOutlet: {
          'Enakko Sudirman': ['Ahmad', 'Budi'],
          'Enakko Margonda': ['Citra', 'Dian', 'Eka'],
        },
      );
      expect(result.totalImported, 5);
      expect(result.employeesByOutlet.keys.length, 2);
      expect(result.employeesByOutlet['Enakko Sudirman'], ['Ahmad', 'Budi']);
      expect(result.employeesByOutlet['Enakko Margonda']!.length, 3);
    });
  });
}
