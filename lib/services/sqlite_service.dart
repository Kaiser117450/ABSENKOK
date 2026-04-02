import 'dart:math';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../models/attendance_log.dart';
import '../models/pending_log.dart';

/// Manages the local SQLite offline queue for attendance logs.
class SqliteService {
  static Database? _db;

  static Future<Database> getDatabase() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, AppConstants.dbName),
      version: AppConstants.dbVersion,
      onCreate: _initSchema,
      onUpgrade: _onUpgrade,
    );
    await _db!.rawQuery('PRAGMA journal_mode = WAL;');
    return _db!;
  }

  static Future<void> _initSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_logs (
        local_id             TEXT PRIMARY KEY,
        employee_id          TEXT NOT NULL,
        scan_outlet_id       TEXT NOT NULL,
        type                 TEXT NOT NULL CHECK (type IN ('masuk', 'break', 'pulang', 'kembali', 'sakit', 'izin')),
        lat                  REAL,
        lng                  REAL,
        device_id            TEXT NOT NULL,
        scanned_at           TEXT NOT NULL,
        device_captured_at   TEXT,
        capture_mode         TEXT NOT NULL DEFAULT 'queued'
                             CHECK (capture_mode IN ('live','queued')),
        queue_order          INTEGER NOT NULL,
        initial_scan_intent  TEXT NOT NULL DEFAULT 'none'
                             CHECK (initial_scan_intent IN ('none','break_first')),
        sync_status          TEXT NOT NULL DEFAULT 'pending'
                             CHECK (sync_status IN ('pending','uploading','synced','failed')),
        retry_count          INTEGER NOT NULL DEFAULT 0,
        is_backup            INTEGER NOT NULL DEFAULT 0,
        notes                TEXT,
        created_at           TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_status ON pending_logs(sync_status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_created_at ON pending_logs(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pending_logs_queue_order ON pending_logs(queue_order ASC)',
    );
  }

  /// Migration strategy:
  /// - v1 and earlier are best-effort only: recreate the table.
  /// - v2-v5 keep unsynced rows and backfill the Phase 56 queue metadata.
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS pending_logs');
      await _initSchema(db, newVersion);
      return;
    }

    if (oldVersion < 6) {
      await _migratePendingLogsToPhase56Schema(db, newVersion);
    }
  }

  static Future<void> _migratePendingLogsToPhase56Schema(
    Database db,
    int newVersion,
  ) async {
    await db.execute('ALTER TABLE pending_logs RENAME TO pending_logs_old_v6');
    final oldRows = await db.query(
      'pending_logs_old_v6',
      where: "sync_status IN ('pending','failed')",
      orderBy: 'created_at ASC, local_id ASC',
    );

    await _initSchema(db, newVersion);

    var nextQueueOrder = 0;
    for (final row in oldRows) {
      final existingQueueOrder = _readInt(row['queue_order']);
      final resolvedQueueOrder = existingQueueOrder ?? (nextQueueOrder + 1);
      nextQueueOrder = max(nextQueueOrder, resolvedQueueOrder);

      await db.insert('pending_logs', {
        'local_id': _readString(row['local_id']) ?? _generateLocalId(),
        'employee_id': _readString(row['employee_id']) ?? '',
        'scan_outlet_id': _readString(row['scan_outlet_id']) ?? '',
        'type': _readString(row['type']) ?? AttendanceType.masuk.value,
        'lat': _readDouble(row['lat']),
        'lng': _readDouble(row['lng']),
        'device_id': _readString(row['device_id']) ?? '',
        'scanned_at': _readString(row['scanned_at']) ?? '',
        'device_captured_at': _readString(row['device_captured_at']) ??
            _readString(row['scanned_at']),
        'capture_mode': _readString(row['capture_mode']) ??
            AttendanceCaptureMode.queued.value,
        'queue_order': resolvedQueueOrder,
        'initial_scan_intent': _readString(row['initial_scan_intent']) ??
            InitialScanIntent.none.value,
        'sync_status':
            _readString(row['sync_status']) ?? SyncStatus.pending.value,
        'retry_count': _readInt(row['retry_count']) ?? 0,
        'is_backup': _readBoolAsInt(row['is_backup']),
        'notes': _readString(row['notes']),
        'created_at': _readString(row['created_at']) ??
            _readString(row['scanned_at']) ??
            DateTime.now().toUtc().toIso8601String(),
      });
    }

    await db.execute('DROP TABLE pending_logs_old_v6');
  }

  /// Insert a new attendance event into the offline queue.
  static Future<String> insertPendingLog({
    required String employeeId,
    required String scanOutletId,
    required AttendanceType type,
    double? lat,
    double? lng,
    required String deviceId,
    required String scannedAt,
    DateTime? deviceCapturedAt,
    AttendanceCaptureMode captureMode = AttendanceCaptureMode.queued,
    int? queueOrder,
    InitialScanIntent initialScanIntent = InitialScanIntent.none,
    bool isBackup = false,
    String? notes,
  }) async {
    final db = await getDatabase();

    return db.transaction((txn) async {
      final localId = _generateLocalId();
      final resolvedQueueOrder = queueOrder ?? await _nextQueueOrder(txn);
      await txn.insert('pending_logs', {
        'local_id': localId,
        'employee_id': employeeId,
        'scan_outlet_id': scanOutletId,
        'type': type.value,
        'lat': lat,
        'lng': lng,
        'device_id': deviceId,
        'scanned_at': scannedAt,
        'device_captured_at': (deviceCapturedAt ?? _tryParseDateTime(scannedAt))
                ?.toUtc()
                .toIso8601String() ??
            scannedAt,
        'capture_mode': captureMode.value,
        'queue_order': resolvedQueueOrder,
        'initial_scan_intent': initialScanIntent.value,
        'sync_status': SyncStatus.pending.value,
        'retry_count': 0,
        'is_backup': isBackup ? 1 : 0,
        'notes': notes,
      });
      return localId;
    });
  }

  static Future<int> _nextQueueOrder(DatabaseExecutor db) async {
    final result = await db.rawQuery(
      'SELECT COALESCE(MAX(queue_order), 0) + 1 AS next_queue_order FROM pending_logs',
    );
    return _readInt(result.first['next_queue_order']) ?? 1;
  }

  /// Get all logs eligible for sync (pending or failed with retries < max).
  static Future<List<PendingLog>> getPendingLogs() async {
    final db = await getDatabase();
    final rows = await db.query(
      'pending_logs',
      where: "sync_status IN ('pending','failed') AND retry_count < ?",
      whereArgs: [AppConstants.syncMaxRetries],
      orderBy: 'queue_order ASC, created_at ASC, local_id ASC',
      limit: AppConstants.syncBatchSize,
    );
    return rows.map(PendingLog.fromMap).toList();
  }

  /// Mark a log as successfully synced.
  static Future<void> markLogSynced(String localId) async {
    final db = await getDatabase();
    await db.update(
      'pending_logs',
      {'sync_status': SyncStatus.synced.value},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Mark a log as failed and increment retry count.
  static Future<void> markLogFailed(String localId) async {
    final db = await getDatabase();
    await db.rawUpdate(
      'UPDATE pending_logs SET sync_status = ?, retry_count = retry_count + 1 WHERE local_id = ?',
      [SyncStatus.failed.value, localId],
    );
  }

  /// Count logs that are not yet synced — used for the UI badge.
  static Future<int> countPendingLogs() async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM pending_logs WHERE sync_status IN ('pending','failed')",
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Delete synced logs older than 7 days to prevent DB bloat.
  static Future<void> cleanOldSyncedLogs() async {
    final db = await getDatabase();
    await db.rawDelete(
      "DELETE FROM pending_logs WHERE sync_status = 'synced' AND created_at < datetime('now', '-7 days')",
    );
  }

  static DateTime? _tryParseDateTime(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static String? _readString(Object? raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static int? _readInt(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  static double? _readDouble(Object? raw) {
    if (raw == null) return null;
    if (raw is double) return raw;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  static int _readBoolAsInt(Object? raw) {
    if (raw is int) return raw == 0 ? 0 : 1;
    if (raw is num) return raw == 0 ? 0 : 1;
    if (raw is bool) return raw ? 1 : 0;
    final value = raw?.toString().trim().toLowerCase();
    return value == 'true' || value == '1' ? 1 : 0;
  }

  static String _generateLocalId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999999).toRadixString(36);
    return '$ts-$rand';
  }
}
