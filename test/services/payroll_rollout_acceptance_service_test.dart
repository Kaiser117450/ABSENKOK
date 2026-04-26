import 'package:absensi_enakko_flutter/models/payroll_rollout_acceptance.dart';
import 'package:absensi_enakko_flutter/services/payroll_rollout_acceptance_service.dart';
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
    String logicalWorkdayLabel = '2026-03-31',
    String? blockerReason,
  }) {
    return PayrollScenarioReview(
      scenarioId: scenarioId,
      logicalWorkdayLabel: logicalWorkdayLabel,
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

  List<PayrollScenarioReview> allScenarioReviews() {
    return requiredPayrollRolloutScenarioIds
        .map((scenarioId) => reviewFor(scenarioId))
        .toList(growable: false);
  }

  group('buildPayrollRolloutAcceptanceSummary', () {
    test('includes all six required scenario IDs in locked order', () {
      final summary = buildPayrollRolloutAcceptanceSummary(
        reviews: allScenarioReviews(),
        databaseReviewConfirmed: true,
      );

      expect(
        summary.scenarios.map((scenario) => scenario.scenarioId).toList(),
        requiredPayrollRolloutScenarioIds,
      );
      expect(summary.passedCount, 6);
      expect(summary.pendingCount, 0);
      expect(summary.blockedCount, 0);
      expect(summary.canMarkPayrollReady, isTrue);
    });

    test('keeps CTA disabled while any scenario is pending', () {
      final reviews = allScenarioReviews();
      reviews[0] = reviewFor(
        PayrollRolloutScenarioId.fullTime,
        evidenceBySource: <PayrollEvidenceSource, PayrollEvidenceSnapshot>{
          PayrollEvidenceSource.admin: snapshot(PayrollEvidenceSource.admin),
          PayrollEvidenceSource.spreadsheet:
              snapshot(PayrollEvidenceSource.spreadsheet),
          PayrollEvidenceSource.pdf: snapshot(PayrollEvidenceSource.pdf),
        },
      );

      final summary = buildPayrollRolloutAcceptanceSummary(
        reviews: reviews,
        databaseReviewConfirmed: true,
      );

      expect(summary.canMarkPayrollReady, isFalse);
      expect(summary.pendingCount, 1);
      expect(summary.blockedCount, 0);
      expect(summary.disabledReason, contains('pending'));
      expect(
          summary.scenarios.first.status, PayrollRolloutScenarioStatus.pending);
    });

    test('blocked parity rows force blocked readiness', () {
      final reviews = allScenarioReviews();
      reviews[5] = reviewFor(
        PayrollRolloutScenarioId.noShow,
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

      final summary = buildPayrollRolloutAcceptanceSummary(
        reviews: reviews,
        databaseReviewConfirmed: true,
      );

      expect(summary.canMarkPayrollReady, isFalse);
      expect(summary.pendingCount, 0);
      expect(summary.blockedCount, 1);
      expect(summary.blockedParityRows, hasLength(1));
      expect(
        summary.blockedParityRows.single.scenarioId,
        PayrollRolloutScenarioId.noShow,
      );
      expect(summary.disabledReason, contains('blocked'));
    });

    test('requires manual database confirmation before readiness passes', () {
      final summary = buildPayrollRolloutAcceptanceSummary(
        reviews: allScenarioReviews(),
        databaseReviewConfirmed: false,
      );

      expect(summary.passedCount, 6);
      expect(summary.pendingCount, 0);
      expect(summary.blockedCount, 0);
      expect(summary.canMarkPayrollReady, isFalse);
      expect(summary.disabledReason, contains('database'));
      expect(summary.readinessHeadline, 'Payroll belum aman dipakai');
    });
  });
}
