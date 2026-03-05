import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Colored status chip with named factory constructors for attendance statuses.
///
/// Usage:
/// ```dart
/// AppBadge.hadir()
/// AppBadge.sakit()
/// AppBadge.izin()
/// AppBadge.belumPulang()
/// AppBadge(label: 'Custom', backgroundColor: Colors.grey, textColor: Colors.white)
/// ```
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  /// Hadir (present) — green badge
  factory AppBadge.hadir() => const AppBadge(
        label: 'Hadir',
        backgroundColor: AppColors.badgeMasukBg,
        textColor: AppColors.badgeMasukText,
      );

  /// Sakit (sick leave) — warm amber badge
  factory AppBadge.sakit() => const AppBadge(
        label: 'Sakit',
        backgroundColor: AppColors.badgeSakitBg,
        textColor: AppColors.badgeSakitText,
      );

  /// Izin (permitted absence) — blue badge
  factory AppBadge.izin() => const AppBadge(
        label: 'Izin',
        backgroundColor: AppColors.badgeIzinBg,
        textColor: AppColors.badgeIzinText,
      );

  /// Belum Pulang (not clocked out) — yellow badge
  factory AppBadge.belumPulang() => const AppBadge(
        label: 'Belum Pulang',
        backgroundColor: AppColors.badgeBelumPulangBg,
        textColor: AppColors.badgeBelumPulangText,
      );

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
