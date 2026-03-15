import 'package:flutter/material.dart';

/// Horizontal legend bar showing all shift and status types with matching colors.
///
/// Displays: Pagi, Siang, Sore, Libur, Sakit, Izin — each as a compact chip.
class ScheduleLegend extends StatelessWidget {
  const ScheduleLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _legendChip('Pagi', const Color(0xFF3B82F6)),
            _legendChip('Siang', const Color(0xFFF59E0B)),
            _legendChip('Sore', const Color(0xFFF97316)),
            _legendChip('Libur', const Color(0xFFDC2626)),
            _legendChip('Sakit', const Color(0xFF991B1B)),
            _legendChip('Izin', const Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }

  Widget _legendChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
