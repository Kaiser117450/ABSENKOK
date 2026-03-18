import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/analytics_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OvertimeAlertRow
// ─────────────────────────────────────────────────────────────────────────────

/// Horizontal scrollable row of overtime alert chips.
/// Hidden (SizedBox.shrink) when [flags] is empty.
/// Each chip shows employee name + overtime hours: "Budi +2j".
class OvertimeAlertRow extends StatelessWidget {
  final List<OvertimeFlag> flags;

  const OvertimeAlertRow({super.key, required this.flags});

  @override
  Widget build(BuildContext context) {
    if (flags.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: flags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _OvertimeChip(flag: flags[index]),
      ),
    );
  }
}

class _OvertimeChip extends StatelessWidget {
  final OvertimeFlag flag;

  const _OvertimeChip({required this.flag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_outlined,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            '${flag.employeeName} +${flag.overtimeHours.round()}j',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
