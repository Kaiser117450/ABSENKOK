import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../main.dart' show supabaseReady;
import '../../providers/app_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/streak_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/overtime_alert_row.dart';
import '../../widgets/shimmer_skeleton.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Chart Dashboard Screen
// ─────────────────────────────────────────────────────────────────────────────

@visibleForTesting
class ChartDashboardDebugData {
  final AttendanceRateData? rateData;
  final List<Map<String, dynamic>> weeklyTrend;
  final List<OvertimeFlag> overtimeFlags;
  final List<StreakLeaderEntry> leaderboard;
  final List<Map<String, dynamic>> outletComparison;

  const ChartDashboardDebugData({
    this.rateData,
    this.weeklyTrend = const [],
    this.overtimeFlags = const [],
    this.leaderboard = const [],
    this.outletComparison = const [],
  });
}

class ChartDashboardScreen extends ConsumerStatefulWidget {
  final String outletId;
  final ChartDashboardDebugData? debugData;

  const ChartDashboardScreen({super.key, required this.outletId})
      : debugData = null;

  @visibleForTesting
  const ChartDashboardScreen.testable({
    super.key,
    required this.outletId,
    required this.debugData,
  });

  @override
  ConsumerState<ChartDashboardScreen> createState() =>
      _ChartDashboardScreenState();
}

class _ChartDashboardScreenState extends ConsumerState<ChartDashboardScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Section data
  AttendanceRateData? _rateData;
  List<Map<String, dynamic>> _weeklyTrend = [];
  List<OvertimeFlag> _overtimeFlags = [];
  List<StreakLeaderEntry> _leaderboard = [];
  List<Map<String, dynamic>> _outletComparison = [];
  List<EmployeeInsightData> _insightData = [];

  // Loading / error state
  bool _isLoading = true;
  String? _rateError;
  String? _trendError;
  String? _overtimeError;
  String? _leaderboardError;
  String? _comparisonError;
  String? _insightError;
  int _insightSortIndex = 0; // 0=masalah, 1=terlambat, 2=overtime, 3=aman

  @override
  void initState() {
    super.initState();
    final debugData = widget.debugData;
    if (debugData != null) {
      _rateData = debugData.rateData;
      _weeklyTrend = debugData.weeklyTrend
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _overtimeFlags = List<OvertimeFlag>.from(debugData.overtimeFlags);
      _leaderboard = List<StreakLeaderEntry>.from(debugData.leaderboard);
      _outletComparison = debugData.outletComparison
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _insightData = []; // No debug data for insights yet
      _isLoading = false;
      return;
    }
    _loadAllSections();
  }

  Future<void> _loadAllSections() async {
    setState(() => _isLoading = true);
    final appState = ref.read(appProvider);
    final outletId = widget.outletId;
    final now = DateTime.now();
    await Future.wait([
      _loadAttendanceRate(outletId, now),
      _loadWeeklyTrend(outletId),
      _loadOvertimeFlags(outletId, now),
      _loadLeaderboard(outletId),
      _loadInsightData(outletId),
      if (appState.isAdmin) _loadOutletComparison(now),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadAttendanceRate(String outletId, DateTime now) async {
    _rateError = null;
    try {
      final today = DateTime(now.year, now.month, now.day);
      final start = today.subtract(const Duration(days: 6));
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final result = await AnalyticsService.instance.getAttendanceRates(
        outletId: outletId,
        start: start,
        end: end,
      );
      if (mounted) setState(() => _rateData = result);
    } catch (e) {
      if (mounted) setState(() => _rateError = e.toString());
    }
  }

  Future<void> _loadWeeklyTrend(String outletId) async {
    _trendError = null;
    if (!supabaseReady) return;
    try {
      final result = await SupabaseClientFactory.admin.rpc(
        'get_weekly_trend',
        params: {'p_outlet_id': outletId, 'p_days': 7},
      );
      if (mounted) {
        setState(() {
          _weeklyTrend = (result as List?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _trendError = e.toString());
    }
  }

  Future<void> _loadOvertimeFlags(String outletId, DateTime now) async {
    _overtimeError = null;
    try {
      final result = await AnalyticsService.instance.getOvertimeFlags(
        outletId: outletId,
        date: now,
      );
      if (mounted) setState(() => _overtimeFlags = result);
    } catch (e) {
      if (mounted) setState(() => _overtimeError = e.toString());
    }
  }

  Future<void> _loadLeaderboard(String outletId) async {
    _leaderboardError = null;
    try {
      final result = await StreakService.instance.getLeaderboard(
        outletId: outletId,
      );
      if (mounted) setState(() => _leaderboard = result);
    } catch (e) {
      if (mounted) setState(() => _leaderboardError = e.toString());
    }
  }

  Future<void> _loadOutletComparison(DateTime now) async {
    _comparisonError = null;
    if (!supabaseReady) return;
    try {
      final today = DateTime(now.year, now.month, now.day);
      final start = today.subtract(const Duration(days: 6));
      final startStr =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      final endStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final result = await SupabaseClientFactory.admin.rpc(
        'get_outlet_comparison',
        params: {'p_start': startStr, 'p_end': endStr},
      );
      if (mounted) {
        setState(() {
          _outletComparison = (result as List?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _comparisonError = e.toString());
    }
  }

  Future<void> _loadInsightData(String outletId) async {
    _insightError = null;
    try {
      final result = await AnalyticsService.instance.getEmployeeInsights(outletId);
      if (mounted) setState(() => _insightData = result);
    } catch (e) {
      if (mounted) setState(() => _insightError = e.toString());
    }
  }

  List<EmployeeInsightData> get _sortedInsightData {
    final sorted = List<EmployeeInsightData>.from(_insightData);
    switch (_insightSortIndex) {
      case 0: // masalah
        sorted.sort((a, b) => b.totalIssues.compareTo(a.totalIssues));
        break;
      case 1: // terlambat
        sorted.sort((a, b) => b.lateCount.compareTo(a.lateCount));
        break;
      case 2: // overtime
        sorted.sort((a, b) => b.overtimeCount.compareTo(a.overtimeCount));
        break;
      case 3: // aman
        sorted.sort((a, b) => a.totalIssues.compareTo(b.totalIssues));
        break;
    }
    return sorted.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final appState = ref.watch(appProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Kehadiran'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadAllSections,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Section 1: Attendance rate summary (reuse data)
            _buildAttendanceRateSection(),
            const SizedBox(height: 24),

            // Section 2: Donut chart
            _buildDonutSection(),
            const SizedBox(height: 24),

            // Section 3: Weekly trend
            _buildWeeklyTrendSection(),
            const SizedBox(height: 24),

            // Section 4: Overtime
            _buildOvertimeSection(),
            const SizedBox(height: 24),

            // Section 5: Employee Insights
            _buildInsightSection(),
            const SizedBox(height: 24),

            // Section 6: Streak leaderboard
            _buildLeaderboardSection(),

            // Section 7: Outlet comparison (admin only)
            if (appState.isAdmin) ...[
              const SizedBox(height: 24),
              _buildOutletComparisonSection(),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Section 1: Attendance Rate Summary ─────────────────────────────────────

  Widget _buildAttendanceRateSection() {
    if (_isLoading) {
      return const AppCard(child: ShimmerSkeleton(height: 80));
    }
    if (_rateError != null || _rateData == null) {
      return AppCard(
        child: AppEmptyState(
          icon: Icons.bar_chart_outlined,
          heading: 'Belum Ada Data',
          subtext:
              'Data kehadiran akan muncul setelah karyawan mulai absen di kiosk.',
        ),
      );
    }
    final data = _rateData!;
    final rateColor = data.rate >= 80 ? AppColors.success : AppColors.danger;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tingkat Kehadiran',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${data.rate}%',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: rateColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hadir ${data.totalPresent}/${data.totalEmployees * data.daysInRange} hari',
            style:
                const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ─── Section 2: Donut Chart ─────────────────────────────────────────────────

  Widget _buildDonutSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Kehadiran',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const ShimmerSkeleton(height: 200)
          else if (_rateData == null)
            const SizedBox(
              height: 200,
              child: AppEmptyState(
                icon: Icons.pie_chart_outline,
                heading: 'Belum Ada Data',
                subtext:
                    'Data kehadiran akan muncul setelah karyawan mulai absen di kiosk.',
              ),
            )
          else
            _buildDonutChart(),
        ],
      ),
    );
  }

  Widget _buildDonutChart() {
    final rate = _rateData!.rate;
    final absentRate = 100 - rate;

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  centerSpaceRadius: 60,
                  sectionsSpace: 2,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: [
                    PieChartSectionData(
                      value: rate,
                      color: AppColors.success,
                      radius: 24,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: absentRate > 0 ? absentRate : 0.01,
                      color: AppColors.danger,
                      radius: 24,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendDot(AppColors.success, 'Hadir'),
            const SizedBox(width: 24),
            _buildLegendDot(AppColors.danger, 'Tidak Hadir'),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  // ─── Section 3: Weekly Trend ────────────────────────────────────────────────

  Widget _buildWeeklyTrendSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tren Mingguan',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const ShimmerSkeleton(height: 180)
          else if (_trendError != null || _weeklyTrend.isEmpty)
            const SizedBox(
              height: 180,
              child: AppEmptyState(
                icon: Icons.trending_up_outlined,
                heading: 'Belum Ada Data',
                subtext: 'Data tren akan muncul setelah beberapa hari absensi.',
              ),
            )
          else
            _buildWeeklyTrendChart(),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrendChart() {
    final dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    double maxY = 0;
    final bars = <BarChartGroupData>[];

    for (int i = 0; i < _weeklyTrend.length && i < 7; i++) {
      final count = (_weeklyTrend[i]['count'] as num?)?.toDouble() ?? 0;
      if (count > maxY) maxY = count;

      // Parse day of week from date string
      final dateStr = _weeklyTrend[i]['date'] as String? ?? '';
      int dayIndex = i;
      if (dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          dayIndex = (date.weekday - 1) % 7; // 0=Mon, 6=Sun
        } catch (_) {}
      }

      bars.add(
        BarChartGroupData(
          x: dayIndex,
          barRods: [
            BarChartRodData(
              toY: count,
              color: AppColors.success,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxY > 0 ? maxY * 1.2 : 10,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= dayLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      dayLabels[idx],
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF111827),
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.toInt()} hadir',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          barGroups: bars,
        ),
      ),
    );
  }

  // ─── Section 4: Overtime ────────────────────────────────────────────────────

  Widget _buildOvertimeSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lembur Hari Ini',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const ShimmerSkeleton(height: 48)
          else if (_overtimeFlags.isEmpty)
            const Text(
              'Tidak ada lembur hari ini',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            )
          else
            OvertimeAlertRow(flags: _overtimeFlags),
        ],
      ),
    );
  }

  // ─── Section 5: Employee Insights ──────────────────────────────────────────

  Widget _buildInsightSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Insight Karyawan',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Sort buttons row
          _buildInsightSortButtons(),
          const SizedBox(height: 16),

          if (_isLoading)
            const ShimmerSkeleton(height: 300)
          else if (_insightError != null || _insightData.isEmpty)
            const SizedBox(
              height: 300,
              child: AppEmptyState(
                icon: Icons.analytics_outlined,
                heading: 'Belum Ada Data',
                subtext:
                    'Data insight karyawan akan muncul setelah ada data kehadiran bulan ini.',
              ),
            )
          else
            _buildInsightChart(),
        ],
      ),
    );
  }

  Widget _buildInsightSortButtons() {
    final buttons = [
      {
        'icon': Icons.warning_amber_outlined,
        'label': 'Masalah',
        'color': AppColors.danger,
      },
      {
        'icon': Icons.schedule_outlined,
        'label': 'Terlambat',
        'color': const Color(0xFF3B82F6), // Blue
      },
      {
        'icon': Icons.more_time_outlined,
        'label': 'Overtime',
        'color': AppColors.accent,
      },
      {
        'icon': Icons.verified_outlined,
        'label': 'Aman',
        'color': AppColors.success,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(buttons.length, (index) {
          final button = buttons[index];
          final isSelected = _insightSortIndex == index;

          return Padding(
            padding: EdgeInsets.only(right: index < buttons.length - 1 ? 8 : 0),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    button['icon'] as IconData,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : button['color'] as Color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    button['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : button['color'] as Color,
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _insightSortIndex = index);
                }
              },
              selectedColor: button['color'] as Color,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: isSelected
                    ? button['color'] as Color
                    : AppColors.border,
                width: 1,
              ),
              showCheckmark: false,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildInsightChart() {
    final sortedData = _sortedInsightData;
    if (sortedData.isEmpty) {
      return const SizedBox(
        height: 300,
        child: AppEmptyState(
          icon: Icons.analytics_outlined,
          heading: 'Tidak Ada Data',
          subtext: 'Tidak ada data karyawan untuk ditampilkan.',
        ),
      );
    }

    // Find max value for scaling
    double maxY = 0;
    for (final employee in sortedData) {
      final maxValue = [
        employee.totalIssues.toDouble(),
        employee.overtimeCount.toDouble(),
        employee.safeCount.toDouble(),
      ].reduce((a, b) => a > b ? a : b);
      if (maxValue > maxY) maxY = maxValue;
    }

    // Create bar groups - each employee gets 3 stacked/grouped bars
    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < sortedData.length; i++) {
      final employee = sortedData[i];

      barGroups.add(
        BarChartGroupData(
          x: i,
          groupVertically: false,
          barRods: [
            // Red bar for total issues
            BarChartRodData(
              toY: employee.totalIssues.toDouble(),
              color: AppColors.danger,
              width: 8,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(2),
              ),
            ),
            // Amber bar for overtime
            BarChartRodData(
              toY: employee.overtimeCount.toDouble(),
              color: AppColors.accent,
              width: 8,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(2),
              ),
            ),
            // Green bar for safe days
            BarChartRodData(
              toY: employee.safeCount.toDouble(),
              color: AppColors.success,
              width: 8,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(2),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              maxY: maxY > 0 ? maxY * 1.2 : 10,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                drawHorizontalLine: false,
                verticalInterval: maxY > 0 ? maxY / 4 : 2.5,
                getDrawingVerticalLine: (value) {
                  return const FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= sortedData.length) {
                        return const SizedBox.shrink();
                      }
                      final name = sortedData[idx].employeeName;
                      final truncatedName = name.length > 12
                          ? '${name.substring(0, 12)}..'
                          : name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          truncatedName,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF111827),
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final employee = sortedData[group.x];
                    String label;
                    switch (rodIndex) {
                      case 0:
                        label = 'Masalah: ${employee.totalIssues}';
                        break;
                      case 1:
                        label = 'Overtime: ${employee.overtimeCount}';
                        break;
                      case 2:
                        label = 'Aman: ${employee.safeCount}';
                        break;
                      default:
                        label = '${rod.toY.toInt()}';
                    }
                    return BarTooltipItem(
                      '${employee.employeeName}\n$label',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              groupsSpace: 12,
              barGroups: barGroups,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendDot(AppColors.danger, 'Masalah'),
            const SizedBox(width: 16),
            _buildLegendDot(AppColors.accent, 'Overtime'),
            const SizedBox(width: 16),
            _buildLegendDot(AppColors.success, 'Aman'),
          ],
        ),
      ],
    );
  }

  // ─── Section 6: Streak Leaderboard ──────────────────────────────────────────

  Widget _buildLeaderboardSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 5 Streak Kehadiran',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const ShimmerSkeleton(height: 200)
          else if (_leaderboard.isEmpty)
            const AppEmptyState(
              icon: Icons.local_fire_department_outlined,
              heading: 'Belum Ada Streak',
              subtext:
                  'Streak akan terhitung setelah karyawan absen beberapa hari berturut-turut.',
            )
          else
            Column(
              children: List.generate(_leaderboard.length, (i) {
                return _buildLeaderboardRow(i, _leaderboard[i]);
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardRow(int index, StreakLeaderEntry entry) {
    final rank = index + 1;
    Color? bgColor;
    Color rankColor = AppColors.textSecondary;

    if (rank == 1) {
      bgColor = const Color(0xFFFEF3C7);
      rankColor = const Color(0xFFD97706);
    } else if (rank <= 3) {
      bgColor = const Color(0xFFF3F4F6);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rank == 1
                  ? const Color(0xFFD97706)
                  : AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: rank == 1 ? Colors.white : rankColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.employeeName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(
            Icons.local_fire_department,
            size: 18,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(width: 4),
          Text(
            '${entry.currentStreak} hari',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section 7: Outlet Comparison (admin only) ─────────────────────────────

  Widget _buildOutletComparisonSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Perbandingan Outlet',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const ShimmerSkeleton(height: 200)
          else if (_comparisonError != null || _outletComparison.isEmpty)
            const SizedBox(
              height: 200,
              child: AppEmptyState(
                icon: Icons.compare_arrows_outlined,
                heading: 'Belum Ada Data',
                subtext:
                    'Perbandingan outlet akan muncul setelah ada data kehadiran.',
              ),
            )
          else
            _buildOutletComparisonChart(),
        ],
      ),
    );
  }

  Widget _buildOutletComparisonChart() {
    const barColors = [
      Color(0xFFDC2626),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFF14B8A6),
    ];

    final bars = <BarChartGroupData>[];
    final outletNames = <int, String>{};

    for (int i = 0; i < _outletComparison.length; i++) {
      final item = _outletComparison[i];
      final rate = (item['rate'] as num?)?.toDouble() ?? 0;
      final name = item['outlet_name'] as String? ?? 'Outlet ${i + 1}';
      outletNames[i] = name;

      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: rate,
              color: barColors[i % barColors.length],
              width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: 100,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      final name = outletNames[idx] ?? '';
                      // Truncate long names
                      final display =
                          name.length > 8 ? '${name.substring(0, 8)}..' : name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          display,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF111827),
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final name = outletNames[group.x] ?? '';
                    return BarTooltipItem(
                      '$name\n${rod.toY.toStringAsFixed(1)}%',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              barGroups: bars,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: List.generate(_outletComparison.length, (i) {
            final name = _outletComparison[i]['outlet_name'] as String? ??
                'Outlet ${i + 1}';
            return _buildLegendDot(barColors[i % barColors.length], name);
          }),
        ),
      ],
    );
  }
}
