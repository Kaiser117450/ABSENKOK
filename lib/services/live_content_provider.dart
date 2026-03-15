import 'package:flutter/foundation.dart';

import '../core/supabase_client.dart';

/// Typedef for the function that fetches today's attendance logs.
typedef FetchLogsCallback = Future<List<dynamic>> Function(String outletId);

/// Typedef for the function that fetches active employee count for an outlet.
typedef FetchActiveCountCallback = Future<int> Function(String outletId);

/// Pure Dart service that computes break status and fun-fact content pools.
///
/// Decoupled from Supabase via injectable callbacks for testability.
/// Production code passes real Supabase calls; tests pass mock functions.
class LiveContentProvider {
  LiveContentProvider({
    FetchLogsCallback? fetchLogs,
    FetchActiveCountCallback? fetchActiveCount,
  })  : _fetchLogs = fetchLogs ?? _defaultFetchLogs,
        _fetchActiveCount = fetchActiveCount ?? _defaultFetchActiveCount;

  final FetchLogsCallback _fetchLogs;
  final FetchActiveCountCallback _fetchActiveCount;

  // --- Cached content pools ---
  List<String> _breakNames = [];
  List<String> _funFacts = List<String>.from(_defaultMotivationalMessages);
  int _breakIndex = 0;
  int _funFactIndex = 0;

  /// Whether any employees are currently on break.
  bool get hasActiveBreaks => _breakNames.isNotEmpty;

  /// Returns the next display text for the overlay attendance label.
  ///
  /// When employees are on break, rotates through break names:
  ///   "🍽️ Budi istirahat" → "🍽️ Sari istirahat"
  /// When idle, rotates through interleaved stats + motivational messages.
  String nextDisplayText() {
    if (_breakNames.isNotEmpty) {
      final name = _breakNames[_breakIndex % _breakNames.length];
      _breakIndex++;
      return '🍽️ $name istirahat';
    }
    final fact = _funFacts[_funFactIndex % _funFacts.length];
    _funFactIndex++;
    return fact;
  }

  /// Poll for today's attendance data. On error, keeps last cached data.
  ///
  /// Called every 30 seconds from KioskBackgroundService._pollTimer.
  Future<void> poll(String outletId) async {
    try {
      debugPrint('[LiveContent] poll start outletId=$outletId');
      final logs = await _fetchLogs(outletId);
      final activeCount = await _fetchActiveCount(outletId);
      debugPrint('[LiveContent] poll OK: ${logs.length} logs, $activeCount active employees');

      _computeBreakNames(logs);
      _computeFunFacts(logs, activeCount);
      debugPrint('[LiveContent] poll result: ${_breakNames.length} breaks, ${_funFacts.length} facts');
    } catch (e) {
      // Keep last cached data — don't clear on error (Pitfall from RESEARCH.md)
      debugPrint('[LiveContent] poll error: $e');
    }
  }

  /// Compute which employees are currently on break.
  ///
  /// Iterates chronologically through logs. `type == 'break'` sets onBreak=true,
  /// `type == 'kembali'` sets onBreak=false.
  /// CRITICAL: DB stores 'break' (NOT 'istirahat') — see AttendanceType.breakTime.value.
  void _computeBreakNames(List<dynamic> logs) {
    final Map<String, ({String name, bool onBreak})> employees = {};

    for (final log in logs) {
      final empId = (log as Map<String, dynamic>)['employee_id'] as String;
      final type = log['type'] as String;
      final empData = log['employees'] as Map<String, dynamic>?;
      final name = empData?['name'] as String? ?? '-';

      if (type == 'break') {
        employees[empId] = (name: name, onBreak: true);
      } else if (type == 'kembali') {
        final existing = employees[empId];
        if (existing != null) {
          employees[empId] = (name: existing.name, onBreak: false);
        }
      }
    }

    // Replace list completely — don't append (Pitfall 3: memory growth)
    _breakNames = employees.entries
        .where((e) => e.value.onBreak)
        .map((e) => e.value.name)
        .toList();
    _breakIndex = 0;
  }

  /// Compute fun facts pool: interleave live stats with motivational messages.
  ///
  /// Replace list completely each poll — don't append (prevents memory growth).
  void _computeFunFacts(List<dynamic> logs, int totalActive) {
    final stats = <String>[];

    // Stat 1: Today's attendance count — "Hari ini X/Y hadir 🎉"
    final uniqueMasuk = logs
        .where((l) => (l as Map<String, dynamic>)['type'] == 'masuk')
        .map((l) => (l as Map<String, dynamic>)['employee_id'] as String)
        .toSet();

    if (totalActive > 0) {
      stats.add('Hari ini ${uniqueMasuk.length}/$totalActive hadir 🎉');
    }

    // Stat 2: Attendance rate percentage — "Kehadiran hari ini N% 📊"
    if (totalActive > 0) {
      final rate = ((uniqueMasuk.length / totalActive) * 100).round();
      stats.add('Kehadiran hari ini $rate% 📊');
    }

    // Stat 3: Earliest arrival — "{name} datang pertama {time} 🏆"
    final masukLogs = logs
        .where((l) => (l as Map<String, dynamic>)['type'] == 'masuk')
        .toList();
    if (masukLogs.isNotEmpty) {
      final earliest = masukLogs.first as Map<String, dynamic>;
      final empData = earliest['employees'] as Map<String, dynamic>?;
      final name = empData?['name'] as String? ?? '';
      final time = _extractTime(earliest['scanned_at'] as String? ?? '');
      if (name.isNotEmpty) {
        stats.add('$name datang pertama $time 🏆');
      }
    }

    // Interleave stats with motivational messages
    final mixed = <String>[];
    final motivational = List<String>.from(_defaultMotivationalMessages);
    int si = 0, mi = 0;
    while (si < stats.length || mi < motivational.length) {
      if (si < stats.length) mixed.add(stats[si++]);
      if (mi < motivational.length) mixed.add(motivational[mi++]);
    }

    // Replace list completely (not append) — Pitfall 3
    _funFacts = mixed.isNotEmpty ? mixed : List<String>.from(_defaultMotivationalMessages);
    _funFactIndex = 0;
  }

  /// Extract HH:mm from ISO 8601 timestamp string.
  static String _extractTime(String isoTimestamp) {
    try {
      final dt = DateTime.parse(isoTimestamp).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  // --- Default Supabase callbacks (production) ---

  static Future<List<dynamic>> _defaultFetchLogs(String outletId) async {
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

    final data = await SupabaseClientFactory.kiosk
        .from('attendance_logs')
        .select('employee_id, type, scanned_at, employees(name)')
        .eq('scan_outlet_id', outletId)
        .gte('scanned_at', startOfDay)
        .order('scanned_at', ascending: true);

    return data as List<dynamic>;
  }

  static Future<int> _defaultFetchActiveCount(String outletId) async {
    final data = await SupabaseClientFactory.kiosk
        .from('employees')
        .select('id')
        .eq('home_outlet_id', outletId)
        .eq('is_active', true);

    return (data as List<dynamic>).length;
  }

  static const _defaultMotivationalMessages = [
    'Semangat kerja! 💪',
    'Terima kasih sudah tepat waktu 🙏',
    'Kerja keras, hasil manis 🍯',
    'Tim terbaik! ⭐',
    'Satu tim, satu semangat 🤝',
  ];
}
