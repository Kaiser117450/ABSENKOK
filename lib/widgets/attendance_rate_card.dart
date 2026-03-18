import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/analytics_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Period enum
// ─────────────────────────────────────────────────────────────────────────────

enum RatePeriod { daily, weekly, monthly }

// ─────────────────────────────────────────────────────────────────────────────
// AttendanceRateCard
// ─────────────────────────────────────────────────────────────────────────────

/// Displays the attendance rate for an outlet with a period toggle
/// (Hari/Minggu/Bulan). Shows percentage + concrete counts,
/// e.g. "Hadir 14/16 hari — 87.5%". Color-coded: success green when
/// rate >= 80%, danger red when below. Parent calls [refresh] on pull-to-refresh.
class AttendanceRateCard extends StatefulWidget {
  final String outletId;
  final VoidCallback? onRefresh;

  const AttendanceRateCard({
    super.key,
    required this.outletId,
    this.onRefresh,
  });

  @override
  State<AttendanceRateCard> createState() => AttendanceRateCardState();
}

class AttendanceRateCardState extends State<AttendanceRateCard> {
  RatePeriod _period = RatePeriod.weekly;
  AttendanceRateData? _data;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(AttendanceRateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outletId != widget.outletId) {
      _loadData();
    }
  }

  /// Called by parent's pull-to-refresh handler.
  Future<void> refresh() => _loadData();

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });

    if (widget.outletId.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _data = null;
        });
      }
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    DateTime start;
    switch (_period) {
      case RatePeriod.daily:
        start = today;
        break;
      case RatePeriod.weekly:
        start = today.subtract(const Duration(days: 6));
        break;
      case RatePeriod.monthly:
        start = today.subtract(const Duration(days: 29));
        break;
    }

    final result = await AnalyticsService.instance.getAttendanceRates(
      outletId: widget.outletId,
      start: start,
      end: endOfDay,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = result;
      _error = result == null;
    });
  }

  void _onPeriodChanged(RatePeriod period) {
    if (_period == period) return;
    setState(() => _period = period);
    _loadData();
  }

  Color get _rateColor {
    final rate = _data?.rate ?? 0;
    return rate >= 80 ? AppColors.success : AppColors.danger;
  }

  Color get _accentStripeColor {
    if (_loading || _data == null) return AppColors.border;
    return _data!.rate >= 80 ? AppColors.success : AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dashboard lengkap segera hadir'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Card(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent stripe
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 4,
                  color: _accentStripeColor,
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 12),
                        _buildContent(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          'Tingkat Kehadiran',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildChoiceChip('Hari', RatePeriod.daily),
            const SizedBox(width: 4),
            _buildChoiceChip('Minggu', RatePeriod.weekly),
            const SizedBox(width: 4),
            _buildChoiceChip('Bulan', RatePeriod.monthly),
          ],
        ),
      ],
    );
  }

  Widget _buildChoiceChip(String label, RatePeriod period) {
    final selected = _period == period;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _onPeriodChanged(period),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppColors.textSecondary,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildContent() {
    if (_loading) return _buildLoadingState();
    if (_error) return _buildErrorState();
    if (_data == null ||
        (_data!.totalEmployees == 0 && _data!.totalPresent == 0)) {
      return _buildEmptyState();
    }
    return _buildRateDisplay();
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Belum Ada Data Kehadiran',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Data kehadiran akan muncul setelah karyawan mulai absen. '
          'Pastikan kiosk sudah aktif dan karyawan terdaftar.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return const Text(
      'Gagal memuat data kehadiran. Periksa koneksi internet lalu tarik ke bawah untuk coba lagi.',
      style: TextStyle(
        fontSize: 12,
        color: AppColors.danger,
        height: 1.4,
      ),
    );
  }

  Widget _buildRateDisplay() {
    final data = _data!;
    final totalPossible = data.totalEmployees * data.daysInRange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data.rate}%',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: _rateColor,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hadir ${data.totalPresent}/$totalPossible hari — ${data.rate}%',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
