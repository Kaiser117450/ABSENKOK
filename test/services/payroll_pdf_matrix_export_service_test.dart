import 'dart:convert';
import 'dart:io';

import 'package:absensi_enakko_flutter/models/payroll_matrix_day_cell.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';
import 'package:absensi_enakko_flutter/services/admin_policy_recap_dataset_service.dart';
import 'package:absensi_enakko_flutter/services/payroll_matrix_builder.dart';
import 'package:absensi_enakko_flutter/services/payroll_matrix_semantics.dart';
import 'package:absensi_enakko_flutter/services/payroll_pdf_matrix_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../fixtures/report_export_parity_fixture.dart';

void main() {
  group('PayrollPdfMatrixExportService', () {
    const recapDatasetService = AdminPolicyRecapDatasetService();
    const semantics = PayrollMatrixSemantics();
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('payroll-pdf-test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        'builds a payroll-first PDF preview and file with locked summary order, legend tags, overnight fixture, fallback fixture, and forbidden-field exclusion',
        () async {
      final context = _buildParityPdfContext(recapDatasetService);
      final service = PayrollPdfMatrixExportService(
        temporaryDirectoryProvider: () async => tempDir,
        logoLoader: () async => null,
        nowProvider: () => DateTime(2026, 3, 28, 10, 15),
      );

      final preview = service.buildPreview(
        dataset: context.dataset,
        outletName: context.bundle.outletName,
        startDate: context.bundle.startDate,
        endDate: context.bundle.endDate,
        isCompatibilityMode: context.isCompatibilityMode,
      );

      expect(preview.title, 'Rekap Payroll PDF');
      expect(preview.compatibilityTitle, 'Mode kompatibilitas aktif');
      expect(
        preview.summaryMetrics
            .map((metric) => metric.label)
            .toList(growable: false),
        PayrollMatrixRow.summaryLabels,
      );
      expect(
        preview.summaryMetrics
            .map((metric) => metric.value)
            .toList(growable: false),
        context.summaryValues,
      );
      expect(preview.legendTags, semantics.legendTags);

      final latePreviewCell = _previewCellFor(
        preview,
        employeeName: context.employeeNameFor('emp-outlet-24-jam'),
        date: DateTime(2026, 3, 18),
      );
      final overtimePreviewCell = _previewCellFor(
        preview,
        employeeName: context.employeeNameFor('emp-overtime'),
        date: DateTime(2026, 3, 25),
      );
      final absencePreviewCell = _previewCellFor(
        preview,
        employeeName: context.employeeNameFor('emp-no-show'),
        date: DateTime(2026, 3, 28),
      );
      final fallbackPreviewCell = _previewCellFor(
        preview,
        employeeName:
            context.employeeNameFor('emp-legacy-fallback-no-schedule'),
        date: DateTime(2026, 3, 21),
      );

      expect(
        latePreviewCell.primaryLabel,
        context
            .cellFor('emp-outlet-24-jam', DateTime(2026, 3, 18))
            .primaryLabel,
      );
      expect(
        latePreviewCell.secondaryTags,
        context
            .cellFor('emp-outlet-24-jam', DateTime(2026, 3, 18))
            .secondaryTags,
      );
      expect(
        overtimePreviewCell.primaryLabel,
        context.cellFor('emp-overtime', DateTime(2026, 3, 25)).primaryLabel,
      );
      expect(
        overtimePreviewCell.secondaryTags,
        context.cellFor('emp-overtime', DateTime(2026, 3, 25)).secondaryTags,
      );
      expect(
        absencePreviewCell.primaryLabel,
        context.cellFor('emp-no-show', DateTime(2026, 3, 28)).primaryLabel,
      );
      expect(
        absencePreviewCell.secondaryTags,
        context.cellFor('emp-no-show', DateTime(2026, 3, 28)).secondaryTags,
      );
      expect(
        fallbackPreviewCell.primaryLabel,
        context
            .cellFor('emp-legacy-fallback-no-schedule', DateTime(2026, 3, 21))
            .primaryLabel,
      );
      expect(
        fallbackPreviewCell.secondaryTags,
        context
            .cellFor('emp-legacy-fallback-no-schedule', DateTime(2026, 3, 21))
            .secondaryTags,
      );
      expect(latePreviewCell.secondaryTags, contains('TLT'));
      expect(overtimePreviewCell.secondaryTags, contains('OT'));
      expect(absencePreviewCell.secondaryTags, contains('ABS'));
      expect(fallbackPreviewCell.primaryLabel, 'Hadir tanpa jadwal');
      expect(
        preview.matrixPages.expand((page) => page.rows).isNotEmpty,
        isTrue,
      );

      final serializedPreview = jsonEncode(preview.toJson());
      for (final forbiddenField
          in PayrollPdfMatrixExportService.forbiddenFields) {
        expect(
          serializedPreview.contains(forbiddenField),
          isFalse,
          reason: 'Preview should not expose $forbiddenField',
        );
      }

      final file = await service.buildPayrollPdf(
        dataset: context.dataset,
        outletName: context.bundle.outletName,
        startDate: context.bundle.startDate,
        endDate: context.bundle.endDate,
        isCompatibilityMode: context.isCompatibilityMode,
      );

      expect(await file.exists(), isTrue);
      expect(file.path, endsWith('.pdf'));
      expect(
        path.basename(file.path),
        'rekap_payroll_pdf_outlet_parity_20260318_20260328.pdf',
      );
      expect(await file.length(), greaterThan(0));

      final serializedPdf = latin1.decode(await file.readAsBytes());
      for (final forbiddenField
          in PayrollPdfMatrixExportService.forbiddenFields) {
        expect(
          serializedPdf.contains(forbiddenField),
          isFalse,
          reason: 'Generated PDF should not expose $forbiddenField',
        );
      }
    });
  });
}

_ParityPdfContext _buildParityPdfContext(
  AdminPolicyRecapDatasetService recapDatasetService,
) {
  final bundle = buildReportExportParityFixtureBundle();
  final recapDataset = recapDatasetService.build(
    employees: bundle.employees,
    strictRows: bundle.strictRows,
    attendanceLogs: bundle.attendanceLogs,
    outletId: bundle.outletId,
    outletName: bundle.outletName,
    outletOperatingMode: bundle.outletOperatingMode,
    now: DateTime(2026, 3, 29, 10),
  );

  final dataset = buildPayrollMatrix(
    startDate: bundle.startDate,
    endDate: bundle.endDate,
    employees: bundle.employees,
    recapRows: recapDataset.mergedRows,
  );

  final employeeNamesById = <String, String>{
    for (final row in dataset.rows) row.employeeId: row.employeeName,
  };
  final summaryValues = List<int>.generate(
    PayrollMatrixRow.summaryLabels.length,
    (index) => dataset.rows.fold<int>(
      0,
      (sum, row) => sum + row.summaryValuesInOrder[index],
    ),
    growable: false,
  );

  return _ParityPdfContext(
    bundle: bundle,
    dataset: dataset,
    employeeNamesById: employeeNamesById,
    isCompatibilityMode: recapDataset.isCompatibilityMode,
    summaryValues: summaryValues,
  );
}

class _ParityPdfContext {
  const _ParityPdfContext({
    required this.bundle,
    required this.dataset,
    required this.employeeNamesById,
    required this.isCompatibilityMode,
    required this.summaryValues,
  });

  final ReportExportParityFixtureBundle bundle;
  final PayrollMatrixDataset dataset;
  final Map<String, String> employeeNamesById;
  final bool isCompatibilityMode;
  final List<int> summaryValues;

  String employeeNameFor(String employeeId) => employeeNamesById[employeeId]!;

  PayrollMatrixDayCell cellFor(String employeeId, DateTime date) {
    final row = dataset.rows
        .firstWhere((candidate) => candidate.employeeId == employeeId);
    return row.cells.firstWhere(
      (candidate) => candidate.hasData && _isSameDate(candidate.date, date),
    );
  }
}

PayrollPdfMatrixCellPreview _previewCellFor(
  PayrollPdfDocumentPreview preview, {
  required String employeeName,
  required DateTime date,
}) {
  for (final page in preview.matrixPages) {
    final dateIndex =
        page.dates.indexWhere((candidate) => _isSameDate(candidate, date));
    if (dateIndex == -1) {
      continue;
    }

    for (final row in page.rows) {
      if (row.employeeName == employeeName) {
        return row.cells[dateIndex];
      }
    }
  }

  throw StateError('Preview cell not found for $employeeName on $date');
}

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
