import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/grooming_qc_service.dart';

class GroomingAnalyticsCharts extends StatelessWidget {
  final List<GroomingRow> rows;
  const GroomingAnalyticsCharts({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    final byEmployee = <String, List<GroomingRow>>{};
    final byOutlet = <String, List<GroomingRow>>{};
    final byDay = <DateTime, List<double>>{};
    for (final r in rows) {
      byEmployee.putIfAbsent(r.employeeName, () => []).add(r);
      byOutlet.putIfAbsent(r.outletName, () => []).add(r);
      final d = DateTime(
          r.scannedAt.year, r.scannedAt.month, r.scannedAt.day);
      byDay.putIfAbsent(d, () => []).add(r.effectiveScore ?? 0);
    }

    final topViolators = byEmployee.entries
        .map((e) {
          final viol =
              e.value.where((r) => (r.effectiveScore ?? 0) < 6).length;
          return (name: e.key, rate: viol / e.value.length, count: viol);
        })
        .where((e) => e.count > 0)
        .toList()
      ..sort((a, b) => b.rate.compareTo(a.rate));

    final perOutlet = byOutlet.entries
        .map((e) {
          final pass =
              e.value.where((r) => (r.effectiveScore ?? 0) >= 6).length;
          return (name: e.key, passRate: pass / e.value.length);
        })
        .toList();

    final trend = byDay.entries
        .map((e) {
          final avg = e.value.isEmpty
              ? 0
              : e.value.reduce((a, b) => a + b) / e.value.length;
          return (day: e.key, avg: avg.toDouble());
        })
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));

    return ListView(padding: EdgeInsets.zero, children: [
      _ChartCard(
        title: 'Top pelanggar (window saat ini)',
        child: _BarRows(
          rows: topViolators
              .take(10)
              .map((e) => (label: e.name, value: e.rate * 100))
              .toList(),
          maxValue: 100,
          suffix: '%',
        ),
      ),
      const SizedBox(height: 12),
      _ChartCard(
        title: 'Persentase lulus per outlet',
        child: _BarRows(
          rows: perOutlet
              .map((e) => (label: e.name, value: e.passRate * 100))
              .toList(),
          maxValue: 100,
          suffix: '%',
        ),
      ),
      const SizedBox(height: 12),
      _ChartCard(
        title: 'Tren skor rata-rata harian',
        child: SizedBox(
          height: 160,
          child: LineChart(LineChartData(
            minY: 0,
            maxY: 10,
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < trend.length; i++)
                    FlSpot(i.toDouble(), trend[i].avg)
                ],
                isCurved: true,
                color: AppColors.primary,
                barWidth: 2,
                dotData: const FlDotData(show: false),
              ),
            ],
          )),
        ),
      ),
    ]);
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _BarRows extends StatelessWidget {
  final List<({String label, double value})> rows;
  final double maxValue;
  final String suffix;
  const _BarRows(
      {required this.rows,
      required this.maxValue,
      required this.suffix});
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Belum cukup data',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Column(children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(
                width: 120,
                child: Text(r.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(children: [
                  Container(height: 14, color: AppColors.surface),
                  FractionallySizedBox(
                    widthFactor: (r.value / maxValue).clamp(0, 1),
                    child: Container(
                        height: 14, color: AppColors.primary),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Text('${r.value.toStringAsFixed(0)}$suffix',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
        ),
    ]);
  }
}
