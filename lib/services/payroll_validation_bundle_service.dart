import '../models/payroll_rollout_acceptance.dart';

typedef PayrollValidationBundleNowProvider = DateTime Function();

class PayrollValidationBundle {
  const PayrollValidationBundle({
    required this.filename,
    required this.content,
    required this.generatedAt,
  });

  final String filename;
  final String content;
  final DateTime generatedAt;
}

class PayrollValidationBundleService {
  PayrollValidationBundleService({
    PayrollValidationBundleNowProvider? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now;

  static const List<String> forbiddenFields = <String>[
    'latitude',
    'longitude',
    'capture_mode',
    'queue_order',
    'detail_note',
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
      'Headline: ${summary.readinessHeadline}',
      'Mode rollout additive',
      'Perubahan produksi harus additive-only dan setiap langkah database tetap membutuhkan konfirmasi manual.',
      '',
      '## Ringkasan',
      '- Status akhir: ${summary.readinessState.name}',
      '- Passed: ${summary.passedCount}',
      '- Pending: ${summary.pendingCount}',
      '- Blocked: ${summary.blockedCount}',
      '- Review database dikonfirmasi: ${summary.databaseReviewConfirmed ? 'ya' : 'belum'}',
      '',
      '## Status skenario wajib',
    ];

    for (final scenario in summary.scenarios) {
      lines.add('- ${scenario.label}: ${scenario.status.label}');
    }

    lines.add('');
    lines.add('## Bukti parity');
    lines.add('Kolom evidence: Admin | Spreadsheet | PDF | Portal');
    for (final scenario in summary.scenarios) {
      for (final row in scenario.parityRows) {
        lines.add(
          '- ${row.title} (${_formatDate(row.logicalWorkday)}): '
          'Admin, Spreadsheet, PDF, Portal -> ${row.status.label}',
        );
      }
    }

    if (summary.blockedParityRows.isNotEmpty) {
      lines.add('');
      lines.add('## Blocked follow-up');
      for (final row in summary.blockedParityRows) {
        lines.add('- ${row.title}: ${row.nextActionNote}');
      }
    }

    if (summary.disabledReason.isNotEmpty) {
      lines.add('');
      lines.add('## Alasan CTA Dinonaktifkan');
      lines.add(summary.disabledReason);
    }

    lines.add('');
    lines.add('## Catatan');
    lines.add(
      'Bundle ini merangkum hasil Admin, Spreadsheet, PDF, dan Portal tanpa membawa field teknis rendah-sinyal.',
    );

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
