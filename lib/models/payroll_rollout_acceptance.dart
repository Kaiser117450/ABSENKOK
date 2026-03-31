const List<PayrollRolloutScenarioId> requiredPayrollRolloutScenarioIds =
    <PayrollRolloutScenarioId>[
  PayrollRolloutScenarioId.fullTime,
  PayrollRolloutScenarioId.partTime,
  PayrollRolloutScenarioId.overtime,
  PayrollRolloutScenarioId.outlet24Hour,
  PayrollRolloutScenarioId.outletNormal,
  PayrollRolloutScenarioId.breakFirst,
  PayrollRolloutScenarioId.noShow,
];

const List<PayrollEvidenceSource> requiredPayrollEvidenceSources =
    <PayrollEvidenceSource>[
  PayrollEvidenceSource.admin,
  PayrollEvidenceSource.spreadsheet,
  PayrollEvidenceSource.pdf,
  PayrollEvidenceSource.portal,
];

enum PayrollRolloutScenarioId {
  fullTime,
  partTime,
  overtime,
  outlet24Hour,
  outletNormal,
  breakFirst,
  noShow,
}

extension PayrollRolloutScenarioIdMetadata on PayrollRolloutScenarioId {
  String get key {
    switch (this) {
      case PayrollRolloutScenarioId.fullTime:
        return 'fullTime';
      case PayrollRolloutScenarioId.partTime:
        return 'partTime';
      case PayrollRolloutScenarioId.overtime:
        return 'overtime';
      case PayrollRolloutScenarioId.outlet24Hour:
        return 'outlet24Hour';
      case PayrollRolloutScenarioId.outletNormal:
        return 'outletNormal';
      case PayrollRolloutScenarioId.breakFirst:
        return 'breakFirst';
      case PayrollRolloutScenarioId.noShow:
        return 'noShow';
    }
  }

  String get label {
    switch (this) {
      case PayrollRolloutScenarioId.fullTime:
        return 'Full-time';
      case PayrollRolloutScenarioId.partTime:
        return 'Part-time';
      case PayrollRolloutScenarioId.overtime:
        return 'Lembur';
      case PayrollRolloutScenarioId.outlet24Hour:
        return 'Outlet 24 jam';
      case PayrollRolloutScenarioId.outletNormal:
        return 'Outlet normal';
      case PayrollRolloutScenarioId.breakFirst:
        return 'Break-first';
      case PayrollRolloutScenarioId.noShow:
        return 'No-show';
    }
  }
}

enum PayrollEvidenceSource {
  admin,
  spreadsheet,
  pdf,
  portal,
}

extension PayrollEvidenceSourceMetadata on PayrollEvidenceSource {
  String get key {
    switch (this) {
      case PayrollEvidenceSource.admin:
        return 'admin';
      case PayrollEvidenceSource.spreadsheet:
        return 'spreadsheet';
      case PayrollEvidenceSource.pdf:
        return 'pdf';
      case PayrollEvidenceSource.portal:
        return 'portal';
    }
  }

  String get label {
    switch (this) {
      case PayrollEvidenceSource.admin:
        return 'Admin';
      case PayrollEvidenceSource.spreadsheet:
        return 'Spreadsheet';
      case PayrollEvidenceSource.pdf:
        return 'PDF';
      case PayrollEvidenceSource.portal:
        return 'Portal';
    }
  }
}

enum PayrollRolloutScenarioStatus {
  passed,
  pending,
  blocked,
}

extension PayrollRolloutScenarioStatusMetadata on PayrollRolloutScenarioStatus {
  String get key {
    switch (this) {
      case PayrollRolloutScenarioStatus.passed:
        return 'passed';
      case PayrollRolloutScenarioStatus.pending:
        return 'pending';
      case PayrollRolloutScenarioStatus.blocked:
        return 'blocked';
    }
  }

  String get label {
    switch (this) {
      case PayrollRolloutScenarioStatus.passed:
        return 'passed';
      case PayrollRolloutScenarioStatus.pending:
        return 'pending';
      case PayrollRolloutScenarioStatus.blocked:
        return 'blocked';
    }
  }
}

enum PayrollOutcomeSeverityFamily {
  neutral,
  info,
  yellow,
  red,
  purple,
  gray,
}

extension PayrollOutcomeSeverityFamilyMetadata on PayrollOutcomeSeverityFamily {
  String get key {
    switch (this) {
      case PayrollOutcomeSeverityFamily.neutral:
        return 'neutral';
      case PayrollOutcomeSeverityFamily.info:
        return 'info';
      case PayrollOutcomeSeverityFamily.yellow:
        return 'yellow';
      case PayrollOutcomeSeverityFamily.red:
        return 'red';
      case PayrollOutcomeSeverityFamily.purple:
        return 'purple';
      case PayrollOutcomeSeverityFamily.gray:
        return 'gray';
    }
  }
}

class PayrollEvidenceSnapshot {
  final PayrollEvidenceSource source;
  final String primaryLabel;
  final List<String> shortTags;
  final PayrollOutcomeSeverityFamily severityFamily;
  final String? note;

  const PayrollEvidenceSnapshot({
    required this.source,
    required this.primaryLabel,
    required this.shortTags,
    required this.severityFamily,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'source': source.key,
      'primaryLabel': primaryLabel,
      'shortTags': shortTags,
      'severityFamily': severityFamily.key,
      'note': note,
    };
  }
}

class PayrollScenarioReview {
  final PayrollRolloutScenarioId scenarioId;
  final String logicalWorkdayLabel;
  final String? contextLabel;
  final Map<PayrollEvidenceSource, PayrollEvidenceSnapshot> evidenceBySource;
  final String? blockerReason;

  const PayrollScenarioReview({
    required this.scenarioId,
    required this.logicalWorkdayLabel,
    required this.evidenceBySource,
    this.contextLabel,
    this.blockerReason,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'scenarioId': scenarioId.key,
      'logicalWorkdayLabel': logicalWorkdayLabel,
      'contextLabel': contextLabel,
      'evidenceBySource': <String, dynamic>{
        for (final entry in evidenceBySource.entries)
          entry.key.key: entry.value.toJson(),
      },
      'blockerReason': blockerReason,
    };
  }
}

class PayrollParityEvidenceRow {
  final PayrollRolloutScenarioId scenarioId;
  final String scenarioLabel;
  final String logicalWorkdayLabel;
  final String? contextLabel;
  final Map<PayrollEvidenceSource, PayrollEvidenceSnapshot> evidenceBySource;
  final List<PayrollEvidenceSource> missingSources;
  final PayrollRolloutScenarioStatus status;
  final String reason;
  final String nextActionNote;

  const PayrollParityEvidenceRow({
    required this.scenarioId,
    required this.scenarioLabel,
    required this.logicalWorkdayLabel,
    required this.contextLabel,
    required this.evidenceBySource,
    required this.missingSources,
    required this.status,
    required this.reason,
    required this.nextActionNote,
  });

  bool get isBlocked => status == PayrollRolloutScenarioStatus.blocked;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'scenarioId': scenarioId.key,
      'scenarioLabel': scenarioLabel,
      'logicalWorkdayLabel': logicalWorkdayLabel,
      'contextLabel': contextLabel,
      'evidenceBySource': <String, dynamic>{
        for (final entry in evidenceBySource.entries)
          entry.key.key: entry.value.toJson(),
      },
      'missingSources':
          missingSources.map((source) => source.key).toList(growable: false),
      'status': status.key,
      'reason': reason,
      'nextActionNote': nextActionNote,
    };
  }
}

class PayrollRolloutScenarioState {
  final PayrollRolloutScenarioId scenarioId;
  final String label;
  final PayrollRolloutScenarioStatus status;
  final String primaryLabel;
  final List<String> shortTags;
  final PayrollOutcomeSeverityFamily? severityFamily;
  final String reason;

  const PayrollRolloutScenarioState({
    required this.scenarioId,
    required this.label,
    required this.status,
    required this.primaryLabel,
    required this.shortTags,
    required this.severityFamily,
    required this.reason,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'scenarioId': scenarioId.key,
      'label': label,
      'status': status.key,
      'primaryLabel': primaryLabel,
      'shortTags': shortTags,
      'severityFamily': severityFamily?.key,
      'reason': reason,
    };
  }
}

class PayrollRolloutAcceptanceSummary {
  final List<PayrollRolloutScenarioState> scenarios;
  final List<PayrollParityEvidenceRow> parityRows;
  final bool databaseReviewConfirmed;
  final String disabledReason;
  final String readinessHeadline;
  final String additiveOnlyReminderTitle;
  final String additiveOnlyReminderBody;

  const PayrollRolloutAcceptanceSummary({
    required this.scenarios,
    required this.parityRows,
    required this.databaseReviewConfirmed,
    required this.disabledReason,
    required this.readinessHeadline,
    required this.additiveOnlyReminderTitle,
    required this.additiveOnlyReminderBody,
  });

  int get passedCount => scenarios
      .where(
          (scenario) => scenario.status == PayrollRolloutScenarioStatus.passed)
      .length;

  int get pendingCount => scenarios
      .where(
          (scenario) => scenario.status == PayrollRolloutScenarioStatus.pending)
      .length;

  int get blockedCount => scenarios
      .where(
          (scenario) => scenario.status == PayrollRolloutScenarioStatus.blocked)
      .length;

  List<PayrollParityEvidenceRow> get blockedParityRows => parityRows
      .where((row) => row.status == PayrollRolloutScenarioStatus.blocked)
      .toList(growable: false);

  bool get canMarkPayrollReady =>
      passedCount == requiredPayrollRolloutScenarioIds.length &&
      blockedParityRows.isEmpty &&
      databaseReviewConfirmed;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'scenarios': scenarios.map((scenario) => scenario.toJson()).toList(),
      'parityRows': parityRows.map((row) => row.toJson()).toList(),
      'databaseReviewConfirmed': databaseReviewConfirmed,
      'disabledReason': disabledReason,
      'readinessHeadline': readinessHeadline,
      'additiveOnlyReminderTitle': additiveOnlyReminderTitle,
      'additiveOnlyReminderBody': additiveOnlyReminderBody,
      'passedCount': passedCount,
      'pendingCount': pendingCount,
      'blockedCount': blockedCount,
      'canMarkPayrollReady': canMarkPayrollReady,
    };
  }
}
