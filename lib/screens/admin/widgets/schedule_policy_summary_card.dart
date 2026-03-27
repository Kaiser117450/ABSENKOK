import 'package:flutter/material.dart';

class SchedulePolicySummaryCard extends StatelessWidget {
  const SchedulePolicySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Aturan Jadwal Minggu Ini',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Band dan jam wajib menjadi acuan utama. Jam lama hanya tampil sebagai petunjuk kecil bila masih dibutuhkan.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF475569),
            ),
          ),
          SizedBox(height: 14),
          _SchedulePolicySummaryRow(
            label: 'Batas telat',
            value: 'Pagi 07:00\nSiang 10:00\nSore 15:00',
          ),
          SizedBox(height: 10),
          _SchedulePolicySummaryRow(
            label: 'Jam wajib default',
            value: 'FULLTIME 10j\nPARTTIME 9j',
          ),
          SizedBox(height: 10),
          _SchedulePolicySummaryRow(
            label: 'Break-first',
            value:
                'FULLTIME sampai 09:00 / 12:00 / 17:00\nPARTTIME sampai 08:00 / 11:00 / 16:00',
          ),
        ],
      ),
    );
  }
}

class _SchedulePolicySummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SchedulePolicySummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }
}
