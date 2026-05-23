import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/grooming_qc_service.dart';

class GroomingPerEmployeeData {
  final String employeeId;
  final String employeeName;
  final String position;
  final String outletName;
  final double avgScore;
  final int violationCount;
  final List<double> dailyScores;
  final List<String> recentThumbnails;
  final VoidCallback onSelect;

  const GroomingPerEmployeeData({
    required this.employeeId,
    required this.employeeName,
    required this.position,
    required this.outletName,
    required this.avgScore,
    required this.violationCount,
    required this.dailyScores,
    required this.recentThumbnails,
    required this.onSelect,
  });

  static GroomingPerEmployeeData fromRows(
    String employeeId,
    List<GroomingRow> rows, {
    required VoidCallback onSelect,
  }) {
    final scores = rows.map((r) => r.effectiveScore ?? 0).toList();
    final avg = scores.isEmpty
        ? 0
        : scores.reduce((a, b) => a + b) / scores.length;
    final violations = scores.where((s) => s < 6).length;
    final first = rows.first;
    final thumbs = rows
        .where((r) => r.photoUrl.isNotEmpty)
        .take(4)
        .map((r) => r.photoUrl)
        .toList();
    return GroomingPerEmployeeData(
      employeeId: employeeId,
      employeeName: first.employeeName,
      position: first.employeePosition,
      outletName: first.outletName,
      avgScore: avg.toDouble(),
      violationCount: violations,
      dailyScores:
          scores.reversed.take(30).toList().reversed.toList(),
      recentThumbnails: thumbs,
      onSelect: onSelect,
    );
  }
}

class GroomingPerEmployeeCard extends StatelessWidget {
  final GroomingPerEmployeeData data;
  const GroomingPerEmployeeCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final danger = data.violationCount > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: danger
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.employeeName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900)),
                  Text('${data.position} · ${data.outletName}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            _StatPill(
                label: 'Avg 30d',
                value: data.avgScore.toStringAsFixed(1),
                danger: danger),
            const SizedBox(width: 6),
            _StatPill(
                label: 'Pelanggaran',
                value: data.violationCount.toString(),
                danger: danger),
          ]),
          const SizedBox(height: 10),
          SizedBox(height: 40, child: _Sparkline(values: data.dailyScores)),
          const SizedBox(height: 10),
          Row(children: [
            ...data.recentThumbnails.map((u) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: u,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                          width: 56, height: 56, color: AppColors.surface),
                      errorWidget: (_, __, ___) => Container(
                          width: 56, height: 56, color: AppColors.surface),
                    ),
                  ),
                )),
            const Spacer(),
            TextButton(
                onPressed: data.onSelect,
                child: const Text('Detail per foto →')),
          ]),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final bool danger;
  const _StatPill(
      {required this.label, required this.value, required this.danger});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: danger ? AppColors.dangerLight : AppColors.successLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(value,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: danger ? AppColors.danger : AppColors.success,
                )),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: AppColors.textSecondary)),
          ]),
        ),
      );
}

class _Sparkline extends StatelessWidget {
  final List<double> values;
  const _Sparkline({required this.values});
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return LineChart(LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      minY: 0,
      maxY: 10,
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < values.length; i++)
              FlSpot(i.toDouble(), values[i])
          ],
          isCurved: true,
          color: AppColors.primary,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
    ));
  }
}
