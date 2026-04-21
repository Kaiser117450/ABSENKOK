import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:absensi_enakko_flutter/core/supabase_client.dart';
import 'package:absensi_enakko_flutter/core/theme.dart';
import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/outlet_operating_mode.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';
import 'package:absensi_enakko_flutter/models/shift_schedule.dart';
import 'package:absensi_enakko_flutter/services/shift_role_service.dart';
import 'package:absensi_enakko_flutter/providers/app_provider.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/schedule_legend.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/schedule_summary_bar.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/schedule_table_view.dart';
import 'package:absensi_enakko_flutter/services/pdf_service.dart';
import 'package:absensi_enakko_flutter/services/schedule_policy_service.dart';
import 'package:absensi_enakko_flutter/services/schedule_sqlite_service.dart';

class ShiftSchedulerScreen extends ConsumerStatefulWidget {
  final String? outletId;
  final String? outletName;

  const ShiftSchedulerScreen({super.key, this.outletId, this.outletName});

  @override
  ConsumerState<ShiftSchedulerScreen> createState() =>
      _ShiftSchedulerScreenState();
}

class _ShiftSchedulerScreenState extends ConsumerState<ShiftSchedulerScreen> {
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;
  List<Employee> _employees = [];
  OutletSchedule? _currentSchedule;

  // Bulk assign state
  Set<String> _selectedEmployeeIds = {};
  bool _isBulkMode = false;
  String? _bulkSelectedRole;
  List<String> _dynamicRoles = [];

  // Data
  Map<String, Map<String, AttendanceType>> _sakitIzinMap = {};
  Map<String, List<DateTime>> _timeOffMap = {};
  Map<String, int> _leaveBalance = {};

  // Outlet operating mode (for role filtering)
  OutletOperatingMode _outletOperatingMode = OutletOperatingMode.normal;

  // Settings
  DateTime _startDate = _getStartOfWeek(DateTime.now());
  DateTime? _selectedDay;
  ShiftTemplate? _template;
  double _zoomScale = 1.0;

  List<String> get _availableBulkRoles {
    if (_dynamicRoles.isNotEmpty) return _dynamicRoles;
    // Hardcoded fallback for offline
    const baseRoles = [
      'Kasir',
      'Assambler',
      'Housekeeping',
      'Checker',
      'Ayam',
      'Kitchen'
    ];
    if (_outletOperatingMode == OutletOperatingMode.twentyFourHour) {
      return [...baseRoles, 'Kopi'];
    }
    return baseRoles;
  }

  List<ShiftBand> _availableShiftBands({bool includeLibur = true}) {
    final bands = <ShiftBand>[
      ShiftBand.pagi,
      ShiftBand.siang,
      ShiftBand.sore,
      if (_outletOperatingMode == OutletOperatingMode.twentyFourHour)
        ShiftBand.malam,
    ];
    if (includeLibur) {
      bands.add(ShiftBand.libur);
    }
    return bands;
  }

  ShiftTemplate _buildTemplateForOutlet(String outletId) {
    return ShiftTemplate.forOperatingMode(outletId, _outletOperatingMode);
  }

  bool _isBandEligibleForAutoGenerate(Employee employee, ShiftBand band) {
    if (band == ShiftBand.libur) {
      return false;
    }

    if (band == ShiftBand.sore &&
        employee.employmentContract != EmployeeContract.parttime) {
      return false;
    }

    return true;
  }

  List<ShiftBand> _autoAssignableBands(
      List<ShiftSlot> shiftSlots, Employee emp) {
    final bands = shiftSlots
        .map((slot) => slot.band)
        .where((band) => _isBandEligibleForAutoGenerate(emp, band))
        .toList(growable: false);
    if (bands.isNotEmpty) {
      return bands;
    }

    return shiftSlots
        .map((slot) => slot.band)
        .where((band) => band != ShiftBand.libur)
        .toList(growable: false);
  }

  IconData _iconForBand(ShiftBand band) {
    switch (band) {
      case ShiftBand.pagi:
        return Icons.wb_sunny;
      case ShiftBand.siang:
        return Icons.wb_twilight;
      case ShiftBand.sore:
        return Icons.wb_twilight_outlined;
      case ShiftBand.malam:
        return Icons.nights_stay;
      case ShiftBand.libur:
        return Icons.beach_access;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  static DateTime _getStartOfWeek(DateTime date) {
    // Normalisasi ke Senin 00:00:00
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  Future<void> _loadRoles() async {
    final modeStr = _outletOperatingMode == OutletOperatingMode.twentyFourHour
        ? 'TWENTY_FOUR_HOUR'
        : 'NORMAL';
    final roles =
        await ShiftRoleService.getRoleNames(outletOperatingMode: modeStr);
    if (mounted) setState(() => _dynamicRoles = roles);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final outletId = widget.outletId ?? ref.read(appProvider).managedOutletId;
      if (outletId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final empData = await SupabaseClientFactory.admin
          .from('employees')
          .select('*')
          .eq('home_outlet_id', outletId)
          .eq('is_active', true)
          .order('name');

      final allEmployees = (empData as List)
          .map((e) => Employee.fromJson(e as Map<String, dynamic>))
          .toList();

      // Exclude kepala toko / kepala gerai from schedule
      final loadedEmployees = allEmployees.where((emp) {
        final pos = (emp.position ?? '').toLowerCase().trim();
        return pos != 'kepala toko' && pos != 'kepala gerai';
      }).toList();

      // Load outlet operating mode for role filtering
      try {
        final outletData = await SupabaseClientFactory.admin
            .from('outlets')
            .select('operating_mode')
            .eq('id', outletId)
            .maybeSingle();
        if (outletData != null) {
          _outletOperatingMode = OutletOperatingMode.parse(
              outletData['operating_mode'] as String?);
        }
      } catch (e) {
        debugPrint('Error loading outlet mode: $e');
      }

      await _loadRoles();

      await _loadSakitIzinData(outletId, loadedEmployees);
      await _loadTimeOffRequests(outletId, loadedEmployees);
      await _loadCarryOverBalance(outletId, loadedEmployees);

      final endDate = _startDate.add(const Duration(days: 6));

      // SUPABASE-FIRST: try cloud, cache to SQLite, fallback to SQLite on error
      OutletSchedule? existingSchedule;
      try {
        existingSchedule = await _loadScheduleFromSupabase(
            outletId, _startDate, endDate, loadedEmployees);
        if (existingSchedule != null) {
          // Write-through: cache to SQLite for offline use
          await ScheduleSQLiteService.saveSchedule(existingSchedule);
          debugPrint(
              'Loaded schedule from Supabase, cached to SQLite: ${existingSchedule.entries.length} entries');
        }
      } catch (e) {
        debugPrint('Supabase fetch failed, falling back to SQLite: $e');
      }
      // Fallback to SQLite only if Supabase returned nothing or failed
      existingSchedule ??= await ScheduleSQLiteService.getSchedule(
          outletId, _startDate, endDate);

      setState(() {
        _employees = loadedEmployees;
        _currentSchedule = existingSchedule ??
            OutletSchedule(
              id: '${outletId}_${_startDate.millisecondsSinceEpoch}',
              outletId: outletId,
              startDate: _startDate,
              endDate: endDate,
              template: _buildTemplateForOutlet(outletId),
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

  Future<OutletSchedule?> _loadScheduleFromSupabase(String outletId,
      DateTime startDate, DateTime endDate, List<Employee> employees) async {
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

      debugPrint(
          'Loaded ${(entriesData as List).length} entries from Supabase');

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
          role: e['role'] as String?,
        );
      }).toList();

      return OutletSchedule(
        id: scheduleData['id'],
        outletId: outletId,
        startDate: DateTime.parse(scheduleData['start_date']),
        endDate: DateTime.parse(scheduleData['end_date']),
        template: _buildTemplateForOutlet(outletId),
        entries: entries,
        createdAt: DateTime.parse(scheduleData['created_at']),
      );
    } catch (e) {
      debugPrint('Error loading from Supabase: $e');
      return null;
    }
  }

  Future<void> _loadSakitIzinData(
      String outletId, List<Employee> employees) async {
    try {
      final endDate = _startDate.add(const Duration(days: 6));
      final logsData = await SupabaseClientFactory.admin
          .from('attendance_logs')
          .select('employee_id, type, scanned_at')
          .inFilter('employee_id', employees.map((e) => e.id).toList())
          .inFilter('type', ['sakit', 'izin'])
          .gte('scanned_at', _startDate.toIso8601String())
          .lte('scanned_at', endDate.toIso8601String());

      final Map<String, Map<String, AttendanceType>> tempMap = {};
      for (final log in logsData as List) {
        final empId = log['employee_id'] as String;
        final type = AttendanceTypeExt.fromString(log['type'] as String);
        final dateKey = DateFormat('yyyy-MM-dd')
            .format(DateTime.parse(log['scanned_at'] as String));
        tempMap[empId] ??= {};
        tempMap[empId]![dateKey] = type;
      }
      setState(() => _sakitIzinMap = tempMap);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _loadTimeOffRequests(
      String outletId, List<Employee> employees) async {
    try {
      final endDate = _startDate.add(const Duration(days: 6));
      final requestsData = await SupabaseClientFactory.admin
          .from('time_off_requests')
          .select('*')
          .eq('outlet_id', outletId)
          .eq('status', 'approved')
          .gte('request_date', _startDate.toIso8601String())
          .lte('request_date', endDate.toIso8601String());

      final Map<String, List<DateTime>> tempMap = {};
      for (final req in requestsData as List) {
        final empId = req['employee_id'] as String;
        tempMap[empId] ??= [];
        tempMap[empId]!.add(DateTime.parse(req['request_date'] as String));
      }
      setState(() => _timeOffMap = tempMap);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  AttendanceType? _getSakitIzin(String empId, DateTime date) {
    return _sakitIzinMap[empId]?[DateFormat('yyyy-MM-dd').format(date)];
  }

  bool _hasTimeOff(String empId, DateTime date) {
    return (_timeOffMap[empId] ?? []).any((d) =>
        d.year == date.year && d.month == date.month && d.day == date.day);
  }

  /// Load carry over balance dari minggu lalu
  Future<void> _loadCarryOverBalance(
      String outletId, List<Employee> employees) async {
    try {
      final prevWeekEnd = _startDate.subtract(const Duration(days: 1));
      final prevWeekStart = prevWeekEnd.subtract(const Duration(days: 6));

      // Load schedule minggu lalu
      final prevSchedule = await ScheduleSQLiteService.getSchedule(
          outletId, prevWeekStart, prevWeekEnd);

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
                (e.shift.name.toLowerCase().contains('libur') || e.isDayOff));
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

  ShiftSlot _buildShiftForEmployee(
    Employee emp,
    ShiftBand band, {
    int? requiredWorkMinutes,
  }) {
    if (band == ShiftBand.libur) {
      return ShiftSlot.libur();
    }

    return ShiftSlot.fromBand(
      band: band,
      contract: emp.employmentContract,
      requiredWorkMinutes: requiredWorkMinutes,
    );
  }

  String _formatRequiredHours(int minutes) => '${minutes ~/ 60}j';

  String _formatClock(int hour, int minute) {
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatLateCutoff(ShiftSlot shift) {
    if (shift.band == ShiftBand.libur) {
      return '-';
    }
    return _formatClock(shift.lateCutoffHour, shift.lateCutoffMinute);
  }

  String _formatBreakFirstDeadline(ShiftSlot shift) {
    if (shift.band == ShiftBand.libur) {
      return '-';
    }
    return _formatClock(
      shift.breakFirstDeadlineHour,
      shift.breakFirstDeadlineMinute,
    );
  }

  void _replaceEntryForDay(Employee emp, DateTime date, ShiftSlot shift,
      {String? role}) {
    _currentSchedule!.entries.removeWhere((e) =>
        e.employeeId == emp.id &&
        e.date.year == date.year &&
        e.date.month == date.month &&
        e.date.day == date.day);

    _currentSchedule!.entries.add(
      ScheduleEntry.fromEmployee(
        id: '${DateTime.now().millisecondsSinceEpoch}_${emp.id}_${date.day}',
        date: date,
        employee: emp,
        shift: shift,
        isDayOff: shift.band == ShiftBand.libur,
        role: role,
      ),
    );
  }

  void _addShift(Employee emp, DateTime date, ShiftBand band,
      {int? requiredWorkMinutes, String? role}) {
    final sakitIzin = _getSakitIzin(emp.id, date);
    if (sakitIzin != null) {
      _showError('${emp.name} sedang ${sakitIzin.label}');
      return;
    }
    final shift = _buildShiftForEmployee(
      emp,
      band,
      requiredWorkMinutes: requiredWorkMinutes,
    );

    setState(() {
      _replaceEntryForDay(emp, date, shift, role: role);
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

  void _bulkAssignBand(ShiftBand band) {
    if (_selectedEmployeeIds.isEmpty || _currentSchedule == null) return;
    final days = List.generate(7, (i) => _startDate.add(Duration(days: i)));
    final selectedEmps =
        _employees.where((e) => _selectedEmployeeIds.contains(e.id)).toList();

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
              e.date.year == day.year &&
              e.date.month == day.month &&
              e.date.day == day.day);

          _replaceEntryForDay(emp, day, _buildShiftForEmployee(emp, band),
              role: _bulkSelectedRole);
        }
      }
      _hasUnsavedChanges = true;
      _bulkSelectedRole = null;
    });

    _showSuccess('${band.label} diterapkan ke ${selectedEmps.length} karyawan');
  }

  String _buildBulkRequiredHoursSummary(
      ShiftBand band, List<Employee> employees) {
    if (band == ShiftBand.libur) {
      return 'Libur';
    }

    final hasFulltime =
        employees.any((emp) => emp.employmentContract.dbValue == 'FULLTIME');
    final hasParttime =
        employees.any((emp) => emp.employmentContract.dbValue == 'PARTTIME');

    if (hasFulltime && hasParttime) {
      return 'FULLTIME 10j • PARTTIME 8j';
    }
    if (hasParttime) {
      return 'PARTTIME 8j';
    }
    return 'FULLTIME 10j';
  }

  String _buildBulkBreakFirstSummary(ShiftBand band, List<Employee> employees) {
    if (band == ShiftBand.libur) {
      return 'Tidak berlaku';
    }

    final fulltimeShift = ShiftSlot.fromBand(
      band: band,
      contract: EmployeeContract.fulltime,
    );
    final parttimeShift = ShiftSlot.fromBand(
      band: band,
      contract: EmployeeContract.parttime,
    );

    final hasFulltime =
        employees.any((emp) => emp.employmentContract.dbValue == 'FULLTIME');
    final hasParttime =
        employees.any((emp) => emp.employmentContract.dbValue == 'PARTTIME');

    if (hasFulltime && hasParttime) {
      return 'FULLTIME sampai ${_formatBreakFirstDeadline(fulltimeShift)} • PARTTIME sampai ${_formatBreakFirstDeadline(parttimeShift)}';
    }
    if (hasParttime) {
      return 'PARTTIME sampai ${_formatBreakFirstDeadline(parttimeShift)}';
    }
    return 'FULLTIME sampai ${_formatBreakFirstDeadline(fulltimeShift)}';
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBulkReviewSheet(ShiftBand band) {
    final selectedEmployees =
        _employees.where((e) => _selectedEmployeeIds.contains(e.id)).toList();
    if (selectedEmployees.isEmpty) {
      return;
    }

    final policyShift = band == ShiftBand.libur
        ? ShiftSlot.libur()
        : ShiftSlot.fromBand(band: band);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tinjau Penugasan',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Periksa shift, jam wajib, dan batas telat sebelum konfirmasi.',
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF475569), height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '${selectedEmployees.length} karyawan • ${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_startDate.add(const Duration(days: 6)))}',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              _buildReviewRow('Shift', policyShift.band.label),
              _buildReviewRow(
                'Jam wajib',
                _buildBulkRequiredHoursSummary(band, selectedEmployees),
              ),
              _buildReviewRow(
                'Batas telat',
                band == ShiftBand.libur
                    ? 'Tidak berlaku'
                    : _formatLateCutoff(policyShift),
              ),
              _buildReviewRow(
                'Break-first',
                _buildBulkBreakFirstSummary(band, selectedEmployees),
              ),
              const SizedBox(height: 12),
              const Text('Role (Opsional)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155))),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (sheetCtx, setSheetState) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: const Text('Tidak ada'),
                        selected: _bulkSelectedRole == null,
                        labelStyle: TextStyle(
                          color: _bulkSelectedRole == null
                              ? Colors.white
                              : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        onSelected: (_) {
                          setSheetState(() {});
                          setState(() => _bulkSelectedRole = null);
                        },
                      ),
                      ..._availableBulkRoles.map((role) => ChoiceChip(
                            label: Text(role),
                            selected: _bulkSelectedRole == role,
                            labelStyle: TextStyle(
                              color: _bulkSelectedRole == role
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            onSelected: (_) {
                              setSheetState(() {});
                              setState(() => _bulkSelectedRole = role);
                            },
                          )),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _bulkAssignBand(band);
                  },
                  child: const Text('Konfirmasi Penugasan'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                'Terapkan shift untuk ${_selectedEmployeeIds.length} karyawan',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            ..._availableShiftBands().map((band) {
              final shift = band == ShiftBand.libur
                  ? ShiftSlot.libur()
                  : ShiftSlot.fromBand(band: band);
              final subtitle = band == ShiftBand.libur
                  ? 'Hari libur'
                  : '${_formatLateCutoff(shift)} batas telat • jam wajib ikut kontrak';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: shift.color,
                  radius: 16,
                  child: Icon(
                    _iconForBand(band),
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                title: Text(band.label),
                subtitle: Text(subtitle),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBulkReviewSheet(band);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAutoSchedule() async {
    if (_employees.isEmpty) return;
    final outletId =
        widget.outletId ?? ref.read(appProvider).managedOutletId ?? '';
    if (outletId.isEmpty) {
      return;
    }
    _template = _buildTemplateForOutlet(outletId);

    setState(() => _isLoading = true);

    try {
      final days = List.generate(7, (i) => _startDate.add(Duration(days: i)));
      final newEntries = <ScheduleEntry>[];

      // Per-employee leave days map (computed in pass 1)
      final empLeaveDays = <String, List<DateTime>>{};

      // Pass 1: Compute leave days for each employee
      for (final emp in _employees) {
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
          final availableDays =
              days.where((d) => !leaveDays.contains(d)).toList()..shuffle();
          for (int i = 0; i < needLeave && i < availableDays.length; i++) {
            leaveDays.add(availableDays[i]);
          }
        }

        // Update carry over untuk minggu depan
        final assignedLeave = leaveDays.length;
        final totalRequired = 1 + carryOver;
        final remainingLeave =
            totalRequired > assignedLeave ? totalRequired - assignedLeave : 0;
        _leaveBalance[emp.id] = remainingLeave;

        empLeaveDays[emp.id] = leaveDays;
      }

      // Pass 2: Generate entries with pagi cap (max 2 per day)
      const maxPagiPerDay = 2;
      final pagiCountPerDay = <int, int>{}; // dayIndex → count
      final shiftSlots = _template!.slots;

      for (final emp in _employees) {
        final leaveDays = empLeaveDays[emp.id] ?? [];
        final eligibleBands = _autoAssignableBands(shiftSlots, emp);

        for (final day in days) {
          if (leaveDays.contains(day)) {
            newEntries.add(ScheduleEntry.fromEmployee(
              id: 'libur_${emp.id}_${day.day}',
              date: day,
              employee: emp,
              shift: ShiftSlot.libur(),
            ));
          } else if (_getSakitIzin(emp.id, day) == null &&
              !_hasTimeOff(emp.id, day)) {
            final dayIdx = days.indexOf(day);
            final baseIndex =
                (_employees.indexOf(emp) + dayIdx) % eligibleBands.length;
            var band = eligibleBands[baseIndex];

            // Cap pagi at maxPagiPerDay per day
            if (band == ShiftBand.pagi) {
              final currentPagi = pagiCountPerDay[dayIdx] ?? 0;
              if (currentPagi >= maxPagiPerDay) {
                // Redistribute to next available non-pagi slot
                for (int offset = 1; offset < eligibleBands.length; offset++) {
                  final altBand = eligibleBands[
                      (baseIndex + offset) % eligibleBands.length];
                  if (altBand != ShiftBand.pagi) {
                    band = altBand;
                    break;
                  }
                }
              } else {
                pagiCountPerDay[dayIdx] = currentPagi + 1;
              }
            }

            final shift = _buildShiftForEmployee(emp, band);
            newEntries.add(ScheduleEntry.fromEmployee(
              id: 'shift_${emp.id}_${day.day}',
              date: day,
              employee: emp,
              shift: shift,
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
      _showSuccess(
          'Jadwal ${_template!.name} berhasil dibuat. Shift sore diprioritaskan untuk PARTTIME dan mode gerai dipakai otomatis.');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: $e');
    }
  }

  void _showTimeOffDialog(Employee emp) {
    DateTime? selectedDate;
    showDialog(
      context: context,
      useRootNavigator: false, // PENTING
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Request Libur - ${emp.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pilih hari libur:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (i) {
                  final date = _startDate.add(Duration(days: i));
                  final dayName = [
                    'Sen',
                    'Sel',
                    'Rab',
                    'Kam',
                    'Jum',
                    'Sab',
                    'Min'
                  ][date.weekday - 1];
                  final isSelected = selectedDate == date;
                  return ChoiceChip(
                    label: Text(
                      '$dayName ${date.day}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.grey.shade200,
                    onSelected: (_) =>
                        setDialogState(() => selectedDate = date),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: selectedDate == null
                  ? null
                  : () async {
                      try {
                        final outletId = widget.outletId ??
                            ref.read(appProvider).managedOutletId;
                        if (outletId == null) throw Exception('No outlet');

                        // Format date untuk PostgreSQL (YYYY-MM-DD)
                        final dateStr =
                            selectedDate!.toIso8601String().split('T')[0];

                        debugPrint(
                            'Saving time_off: emp=${emp.id}, outlet=$outletId, date=$dateStr');

                        // Insert tanpa ID (Supabase akan generate UUID otomatis)
                        await SupabaseClientFactory.admin
                            .from('time_off_requests')
                            .insert({
                          'employee_id': emp.id,
                          'outlet_id': outletId,
                          'request_date': dateStr,
                          'reason': 'Request libur',
                          'status': 'approved',
                        });

                        if (!dialogContext.mounted) {
                          return;
                        }

                        Navigator.pop(dialogContext);
                        _showSuccess('Request libur disimpan');
                        _loadData();
                      } catch (e) {
                        debugPrint('Time off error: $e');
                        if (!dialogContext.mounted) {
                          return;
                        }
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
        final startDateStr =
            _currentSchedule!.startDate.toIso8601String().split('T')[0];
        final endDateStr =
            _currentSchedule!.endDate.toIso8601String().split('T')[0];

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
        final result = await SupabaseClientFactory.admin
            .from('schedules')
            .insert({
              'outlet_id': _currentSchedule!.outletId,
              'start_date': startDateStr,
              'end_date': endDateStr,
              'is_active': true,
            })
            .select('id')
            .single();

        final newScheduleId = result['id'];
        debugPrint('Created new schedule: $newScheduleId');

        // 1c. Bulk Insert data ke schedule_entries dengan scheduleId baru
        final entriesData = _currentSchedule!.entries
            .map((entry) => {
                  'schedule_id': newScheduleId,
                  'date': entry.date.toIso8601String().split('T')[0],
                  'employee_id': entry.employeeId,
                  'custom_name': entry.customName,
                  'display_name': entry.displayName,
                  'is_custom_name': entry.isCustomName,
                  'shift_slot': entry.shift.toJson(),
                  'is_day_off': entry.isDayOff,
                  'notes': entry.notes,
                  'role': entry.role,
                })
            .toList();

        if (entriesData.isNotEmpty) {
          await SupabaseClientFactory.admin
              .from('schedule_entries')
              .insert(entriesData);
          debugPrint(
              'Bulk inserted ${entriesData.length} entries for $newScheduleId');
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

  // ===========================================================================
  // CLEAR SCHEDULE
  // ===========================================================================

  void _clearSchedule() {
    if (_currentSchedule == null) return;
    final bool isSelectiveDelete =
        _isBulkMode && _selectedEmployeeIds.isNotEmpty;
    final int count = _selectedEmployeeIds.length;
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: Text(isSelectiveDelete
            ? 'Hapus Jadwal $count Karyawan?'
            : 'Hapus Semua Jadwal?'),
        content: Text(isSelectiveDelete
            ? 'Jadwal $count karyawan terpilih minggu ini akan dihapus. Anda masih perlu menyimpan untuk sync ke cloud.'
            : 'Semua jadwal minggu ini akan dihapus. Anda masih perlu menyimpan untuk sync ke cloud.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                if (isSelectiveDelete) {
                  _currentSchedule!.entries.removeWhere(
                      (e) => _selectedEmployeeIds.contains(e.employeeId));
                  _selectedEmployeeIds.clear();
                } else {
                  _currentSchedule!.entries.clear();
                }
                _hasUnsavedChanges = true;
              });
              _showSuccess(isSelectiveDelete
                  ? 'Jadwal $count karyawan dihapus'
                  : 'Jadwal dibersihkan');
            },
            child: Text(isSelectiveDelete ? 'Hapus Terpilih' : 'Hapus Semua',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PDF EXPORT
  // ===========================================================================

  Future<void> _exportToPdf() async {
    if (_currentSchedule == null) return;
    setState(() => _isLoading = true);
    try {
      // Buat salinan entries yang memasukkan status sakit/izin secara eksplisit
      // supaya PDF bisa merendernya.
      final days = List.generate(
        _currentSchedule!.endDate
                .difference(_currentSchedule!.startDate)
                .inDays +
            1,
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
  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  // ===========================================================================
  // BUILD METHODS
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor:
            _isBulkMode ? Colors.orange.shade700 : AppColors.primary,
        leading: _isBulkMode
            ? IconButton(
                icon: const Icon(Icons.close), onPressed: _toggleBulkMode)
            : null,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_isBulkMode ? 'Penugasan Massal' : 'Jadwal Shift',
              style: const TextStyle(fontSize: 18)),
          Text(
            _isBulkMode
                ? '${_selectedEmployeeIds.length} karyawan dipilih'
                : (widget.outletName ?? 'Unknown'),
            style: const TextStyle(fontSize: 12),
          ),
        ]),
        actions: [
          IconButton(
              icon: const Icon(Icons.picture_as_pdf), onPressed: _exportToPdf),
          Stack(
            children: [
              IconButton(
                  icon: const Icon(Icons.save), onPressed: _saveSchedule),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              _buildHeader(),
              const ScheduleLegend(),
              ScheduleSummaryBar(
                entries: _currentSchedule?.entries ?? [],
                employees: _employees,
                startDate: _startDate,
                sakitIzinMap: _sakitIzinMap,
                timeOffMap: _timeOffMap,
                selectedDay: _selectedDay,
              ),
              Expanded(
                child: ScheduleTableView(
                  employees: _employees,
                  currentSchedule: _currentSchedule,
                  startDate: _startDate,
                  sakitIzinMap: _sakitIzinMap,
                  timeOffMap: _timeOffMap,
                  leaveBalance: _leaveBalance,
                  isBulkMode: _isBulkMode,
                  selectedEmployeeIds: _selectedEmployeeIds,
                  zoomScale: _zoomScale,
                  onCellTap: (emp, date) => _showShiftPicker(emp, date),
                  onEntryTap: _showAssignedEntryEditor,
                  onTimeOffTap: (emp) => _showTimeOffDialog(emp),
                  onToggleSelectAll: _toggleSelectAll,
                  onToggleEmployee: (empId) {
                    setState(() {
                      if (_selectedEmployeeIds.contains(empId)) {
                        _selectedEmployeeIds.remove(empId);
                      } else {
                        _selectedEmployeeIds.add(empId);
                      }
                    });
                  },
                  getSakitIzin: _getSakitIzin,
                  getHasTimeOff: _hasTimeOff,
                  selectedDay: _selectedDay,
                  onDayHeaderTap: (date) {
                    setState(() {
                      _selectedDay = (_selectedDay != null &&
                              _selectedDay!.year == date.year &&
                              _selectedDay!.month == date.month &&
                              _selectedDay!.day == date.day)
                          ? null
                          : date;
                    });
                  },
                ),
              ),
            ]),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom in mini button
          SizedBox(
            width: 32,
            height: 32,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => setState(
                    () => _zoomScale = (_zoomScale + 0.1).clamp(0.5, 2.0)),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Zoom out mini button
          SizedBox(
            width: 32,
            height: 32,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => setState(
                    () => _zoomScale = (_zoomScale - 0.1).clamp(0.5, 2.0)),
                child: const Icon(Icons.remove, color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Clear schedule FAB
          FloatingActionButton.small(
            heroTag: 'clear',
            onPressed: _clearSchedule,
            backgroundColor: Colors.red.shade400,
            child:
                const Icon(Icons.delete_sweep, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          // Bulk assign FAB
          FloatingActionButton.small(
            heroTag: 'bulk',
            onPressed: _isBulkMode ? _showBulkAssignSheet : _toggleBulkMode,
            backgroundColor: _isBulkMode ? Colors.orange : Colors.blueGrey,
            child: Icon(
              _isBulkMode ? Icons.assignment : Icons.checklist,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          // Auto-generate FAB
          FloatingActionButton.small(
            heroTag: 'auto',
            onPressed: _generateAutoSchedule,
            backgroundColor: AppColors.primary,
            child:
                const Icon(Icons.auto_fix_high, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: Colors.white,
      child: Column(
        children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 28),
              onPressed: () {
                setState(() {
                  _startDate = _startDate.subtract(const Duration(days: 7));
                  _selectedDay = null;
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
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Shift utama, jam wajib, dan batas telat minggu ini',
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
                  _selectedDay = null;
                });
                _loadData();
              },
            ),
          ]),
        ],
      ),
    );
  }

  void _showAssignedEntryEditor(ScheduleEntry entry) {
    final emp = _employees.firstWhere(
      (employee) => employee.id == entry.employeeId,
      orElse: () => Employee(
        id: entry.employeeId ?? '',
        name: entry.displayName,
        isActive: true,
        createdAt: '',
        updatedAt: '',
      ),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ScheduleAssignedEntryEditorSheet(
        employee: emp,
        entry: entry,
        outletOperatingMode: _outletOperatingMode,
        dynamicRoles: _dynamicRoles.isNotEmpty ? _dynamicRoles : null,
        onDelete: () {
          _removeEntry(entry.id);
          Navigator.pop(sheetContext);
        },
        onSave: (selection) {
          _addShift(
            emp,
            entry.date,
            selection.band,
            requiredWorkMinutes: selection.requiredWorkMinutes,
            role: selection.role,
          );
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  void _showShiftPicker(Employee emp, DateTime date) {
    if (_getSakitIzin(emp.id, date) != null || _hasTimeOff(emp.id, date)) {
      return;
    }

    showDialog(
      context: context,
      useRootNavigator: false, // PENTING: Jangan pop ke root
      builder: (dialogContext) => AlertDialog(
        title: Text('Pilih Shift - ${emp.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _availableShiftBands()
              .map(
                (band) => _shiftOption(
                  emp,
                  date,
                  dialogContext,
                  band,
                  _iconForBand(band),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _shiftOption(
    Employee emp,
    DateTime date,
    BuildContext dialogContext,
    ShiftBand band,
    IconData icon,
  ) {
    final shift = _buildShiftForEmployee(emp, band);
    final subtitle = band == ShiftBand.libur
        ? 'Hari libur'
        : 'Jam wajib ${_formatRequiredHours(shift.requiredWorkMinutes)} • Batas telat ${_formatLateCutoff(shift)}';

    return ListTile(
      leading: CircleAvatar(
          backgroundColor: shift.color.withValues(alpha: 0.2),
          child: Icon(icon, color: shift.color, size: 18)),
      title: Text(band.label),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: () {
        _addShift(emp, date, band);
        Navigator.pop(
            dialogContext); // PENTING: Gunakan dialogContext, bukan context
      },
    );
  }
}

const Color _scheduleChipLabelColor = Color(0xFF111827);
const Color _scheduleChipSelectedColor = Color(0xFFE2E8F0);
const Color _scheduleChipBackgroundColor = Color(0xFFF8FAFC);
const Color _scheduleChipDisabledColor = Color(0xFFE5E7EB);
const BorderSide _scheduleChipBorderSide = BorderSide(color: Color(0xFFCBD5E1));

ShiftSlot _buildPreviewShiftForEmployee(
  Employee employee,
  ShiftBand band, {
  int? requiredWorkMinutes,
}) {
  if (band == ShiftBand.libur) {
    return ShiftSlot.libur();
  }

  return ShiftSlot.fromBand(
    band: band,
    contract: employee.employmentContract,
    requiredWorkMinutes: requiredWorkMinutes,
  );
}

String _formatRequiredHoursLabel(int minutes) => '${minutes ~/ 60}j';

String _formatScheduleClock(int hour, int minute) {
  final hh = hour.toString().padLeft(2, '0');
  final mm = minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _formatPreviewLateCutoff(ShiftSlot shift) {
  if (shift.band == ShiftBand.libur) {
    return '-';
  }
  return _formatScheduleClock(shift.lateCutoffHour, shift.lateCutoffMinute);
}

String _formatPreviewBreakFirst(ShiftSlot shift) {
  if (shift.band == ShiftBand.libur) {
    return 'Tidak berlaku';
  }
  return 'sampai ${_formatScheduleClock(shift.breakFirstDeadlineHour, shift.breakFirstDeadlineMinute)} (${shift.requiredWorkMinutes < SchedulePolicyService.fulltimeRequiredWorkMinutes ? 'PARTTIME' : 'FULLTIME'})';
}

class ScheduleEntryEditorSelection {
  const ScheduleEntryEditorSelection({
    required this.band,
    required this.requiredWorkMinutes,
    this.role,
  });

  final ShiftBand band;
  final int? requiredWorkMinutes;
  final String? role;
}

class ScheduleAssignedEntryEditorSheet extends StatefulWidget {
  const ScheduleAssignedEntryEditorSheet({
    super.key,
    required this.employee,
    required this.entry,
    required this.onDelete,
    required this.onSave,
    this.outletOperatingMode = OutletOperatingMode.normal,
    this.dynamicRoles,
  });

  final Employee employee;
  final ScheduleEntry entry;
  final VoidCallback onDelete;
  final ValueChanged<ScheduleEntryEditorSelection> onSave;
  final OutletOperatingMode outletOperatingMode;
  final List<String>? dynamicRoles;

  @override
  State<ScheduleAssignedEntryEditorSheet> createState() =>
      _ScheduleAssignedEntryEditorSheetState();
}

class _ScheduleAssignedEntryEditorSheetState
    extends State<ScheduleAssignedEntryEditorSheet> {
  static const List<int> _workMinuteOptions = <int>[480, 540, 600, 660, 720];
  static const List<String> _baseRoles = [
    'Kasir',
    'Assambler',
    'Housekeeping',
    'Checker',
    'Ayam',
    'Kitchen',
  ];

  late ShiftBand _selectedBand;
  late int _selectedMinutes;
  String? _selectedRole;

  List<String> get _availableEditorRoles {
    if (widget.dynamicRoles != null && widget.dynamicRoles!.isNotEmpty) {
      return widget.dynamicRoles!;
    }
    // Hardcoded fallback for offline
    if (widget.outletOperatingMode == OutletOperatingMode.twentyFourHour) {
      return [..._baseRoles, 'Kopi'];
    }
    return _baseRoles;
  }

  @override
  void initState() {
    super.initState();
    _selectedBand = widget.entry.shift.band;
    _selectedMinutes = widget.entry.shift.requiredWorkMinutes == 0
        ? SchedulePolicyService.defaultRequiredWorkMinutes(
            widget.employee.employmentContract,
          )
        : widget.entry.shift.requiredWorkMinutes;
    _selectedRole = widget.entry.role;
  }

  @override
  Widget build(BuildContext context) {
    final availableBands = <ShiftBand>[
      ShiftBand.pagi,
      ShiftBand.siang,
      ShiftBand.sore,
      if (widget.outletOperatingMode == OutletOperatingMode.twentyFourHour)
        ShiftBand.malam,
      ShiftBand.libur,
    ];
    final previewShift = _buildPreviewShiftForEmployee(
      widget.employee,
      _selectedBand,
      requiredWorkMinutes:
          _selectedBand == ShiftBand.libur ? null : _selectedMinutes,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Atur ${widget.employee.name}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableBands.map((band) {
                return _buildStyledChoiceChip(
                  key: ValueKey<String>('schedule-band-${band.storageValue}'),
                  label: band.label,
                  selected: _selectedBand == band,
                  onSelected: (_) {
                    setState(() {
                      _selectedBand = band;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Jam wajib',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _workMinuteOptions.map((minutes) {
                return _buildStyledChoiceChip(
                  key: ValueKey<String>('schedule-hours-$minutes'),
                  label: _formatRequiredHoursLabel(minutes),
                  selected: _selectedMinutes == minutes,
                  enabled: _selectedBand != ShiftBand.libur,
                  onSelected: (_) {
                    setState(() {
                      _selectedMinutes = minutes;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Posisi (opsional)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _scheduleChipBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRole,
                  hint: const Text('— Tidak ada —',
                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                  isExpanded: true,
                  isDense: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('— Tidak ada —',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF94A3B8))),
                    ),
                    ..._availableEditorRoles.map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(role),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedRole = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildReviewRow('Shift', previewShift.band.label),
            _buildReviewRow(
              'Jam wajib',
              previewShift.band == ShiftBand.libur
                  ? 'Libur'
                  : _formatRequiredHoursLabel(previewShift.requiredWorkMinutes),
            ),
            _buildReviewRow(
                'Batas telat', _formatPreviewLateCutoff(previewShift)),
            _buildReviewRow(
                'Break-first', _formatPreviewBreakFirst(previewShift)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onSave(
                        ScheduleEntryEditorSelection(
                          band: _selectedBand,
                          requiredWorkMinutes: _selectedBand == ShiftBand.libur
                              ? null
                              : _selectedMinutes,
                          role: _selectedRole,
                        ),
                      );
                    },
                    child: const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ChoiceChip _buildStyledChoiceChip({
    required Key key,
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
    bool enabled = true,
  }) {
    return ChoiceChip(
      key: key,
      label: Text(label),
      labelStyle: const TextStyle(
        color: _scheduleChipLabelColor,
        fontWeight: FontWeight.w700,
      ),
      selected: selected,
      onSelected: enabled ? onSelected : null,
      backgroundColor: _scheduleChipBackgroundColor,
      selectedColor: _scheduleChipSelectedColor,
      disabledColor: _scheduleChipDisabledColor,
      side: _scheduleChipBorderSide,
      showCheckmark: false,
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Role Picker Sheet — REMOVED (roles now assigned per schedule entry)
// ---------------------------------------------------------------------------
