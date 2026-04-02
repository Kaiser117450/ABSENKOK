import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_enakko_flutter/models/csv_import_result.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';

void main() {
  group('CsvRow', () {
    test('stores all fields correctly', () {
      final row = CsvRow(
        rowNumber: 1,
        nama: 'Ahmad Fauzi',
        jabatan: 'Kasir',
        gerai: 'Enakko Sudirman',
        kontrak: 'FULLTIME',
        fotoUrl: 'https://example.com/photo.jpg',
      );
      expect(row.rowNumber, 1);
      expect(row.nama, 'Ahmad Fauzi');
      expect(row.jabatan, 'Kasir');
      expect(row.gerai, 'Enakko Sudirman');
      expect(row.kontrak, 'FULLTIME');
      expect(row.fotoUrl, 'https://example.com/photo.jpg');
    });

    test('jabatan and fotoUrl are optional (nullable)', () {
      final row = CsvRow(
        rowNumber: 2,
        nama: 'Budi Santoso',
        gerai: 'Enakko Margonda',
        kontrak: 'PARTTIME',
      );
      expect(row.jabatan, isNull);
      expect(row.fotoUrl, isNull);
    });

    test('toString returns debug-friendly string', () {
      final row = CsvRow(
        rowNumber: 1,
        nama: 'Ahmad',
        gerai: 'Enakko Sudirman',
        kontrak: 'FULLTIME',
      );
      final str = row.toString();
      expect(str, contains('Ahmad'));
      expect(str, contains('1'));
      expect(str, contains('FULLTIME'));
    });
  });

  group('CsvRowValidation', () {
    test('isValid returns true when errors is empty', () {
      final validation = CsvRowValidation(
        row: CsvRow(
          rowNumber: 1,
          nama: 'Test',
          gerai: 'Outlet',
          kontrak: 'FULLTIME',
        ),
        errors: [],
        resolvedOutletId: 'uuid-123',
        resolvedOutletName: 'Outlet',
        resolvedContract: EmployeeContract.fulltime,
      );
      expect(validation.isValid, isTrue);
      expect(validation.resolvedContract, EmployeeContract.fulltime);
    });

    test('isValid returns false when errors is non-empty', () {
      final validation = CsvRowValidation(
        row: CsvRow(rowNumber: 1, nama: '', gerai: '', kontrak: ''),
        errors: ['Nama wajib diisi'],
      );
      expect(validation.isValid, isFalse);
    });

    test('resolvedOutletId is null when outlet not found', () {
      final validation = CsvRowValidation(
        row: CsvRow(
          rowNumber: 1,
          nama: 'Test',
          gerai: 'Unknown',
          kontrak: 'PARTTIME',
        ),
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
