import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Empty state widget with icon, heading, and optional subtext.
///
/// Usage:
/// ```dart
/// AppEmptyState(
///   icon: Icons.inbox_outlined,
///   heading: 'Tidak ada data',
///   subtext: 'Belum ada karyawan yang terdaftar.',
/// )
/// ```
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.heading,
    this.subtext,
  });

  final IconData icon;
  final String heading;
  final String? subtext;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 56,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            heading,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          if (subtext != null) ...[
            const SizedBox(height: 6),
            Text(
              subtext!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
