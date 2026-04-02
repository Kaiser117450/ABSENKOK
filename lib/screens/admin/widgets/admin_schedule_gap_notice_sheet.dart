import 'package:absensi_enakko_flutter/core/theme.dart';
import 'package:absensi_enakko_flutter/models/schedule_gap_notice.dart';
import 'package:flutter/material.dart';

class AdminDashboardScheduleGapQuickAction extends StatelessWidget {
  const AdminDashboardScheduleGapQuickAction({
    super.key,
    required this.hasResolvedOutlet,
    required this.notices,
    required this.onTap,
  });

  final bool hasResolvedOutlet;
  final ScheduleGapNoticeResult notices;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!hasResolvedOutlet || !notices.hasNotices) {
      return const SizedBox.shrink();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 90,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(15, 118, 110, 0.25),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: 22,
                  color: Colors.white,
                ),
                SizedBox(height: 5),
                Text(
                  'Jadwal\nKosong',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              '${notices.count}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AdminScheduleGapNoticeSheet extends StatelessWidget {
  const AdminScheduleGapNoticeSheet({
    super.key,
    required this.notices,
    required this.onOpenScheduler,
  });

  final ScheduleGapNoticeResult notices;
  final VoidCallback onOpenScheduler;

  @override
  Widget build(BuildContext context) {
    final listHeight = notices.count <= 1
        ? 116.0
        : notices.count == 2
            ? 212.0
            : 320.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Jadwal Kosong',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6FFFA),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: const Color(0xFF99F6E4), width: 1),
                  ),
                  child: Text(
                    '${notices.count} item',
                    style: const TextStyle(
                      color: Color(0xFF0F766E),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Tindak lanjut ini hanya memberi tahu hari hadir yang masih belum punya jadwal aktif pada outlet yang sedang dipilih.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: listHeight,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: notices.entries.length,
                itemBuilder: (context, index) {
                  final entry = notices.entries[index];
                  return _ScheduleGapNoticeRow(entry: entry);
                },
                separatorBuilder: (_, __) => const SizedBox(height: 10),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onOpenScheduler,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text(
                  'Buka Jadwal',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleGapNoticeRow extends StatelessWidget {
  const _ScheduleGapNoticeRow({
    required this.entry,
  });

  final ScheduleGapNoticeEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.outletName} • ${_formatDate(entry.logicalDate)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6FFFA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.statusLabel,
                  style: const TextStyle(
                    color: Color(0xFF0F766E),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.helperText,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  const monthLabels = <String>[
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${value.day.toString().padLeft(2, '0')} ${monthLabels[value.month]} ${value.year}';
}
