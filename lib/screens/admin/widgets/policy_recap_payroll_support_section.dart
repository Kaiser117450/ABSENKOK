import 'package:flutter/material.dart';
import 'package:absensi_enakko_flutter/core/theme.dart';
import 'package:absensi_enakko_flutter/widgets/app_card.dart';

class PolicyRecapPayrollSupportSection extends StatelessWidget {
  const PolicyRecapPayrollSupportSection({
    super.key,
    required this.canExportPayrollPdf,
    required this.canExportPayrollSpreadsheet,
    required this.exportingPayrollPdf,
    required this.exportingSpreadsheet,
    required this.onExportPayrollPdf,
    required this.onExportPayrollSpreadsheet,
    required this.payrollExportStatusMessage,
    required this.payrollExportStatusIsError,
    this.previewSection,
  });

  final bool canExportPayrollPdf;
  final bool canExportPayrollSpreadsheet;
  final bool exportingPayrollPdf;
  final bool exportingSpreadsheet;
  final VoidCallback? onExportPayrollPdf;
  final VoidCallback? onExportPayrollSpreadsheet;
  final String? payrollExportStatusMessage;
  final bool payrollExportStatusIsError;
  final Widget? previewSection;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        payrollExportStatusIsError ? AppColors.danger : AppColors.textSecondary;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Output Payroll',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'PDF payroll dan spreadsheet tetap tersedia sebagai output gaji dari dataset recap yang sama.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: canExportPayrollPdf ? onExportPayrollPdf : null,
                icon: exportingPayrollPdf
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 18,
                      ),
                label: const Text('Ekspor PDF Payroll'),
              ),
              OutlinedButton.icon(
                onPressed: canExportPayrollSpreadsheet
                    ? onExportPayrollSpreadsheet
                    : null,
                icon: exportingSpreadsheet
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.grid_on_outlined, size: 18),
                label: const Text('Ekspor Spreadsheet'),
              ),
            ],
          ),
          if (payrollExportStatusMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              payrollExportStatusMessage!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ],
          if (previewSection != null) ...[
            const SizedBox(height: 12),
            previewSection!,
          ],
        ],
      ),
    );
  }
}
