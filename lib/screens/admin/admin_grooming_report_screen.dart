import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:absensi_enakko_flutter/core/supabase_client.dart';
import 'package:absensi_enakko_flutter/core/theme.dart';
import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/providers/app_provider.dart';
import 'package:absensi_enakko_flutter/widgets/app_empty_state.dart';

class AdminGroomingReportScreen extends ConsumerStatefulWidget {
  const AdminGroomingReportScreen({super.key});

  @override
  ConsumerState<AdminGroomingReportScreen> createState() =>
      _AdminGroomingReportScreenState();
}

class _AdminGroomingReportScreenState
    extends ConsumerState<AdminGroomingReportScreen> {
  bool _loading = true;
  bool _showNeedsReviewOnly = false;
  String? _error;
  List<_GroomingReportRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRows());
  }

  Future<void> _loadRows() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final since = DateTime.now()
          .subtract(const Duration(days: 7))
          .toUtc()
          .toIso8601String();
      final raw = await SupabaseClientFactory.admin
          .from('attendance_photo_analysis')
          .select(
            'attendance_log_id, photo_url, face_detected, face_confidence, '
            'face_count, photo_quality, grooming_labels, grooming_score, '
            'safe_search_passed, analyzed_at, attendance_logs!inner('
            'id, type, scanned_at, scan_outlet_id, employee_id, '
            'employees(name, position), outlets(name))',
          )
          .gte('analyzed_at', since)
          .order('analyzed_at', ascending: false)
          .limit(100);

      final appState = ref.read(appProvider);
      final rows = (raw as List)
          .map((item) => _GroomingReportRow.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .where((row) => appState.canAccessOutlet(row.outletId))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Data grooming belum bisa dimuat.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleRows = _showNeedsReviewOnly
        ? _rows.where((row) => row.needsReview).toList(growable: false)
        : _rows;
    final reviewCount = _rows.where((row) => row.needsReview).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: _loadRows,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Grooming QC',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _loading ? null : _loadRows,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryStrip(
              total: _rows.length,
              reviewCount: reviewCount,
              showNeedsReviewOnly: _showNeedsReviewOnly,
              onToggleReviewOnly: (value) {
                setState(() => _showNeedsReviewOnly = value);
              },
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_error != null)
              AppEmptyState(
                icon: Icons.error_outline_rounded,
                heading: 'Gagal memuat data',
                subtext: _error!,
              )
            else if (visibleRows.isEmpty)
              const AppEmptyState(
                icon: Icons.photo_camera_front_outlined,
                heading: 'Belum ada foto grooming',
                subtext:
                    'Hasil analisis akan muncul setelah foto beta diupload.',
              )
            else
              ...visibleRows.map((row) => _GroomingReportCard(row: row)),
          ],
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final int total;
  final int reviewCount;
  final bool showNeedsReviewOnly;
  final ValueChanged<bool> onToggleReviewOnly;

  const _SummaryStrip({
    required this.total,
    required this.reviewCount,
    required this.showNeedsReviewOnly,
    required this.onToggleReviewOnly,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: _Metric(label: 'Foto', value: total.toString())),
            Expanded(
              child: _Metric(
                label: 'Review',
                value: reviewCount.toString(),
                danger: reviewCount > 0,
              ),
            ),
            Switch(
              value: showNeedsReviewOnly,
              activeThumbColor: AppColors.primary,
              onChanged: onToggleReviewOnly,
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool danger;

  const _Metric({
    required this.label,
    required this.value,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: danger ? AppColors.danger : AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _GroomingReportCard extends StatelessWidget {
  final _GroomingReportRow row;

  const _GroomingReportCard({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: row.needsReview
              ? AppColors.danger.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: row.photoUrl.isEmpty
                  ? const ColoredBox(
                      color: AppColors.surface,
                      child: SizedBox(
                        width: 72,
                        height: 96,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    )
                  : Image.network(
                      row.photoUrl,
                      width: 72,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppColors.surface,
                        child: SizedBox(
                          width: 72,
                          height: 96,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.employeeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      _ScorePill(score: row.groomingScore),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${row.outletName} - ${row.typeLabel} - ${row.scannedAtLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _StatusChip(
                        label: row.faceDetected ? 'Wajah OK' : 'Wajah kurang',
                        danger: !row.faceDetected,
                      ),
                      _StatusChip(
                        label: row.safeSearchPassed ? 'Safe' : 'Safe flagged',
                        danger: !row.safeSearchPassed,
                      ),
                      _StatusChip(label: row.photoQuality),
                    ],
                  ),
                  if (row.labels.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      row.labels.take(4).join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final double? score;

  const _ScorePill({required this.score});

  @override
  Widget build(BuildContext context) {
    final value = score;
    final danger = value != null && value < 6;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: danger ? AppColors.dangerLight : AppColors.successLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          value == null ? '-' : value.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: danger ? AppColors.danger : AppColors.success,
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool danger;

  const _StatusChip({
    required this.label,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: danger ? AppColors.dangerLight : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: danger ? AppColors.danger : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _GroomingReportRow {
  final String outletId;
  final String employeeName;
  final String outletName;
  final String photoUrl;
  final String typeLabel;
  final String scannedAtLabel;
  final bool faceDetected;
  final int faceCount;
  final String photoQuality;
  final double? groomingScore;
  final bool safeSearchPassed;
  final List<String> labels;

  const _GroomingReportRow({
    required this.outletId,
    required this.employeeName,
    required this.outletName,
    required this.photoUrl,
    required this.typeLabel,
    required this.scannedAtLabel,
    required this.faceDetected,
    required this.faceCount,
    required this.photoQuality,
    required this.groomingScore,
    required this.safeSearchPassed,
    required this.labels,
  });

  bool get needsReview =>
      (groomingScore != null && groomingScore! < 6) ||
      !faceDetected ||
      faceCount != 1 ||
      !safeSearchPassed;

  factory _GroomingReportRow.fromJson(Map<String, dynamic> json) {
    final log = Map<String, dynamic>.from(
      (json['attendance_logs'] as Map?) ?? const {},
    );
    final employee = Map<String, dynamic>.from(
      (log['employees'] as Map?) ?? const {},
    );
    final outlet = Map<String, dynamic>.from(
      (log['outlets'] as Map?) ?? const {},
    );
    final labelsRaw = json['grooming_labels'];
    final labels = labelsRaw is List
        ? labelsRaw
            .map((item) {
              if (item is Map) return item['description']?.toString() ?? '';
              return item.toString();
            })
            .where((label) => label.trim().isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    return _GroomingReportRow(
      outletId: log['scan_outlet_id']?.toString() ?? '',
      employeeName: employee['name']?.toString() ?? '-',
      outletName: outlet['name']?.toString() ?? '-',
      photoUrl: json['photo_url']?.toString() ?? '',
      typeLabel: AttendanceTypeExt.fromString(
        log['type']?.toString() ?? 'masuk',
      ).label,
      scannedAtLabel: _formatDateTime(log['scanned_at']?.toString() ?? ''),
      faceDetected: json['face_detected'] == true,
      faceCount: (json['face_count'] as num?)?.toInt() ?? 0,
      photoQuality: json['photo_quality']?.toString() ?? 'clear',
      groomingScore: (json['grooming_score'] as num?)?.toDouble(),
      safeSearchPassed: json['safe_search_passed'] != false,
      labels: labels,
    );
  }

  static String _formatDateTime(String raw) {
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m $h:$min';
  }
}
