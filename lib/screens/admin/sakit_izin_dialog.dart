import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/attendance_log.dart';
import '../../models/employee.dart';
import '../../models/shift_schedule.dart';
import '../../services/sqlite_service.dart';
import '../../services/sync_service.dart';
import '../../services/schedule_sqlite_service.dart';
import '../../widgets/app_toast.dart';

/// Dialog untuk input absensi Sakit/Izin oleh Admin/Kepala Gerai
class SakitIzinDialog extends ConsumerStatefulWidget {
  final Employee employee;
  final String outletId;
  final String outletName;
  final AttendanceLog? existingLog; // null = create, non-null = edit

  const SakitIzinDialog({
    super.key,
    required this.employee,
    required this.outletId,
    required this.outletName,
    this.existingLog,
  });

  @override
  ConsumerState<SakitIzinDialog> createState() => _SakitIzinDialogState();
}

class _SakitIzinDialogState extends ConsumerState<SakitIzinDialog> {
  AttendanceType _selectedType = AttendanceType.sakit;
  DateTime _selectedDate = DateTime.now();
  final _notesCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existingLog != null) {
      final log = widget.existingLog!;
      _selectedType = log.type;
      _selectedDate = DateTime.parse(log.scannedAt).toLocal();
      // Parse notes: strip "Sakit: " or "Izin: " prefix
      final rawNotes = log.notes ?? '';
      if (rawNotes.startsWith('Sakit: ')) {
        _notesCtrl.text = rawNotes.substring(7);
      } else if (rawNotes.startsWith('Izin: ')) {
        _notesCtrl.text = rawNotes.substring(6);
      } else if (rawNotes == 'Sakit') {
        _notesCtrl.text = '';
      } else {
        _notesCtrl.text = rawNotes;
      }
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  /// Check for existing sakit/izin record on the selected date
  Future<bool> _checkDuplicate() async {
    if (widget.existingLog != null) {
      // In edit mode, skip duplicate check if same date
      final existingDate = DateTime.parse(widget.existingLog!.scannedAt).toLocal();
      if (existingDate.year == _selectedDate.year &&
          existingDate.month == _selectedDate.month &&
          existingDate.day == _selectedDate.day) {
        return false; // No duplicate — editing same date
      }
    }

    final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    try {
      final existing = await SupabaseClientFactory.admin
          .from('attendance_logs')
          .select('id')
          .eq('employee_id', widget.employee.id)
          .inFilter('type', ['sakit', 'izin'])
          .gte('scanned_at', dayStart.toUtc().toIso8601String())
          .lt('scanned_at', dayEnd.toUtc().toIso8601String())
          .limit(1);
      return (existing as List).isNotEmpty;
    } catch (e) {
      debugPrint('[SakitIzin] Duplicate check failed: $e');
      return false; // Network error — don't block
    }
  }

  Future<void> _submit() async {
    if (_notesCtrl.text.trim().isEmpty && _selectedType == AttendanceType.izin) {
      setState(() => _error = 'Keterangan wajib diisi untuk izin');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // Check for duplicates (CREATE mode only, or if date changed in EDIT)
      final isDuplicate = await _checkDuplicate();
      if (isDuplicate) {
        setState(() {
          _error = 'Sudah ada catatan sakit/izin untuk tanggal ini';
          _isSubmitting = false;
        });
        return;
      }

      // Anchor time at 08:00 local for correct day bucketing in Rekap Harian
      final scannedAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        8, 0, // 08:00 local time
      ).toUtc().toIso8601String();

      final notes = _selectedType == AttendanceType.sakit
          ? (_notesCtrl.text.trim().isEmpty ? 'Sakit' : 'Sakit: ${_notesCtrl.text.trim()}')
          : 'Izin: ${_notesCtrl.text.trim()}';

      final isEditMode = widget.existingLog != null;

      if (isEditMode) {
        // UPDATE existing record
        await SupabaseClientFactory.admin
            .from('attendance_logs')
            .update({
              'type': _selectedType.value,
              'scanned_at': scannedAt,
              'notes': notes,
            })
            .eq('id', widget.existingLog!.id);
      } else {
        // INSERT new record — direct to Supabase
        try {
          await SupabaseClientFactory.admin
              .from('attendance_logs')
              .insert({
                'employee_id': widget.employee.id,
                'scan_outlet_id': widget.outletId,
                'type': _selectedType.value,
                'device_id': 'ADMIN_INPUT',
                'scanned_at': scannedAt,
                'is_backup': false,
                'notes': notes,
              });
        } catch (supabaseError) {
          // Fallback to SQLite offline queue if Supabase fails
          debugPrint('[SakitIzin] Supabase insert failed, using offline queue: $supabaseError');
          await SqliteService.insertPendingLog(
            employeeId: widget.employee.id,
            scanOutletId: widget.outletId,
            type: _selectedType,
            lat: null,
            lng: null,
            deviceId: 'ADMIN_INPUT',
            scannedAt: scannedAt,
            isBackup: false,
            notes: notes,
          );
          try { await SyncService.syncPendingLogs(); } catch (_) {}
        }
      }

      // Update jadwal shift jika ada
      await _updateScheduleStatus();

      if (mounted) {
        Navigator.of(context).pop(true);
        final action = isEditMode ? 'diperbarui' : 'tercatat';
        AppToast.success(context, '${_selectedType.label} $action untuk ${widget.employee.name}');
      }
    } catch (e) {
      setState(() {
        _error = 'Gagal menyimpan: $e';
        _isSubmitting = false;
      });
    }
  }

  /// Update status jadwal shift jika karyawan sudah dijadwalkan
  Future<void> _updateScheduleStatus() async {
    try {
      // Cari jadwal yang mencakup tanggal ini
      final startOfWeek = _selectedDate.subtract(
        Duration(days: _selectedDate.weekday - 1),
      );
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      
      final schedule = await ScheduleSQLiteService.getSchedule(
        widget.outletId,
        startOfWeek,
        endOfWeek,
      );
      
      if (schedule != null) {
        // Cari entry untuk karyawan ini di tanggal yang dipilih
        final entryIndex = schedule.entries.indexWhere((e) =>
            e.employeeId == widget.employee.id &&
            e.date.year == _selectedDate.year &&
            e.date.month == _selectedDate.month &&
            e.date.day == _selectedDate.day);
        
        if (entryIndex != -1) {
          // Update entry dengan status sakit/izin
          final oldEntry = schedule.entries[entryIndex];
          final newEntry = ScheduleEntry(
            id: oldEntry.id,
            date: oldEntry.date,
            employeeId: oldEntry.employeeId,
            customName: oldEntry.customName,
            displayName: '${widget.employee.name} (${_selectedType.label.toUpperCase()})',
            isCustomName: oldEntry.isCustomName,
            shift: oldEntry.shift,
            isDayOff: true,
            status: _selectedType == AttendanceType.sakit 
                ? ScheduleStatus.sakit 
                : ScheduleStatus.izin,
            notes: _notesCtrl.text.trim().isEmpty 
                ? _selectedType.label 
                : '${_selectedType.label}: ${_notesCtrl.text.trim()}',
          );
          
          schedule.entries[entryIndex] = newEntry;
          await ScheduleSQLiteService.saveSchedule(schedule);
        }
      }
    } catch (e) {
      // Jadwal mungkin belum dibuat, tidak apa-apa
      debugPrint('[SakitIzin] No schedule to update: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existingLog != null ? 'Edit Sakit/Izin' : 'Input Sakit/Izin',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.employee.name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pilihan Sakit/Izin
            Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    type: AttendanceType.sakit,
                    isSelected: _selectedType == AttendanceType.sakit,
                    onTap: () => setState(() => _selectedType = AttendanceType.sakit),
                    icon: Icons.sick_outlined,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeButton(
                    type: AttendanceType.izin,
                    isSelected: _selectedType == AttendanceType.izin,
                    onTap: () => setState(() => _selectedType = AttendanceType.izin),
                    icon: Icons.event_note_outlined,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tanggal
            Text(
              'Tanggal',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dateFormat.format(_selectedDate),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Keterangan
            Text(
              _selectedType == AttendanceType.sakit 
                  ? 'Keterangan (opsional)' 
                  : 'Keterangan (wajib)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _selectedType == AttendanceType.sakit
                    ? 'Contoh: Demam, flu...'
                    : 'Contoh: Urusan keluarga, cuti...',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Catatan akan tampil di laporan',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, 
                        color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedType == AttendanceType.sakit
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            widget.existingLog != null
                                ? 'Perbarui ${_selectedType.label}'
                                : 'Simpan ${_selectedType.label}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final AttendanceType type;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;

  const _TypeButton({
    required this.type,
    required this.isSelected,
    required this.onTap,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              type.label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
