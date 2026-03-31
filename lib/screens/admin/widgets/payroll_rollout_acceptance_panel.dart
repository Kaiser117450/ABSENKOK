import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/payroll_rollout_acceptance.dart';
import '../../../services/payroll_rollout_acceptance_service.dart';
import '../../../widgets/app_card.dart';

class PayrollRolloutAcceptancePanel extends StatefulWidget {
  const PayrollRolloutAcceptancePanel({
    super.key,
    required this.reviews,
    required this.outletName,
    required this.startDate,
    required this.endDate,
    required this.onDownloadValidationBundle,
    this.onMarkPayrollReady,
  });

  final List<PayrollScenarioReview> reviews;
  final String outletName;
  final DateTime startDate;
  final DateTime endDate;
  final Future<void> Function(PayrollRolloutAcceptanceSummary summary)
      onDownloadValidationBundle;
  final VoidCallback? onMarkPayrollReady;

  @override
  State<PayrollRolloutAcceptancePanel> createState() =>
      _PayrollRolloutAcceptancePanelState();
}

class _PayrollRolloutAcceptancePanelState
    extends State<PayrollRolloutAcceptancePanel> {
  bool _databaseReviewConfirmed = false;
  bool _exportingValidationBundle = false;

  PayrollRolloutAcceptanceSummary get _summary =>
      buildPayrollRolloutAcceptanceSummary(
        reviews: widget.reviews,
        databaseReviewConfirmed: _databaseReviewConfirmed,
      );

  Future<void> _handleDatabaseReview() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Terapkan perubahan database'),
          content: const Text(
            'Perubahan database harus additive-only dan hanya dijalankan '
            'setelah backup, checklist, dan persetujuan operator lengkap. '
            'Lanjutkan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Saya Sudah Review'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _databaseReviewConfirmed = true);
    }
  }

  Future<void> _handleDownloadValidationBundle() async {
    if (_exportingValidationBundle) {
      return;
    }

    setState(() => _exportingValidationBundle = true);
    try {
      await widget.onDownloadValidationBundle(_summary);
    } finally {
      if (mounted) {
        setState(() => _exportingValidationBundle = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final readinessColor = _statusColor(
      summary.blockedCount > 0
          ? PayrollRolloutScenarioStatus.blocked
          : summary.pendingCount > 0
              ? PayrollRolloutScenarioStatus.pending
              : PayrollRolloutScenarioStatus.passed,
    );

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rollout Payroll',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            summary.readinessHeadline,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: readinessColor,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            summary.disabledReason.isEmpty
                ? 'Semua skenario wajib sudah selaras dan payroll bisa dilanjutkan.'
                : summary.disabledReason,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFEFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF99F6E4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mode rollout additive',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.additiveOnlyReminderBody,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Skenario wajib',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...summary.scenarios.map(
            (scenario) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scenario.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          scenario.reason,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusChip(status: scenario.status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bukti parity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(148),
              border: TableBorder.all(color: const Color(0xFFE2E8F0)),
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                  children: [
                    _HeaderCell('Admin'),
                    _HeaderCell('Spreadsheet'),
                    _HeaderCell('PDF'),
                    _HeaderCell('Portal'),
                    _HeaderCell('Status'),
                  ],
                ),
                ...summary.parityRows.map(
                  (row) => TableRow(
                    children: [
                      _ValueCell(_evidenceText(
                        row,
                        PayrollEvidenceSource.admin,
                      )),
                      _ValueCell(_evidenceText(
                        row,
                        PayrollEvidenceSource.spreadsheet,
                      )),
                      _ValueCell(_evidenceText(
                        row,
                        PayrollEvidenceSource.pdf,
                      )),
                      _ValueCell(_evidenceText(
                        row,
                        PayrollEvidenceSource.portal,
                      )),
                      _ValueCell(row.status.label),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Outlet ${widget.outletName} | '
            '${_formatDate(widget.startDate)} - ${_formatDate(widget.endDate)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _handleDatabaseReview,
                icon: Icon(
                  _databaseReviewConfirmed
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  size: 18,
                ),
                label: Text(
                  _databaseReviewConfirmed
                      ? 'Review database tersimpan'
                      : 'Review database additive',
                ),
              ),
              FilledButton(
                onPressed: summary.canMarkPayrollReady
                    ? widget.onMarkPayrollReady
                    : null,
                child: const Text('Tandai Siap Payroll'),
              ),
              OutlinedButton.icon(
                onPressed: _exportingValidationBundle
                    ? null
                    : _handleDownloadValidationBundle,
                icon: _exportingValidationBundle
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined, size: 18),
                label: const Text('Unduh Bukti Validasi'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _statusColor(PayrollRolloutScenarioStatus status) {
    switch (status) {
      case PayrollRolloutScenarioStatus.passed:
        return const Color(0xFF166534);
      case PayrollRolloutScenarioStatus.pending:
        return const Color(0xFF92400E);
      case PayrollRolloutScenarioStatus.blocked:
        return const Color(0xFFB91C1C);
    }
  }

  static String _evidenceText(
    PayrollParityEvidenceRow row,
    PayrollEvidenceSource source,
  ) {
    final evidence = row.evidenceBySource[source];
    if (evidence == null) {
      return 'Menunggu';
    }
    if (evidence.shortTags.isEmpty) {
      return evidence.primaryLabel;
    }
    return '${evidence.primaryLabel}\n${evidence.shortTags.join(' ')}';
  }

  static String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.year}';
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          height: 1.35,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final PayrollRolloutScenarioStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _PayrollRolloutAcceptancePanelState._statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
