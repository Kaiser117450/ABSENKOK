import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/attendance_log.dart';
import '../../models/employee.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_skeleton.dart';
import 'sakit_izin_dialog.dart';

/// Screen that shows sakit/izin history for a specific employee.
/// Accessible from the employee card popup menu in AdminEmployeesScreen.
class SakitIzinListScreen extends ConsumerStatefulWidget {
  final Employee employee;
  final String outletId;
  final String outletName;

  const SakitIzinListScreen({
    super.key,
    required this.employee,
    required this.outletId,
    required this.outletName,
  });

  @override
  ConsumerState<SakitIzinListScreen> createState() =>
      _SakitIzinListScreenState();
}

class _SakitIzinListScreenState extends ConsumerState<SakitIzinListScreen> {
  List<AttendanceLog> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSakitIzinRecords();
  }

  Future<void> _loadSakitIzinRecords() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseClientFactory.admin
          .from('attendance_logs')
          .select('*')
          .eq('employee_id', widget.employee.id)
          .inFilter('type', ['sakit', 'izin'])
          .order('scanned_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() {
          _records = (data as List)
              .map((e) => AttendanceLog.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppToast.error(context, 'Gagal memuat data: $e');
      }
    }
  }

  void _editRecord(AttendanceLog record) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SakitIzinDialog(
        employee: widget.employee,
        outletId: widget.outletId,
        outletName: widget.outletName,
        existingLog: record,
      ),
    ).then((result) {
      if (result == true) _loadSakitIzinRecords();
    });
  }

  Future<void> _deleteRecord(AttendanceLog record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Catatan?'),
        content: Text(
          'Hapus catatan ${record.type.label} tanggal ${_formatDate(record.scannedAt)}?\n\nTindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Safety guard: only delete sakit/izin types
      if (record.type != AttendanceType.sakit &&
          record.type != AttendanceType.izin) {
        if (mounted) {
          AppToast.error(context, 'Hanya catatan sakit/izin yang bisa dihapus');
        }
        return;
      }

      await SupabaseClientFactory.admin
          .from('attendance_logs')
          .delete()
          .eq('id', record.id);

      if (mounted) {
        AppToast.success(context, '${record.type.label} berhasil dihapus');
        _loadSakitIzinRecords();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Gagal menghapus: $e');
      }
    }
  }

  void _createNew() {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SakitIzinDialog(
        employee: widget.employee,
        outletId: widget.outletId,
        outletName: widget.outletName,
      ),
    ).then((result) {
      if (result == true) _loadSakitIzinRecords();
    });
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  String _parseNotes(AttendanceLog record) {
    final raw = record.notes ?? '';
    // Strip type prefix for display
    if (raw.startsWith('Sakit: ')) return raw.substring(7);
    if (raw.startsWith('Izin: ')) return raw.substring(6);
    if (raw == 'Sakit') return '';
    return raw;
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Column(
        children: List.generate(
          4,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: const [
                  ShimmerSkeleton(width: 64, height: 28, borderRadius: 14),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerSkeleton(
                            width: 180, height: 14, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerSkeleton(
                            width: 120, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  ShimmerSkeleton(width: 28, height: 28, borderRadius: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(AttendanceType type) {
    final isSakit = type == AttendanceType.sakit;
    final bgColor = isSakit ? AppColors.badgeSakitBg : AppColors.badgeIzinBg;
    final textColor =
        isSakit ? AppColors.badgeSakitText : AppColors.badgeIzinText;
    final label = '${type.emoji} ${type.label}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRecordTile(AttendanceLog record) {
    final notes = _parseNotes(record);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Type badge
          _buildTypeBadge(record.type),
          const SizedBox(width: 14),

          // Date + notes
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(record.scannedAt),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    notes,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Actions popup
          PopupMenuButton<String>(
            offset: const Offset(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _editRecord(record);
              } else if (value == 'delete') {
                _deleteRecord(record);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    const Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: const Color(0xFFDC2626)),
                    const SizedBox(width: 10),
                    const Text(
                      'Hapus',
                      style: TextStyle(color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.more_vert,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Riwayat Sakit/Izin'),
            Text(
              widget.employee.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNew,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Tambah',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? _buildShimmer()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadSakitIzinRecords,
              child: _records.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(
                          height: 300,
                          child: AppEmptyState(
                            icon: Icons.medical_services_outlined,
                            heading: 'Belum ada catatan sakit/izin',
                            subtext:
                                'Tekan tombol Tambah untuk menambahkan catatan baru.',
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: _records.length,
                      itemBuilder: (context, i) =>
                          _buildRecordTile(_records[i]),
                    ),
            ),
    );
  }
}
