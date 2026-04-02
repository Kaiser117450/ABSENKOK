import 'package:flutter/material.dart';

import 'package:absensi_enakko_flutter/core/theme.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_day_cell.dart';

class PayrollMatrixDayCellWidget extends StatelessWidget {
  const PayrollMatrixDayCellWidget({
    super.key,
    required this.cell,
  });

  final PayrollMatrixDayCell cell;

  @override
  Widget build(BuildContext context) {
    final textColor = _colorFromHex(cell.textColorHex);
    final fillColor = _colorFromHex(cell.fillColorHex);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: fillColor,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            cell.primaryLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: cell.primaryLabel.contains('/') ? 13 : 11,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          if (cell.secondaryTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: cell.secondaryTags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  static Color _colorFromHex(String hex) {
    final normalized = hex.replaceAll('#', '');
    final value = int.parse(
      normalized.length == 6 ? 'FF$normalized' : normalized,
      radix: 16,
    );
    return Color(value);
  }
}
