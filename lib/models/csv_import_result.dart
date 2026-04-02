/// Data models for CSV employee import.
///
/// Pure Dart — no Flutter imports — easily unit-testable.
library;

import 'employee_contract.dart';

/// A single row parsed from the CSV file.
class CsvRow {
  /// 1-based row number from CSV (excluding header).
  final int rowNumber;
  final String nama;
  final String? jabatan;
  final String gerai;
  final String kontrak;
  final String? fotoUrl;

  const CsvRow({
    required this.rowNumber,
    required this.nama,
    this.jabatan,
    required this.gerai,
    required this.kontrak,
    this.fotoUrl,
  });

  @override
  String toString() =>
      'CsvRow(row=$rowNumber, nama=$nama, jabatan=$jabatan, gerai=$gerai, kontrak=$kontrak, fotoUrl=$fotoUrl)';
}

/// Validation result for a single [CsvRow].
class CsvRowValidation {
  final CsvRow row;
  final List<String> errors;
  final String? resolvedOutletId;
  final String? resolvedOutletName;
  final EmployeeContract? resolvedContract;

  const CsvRowValidation({
    required this.row,
    required this.errors,
    this.resolvedOutletId,
    this.resolvedOutletName,
    this.resolvedContract,
  });

  /// True when no validation errors were found.
  bool get isValid => errors.isEmpty;
}

/// Summary result of a successful batch import.
class CsvImportResult {
  /// Number of employees successfully inserted.
  final int totalImported;

  /// Outlet display name → list of imported employee names.
  /// Used by the result screen to show a grouped summary.
  final Map<String, List<String>> employeesByOutlet;

  const CsvImportResult({
    required this.totalImported,
    required this.employeesByOutlet,
  });
}
