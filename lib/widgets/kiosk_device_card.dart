import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/kiosk_device.dart';

/// Displays per-device health metrics for a single physical kiosk.
///
/// Shows: online/offline status dot, device display name, battery level,
/// pending sync count, and a popup menu with Beri Nama and Arsipkan actions.
/// Used in admin dashboard "Status Kiosk" section (Phase 32+).
class KioskDeviceCard extends StatelessWidget {
  final KioskDevice device;
  final VoidCallback onNickname;
  final VoidCallback onArchive;

  const KioskDeviceCard({
    super.key,
    required this.device,
    required this.onNickname,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;

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
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Device name + status label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          // Battery indicator
          if (device.batteryLevel != null) ...[
            _BatteryIndicator(
              level: device.batteryLevel!,
              isCharging: device.isCharging ?? false,
            ),
            const SizedBox(width: 8),
          ],
          // Pending sync badge
          if (device.pendingSyncCount != null && device.pendingSyncCount! > 0) ...[
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
                    '${device.pendingSyncCount}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
          ],
          // Three-dot menu
          PopupMenuButton<String>(
            tooltip: 'Opsi perangkat',
            icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'nickname',
                child: Row(
                  children: const [
                    Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('Beri Nama'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'archive',
                child: Row(
                  children: const [
                    Icon(Icons.archive_outlined, size: 16, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('Arsipkan', style: TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'nickname') {
                onNickname();
              } else {
                onArchive();
              }
            },
          ),
        ],
      ),
    );
  }

  Color get _statusColor {
    if (device.isOnline) return AppColors.success;
    if (device.lastHeartbeatAt == null) return AppColors.textMuted;
    return AppColors.danger;
  }

  String get _statusLabel {
    if (device.isOnline) return 'Online';
    if (device.lastHeartbeatAt == null) return 'Belum Terhubung';
    final age = DateTime.now().difference(device.lastHeartbeatAt!);
    return 'Offline \u2014 ${_formatAge(age)}';
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

/// Battery level indicator with low-battery and charging states.
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
