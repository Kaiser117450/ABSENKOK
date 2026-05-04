import 'dart:convert';

import 'package:absensi_enakko_flutter/models/payroll_rollout_acceptance.dart';
import 'package:absensi_enakko_flutter/services/payroll_rollout_acceptance_service.dart';
import 'package:absensi_enakko_flutter/services/payroll_validation_bundle_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PayrollEvidenceSnapshot snapshot(
    PayrollEvidenceSource source, {
    String primaryLabel = 'Terlambat',
    List<String> shortTags = const <String>['TLT'],
    PayrollOutcomeSeverityFamily severityFamily =
        PayrollOutcomeSeverityFamily.yellow,
  }) {
    return PayrollEvidenceSnapshot(
      source: source,
      primaryLabel: primaryLabel,
      shortTags: shortTags,
      severityFamily: severityFamily,
    );
  }

  PayrollScenarioReview reviewFor(
    PayrollRolloutScenarioId scenarioId, {
    Map<PayrollEvidenceSource, PayrollEvidenceSnapshot>? evidenceBySource,
    String? blockerReason,
  }) {
    return PayrollScenarioReview(
      scenarioId: scenarioId,
      logicalWorkdayLabel: '2026-03-31',
      evidenceBySource: evidenceBySource ??
          <PayrollEvidenceSource, PayrollEvidenceSnapshot>{
            PayrollEvidenceSource.admin: snapshot(PayrollEvidenceSource.admin),
            PayrollEvidenceSource.spreadsheet:
                snapshot(PayrollEvidenceSource.spreadsheet),
            PayrollEvidenceSource.pdf: snapshot(PayrollEvidenceSource.pdf),
            PayrollEvidenceSource.portal:
                snapshot(PayrollEvidenceSource.portal),
          },
      blockerReason: blockerReason,
    );
  }

  PayrollRolloutAcceptanceSummary buildSummary({
    bool databaseReviewConfirmed = true,
    bool blocked = false,
  }) {
    final reviews = requiredPayrollRolloutScenarioIds
        .map((scenarioId) => reviewFor(scenarioId))
        .toList(growable: false);
    if (blocked) {
      reviews[2] = reviewFor(
        PayrollRolloutScenarioId.overtime,
        evidenceBySource: <PayrollEvidenceSource, PayrollEvidenceSnapshot>{
          PayrollEvidenceSource.admin: snapshot(PayrollEvidenceSource.admin),
          PayrollEvidenceSource.spreadsheet:
              snapshot(PayrollEvidenceSource.spreadsheet),
          PayrollEvidenceSource.pdf: snapshot(
            PayrollEvidenceSource.pdf,
            primaryLabel: 'Tidak Hadir',
            shortTags: const <String>['ABS'],
            severityFamily: PayrollOutcomeSeverityFamily.red,
          ),
          PayrollEvidenceSource.portal: snapshot(PayrollEvidenceSource.portal),
        },
      );
    }

    return buildPayrollRolloutAcceptanceSummary(
      reviews: reviews,
      databaseReviewConfirmed: databaseReviewConfirmed,
    );
  }

  group('PayrollValidationBundleService', () {
    final service = PayrollValidationBundleService(
      nowProvider: () => DateTime(2026, 3, 31, 10, 30),
    );

    test('bundle contains rollout summary and evidence sections', () {
      final bundle = service.buildPayrollValidationBundle(
        outletName: 'Outlet Pusat',
        startDate: DateTime(2026, 3, 25),
        endDate: DateTime(2026, 3, 31),
        summary: buildSummary(),
      );

      expect(bundle.readinessHeadline, 'Payroll siap dipakai');
      expect(
        bundle.scenarioStatuses,
        hasLength(requiredPayrollRolloutScenarioIds.length),
      );
      expect(bundle.content, contains('Status Rollout'));
      expect(bundle.content, contains('Skenario wajib'));
      expect(bundle.content, contains('Bukti parity'));
      expect(bundle.content, contains('Admin'));
      expect(bundle.content, contains('Spreadsheet'));
      expect(bundle.content, contains('PDF'));
      expect(bundle.content, contains('Portal'));
      expect(bundle.content, contains('Mode rollout additive'));
    });

    test('forbidden low-signal fields do not appear in the bundle output', () {
      final bundle = service.buildPayrollValidationBundle(
        outletName: 'Outlet Pusat',
        startDate: DateTime(2026, 3, 25),
        endDate: DateTime(2026, 3, 31),
        summary: buildSummary(),
      );

      final serialized = jsonEncode(bundle.toJson());
      final forbiddenFields = <String>[
        'latitude',
        'longitude',
        'capture_mode',
        'queue_order',
        'detail_note',
      ];

      for (final field in forbiddenFields) {
        expect(
          serialized.contains(field),
          isFalse,
          reason: 'Bundle should not expose $field',
        );
      }
    });

    test('blocked rows render as blocked follow-up items', () {
      final bundle = service.buildPayrollValidationBundle(
        outletName: 'Outlet Pusat',
        startDate: DateTime(2026, 3, 25),
        endDate: DateTime(2026, 3, 31),
        summary: buildSummary(blocked: true),
      );

      expect(bundle.blockedFollowUps, isNotEmpty);
      expect(bundle.content, contains('Blocked follow-up'));
      expect(bundle.content, contains('Lembur'));
      expect(bundle.content, contains('blocked'));
    });
  });
}
