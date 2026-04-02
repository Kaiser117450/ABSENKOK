import 'package:flutter/material.dart';

import 'package:absensi_enakko_flutter/core/theme.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';

class PayrollMatrixSummaryRail extends StatelessWidget {
  const PayrollMatrixSummaryRail({
    super.key,
    required this.rows,
    required this.headerHeight,
    required this.dataRowHeight,
    required this.summaryColumnWidth,
  });

  final List<PayrollMatrixRow> rows;
  final double headerHeight;
  final double dataRowHeight;
  final double summaryColumnWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('payroll-summary-rail'),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          SizedBox(
            height: headerHeight,
            child: Row(
              children: PayrollMatrixRow.summaryLabels
                  .map(
                    (label) => _SummaryHeaderCell(
                      label: label,
                      width: summaryColumnWidth,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          ...rows.map(
            (row) => SizedBox(
              height: dataRowHeight,
              child: Row(
                children: row.summaryValuesInOrder
                    .map(
                      (value) => _SummaryValueCell(
                        value: value,
                        width: summaryColumnWidth,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeaderCell extends StatelessWidget {
  const _SummaryHeaderCell({
    required this.label,
    required this.width,
  });

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          height: 1.0,
        ),
      ),
    );
  }
}

class _SummaryValueCell extends StatelessWidget {
  const _SummaryValueCell({
    required this.value,
    required this.width,
  });

  final int value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
          right: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Text(
        '$value',
        style: TextStyle(
          fontSize: value > 0 ? 18 : 11,
          fontWeight: FontWeight.w700,
          color: value > 0 ? AppColors.textPrimary : AppColors.textMuted,
        ),
      ),
    );
  }
}
