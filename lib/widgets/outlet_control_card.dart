import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/analytics_service.dart';

/// Outlet rollup card with drilldown action.
///
/// Displays per-outlet device health and daily attendance rate with a clear
/// tap affordance to drill into the outlet-specific detail dashboard.
class OutletControlCard extends StatelessWidget {
  final OutletControlCenterRow row;
  final VoidCallback onTap;

  const OutletControlCard({
    super.key,
    required this.row,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 4,
              height: 54,
              decoration: BoxDecoration(
                color: row.offlineDevices > 0
                    ? AppColors.danger
                    : AppColors.success,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            // Outlet info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.outletName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _MetricChip(
                        icon: Icons.wifi,
                        label: '${row.connectedDevices}',
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      if (row.offlineDevices > 0) ...[
                        _MetricChip(
                          icon: Icons.wifi_off,
                          label: '${row.offlineDevices}',
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (row.lowBatteryDevices > 0) ...[
                        _MetricChip(
                          icon: Icons.battery_alert,
                          label: '${row.lowBatteryDevices}',
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                      ],
                      _MetricChip(
                        icon: Icons.people_outline,
                        label: '${row.dailyAttendanceRate.toStringAsFixed(0)}%',
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Drilldown CTA
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
