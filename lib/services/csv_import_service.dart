/// CSV import service — parse, validate, and batch-insert employees.
///
/// All public methods except [insertAll] are pure functions that take data
/// as parameters. This makes them trivially unit-testable without Supabase.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/csv_import_result.dart';

/// Expected CSV column headers (case-insensitive).
const _expectedHeaders = ['nama', 'jabatan', 'gerai', 'foto_url'];

class CsvImportService {
  // ──────────────────────────────────────────────────────────────────
  // 1. parseBytes — decode CSV bytes into typed CsvRow list
  // ──────────────────────────────────────────────────────────────────

  /// Parse raw CSV bytes into a list of [CsvRow] objects.
  ///
  /// Handles:
  /// - UTF-8 BOM prefix (0xEF 0xBB 0xBF)
  /// - Quoted fields containing commas
  /// - Trailing empty rows (filtered out)
  ///
  /// Throws [FormatException] when headers don't match or no data rows found.
  static List<CsvRow> parseBytes(Uint8List bytes) {
    var content = utf8.decode(bytes);

    // Strip UTF-8 BOM if present
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }

    // Normalize line endings to \n for consistent parsing
    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Parse CSV — keep all values as strings (don't auto-parse numbers)
    const converter = CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    );
    final rows = converter.convert(content);

    if (rows.isEmpty) {
      throw FormatException('File CSV kosong');
    }

    // Validate headers (case-insensitive)
    final headers =
        rows[0].map((h) => h.toString().trim().toLowerCase()).toList();
    if (headers.length < _expectedHeaders.length) {
      throw FormatException(
        'Header CSV tidak sesuai. Diharapkan: ${_expectedHeaders.join(", ")}',
      );
    }
    for (var i = 0; i < _expectedHeaders.length; i++) {
      if (headers[i] != _expectedHeaders[i]) {
        throw FormatException(
          'Header kolom ${i + 1} harus "${_expectedHeaders[i]}", '
          'ditemukan "${headers[i]}"',
        );
      }
    }

    // Map data rows (skip header), filter empty trailing rows
    final dataRows = <CsvRow>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];

      // Skip empty rows (all cells empty/whitespace)
      if (row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }

      final nama = _cell(row, 0);
      final jabatan = _cellOrNull(row, 1);
      final gerai = _cell(row, 2);
      final fotoUrl = _cellOrNull(row, 3);

      dataRows.add(CsvRow(
        rowNumber: dataRows.length + 1,
        nama: nama,
        jabatan: jabatan,
        gerai: gerai,
        fotoUrl: fotoUrl,
      ));
    }

    if (dataRows.isEmpty) {
      throw FormatException('File CSV tidak memiliki data (hanya header)');
    }

    return dataRows;
  }

  // ──────────────────────────────────────────────────────────────────
  // 2. validate — check rows against rules and outlet lookup
  // ──────────────────────────────────────────────────────────────────

  /// Validate parsed CSV rows.
  ///
  /// Parameters are pre-fetched data so this stays a pure function:
  /// - [outletNameToId]: lowercase outlet name → UUID
  /// - [outletNameDisplay]: lowercase outlet name → display name
  /// - [existingEmployeeKeys]: set of "lowercase_name|outlet_id" for DB dupes
  static List<CsvRowValidation> validate({
    required List<CsvRow> rows,
    required Map<String, String> outletNameToId,
    required Map<String, String> outletNameDisplay,
    required Set<String> existingEmployeeKeys,
  }) {
    final results = <CsvRowValidation>[];
    // Track within-CSV duplicates: "lowercase_name|outlet_id"
    final seenInCsv = <String>{};

    for (final row in rows) {
      final errors = <String>[];
      String? resolvedOutletId;
      String? resolvedOutletName;

      // --- nama validation ---
      final namaTrimmed = row.nama.trim();
      if (namaTrimmed.isEmpty) {
        errors.add('Nama wajib diisi (minimal 3 karakter)');
      } else if (namaTrimmed.length < 3) {
        errors.add('Nama terlalu pendek (minimal 3 karakter)');
      }

      // --- gerai validation ---
      final geraiTrimmed = row.gerai.trim();
      if (geraiTrimmed.isEmpty) {
        errors.add('Gerai wajib diisi');
      } else {
        // Resolve outlet case-insensitively
        final key = geraiTrimmed.toLowerCase();
        resolvedOutletId = outletNameToId[key];
        resolvedOutletName = outletNameDisplay[key];
        if (resolvedOutletId == null) {
          errors.add('Outlet "$geraiTrimmed" tidak ditemukan');
        }
      }

      // --- foto_url validation (optional) ---
      final fotoUrl = row.fotoUrl;
      if (fotoUrl != null && fotoUrl.trim().isNotEmpty) {
        final url = fotoUrl.trim();
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          errors.add('Foto URL harus dimulai dengan http:// atau https://');
        }
      }

      // --- duplicate detection ---
      if (namaTrimmed.isNotEmpty && resolvedOutletId != null) {
        final dupeKey = '${namaTrimmed.toLowerCase()}|$resolvedOutletId';

        // Check within-CSV duplicates
        if (seenInCsv.contains(dupeKey)) {
          errors.add(
            'Karyawan duplikat dalam CSV (nama + gerai sama dengan baris sebelumnya)',
          );
        } else {
          seenInCsv.add(dupeKey);
        }

        // Check against existing DB employees
        if (existingEmployeeKeys.contains(dupeKey)) {
          errors.add(
            'Karyawan "${row.nama}" sudah terdaftar di outlet ini',
          );
        }
      }

      results.add(CsvRowValidation(
        row: row,
        errors: errors,
        resolvedOutletId: errors.isEmpty ? resolvedOutletId : null,
        resolvedOutletName: errors.isEmpty ? resolvedOutletName : null,
      ));
    }

    return results;
  }

  // ──────────────────────────────────────────────────────────────────
  // 3. buildInsertPayloads — create Supabase insert maps
  // ──────────────────────────────────────────────────────────────────

  /// Build Supabase insert payloads from validated rows.
  ///
  /// Every map has ALL keys (consistent shape) — optional values are `null`,
  /// never omitted. This prevents Supabase batch insert mismatch errors.
  static List<Map<String, dynamic>> buildInsertPayloads(
    List<CsvRowValidation> validRows,
  ) {
    return validRows
        .where((v) => v.isValid)
        .map((v) => <String, dynamic>{
              'name': v.row.nama.trim(),
              'position': v.row.jabatan?.trim().isNotEmpty == true
                  ? v.row.jabatan!.trim()
                  : null,
              'home_outlet_id': v.resolvedOutletId,
              'photo_url': v.row.fotoUrl?.trim().isNotEmpty == true
                  ? v.row.fotoUrl!.trim()
                  : null,
              'is_active': true,
            })
        .toList();
  }

  // ──────────────────────────────────────────────────────────────────
  // 4. generateTemplateCsv — downloadable CSV template
  // ──────────────────────────────────────────────────────────────────

  /// Generate a CSV template string with headers and sample rows.
  static String generateTemplateCsv() {
    final buffer = StringBuffer();
    buffer.writeln('nama,jabatan,gerai,foto_url');
    buffer.writeln('Ahmad Fauzi,Kasir,Enakko Sudirman,');
    buffer.writeln('Budi Santoso,Koki,Enakko Margonda,');
    return buffer.toString();
  }

  // ──────────────────────────────────────────────────────────────────
  // 5. insertAll — batch insert to Supabase (only method with side-effects)
  // ──────────────────────────────────────────────────────────────────

  /// Batch insert employee payloads into Supabase.
  ///
  /// [outletIdToName] maps outlet UUID → display name for the result summary.
  ///
  /// Throws user-friendly message on duplicate constraint violation (race
  /// condition where employee was added between validation and insert).
  static Future<CsvImportResult> insertAll(
    List<Map<String, dynamic>> payloads,
    Map<String, String> outletIdToName,
  ) async {
    try {
      await SupabaseClientFactory.admin.from('employees').insert(payloads);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception(
          'Beberapa karyawan sudah terdaftar (duplikat terdeteksi saat insert). '
          'Silakan cek data dan coba lagi.',
        );
      }
      rethrow;
    }

    // Build result summary grouped by outlet
    final employeesByOutlet = <String, List<String>>{};
    for (final payload in payloads) {
      final outletId = payload['home_outlet_id'] as String?;
      final outletName = outletId != null
          ? (outletIdToName[outletId] ?? 'Unknown Outlet')
          : 'Tanpa Outlet';
      final empName = payload['name'] as String;
      employeesByOutlet.putIfAbsent(outletName, () => []).add(empName);
    }

    return CsvImportResult(
      totalImported: payloads.length,
      employeesByOutlet: employeesByOutlet,
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Private helpers
  // ──────────────────────────────────────────────────────────────────

  /// Get a cell value as trimmed string, defaulting to empty string.
  static String _cell(List<dynamic> row, int index) {
    if (index >= row.length) return '';
    return row[index].toString().trim();
  }

  /// Get a cell value as trimmed string, or null if empty.
  static String? _cellOrNull(List<dynamic> row, int index) {
    if (index >= row.length) return null;
    final value = row[index].toString().trim();
    return value.isEmpty ? null : value;
  }
}
