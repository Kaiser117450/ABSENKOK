import 'dart:convert';
import 'dart:math';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../core/constants.dart';
import '../models/employee.dart';
import '../models/shift_schedule.dart';
import '../models/time_off_request.dart';

/// Service untuk mengelola jadwal shift secara offline
class ScheduleSQLiteService {
  static Database? _db;

  static Future<Database> getDatabase() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'shift_schedules.db'),
      version: 1,
      onCreate: _initSchema,
    );
    return _db!;
  }

  static Future<void> _initSchema(Database db, int version) async {
    // Tabel jadwal utama
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schedules (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        template_json TEXT NOT NULL,
        entries_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced_at TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Tabel request libur
    await db.execute('''
      CREATE TABLE IF NOT EXISTS time_off_requests (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        outlet_id TEXT NOT NULL,
        request_date TEXT NOT NULL,
        reason TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        requested_at TEXT NOT NULL
      )
    ''');

    // Index untuk performa
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_schedules_outlet ON schedules(outlet_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_schedules_dates ON schedules(start_date, end_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_timeoff_employee ON time_off_requests(employee_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_timeoff_outlet ON time_off_requests(outlet_id)',
    );
  }

  /// Simpan jadwal baru
  static Future<void> saveSchedule(OutletSchedule schedule) async {
    final db = await getDatabase();
    await db.insert(
      'schedules',
      {
        'id': schedule.id,
        'outlet_id': schedule.outletId,
        'start_date': schedule.startDate.toIso8601String().split('T')[0],
        'end_date': schedule.endDate.toIso8601String().split('T')[0],
        'template_json': jsonEncode(schedule.template.toJson()),
        'entries_json': jsonEncode(schedule.entries.map((e) => e.toJson()).toList()),
        'created_at': schedule.createdAt.toIso8601String(),
        'synced_at': schedule.syncedAt?.toIso8601String(),
        'is_active': schedule.isActive ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ambil jadwal berdasarkan outlet dan periode
  static Future<OutletSchedule?> getSchedule(
    String outletId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await getDatabase();
    final maps = await db.query(
      'schedules',
      where: 'outlet_id = ? AND start_date = ? AND end_date = ? AND is_active = 1',
      whereArgs: [
        outletId,
        startDate.toIso8601String().split('T')[0],
        endDate.toIso8601String().split('T')[0],
      ],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return _mapToSchedule(map);
  }

  /// Ambil semua jadwal untuk 1 outlet
  static Future<List<OutletSchedule>> getSchedulesByOutlet(String outletId) async {
    final db = await getDatabase();
    final maps = await db.query(
      'schedules',
      where: 'outlet_id = ? AND is_active = 1',
      whereArgs: [outletId],
      orderBy: 'start_date DESC',
    );

    return maps.map(_mapToSchedule).toList();
  }

  /// Ambil jadwal yang belum di-sync
  static Future<List<OutletSchedule>> getUnsyncedSchedules() async {
    final db = await getDatabase();
    final maps = await db.query(
      'schedules',
      where: 'synced_at IS NULL AND is_active = 1',
    );

    return maps.map(_mapToSchedule).toList();
  }

  /// Update status synced
  static Future<void> markScheduleSynced(String scheduleId) async {
    final db = await getDatabase();
    await db.update(
      'schedules',
      {'synced_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
  }

  /// Hapus jadwal (soft delete)
  static Future<void> deleteSchedule(String scheduleId) async {
    final db = await getDatabase();
    await db.update(
      'schedules',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
  }

  /// Simpan request libur
  static Future<void> saveTimeOffRequest(TimeOffRequest request) async {
    final db = await getDatabase();
    await db.insert(
      'time_off_requests',
      {
        'id': request.id,
        'employee_id': request.employeeId,
        'outlet_id': request.outletId,
        'request_date': request.requestDate.toIso8601String(),
        'reason': request.reason,
        'status': request.status,
        'requested_at': request.requestedAt?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ambil request libur untuk outlet
  static Future<List<TimeOffRequest>> getTimeOffRequests(String outletId) async {
    final db = await getDatabase();
    final maps = await db.query(
      'time_off_requests',
      where: 'outlet_id = ?',
      whereArgs: [outletId],
      orderBy: 'request_date DESC',
    );

    return maps.map((m) => TimeOffRequest.fromJson(m)).toList();
  }

  /// Ambil request libur yang approved untuk periode tertentu
  static Future<List<TimeOffRequest>> getApprovedTimeOffForPeriod(
    String outletId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await getDatabase();
    final maps = await db.query(
      'time_off_requests',
      where: 'outlet_id = ? AND status = ? AND request_date BETWEEN ? AND ?',
      whereArgs: [
        outletId,
        'approved',
        start.toIso8601String(),
        end.toIso8601String(),
      ],
    );

    return maps.map((m) => TimeOffRequest.fromJson(m)).toList();
  }

  /// Update status request libur
  static Future<void> updateTimeOffStatus(
    String requestId,
    String status,
  ) async {
    final db = await getDatabase();
    await db.update(
      'time_off_requests',
      {'status': status},
      where: 'id = ?',
      whereArgs: [requestId],
    );
  }

  /// Helper method
  static OutletSchedule _mapToSchedule(Map<String, dynamic> map) {
    return OutletSchedule(
      id: map['id'] as String,
      outletId: map['outlet_id'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      template: ShiftTemplate.fromJson(
        jsonDecode(map['template_json'] as String) as Map<String, dynamic>,
      ),
      entries: (jsonDecode(map['entries_json'] as String) as List)
          .map((e) => ScheduleEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(map['created_at'] as String),
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
      isActive: (map['is_active'] as int) == 1,
    );
  }
}
