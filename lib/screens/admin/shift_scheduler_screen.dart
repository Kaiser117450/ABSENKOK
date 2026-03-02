// LENGKAP - ShiftSchedulerScreen dengan Time Off & Synchronized Scroll
// [File lengkap akan saya tulis di response berikut karena terlalu panjang]

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/attendance_log.dart';
import '../../models/employee.dart';
import '../../models/outlet.dart';
import '../../models/shift_schedule.dart';
import '../../models/time_off_request.dart';
import '../../providers/app_provider.dart';
import '../../services/pdf_service.dart';
import '../../services/schedule_sqlite_service.dart';

class ShiftSchedulerScreen extends ConsumerStatefulWidget {
  final String? outletId;
  final String? outletName;
  
  const ShiftSchedulerScreen({super.key, this.outletId, this.outletName});

  @override
  ConsumerState<ShiftSchedulerScreen> createState() => _ShiftSchedulerScreenState();
}

class _ShiftSchedulerScreenState extends ConsumerState<ShiftSchedulerScreen> {
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;
  List<Employee> _employees = [];
  OutletSchedule? _currentSchedule;

  // Bulk assign state
  Set<String> _selectedEmployeeIds = {};
  bool _isBulkMode = false;
  
  // Data
  Map<String, Map<String, AttendanceType>> _sakitIzinMap = {};
  Map<String, List<DateTime>> _timeOffMap = {};
  Map<String, int> _leaveBalance = {};
  
  // Settings
  DateTime _startDate = _getStartOfWeek(DateTime.now());
  bool _isWeekly = true;
  ShiftTemplate? _template;
  
  // SYNCHRONIZED SCROLL
  final ScrollController _employeeListController = ScrollController();
  final ScrollController _scheduleGridController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _setupScrollSync();
    _loadData();
  }

  static DateTime _getStartOfWeek(DateTime date) {
    // Normalisasi ke Senin 00:00:00
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  void _setupScrollSync() {
    _employeeListController.addListener(() {
      if (!_isSyncing && _scheduleGridController.hasClients) {
        _isSyncing = true;
        _scheduleGridController.jumpTo(_employeeListController.offset);
        _isSyncing = false;
      }
    });
    
    _scheduleGridController.addListener(() {
      if (!_isSyncing && _employeeListController.hasClients) {
        _isSyncing = true;
        _employeeListController.jumpTo(_scheduleGridController.offset);
        _isSyncing = false;
      }
    });
  }

  @override
  void dispose() {
    _employeeListController.dispose();
    _scheduleGridController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final outletId = widget.outletId ?? ref.read(appProvider).managedOutletId;
      if (outletId == null) { setState(() => _isLoading = false); return; }

      final empData = await SupabaseClientFactory.admin
          .from('employees').select('*').eq('home_outlet_id', outletId).eq('is_active', true).order('name');
      
      final loadedEmployees = (empData as List).map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
      
      await _loadSakitIzinData(outletId, loadedEmployees);
      await _loadTimeOffRequests(outletId, loadedEmployees);
      await _loadCarryOverBalance(outletId, loadedEmployees);
      
      final endDate = _startDate.add(const Duration(days: 6));
      
      // SUPABASE-FIRST: try cloud, cache to SQLite, fallback to SQLite on error
      OutletSchedule? existingSchedule;
      try {
        existingSchedule = await _loadScheduleFromSupabase(outletId, _startDate, endDate, loadedEmployees);
        if (existingSchedule != null) {
          // Write-through: cache to SQLite for offline use
          await ScheduleSQLiteService.saveSchedule(existingSchedule);
          debugPrint('Loaded schedule from Supabase, cached to SQLite: ${existingSchedule.entries.length} entries');
        }
      } catch (e) {
        debugPrint('Supabase fetch failed, falling back to SQLite: $e');
      }
      // Fallback to SQLite only if Supabase returned nothing or failed
      existingSchedule ??= await ScheduleSQLiteService.getSchedule(outletId, _startDate, endDate);

      setState(() {
        _employees = loadedEmployees;
        _currentSchedule = existingSchedule ?? OutletSchedule(
          id: '${outletId}_${_startDate.millisecondsSinceEpoch}',
          outletId: outletId,
          startDate: _startDate,
          endDate: endDate,
          template: ShiftTemplate.standard(outletId),
          entries: [],
          createdAt: DateTime.now(),
        );
        _template = _currentSchedule!.template;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: $e');
    }
  }

  Future<OutletSchedule?> _loadScheduleFromSupabase(String outletId, DateTime startDate, DateTime endDate, List<Employee> employees) async {
    try {
      // Load schedule header
      final scheduleData = await SupabaseClientFactory.admin
          .from('schedules')
          .select('*')
          .eq('outlet_id', outletId)
          .gte('start_date', startDate.toIso8601String().split('T')[0])
          .lte('end_date', endDate.toIso8601String().split('T')[0])
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (scheduleData == null) {
        debugPrint('No schedule found in Supabase');
        return null;
      }
      
      // Load entries
      final entriesData = await SupabaseClientFactory.admin
          .from('schedule_entries')
          .select('*')
          .eq('schedule_id', scheduleData['id']);
      
      debugPrint('Loaded ${(entriesData as List).length} entries from Supabase');
      
      // Build entries list
      final entries = (entriesData as List).map((e) {
        final shiftJson = e['shift_slot'] as Map<String, dynamic>;
        return ScheduleEntry(
          id: e['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          date: DateTime.parse(e['date']),
          employeeId: e['employee_id'],
          customName: e['custom_name'],
          displayName: e['display_name'] ?? 'Unknown',
          isCustomName: e['is_custom_name'] ?? false,
          shift: ShiftSlot.fromJson(shiftJson),
          isDayOff: e['is_day_off'] ?? false,
          notes: e['notes'],
        );
      }).toList();
      
      return OutletSchedule(
        id: scheduleData['id'],
        outletId: outletId,
        startDate: DateTime.parse(scheduleData['start_date']),
        endDate: DateTime.parse(scheduleData['end_date']),
        template: ShiftTemplate.standard(outletId),
        entries: entries,
        createdAt: DateTime.parse(scheduleData['created_at']),
      );
    } catch (e) {
      debugPrint('Error loading from Supabase: $e');
      return null;
    }
  }

  Future<void> _loadSakitIzinData(String outletId, List<Employee> employees) async {
    try {
      final endDate = _startDate.add(const Duration(days: 6));
      final logsData = await SupabaseClientFactory.admin
          .from('attendance_logs').select('employee_id, type, scanned_at')
          .inFilter('employee_id', employees.map((e) => e.id).toList())
          .inFilter('type', ['sakit', 'izin'])
          .gte('scanned_at', _startDate.toIso8601String())
          .lte('scanned_at', endDate.toIso8601String());
      
      final Map<String, Map<String, AttendanceType>> tempMap = {};
      for (final log in logsData as List) {
        final empId = log['employee_id'] as String;
        final type = AttendanceTypeExt.fromString(log['type'] as String);
        final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.parse(log['scanned_at'] as String));
        tempMap[empId] ??= {}; tempMap[empId]![dateKey] = type;
      }
      setState(() => _sakitIzinMap = tempMap);
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _loadTimeOffRequests(String outletId, List<Employee> employees) async {
    try {
      final endDate = _startDate.add(const Duration(days: 6));
      final requestsData = await SupabaseClientFactory.admin
          .from('time_off_requests').select('*')
          .eq('outlet_id', outletId).eq('status', 'approved')
          .gte('request_date', _startDate.toIso8601String())
          .lte('request_date', endDate.toIso8601String());
      
      final Map<String, List<DateTime>> tempMap = {};
      for (final req in requestsData as List) {
        final empId = req['employee_id'] as String;
        tempMap[empId] ??= []; tempMap[empId]!.add(DateTime.parse(req['request_date'] as String));
      }
      setState(() => _timeOffMap = tempMap);
    } catch (e) { debugPrint('Error: $e'); }
  }

  AttendanceType? _getSakitIzin(String empId, DateTime date) {
    return _sakitIzinMap[empId]?[DateFormat('yyyy-MM-dd').format(date)];
  }

  bool _hasTimeOff(String empId, DateTime date) {
    return (_timeOffMap[empId] ?? []).any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
  }

  /// Load carry over balance dari minggu lalu
  Future<void> _loadCarryOverBalance(String outletId, List<Employee> employees) async {
    try {
      final prevWeekEnd = _startDate.subtract(const Duration(days: 1));
      final prevWeekStart = prevWeekEnd.subtract(const Duration(days: 6));
      
      // Load schedule minggu lalu
      final prevSchedule = await ScheduleSQLiteService.getSchedule(outletId, prevWeekStart, prevWeekEnd);
      
      final Map<String, int> tempBalance = {};
      
      for (final emp in employees) {
        if (prevSchedule != null) {
          // Hitung berapa hari libur yang diambil minggu lalu
          int leaveCount = 0;
          for (int i = 0; i < 7; i++) {
            final date = prevWeekStart.add(Duration(days: i));
            final hasLibur = prevSchedule.entries.any((e) => 
              e.employeeId == emp.id && 
              e.date.year == date.year && 
              e.date.month == date.month && 
              e.date.day == date.day &&
              (e.shift.name.toLowerCase().contains('libur') || e.isDayOff)
            );
            if (hasLibur) leaveCount++;
          }
          
          // Carry over = 1 (wajib) - leaveCount (yang diambil)
          // Jika 0 libur minggu lalu, carry over = 1
          // Jika 1 libur minggu lalu, carry over = 0
          // Jika >1 libur minggu lalu, carry over = 0 (tidak negatif)
          tempBalance[emp.id] = leaveCount < 1 ? 1 : 0;
        } else {
          tempBalance[emp.id] = 0;
        }
      }
      
      setState(() => _leaveBalance = tempBalance);
    } catch (e) {
      debugPrint('Error loading carry over: $e');
    }
  }

  void _addShift(Employee emp, DateTime date, ShiftSlot shift) {
    final sakitIzin = _getSakitIzin(emp.id, date);
    if (sakitIzin != null) { _showError('${emp.name} sedang ${sakitIzin.label}'); return; }

    setState(() {
      _currentSchedule!.entries.removeWhere((e) => e.employeeId == emp.id && e.date.year == date.year && e.date.month == date.month && e.date.day == date.day);
      _currentSchedule!.entries.add(ScheduleEntry.fromEmployee(
        id: '${DateTime.now().millisecondsSinceEpoch}_${emp.id}', date: date, employee: emp, shift: shift,
      ));
      _hasUnsavedChanges = true;
    });
  }

  void _removeEntry(String entryId) {
    setState(() {
      _currentSchedule!.entries.removeWhere((e) => e.id == entryId);
      _hasUnsavedChanges = true;
    });
  }

  // ===========================================================================
  // BULK ASSIGN
  // ===========================================================================

  void _toggleBulkMode() {
    setState(() {
      _isBulkMode = !_isBulkMode;
      if (!_isBulkMode) _selectedEmployeeIds.clear();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedEmployeeIds.length == _employees.length) {
        _selectedEmployeeIds.clear();
      } else {
        _selectedEmployeeIds = _employees.map((e) => e.id).toSet();
      }
    });
  }

  void _bulkAssign(ShiftSlot shift) {
    if (_selectedEmployeeIds.isEmpty || _currentSchedule == null) return;
    final days = List.generate(7, (i) => _startDate.add(Duration(days: i)));
    final selectedEmps = _employees.where((e) => _selectedEmployeeIds.contains(e.id)).toList();

    setState(() {
      for (final emp in selectedEmps) {
        for (final day in days) {
          // Skip days with sakit/izin
          if (_getSakitIzin(emp.id, day) != null) continue;
          // Skip days with approved time off
          if (_hasTimeOff(emp.id, day)) continue;

          // Remove existing entry for this employee+day
          _currentSchedule!.entries.removeWhere((e) =>
            e.employeeId == emp.id &&
            e.date.year == day.year && e.date.month == day.month && e.date.day == day.day);

          // Add new entry
          final isDayOff = shift.name == 'Libur';
          _currentSchedule!.entries.add(ScheduleEntry.fromEmployee(
            id: '${DateTime.now().millisecondsSinceEpoch}_${emp.id}_${day.day}',
            date: day,
            employee: emp,
            shift: shift,
            isDayOff: isDayOff,
          ));
        }
      }
      _hasUnsavedChanges = true;
    });

    _showSuccess('${shift.name} assigned to ${selectedEmps.length} karyawan');
  }

  void _showBulkAssignSheet() {
    if (_selectedEmployeeIds.isEmpty) {
      _showError('Pilih karyawan terlebih dahulu');
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Assign shift untuk ${_selectedEmployeeIds.length} karyawan',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF3B82F6), radius: 16),
              title: const Text('Pagi (09:00-17:00)'),
              onTap: () { Navigator.pop(ctx); _bulkAssign(ShiftSlot.pagi()); },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFF59E0B), radius: 16),
              title: const Text('Siang (12:00-20:00)'),
              onTap: () { Navigator.pop(ctx); _bulkAssign(ShiftSlot.siang()); },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFF97316), radius: 16),
              title: const Text('Sore (14:00-22:00)'),
              onTap: () { Navigator.pop(ctx); _bulkAssign(ShiftSlot.sore()); },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFDC2626), radius: 16),
              title: const Text('Libur'),
              onTap: () { Navigator.pop(ctx); _bulkAssign(ShiftSlot.libur()); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAutoSchedule() async {
    if (_employees.isEmpty) return;
    
    // Tampilkan dialog pilihan template - SEDERHANA
    String? selectedTemplate = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Pilih Template', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 2 Shift
            ListTile(
              leading: const Icon(Icons.store, color: Color(0xFF3B82F6)),
              title: const Text('2 Shift', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Pagi & Siang', style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.pop(dialogCtx, '2shift'),
            ),
            const Divider(),
            // 3 Shift
            ListTile(
              leading: const Icon(Icons.access_time, color: Color(0xFFDC2626)),
              title: const Text('3 Shift (24 Jam)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Pagi - Siang - Sore', style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.pop(dialogCtx, '3shift'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, null), 
            child: const Text('Batal'),
          ),
        ],
      ),
    );
    
    if (selectedTemplate == null) return;
    
    // Set template
    final outletId = widget.outletId ?? ref.read(appProvider).managedOutletId ?? '';
    if (selectedTemplate == '2shift') {
      _template = ShiftTemplate.pagiSiang(outletId);
    } else {
      _template = ShiftTemplate.standard(outletId);
    }
    
    setState(() => _isLoading = true);

    try {
      final days = List.generate(7, (i) => _startDate.add(Duration(days: i)));
      final newEntries = <ScheduleEntry>[];

      for (final emp in _employees) {
        // Count existing libur + sakit + izin + timeoff minggu ini
        int existingLeave = 0;
        final leaveDays = <DateTime>[];
        
        for (final day in days) {
          if (_getSakitIzin(emp.id, day) != null || _hasTimeOff(emp.id, day)) {
            existingLeave++;
            leaveDays.add(day);
          }
        }
        
        // Ambil carry over dari minggu lalu
        final carryOver = _leaveBalance[emp.id] ?? 0;
        
        // Total libur yang harus diassign = 1 wajib + carry over - yang sudah ada
        int needLeave = (1 + carryOver) - existingLeave;
        
        if (needLeave > 0) {
          // Assign libur ke hari yang masih kosong
          final availableDays = days.where((d) => !leaveDays.contains(d)).toList()..shuffle();
          for (int i = 0; i < needLeave && i < availableDays.length; i++) {
            leaveDays.add(availableDays[i]);
          }
        }
        
        // Update carry over untuk minggu depan:
        // Jika tidak cukup hari untuk assign semua libur, sisa carry over ke depan
        final assignedLeave = leaveDays.length;
        final totalRequired = 1 + carryOver;
        final remainingLeave = totalRequired > assignedLeave ? totalRequired - assignedLeave : 0;
        _leaveBalance[emp.id] = remainingLeave;

        // Generate entries
        for (final day in days) {
          if (leaveDays.contains(day)) {
            newEntries.add(ScheduleEntry.fromEmployee(
              id: 'libur_${emp.id}_${day.day}', date: day, employee: emp, shift: ShiftSlot.libur(),
            ));
          } else if (_getSakitIzin(emp.id, day) == null && !_hasTimeOff(emp.id, day)) {
            // Rotate shift berdasarkan template (2 atau 3 shift)
            final shiftSlots = _template?.slots ?? [ShiftSlot.pagi(), ShiftSlot.siang(), ShiftSlot.sore()];
            final shiftIndex = (_employees.indexOf(emp) + days.indexOf(day)) % shiftSlots.length;
            final shift = shiftSlots[shiftIndex];
            newEntries.add(ScheduleEntry.fromEmployee(
              id: 'shift_${emp.id}_${day.day}', date: day, employee: emp, shift: shift,
            ));
          }
        }
      }

      // Create new schedule dengan entries baru
      final newSchedule = OutletSchedule(
        id: _currentSchedule!.id,
        outletId: _currentSchedule!.outletId,
        startDate: _currentSchedule!.startDate,
        endDate: _currentSchedule!.endDate,
        template: _template!,
        entries: newEntries,
        createdAt: _currentSchedule!.createdAt,
        syncedAt: _currentSchedule!.syncedAt,
        isActive: _currentSchedule!.isActive,
      );
      _currentSchedule = newSchedule;
      await ScheduleSQLiteService.saveSchedule(_currentSchedule!);
      _hasUnsavedChanges = true;

      setState(() => _isLoading = false);
      _showSuccess('Jadwal ${_template!.name} generated! Tap Simpan untuk sync ke cloud.');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: $e');
    }
  }



  void _showTimeOffDialog(Employee emp) {
    DateTime? selectedDate;
    showDialog(
      context: context,
      useRootNavigator: false,  // PENTING
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Request Libur - ${emp.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pilih hari libur:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (i) {
                  final date = _startDate.add(Duration(days: i));
                  final dayName = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][date.weekday % 7];
                  final isSelected = selectedDate == date;
                  return ChoiceChip(
                    label: Text(
                      '$dayName ${date.day}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.grey.shade200,
                    onSelected: (_) => setDialogState(() => selectedDate = date),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
            ElevatedButton(
              onPressed: selectedDate == null ? null : () async {
                try {
                  final outletId = widget.outletId ?? ref.read(appProvider).managedOutletId;
                  if (outletId == null) throw Exception('No outlet');
                  
                  // Format date untuk PostgreSQL (YYYY-MM-DD)
                  final dateStr = selectedDate!.toIso8601String().split('T')[0];
                  
                  debugPrint('Saving time_off: emp=${emp.id}, outlet=$outletId, date=$dateStr');
                  
                  // Insert tanpa ID (Supabase akan generate UUID otomatis)
                  await SupabaseClientFactory.admin.from('time_off_requests').insert({
                    'employee_id': emp.id,
                    'outlet_id': outletId,
                    'request_date': dateStr,
                    'reason': 'Request libur',
                    'status': 'approved',
                  });
                  
                  Navigator.pop(dialogContext);
                  _showSuccess('Request libur disimpan');
                  _loadData();
                } catch (e) { 
                  debugPrint('Time off error: $e');
                  Navigator.pop(dialogContext);
                  _showError('Gagal menyimpan: $e'); 
                }
              },
              child: const Text('Simpan'),
            ),
        ],
      ),
    ),
  );
}

  Future<void> _saveSchedule() async {
    if (_currentSchedule == null) return;
    setState(() => _isLoading = true);
    try {
      // 1. Save ke Supabase FIRST (source of truth)
      try {
        final startDateStr = _currentSchedule!.startDate.toIso8601String().split('T')[0];
        final endDateStr = _currentSchedule!.endDate.toIso8601String().split('T')[0];

        // 1a. Cek apakah ada active schedule di periode ini
        final existing = await SupabaseClientFactory.admin
            .from('schedules')
            .select('id')
            .eq('outlet_id', _currentSchedule!.outletId)
            .eq('start_date', startDateStr)
            .eq('end_date', endDateStr)
            .eq('is_active', true)
            .maybeSingle();

        final existingId = existing?['id'] as String?;

        // 1b. Selalu buat schedule row BARU
        final result = await SupabaseClientFactory.admin.from('schedules').insert({
          'outlet_id': _currentSchedule!.outletId,
          'start_date': startDateStr,
          'end_date': endDateStr,
          'is_active': true,
        }).select('id').single();

        final newScheduleId = result['id'];
        debugPrint('Created new schedule: $newScheduleId');

        // 1c. Bulk Insert data ke schedule_entries dengan scheduleId baru
        final entriesData = _currentSchedule!.entries.map((entry) => {
          'schedule_id': newScheduleId,
          'date': entry.date.toIso8601String().split('T')[0],
          'employee_id': entry.employeeId,
          'custom_name': entry.customName,
          'display_name': entry.displayName,
          'is_custom_name': entry.isCustomName,
          'shift_slot': entry.shift.toJson(),
          'is_day_off': entry.isDayOff,
          'notes': entry.notes,
        }).toList();

        if (entriesData.isNotEmpty) {
          await SupabaseClientFactory.admin.from('schedule_entries').insert(entriesData);
          debugPrint('Bulk inserted ${entriesData.length} entries for $newScheduleId');
        }

        // 1d. Jika inserts sukses, soft-delete schedule lama
        if (existingId != null) {
          await SupabaseClientFactory.admin.from('schedules').update({
            'is_active': false,
          }).eq('id', existingId);
          debugPrint('Soft-deleted old schedule: $existingId');
        }

        // 1e. Update local instance dengan ID yang baru
        _currentSchedule = OutletSchedule(
          id: newScheduleId,
          outletId: _currentSchedule!.outletId,
          startDate: _currentSchedule!.startDate,
          endDate: _currentSchedule!.endDate,
          template: _currentSchedule!.template,
          entries: _currentSchedule!.entries,
          createdAt: _currentSchedule!.createdAt,
          syncedAt: _currentSchedule!.syncedAt,
          isActive: _currentSchedule!.isActive,
        );

        // 2. Write-through: cache to SQLite with correct Supabase ID
        await ScheduleSQLiteService.saveSchedule(_currentSchedule!);
        _hasUnsavedChanges = false;
        debugPrint('Supabase save successful, cached to SQLite');
      } catch (supabaseError) {
        debugPrint('Supabase sync error: $supabaseError');
        // Still save to SQLite as offline fallback
        await ScheduleSQLiteService.saveSchedule(_currentSchedule!);
        _showError('Gagal sync ke cloud: $supabaseError');
      }

      setState(() => _isLoading = false);
      _showSuccess('Jadwal tersimpan');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: $e');
    }
  }

  Future<void> _exportToPdf() async {
    if (_currentSchedule == null) return;
    setState(() => _isLoading = true);
    try {
      // Buat salinan entries yang memasukkan status sakit/izin secara eksplisit
      // supaya PDF bisa merendernya.
      final days = List.generate(
        _currentSchedule!.endDate.difference(_currentSchedule!.startDate).inDays + 1,
        (i) => _currentSchedule!.startDate.add(Duration(days: i)),
      );

      final mergedEntries = <ScheduleEntry>[];
      for (final emp in _employees) {
        for (final date in days) {
          final sakitIzin = _getSakitIzin(emp.id, date);
          final isTimeOff = _hasTimeOff(emp.id, date);

          if (sakitIzin != null) {
            if (sakitIzin.label.toLowerCase() == 'sakit') {
              mergedEntries.add(
                ScheduleEntry.sakit(
                  id: 'merged_${emp.id}_${date.day}',
                  date: date,
                  employee: emp,
                  shift: ShiftSlot.libur(),
                ),
              );
            } else {
              mergedEntries.add(
                ScheduleEntry.izin(
                  id: 'merged_${emp.id}_${date.day}',
                  date: date,
                  employee: emp,
                  shift: ShiftSlot.libur(),
                ),
              );
            }
          } else if (isTimeOff) {
            mergedEntries.add(
              ScheduleEntry.fromEmployee(
                id: 'merged_${emp.id}_${date.day}',
                date: date,
                employee: emp,
                shift: ShiftSlot.libur(),
                isDayOff: true,
                status: ScheduleStatus.libur,
              ),
            );
          } else {
            final e = _currentSchedule!.entries.where((e) =>
                e.employeeId == emp.id &&
                e.date.year == date.year &&
                e.date.month == date.month &&
                e.date.day == date.day);
            if (e.isNotEmpty) mergedEntries.addAll(e);
          }
        }
      }

      final mergedSchedule = OutletSchedule(
        id: _currentSchedule!.id,
        outletId: _currentSchedule!.outletId,
        startDate: _currentSchedule!.startDate,
        endDate: _currentSchedule!.endDate,
        template: _currentSchedule!.template,
        entries: mergedEntries,
        createdAt: _currentSchedule!.createdAt,
        syncedAt: _currentSchedule!.syncedAt,
        isActive: _currentSchedule!.isActive,
      );

      await PdfService.generateAndShareSchedule(
        schedule: mergedSchedule,
        employees: _employees,
        outletName: widget.outletName ?? 'Unknown',
      );
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error PDF: $e');
    }
  }

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.green));
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.red));

  // ===========================================================================
  // BUILD METHODS
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: _isBulkMode ? Colors.orange.shade700 : AppColors.primary,
        leading: _isBulkMode
          ? IconButton(icon: const Icon(Icons.close), onPressed: _toggleBulkMode)
          : null,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_isBulkMode ? 'Bulk Assign' : 'Jadwal Shift', style: const TextStyle(fontSize: 18)),
          Text(
            _isBulkMode
              ? '${_selectedEmployeeIds.length} karyawan dipilih'
              : (widget.outletName ?? 'Unknown'),
            style: const TextStyle(fontSize: 12),
          ),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _exportToPdf),
          Stack(
            children: [
              IconButton(icon: const Icon(Icons.save), onPressed: _saveSchedule),
              if (_hasUnsavedChanges)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) 
          : Column(children: [
              _buildHeader(),
              _buildLegend(),
              Expanded(child: _buildTable()),
            ]),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bulk assign FAB
          FloatingActionButton.small(
            heroTag: 'bulk',
            onPressed: _isBulkMode ? _showBulkAssignSheet : _toggleBulkMode,
            backgroundColor: _isBulkMode ? Colors.orange : Colors.blueGrey,
            child: Icon(
              _isBulkMode ? Icons.assignment : Icons.checklist,
              color: Colors.white, size: 20,
            ),
          ),
          const SizedBox(height: 8),
          // Auto-generate FAB
          FloatingActionButton.small(
            heroTag: 'auto',
            onPressed: _generateAutoSchedule,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.auto_fix_high, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: Colors.white,
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 28), 
          onPressed: () { 
            setState(() {
              _startDate = _startDate.subtract(const Duration(days: 7)); 
            });
            _loadData(); 
          },
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_startDate.add(const Duration(days: 6)))}',
                textAlign: TextAlign.center, 
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Buka: 09:00 - 22:00',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 28),
          onPressed: () { 
            setState(() {
              _startDate = _startDate.add(const Duration(days: 7)); 
            });
            _loadData(); 
          },
        ),
      ]),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.white,
      child: SingleChildScrollView(scrollDirection: Axis.horizontal,
        child: Row(children: [
          _legendChip('Pagi', const Color(0xFF3B82F6)),
          _legendChip('Siang', const Color(0xFFF59E0B)),
          _legendChip('Sore', const Color(0xFFF97316)),
          _legendChip('Libur', const Color(0xFFDC2626)),
          _legendChip('Sakit', const Color(0xFF991B1B)),
          _legendChip('Izin', const Color(0xFF2563EB)),
        ]),
      ),
    );
  }

  Widget _legendChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ===========================================================================
  // SYNCHRONIZED TABLE
  // ===========================================================================

  Widget _buildTable() {
    if (_employees.isEmpty) return const Center(child: Text('Tidak ada karyawan'));
    final days = List.generate(7, (i) => _startDate.add(Duration(days: i)));

    return Row(children: [
      // FIXED: Employee Column - COMPACT
      Container(
        width: 110,
        decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(right: BorderSide(color: Colors.grey.shade300))),
        child: Column(children: [
          Container(height: 40, alignment: Alignment.center,
            decoration: BoxDecoration(color: _isBulkMode ? Colors.orange.withOpacity(0.15) : AppColors.primary.withOpacity(0.1), border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
            child: _isBulkMode
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(
                    width: 24, height: 24,
                    child: Checkbox(
                      value: _selectedEmployeeIds.length == _employees.length && _employees.isNotEmpty,
                      onChanged: (_) => _toggleSelectAll(),
                      activeColor: Colors.orange,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Semua', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                ])
              : const Text('KARYAWAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: ListView.builder(
              controller: _employeeListController,
              itemCount: _employees.length,
              itemBuilder: (ctx, i) => _buildEmployeeCell(_employees[i]),
            ),
          ),
        ]),
      ),
      // SCROLLABLE: Schedule Grid - COMPACT
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final colWidth = (constraints.maxWidth / days.length).clamp(65.0, double.infinity);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalScrollController,
              child: SizedBox(
                width: days.length * colWidth,
                child: Column(children: [
                  // Date Header - COMPACT
                  Container(height: 40, color: AppColors.primary.withOpacity(0.05),
                    child: Row(children: days.map((d) => Container(
                      width: colWidth, alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade200))),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(['Sen','Sel','Rab','Kam','Jum','Sab','Min'][d.weekday%7], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        Text('${d.day}', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                      ]),
                    )).toList()),
                  ),
                  // Schedule Rows (SYNCHRONIZED)
                  Expanded(
                    child: ListView.builder(
                      controller: _scheduleGridController,
                      itemCount: _employees.length,
                      itemBuilder: (ctx, i) => _buildScheduleRow(_employees[i], days, colWidth),
                    ),
                  ),
                ]),
              ),
            );
          }
        ),
      ),
    ]);
  }

  Widget _buildEmployeeCell(Employee emp) {
    final isSelected = _selectedEmployeeIds.contains(emp.id);
    return Container(
      height: 52, // COMPACT
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: _isBulkMode && isSelected ? Colors.orange.withOpacity(0.08) : null,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(children: [
        // Bulk mode checkbox
        if (_isBulkMode)
          SizedBox(
            width: 28, height: 28,
            child: Checkbox(
              value: isSelected,
              onChanged: (_) => setState(() {
                if (isSelected) {
                  _selectedEmployeeIds.remove(emp.id);
                } else {
                  _selectedEmployeeIds.add(emp.id);
                }
              }),
              activeColor: Colors.orange,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        if (!_isBulkMode) const SizedBox(width: 4),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emp.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            // Show leave balance indicator
            if ((_leaveBalance[emp.id] ?? 0) > 0)
              Container(margin: const EdgeInsets.only(top: 2), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(3)),
                child: Text('+${_leaveBalance[emp.id]}', style: TextStyle(fontSize: 8, color: Colors.orange.shade800)),
              ),
          ])),
        // Time off button - COMPACT (hidden in bulk mode)
        if (!_isBulkMode)
          Material(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _showTimeOffDialog(emp),
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                child: Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade700),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildScheduleRow(Employee emp, List<DateTime> days, double colWidth) {
    return Container(
      height: 52, // COMPACT
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(children: days.map((d) => _buildDayCell(emp, d, colWidth)).toList()),
    );
  }

  Widget _buildDayCell(Employee emp, DateTime date, double colWidth) {
    final width = colWidth;
    
    // Check sakit/izin
    final sakitIzin = _getSakitIzin(emp.id, date);
    if (sakitIzin != null) {
      return Container(width: width, padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade200))),
        child: _chip(sakitIzin.label, sakitIzin.color, Icons.medical_services),
      );
    }
    
    // Check time off
    if (_hasTimeOff(emp.id, date)) {
      return Container(width: width, padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade200))),
        child: _chip('Libur', const Color(0xFFDC2626), Icons.beach_access),
      );
    }
    
    // Get shift entry
    final entries = _currentSchedule!.entries.where((e) => 
      e.employeeId == emp.id && e.date.year == date.year && e.date.month == date.month && e.date.day == date.day).toList();
    
    if (entries.isEmpty) {
      return Container(width: width, padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade200))),
        child: GestureDetector(
          onTap: () => _showShiftPicker(emp, date),
          child: Container(decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300)),
            child: Icon(Icons.add, size: 18, color: Colors.grey.shade400)),
        ),
      );
    }
    
    final entry = entries.first;
    final shiftName = entry.shift.name.toLowerCase();
    final (bg, fg, icon) = switch(shiftName) {
      'pagi' => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF), Icons.wb_sunny),
      'siang' => (const Color(0xFFFEF3C7), const Color(0xFF92400E), Icons.wb_twilight),
      'sore' => (const Color(0xFFFFEDD5), const Color(0xFFC2410C), Icons.nights_stay),
      'libur' => (const Color(0xFFFEE2E2), const Color(0xFF991B1B), Icons.beach_access),
      _ => (Colors.grey.shade200, Colors.grey.shade800, Icons.work),
    };
    
    return Container(width: width, padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade200))),
      child: GestureDetector(
        onTap: () => _removeEntry(entry.id),
        child: _chip(entry.shift.name, fg, icon, bg: bg),
      ),
    );
  }

  Widget _chip(String label, Color color, IconData icon, {Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(color: bg ?? color.withOpacity(0.15), borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color), overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  void _showShiftPicker(Employee emp, DateTime date) {
    if (_getSakitIzin(emp.id, date) != null || _hasTimeOff(emp.id, date)) return;
    
    showDialog(
      context: context, 
      useRootNavigator: false,  // PENTING: Jangan pop ke root
      builder: (dialogContext) => AlertDialog(
        title: Text('Pilih Shift - ${emp.name}'),
        content: Column(mainAxisSize: MainAxisSize.min,
          children: [
            _shiftOption(emp, date, dialogContext, ShiftSlot.pagi(), Icons.wb_sunny, 'Pagi', '09:00 - 17:00'),
            _shiftOption(emp, date, dialogContext, ShiftSlot.siang(), Icons.wb_twilight, 'Siang', '12:00 - 20:00'),
            _shiftOption(emp, date, dialogContext, ShiftSlot.sore(), Icons.nights_stay, 'Sore', '14:00 - 22:00'),
            _shiftOption(emp, date, dialogContext, ShiftSlot.libur(), Icons.beach_access, 'Libur', 'Hari libur'),
          ],
        ),
      ),
    );
  }

  Widget _shiftOption(Employee emp, DateTime date, BuildContext dialogContext, ShiftSlot shift, IconData icon, String name, String time) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: shift.color.withOpacity(0.2),
        child: Icon(icon, color: shift.color, size: 18)),
      title: Text(name),
      subtitle: Text(time, style: TextStyle(fontSize: 12)),
      onTap: () { 
        _addShift(emp, date, shift); 
        Navigator.pop(dialogContext);  // PENTING: Gunakan dialogContext, bukan context
      },
    );
  }
}
