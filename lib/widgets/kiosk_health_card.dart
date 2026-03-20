import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/outlet.dart';

/// Displays kiosk health metrics for a single outlet.
///
/// Shows: online/offline status, battery level, pending sync count.
/// Used in admin dashboard "Status Kiosk" section.
class KioskHealthCard extends StatelessWidget {
  final Outlet outlet;
  const KioskHealthCard({super.key, required this.outlet});

  @override
  Widget build(BuildContext context) {
    final status = _kioskStatus;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: status.color,
              boxShadow: [
                BoxShadow(
                  color: status.color.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Outlet name + status label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outlet.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: status.color,
                  ),
                ),
              ],
            ),
          ),
          // Battery indicator (if data available)
          if (outlet.batteryLevel != null) ...[
            _BatteryIndicator(
              level: outlet.batteryLevel!,
              isCharging: outlet.isCharging ?? false,
            ),
            const SizedBox(width: 12),
          ],
          // Pending sync badge (if > 0)
          if (outlet.pendingSyncCount != null && outlet.pendingSyncCount! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sync_problem_outlined,
                    size: 12,
                    color: AppColors.accentDark,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${outlet.pendingSyncCount}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentDark,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Determine kiosk status: Online, Offline, or Belum Terhubung
  _KioskStatus get _kioskStatus {
    if (outlet.lastHeartbeatAt == null) {
      return _KioskStatus('Belum Terhubung', AppColors.textMuted);
    }
    final age = DateTime.now().difference(outlet.lastHeartbeatAt!);
    if (age.inMinutes > 30) {
      return _KioskStatus('Offline — ${_formatAge(age)}', AppColors.danger);
    }
    return _KioskStatus('Online', AppColors.success);
  }

  String _formatAge(Duration age) {
    if (age.inHours >= 24) {
      final days = age.inDays;
      return '$days hari lalu';
    } else if (age.inHours >= 1) {
      return '${age.inHours} jam lalu';
    }
    return '${age.inMinutes} mnt lalu';
  }
}

class _KioskStatus {
  final String label;
  final Color color;
  const _KioskStatus(this.label, this.color);
}

/// Battery level indicator with warning state.
class _BatteryIndicator extends StatelessWidget {
  final int level;
  final bool isCharging;
  const _BatteryIndicator({required this.level, required this.isCharging});

  @override
  Widget build(BuildContext context) {
    final isLow = level < 20;
    final color = isLow ? AppColors.danger : AppColors.success;
    final icon = isCharging
        ? Icons.battery_charging_full_rounded
        : isLow
            ? Icons.battery_alert_rounded
            : Icons.battery_full_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 2),
        Text(
          '$level%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
