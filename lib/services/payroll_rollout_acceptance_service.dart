import '../models/payroll_rollout_acceptance.dart';

const String payrollRolloutAdditiveOnlyTitle = 'Mode rollout additive';
const String payrollRolloutAdditiveOnlyBody =
    'Perubahan produksi harus additive-only dan semua perubahan database wajib lewat konfirmasi operator.';

PayrollRolloutAcceptanceSummary buildPayrollRolloutAcceptanceSummary({
  required List<PayrollScenarioReview> reviews,
  required bool databaseReviewConfirmed,
}) {
  final reviewByScenario = <PayrollRolloutScenarioId, PayrollScenarioReview>{
    for (final review in reviews) review.scenarioId: review,
  };

  final parityRows = <PayrollParityEvidenceRow>[];
  final scenarios = <PayrollRolloutScenarioState>[];

  for (final scenarioId in requiredPayrollRolloutScenarioIds) {
    final review = reviewByScenario[scenarioId];
    final evaluated = _evaluateScenarioReview(
      scenarioId: scenarioId,
      review: review,
    );
    parityRows.add(evaluated.row);
    scenarios.add(evaluated.state);
  }

  final blockedCount = scenarios
      .where(
          (scenario) => scenario.status == PayrollRolloutScenarioStatus.blocked)
      .length;
  final pendingCount = scenarios
      .where(
          (scenario) => scenario.status == PayrollRolloutScenarioStatus.pending)
      .length;
  final allPassed = scenarios.every(
    (scenario) => scenario.status == PayrollRolloutScenarioStatus.passed,
  );
  final canMarkPayrollReady =
      allPassed && blockedCount == 0 && databaseReviewConfirmed;

  return PayrollRolloutAcceptanceSummary(
    scenarios: scenarios,
    parityRows: parityRows,
    databaseReviewConfirmed: databaseReviewConfirmed,
    disabledReason: canMarkPayrollReady
        ? ''
        : _buildDisabledReason(
            pendingCount: pendingCount,
            blockedCount: blockedCount,
            databaseReviewConfirmed: databaseReviewConfirmed,
          ),
    readinessHeadline: canMarkPayrollReady
        ? 'Payroll siap dipakai'
        : 'Payroll belum aman dipakai',
    additiveOnlyReminderTitle: payrollRolloutAdditiveOnlyTitle,
    additiveOnlyReminderBody: payrollRolloutAdditiveOnlyBody,
  );
}

_EvaluatedScenario _evaluateScenarioReview({
  required PayrollRolloutScenarioId scenarioId,
  required PayrollScenarioReview? review,
}) {
  if (review == null) {
    return _buildMissingScenario(scenarioId);
  }

  final baseline = _resolveBaseline(review.evidenceBySource);
  final missingSources = requiredPayrollEvidenceSources
      .where((source) => !review.evidenceBySource.containsKey(source))
      .toList(growable: false);

  final status = _resolveStatus(
    review: review,
    missingSources: missingSources,
  );
  final reason = _resolveReason(
    review: review,
    status: status,
    missingSources: missingSources,
    baseline: baseline,
  );
  final nextActionNote = _resolveNextAction(
    status: status,
    missingSources: missingSources,
  );

  final state = PayrollRolloutScenarioState(
    scenarioId: scenarioId,
    label: scenarioId.label,
    status: status,
    primaryLabel: baseline?.primaryLabel ?? 'Belum ada bukti',
    shortTags: baseline?.shortTags ?? const <String>[],
    severityFamily: baseline?.severityFamily,
    reason: reason,
  );

  final row = PayrollParityEvidenceRow(
    scenarioId: scenarioId,
    scenarioLabel: scenarioId.label,
    logicalWorkdayLabel: review.logicalWorkdayLabel,
    contextLabel: review.contextLabel,
    evidenceBySource: review.evidenceBySource,
    missingSources: missingSources,
    status: status,
    reason: reason,
    nextActionNote: nextActionNote,
  );

  return _EvaluatedScenario(state: state, row: row);
}

_EvaluatedScenario _buildMissingScenario(PayrollRolloutScenarioId scenarioId) {
  const reason = 'Masih pending karena bukti skenario belum dikumpulkan.';
  final state = PayrollRolloutScenarioState(
    scenarioId: scenarioId,
    label: scenarioId.label,
    status: PayrollRolloutScenarioStatus.pending,
    primaryLabel: 'Belum ada bukti',
    shortTags: const <String>[],
    severityFamily: null,
    reason: reason,
  );
  final row = PayrollParityEvidenceRow(
    scenarioId: scenarioId,
    scenarioLabel: scenarioId.label,
    logicalWorkdayLabel: '-',
    contextLabel: null,
    evidenceBySource: const <PayrollEvidenceSource, PayrollEvidenceSnapshot>{},
    missingSources: requiredPayrollEvidenceSources,
    status: PayrollRolloutScenarioStatus.pending,
    reason: reason,
    nextActionNote: 'Kumpulkan bukti Admin, Spreadsheet, PDF, dan Portal.',
  );
  return _EvaluatedScenario(state: state, row: row);
}

PayrollRolloutScenarioStatus _resolveStatus({
  required PayrollScenarioReview review,
  required List<PayrollEvidenceSource> missingSources,
}) {
  if (_hasText(review.blockerReason)) {
    return PayrollRolloutScenarioStatus.blocked;
  }
  if (missingSources.isNotEmpty) {
    return PayrollRolloutScenarioStatus.pending;
  }
  final mismatchReason = _findParityMismatch(review.evidenceBySource);
  if (mismatchReason != null) {
    return PayrollRolloutScenarioStatus.blocked;
  }
  return PayrollRolloutScenarioStatus.passed;
}

String _resolveReason({
  required PayrollScenarioReview review,
  required PayrollRolloutScenarioStatus status,
  required List<PayrollEvidenceSource> missingSources,
  required PayrollEvidenceSnapshot? baseline,
}) {
  switch (status) {
    case PayrollRolloutScenarioStatus.passed:
      return 'Parity terkonfirmasi untuk ${review.scenarioId.label}.';
    case PayrollRolloutScenarioStatus.pending:
      if (missingSources.isEmpty) {
        return 'Masih pending untuk dilengkapi.';
      }
      final labels = missingSources.map((source) => source.label).join(', ');
      return 'Masih pending karena bukti $labels belum lengkap.';
    case PayrollRolloutScenarioStatus.blocked:
      if (_hasText(review.blockerReason)) {
        return review.blockerReason!;
      }
      return _findParityMismatch(review.evidenceBySource) ??
          'Parity blocked untuk ${baseline?.primaryLabel ?? review.scenarioId.label}.';
  }
}

String _resolveNextAction({
  required PayrollRolloutScenarioStatus status,
  required List<PayrollEvidenceSource> missingSources,
}) {
  switch (status) {
    case PayrollRolloutScenarioStatus.passed:
      return 'Skenario siap untuk review akhir.';
    case PayrollRolloutScenarioStatus.pending:
      final labels = missingSources.isEmpty
          ? 'Admin, Spreadsheet, PDF, dan Portal'
          : missingSources.map((source) => source.label).join(', ');
      return 'Lengkapi bukti $labels sebelum approval payroll.';
    case PayrollRolloutScenarioStatus.blocked:
      return 'Tinjau label utama, short tags, dan severity family di semua artefak.';
  }
}

String _buildDisabledReason({
  required int pendingCount,
  required int blockedCount,
  required bool databaseReviewConfirmed,
}) {
  if (blockedCount > 0) {
    return 'Masih ada bukti parity yang blocked.';
  }
  if (pendingCount > 0) {
    return 'Masih ada skenario wajib yang pending.';
  }
  if (!databaseReviewConfirmed) {
    return 'Konfirmasi review database masih wajib sebelum payroll bisa ditandai siap.';
  }
  return 'Payroll belum aman dipakai.';
}

PayrollEvidenceSnapshot? _resolveBaseline(
  Map<PayrollEvidenceSource, PayrollEvidenceSnapshot> evidenceBySource,
) {
  for (final source in requiredPayrollEvidenceSources) {
    final snapshot = evidenceBySource[source];
    if (snapshot != null) {
      return snapshot;
    }
  }
  if (evidenceBySource.isEmpty) {
    return null;
  }
  return evidenceBySource.values.first;
}

String? _findParityMismatch(
  Map<PayrollEvidenceSource, PayrollEvidenceSnapshot> evidenceBySource,
) {
  final baseline = _resolveBaseline(evidenceBySource);
  if (baseline == null) {
    return null;
  }

  for (final source in requiredPayrollEvidenceSources) {
    final candidate = evidenceBySource[source];
    if (candidate == null) {
      continue;
    }
    if (!_matchesPrimaryLabel(baseline, candidate)) {
      return 'Parity blocked: ${candidate.source.label} berbeda dari ${baseline.source.label} pada label utama.';
    }
    if (!_matchesShortTags(baseline, candidate)) {
      return 'Parity blocked: ${candidate.source.label} berbeda dari ${baseline.source.label} pada short tags.';
    }
    if (candidate.severityFamily != baseline.severityFamily) {
      return 'Parity blocked: ${candidate.source.label} berbeda dari ${baseline.source.label} pada severity family.';
    }
  }
  return null;
}

bool _matchesPrimaryLabel(
  PayrollEvidenceSnapshot left,
  PayrollEvidenceSnapshot right,
) {
  return left.primaryLabel.trim().toLowerCase() ==
      right.primaryLabel.trim().toLowerCase();
}

bool _matchesShortTags(
  PayrollEvidenceSnapshot left,
  PayrollEvidenceSnapshot right,
) {
  if (left.shortTags.length != right.shortTags.length) {
    return false;
  }

  for (var index = 0; index < left.shortTags.length; index++) {
    if (left.shortTags[index].trim().toLowerCase() !=
        right.shortTags[index].trim().toLowerCase()) {
      return false;
    }
  }
  return true;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

class _EvaluatedScenario {
  final PayrollRolloutScenarioState state;
  final PayrollParityEvidenceRow row;

  const _EvaluatedScenario({
    required this.state,
    required this.row,
  });
}
