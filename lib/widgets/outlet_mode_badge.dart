import 'package:flutter/material.dart';

import 'package:absensi_enakko_flutter/models/outlet_operating_mode.dart';

/// Compact informative badge showing the outlet's operating mode.
///
/// Designed to sit beside the active/non-active pill in outlet card headers.
class OutletModeBadge extends StatelessWidget {
  final OutletOperatingMode mode;

  const OutletModeBadge({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final is24h = mode == OutletOperatingMode.twentyFourHour;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: is24h ? const Color(0xFFDBEAFE) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        mode.label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: is24h ? const Color(0xFF1D4ED8) : const Color(0xFF6B7280),
        ),
      ),
    );
  }
}
