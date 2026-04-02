import 'dart:math';
import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../models/shift_schedule.dart';
import '../models/time_off_request.dart';

/// Algoritma untuk generate jadwal shift otomatis
class ScheduleGenerator {
  /// Generate jadwal dengan algoritma Round-Robin yang fair
  /// 
  /// Parameters:
  /// - startDate: Tanggal mulai periode
  /// - endDate: Tanggal akhir periode
  /// - template: Template shift (Pagi/Sore/Malam)
  /// - employees: List karyawan yang tersedia
  /// - timeOffRequests: List request libur yang sudah di-approve
  /// - minStaffPerShift: Minimal karyawan per shift (default 2)
  /// - maxDaysPerWeek: Maksimal hari kerja per minggu per karyawan (default 6)
  static List<ScheduleEntry> generate({
    required DateTime startDate,
    required DateTime endDate,
    required ShiftTemplate template,
    required List<Employee> employees,
    required List<TimeOffRequest> timeOffRequests,
    int minStaffPerShift = 2,
    int maxDaysPerWeek = 6,
  }) {
    final entries = <ScheduleEntry>[];
    final random = Random();
    
    // 1. Buat map request libur: {employeeId: Set<tanggal>}
    final dayOffMap = <String, Set<DateTime>>{};
    for (final req in timeOffRequests.where((r) => r.status == TimeOffStatus.approved)) {
      dayOffMap.putIfAbsent(req.employeeId, () => <DateTime>{}).add(
        DateTime(req.requestDate.year, req.requestDate.month, req.requestDate.day),
      );
    }

    // 2. Hitung total hari dan shift
    var currentDate = startDate;
    final totalDays = endDate.difference(startDate).inDays + 1;
    final totalShifts = totalDays * template.slots.length;
    final totalSlotsNeeded = totalShifts * minStaffPerShift;

    // 3. Cek jika understaffed
    final availableManDays = employees.length * maxDaysPerWeek * (template.slots.length > 1 ? 1 : 2);
    if (availableManDays < totalSlotsNeeded) {
      // Warning: akan ada slot yang kosong (OPEN)
      debugPrint('[ScheduleGenerator] WARNING: Understaffed! Need $totalSlotsNeeded slots, have $availableManDays');
    }

    // 4. Track hari kerja per karyawan
    final workDaysCount = <String, int>{};
    for (final emp in employees) {
      workDaysCount[emp.id] = 0;
    }

    // 5. Algoritma: Untuk setiap hari, isi setiap shift
    while (!currentDate.isAfter(endDate)) {
      final dateKey = DateTime(currentDate.year, currentDate.month, currentDate.day);
      
      for (final shift in template.slots) {
        // Cari karyawan yang available untuk shift ini
        final availableEmployees = employees.where((emp) {
          // Cek jika sedang request libur
          final isDayOff = dayOffMap[emp.id]?.contains(dateKey) ?? false;
          if (isDayOff) return false;
          
          // Cek jika sudah melebihi max hari kerja
          final currentWorkDays = workDaysCount[emp.id] ?? 0;
          if (currentWorkDays >= maxDaysPerWeek * (totalDays / 7).ceil()) return false;
          
          // Cek jika sudah di-assign di shift lain di hari yang sama
          final alreadyAssignedToday = entries.any((e) =>
              e.date.year == dateKey.year &&
              e.date.month == dateKey.month &&
              e.date.day == dateKey.day &&
              e.employeeId == emp.id);
          if (alreadyAssignedToday) return false;
          
          return true;
        }).toList();

        // Shuffle untuk distribusi yang lebih adil
        availableEmployees.shuffle(random);

        // Isi slot
        var filled = 0;
        for (var i = 0; i < availableEmployees.length && filled < minStaffPerShift; i++) {
          final emp = availableEmployees[i];
          
          entries.add(ScheduleEntry.fromEmployee(
            id: '${dateKey.millisecondsSinceEpoch}_${shift.name}_$filled',
            date: currentDate,
            employee: emp,
            shift: shift,
          ));
          
          workDaysCount[emp.id] = (workDaysCount[emp.id] ?? 0) + 1;
          filled++;
        }

        // Jika masih kurang, isi dengan OPEN
        while (filled < minStaffPerShift) {
          entries.add(ScheduleEntry.customName(
            id: '${dateKey.millisecondsSinceEpoch}_${shift.name}_open_$filled',
            date: currentDate,
            name: 'OPEN',
            shift: shift,
          ));
          filled++;
        }
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return entries;
  }

  /// Generate jadwal mingguan (convenience method)
  static List<ScheduleEntry> generateWeekly({
    required DateTime weekStart, // Senin
    required ShiftTemplate template,
    required List<Employee> employees,
    required List<TimeOffRequest> timeOffRequests,
    int minStaffPerShift = 2,
  }) {
    return generate(
      startDate: weekStart,
      endDate: weekStart.add(const Duration(days: 6)),
      template: template,
      employees: employees,
      timeOffRequests: timeOffRequests,
      minStaffPerShift: minStaffPerShift,
    );
  }

  /// Generate jadwal bulanan (convenience method)
  static List<ScheduleEntry> generateMonthly({
    required DateTime monthStart,
    required ShiftTemplate template,
    required List<Employee> employees,
    required List<TimeOffRequest> timeOffRequests,
    int minStaffPerShift = 2,
  }) {
    final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0);
    return generate(
      startDate: monthStart,
      endDate: lastDay,
      template: template,
      employees: employees,
      timeOffRequests: timeOffRequests,
      minStaffPerShift: minStaffPerShift,
    );
  }

  /// Balance ulang jadwal untuk memastikan fairness
  static List<ScheduleEntry> balanceSchedule(
    List<ScheduleEntry> entries,
    List<Employee> employees,
    int maxDaysPerWeek,
  ) {
    // Hitung jumlah hari kerja per karyawan
    final workDays = <String, int>{};
    for (final entry in entries.where((e) => e.employeeId != null)) {
      workDays[entry.employeeId!] = (workDays[entry.employeeId!] ?? 0) + 1;
    }

    // Cari karyawan yang kelebihan dan kekurangan
    // TODO: Implementasi algoritma balancing yang lebih canggih
    // Untuk sekarang, return entries as-is
    return entries;
  }

  /// Analisis jadwal untuk statistik
  static ScheduleAnalysis analyze(List<ScheduleEntry> entries, List<Employee> employees) {
    final totalShifts = entries.where((e) => !e.isDayOff).length;
    final openSlots = entries.where((e) => e.isCustomName && e.displayName == 'OPEN').length;
    final filledSlots = totalShifts - openSlots;
    
    final workDaysPerEmployee = <String, int>{};
    for (final entry in entries.where((e) => e.employeeId != null)) {
      workDaysPerEmployee[entry.employeeId!] = (workDaysPerEmployee[entry.employeeId!] ?? 0) + 1;
    }

    final maxWorkDays = workDaysPerEmployee.values.isEmpty 
        ? 0 
        : workDaysPerEmployee.values.reduce((a, b) => a > b ? a : b);
    final minWorkDays = workDaysPerEmployee.values.isEmpty 
        ? 0 
        : workDaysPerEmployee.values.reduce((a, b) => a < b ? a : b);

    return ScheduleAnalysis(
      totalShifts: totalShifts,
      filledSlots: filledSlots,
      openSlots: openSlots,
      fillRate: totalShifts > 0 ? filledSlots / totalShifts : 0,
      maxWorkDays: maxWorkDays,
      minWorkDays: minWorkDays,
      avgWorkDays: workDaysPerEmployee.values.isEmpty 
          ? 0 
          : workDaysPerEmployee.values.reduce((a, b) => a + b) / workDaysPerEmployee.length,
    );
  }
}

/// Hasil analisis jadwal
class ScheduleAnalysis {
  final int totalShifts;
  final int filledSlots;
  final int openSlots;
  final double fillRate;
  final int maxWorkDays;
  final int minWorkDays;
  final double avgWorkDays;

  ScheduleAnalysis({
    required this.totalShifts,
    required this.filledSlots,
    required this.openSlots,
    required this.fillRate,
    required this.maxWorkDays,
    required this.minWorkDays,
    required this.avgWorkDays,
  });

  String get status {
    if (fillRate >= 1.0) return 'Lengkap';
    if (fillRate >= 0.7) return 'Hampir Lengkap';
    if (fillRate >= 0.4) return 'Kurang';
    return 'Kritis';
  }

  Color get statusColor {
    if (fillRate >= 1.0) return const Color(0xFF22C55E); // Green
    if (fillRate >= 0.7) return const Color(0xFFF59E0B); // Amber
    if (fillRate >= 0.4) return const Color(0xFFF97316); // Orange
    return const Color(0xFFDC2626); // Red
  }
}
