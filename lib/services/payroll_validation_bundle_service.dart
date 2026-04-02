import 'package:absensi_enakko_flutter/models/payroll_rollout_acceptance.dart';

typedef PayrollValidationBundleNowProvider = DateTime Function();

class PayrollValidationBundle {
  const PayrollValidationBundle({
    required this.filename,
    required this.content,
    required this.generatedAt,
    required this.readinessHeadline,
    required this.scenarioStatuses,
    required this.blockedFollowUps,
  });

  final String filename;
  final String content;
  final DateTime generatedAt;
  final String readinessHeadline;
  final List<PayrollRolloutScenarioState> scenarioStatuses;
  final List<PayrollParityEvidenceRow> blockedFollowUps;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'filename': filename,
      'content': content,
      'generatedAt': generatedAt.toIso8601String(),
      'readinessHeadline': readinessHeadline,
      'scenarioStatuses':
          scenarioStatuses.map((scenario) => scenario.toJson()).toList(),
      'blockedFollowUps': blockedFollowUps.map((row) => row.toJson()).toList(),
    };
  }
}

class PayrollValidationBundleService {
  PayrollValidationBundleService({
    PayrollValidationBundleNowProvider? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now;

  static const List<String> evidenceLabels = <String>[
    'Admin',
    'Spreadsheet',
    'PDF',
    'Portal',
  ];

  final PayrollValidationBundleNowProvider _nowProvider;

  PayrollValidationBundle buildPayrollValidationBundle({
    required String outletName,
    required DateTime startDate,
    required DateTime endDate,
    required PayrollRolloutAcceptanceSummary summary,
  }) {
    final generatedAt = _nowProvider();
    final content = _buildContent(
      outletName: outletName,
      startDate: startDate,
      endDate: endDate,
      summary: summary,
      generatedAt: generatedAt,
    );

    return PayrollValidationBundle(
      filename: _buildFilename(
        outletName: outletName,
        startDate: startDate,
        endDate: endDate,
      ),
      content: content,
      generatedAt: generatedAt,
      readinessHeadline: summary.readinessHeadline,
      scenarioStatuses:
          List<PayrollRolloutScenarioState>.from(summary.scenarios),
      blockedFollowUps: List<PayrollParityEvidenceRow>.from(
        summary.blockedParityRows,
      ),
    );
  }

  String _buildContent({
    required String outletName,
    required DateTime startDate,
    required DateTime endDate,
    required PayrollRolloutAcceptanceSummary summary,
    required DateTime generatedAt,
  }) {
    final lines = <String>[
      '# Bukti Validasi Payroll',
      '',
      'Generated: ${_formatTimestamp(generatedAt)}',
      'Outlet: $outletName',
      'Periode: ${_formatDate(startDate)} - ${_formatDate(endDate)}',
      '',
      '## Status Rollout',
      summary.readinessHeadline,
      summary.additiveOnlyReminderTitle,
      summary.additiveOnlyReminderBody,
      '- Passed: ${summary.passedCount}',
      '- Pending: ${summary.pendingCount}',
      '- Blocked: ${summary.blockedCount}',
      '- Review database dikonfirmasi: ${summary.databaseReviewConfirmed ? 'ya' : 'belum'}',
      '',
      '## Skenario wajib',
    ];

    for (final scenario in summary.scenarios) {
      lines.add('- ${scenario.label}: ${scenario.status.label}');
    }

    lines.add('');
    lines.add('## Bukti parity');
    lines.add('Kolom evidence: ${evidenceLabels.join(' | ')}');
    for (final row in summary.parityRows) {
      final evidenceSources =
          row.evidenceBySource.keys.map((source) => source.label).join(', ');
      lines.add(
        '- ${row.scenarioLabel} (${row.logicalWorkdayLabel}): '
        '${row.status.label} | $evidenceSources',
      );
      if (row.reason.isNotEmpty) {
        lines.add('  Alasan: ${row.reason}');
      }
    }

    if (summary.blockedParityRows.isNotEmpty) {
      lines.add('');
      lines.add('## Blocked follow-up');
      for (final row in summary.blockedParityRows) {
        lines.add(
          '- ${row.scenarioLabel}: ${row.status.label} | ${row.nextActionNote}',
        );
      }
    }

    if (summary.disabledReason.isNotEmpty) {
      lines.add('');
      lines.add('## Alasan CTA Dinonaktifkan');
      lines.add(summary.disabledReason);
    }

    return '${lines.join('\n')}\n';
  }

  String _buildFilename({
    required String outletName,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final slug = outletName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final resolvedSlug = slug.isEmpty ? 'outlet' : slug;
    return 'bukti_validasi_payroll_'
        '${resolvedSlug}_${_formatDateToken(startDate)}_${_formatDateToken(endDate)}.md';
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.year}';
  }

  String _formatTimestamp(DateTime value) {
    return '${_formatDate(value)} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateToken(DateTime value) {
    return '${value.year}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
