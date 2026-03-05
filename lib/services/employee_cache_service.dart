import 'dart:async';
import '../models/employee.dart';

/// In-memory cache untuk employee lookup berdasarkan NFC UID.
/// TTL 5 menit — kartu NFC karyawan bisa berpindah outlet sewaktu-waktu,
/// jadi cache diperbarui setiap 5 menit untuk sinkronisasi outlet terbaru.
/// Scan NFC kedua dalam 5 menit = instant (skip Supabase).
/// 
/// TTL 5 jam untuk mode backup — jika karyawan pilih backup di gerai lain,
/// tidak perlu konfirmasi lagi selama 5 jam.
class EmployeeCacheService {
  static final instance = EmployeeCacheService._();
  EmployeeCacheService._();

  static const _ttl = Duration(minutes: 5);
  static const _backupTtl = Duration(hours: 5); // TTL 5 jam untuk backup mode
  
  final _cache = <String, _CachedEntry>{};
  final _backupCache = <String, _BackupEntry>{}; // Cache untuk backup mode

  // Mutex implementation for thread-safety against race conditions
  bool _isLocked = false;
  final _lockQueue = <Completer<void>>[];

  Future<void> _acquireLock() async {
    if (!_isLocked) {
      _isLocked = true;
      return;
    }
    final completer = Completer<void>();
    _lockQueue.add(completer);
    await completer.future;
  }

  void _releaseLock() {
    if (_lockQueue.isNotEmpty) {
      final next = _lockQueue.removeAt(0);
      next.complete();
    } else {
      _isLocked = false;
    }
  }

  /// Ambil employee dari cache. Return null jika tidak ada atau sudah expired.
  Future<Employee?> get(String uid) async {
    await _acquireLock();
    try {
      final entry = _cache[uid];
      if (entry == null) return null;
      if (DateTime.now().difference(entry.cachedAt) > _ttl) {
        _cache.remove(uid);
        return null;
      }
      return entry.employee;
    } finally {
      _releaseLock();
    }
  }

  /// Simpan employee ke cache dengan timestamp sekarang.
  Future<void> put(String uid, Employee employee) async {
    await _acquireLock();
    try {
      _cache[uid] = _CachedEntry(employee: employee, cachedAt: DateTime.now());
    } finally {
      _releaseLock();
    }
  }

  /// Cek apakah karyawan masih dalam mode backup (TTL 5 jam)
  /// Return backup outlet ID jika masih valid, null jika expired
  Future<String?> getBackupOutletId(String uid) async {
    await _acquireLock();
    try {
      final entry = _backupCache[uid];
      if (entry == null) return null;
      if (DateTime.now().difference(entry.cachedAt) > _backupTtl) {
        _backupCache.remove(uid);
        return null;
      }
      return entry.backupOutletId;
    } finally {
      _releaseLock();
    }
  }

  /// Simpan mode backup dengan outlet ID dan timestamp
  Future<void> setBackupMode(String uid, String backupOutletId, String? notes) async {
    await _acquireLock();
    try {
      _backupCache[uid] = _BackupEntry(
        backupOutletId: backupOutletId,
        notes: notes,
        cachedAt: DateTime.now(),
      );
    } finally {
      _releaseLock();
    }
  }

  /// Clear backup mode untuk karyawan
  Future<void> clearBackupMode(String uid) async {
    await _acquireLock();
    try {
      _backupCache.remove(uid);
    } finally {
      _releaseLock();
    }
  }

  /// Hapus semua cache (dipanggil saat reset/logout kiosk).
  Future<void> clear() async {
    await _acquireLock();
    try {
      _cache.clear();
      _backupCache.clear();
    } finally {
      _releaseLock();
    }
  }

  /// Jumlah entry yang tersimpan (untuk debugging).
  int get size => _cache.length;
  int get backupSize => _backupCache.length;
}

class _CachedEntry {
  final Employee employee;
  final DateTime cachedAt;
  const _CachedEntry({required this.employee, required this.cachedAt});
}

class _BackupEntry {
  final String backupOutletId;
  final String? notes;
  final DateTime cachedAt;
  const _BackupEntry({
    required this.backupOutletId,
    this.notes,
    required this.cachedAt,
  });
}
