import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/supabase_client.dart';
import '../main.dart' show supabaseReady;

// ─────────────────────────────────────────────────────────────────────────────
// Top-level pure functions — required for compute() isolate
// ─────────────────────────────────────────────────────────────────────────────

/// Top-level function for compute() isolate.
/// Input: RPC rows from `get_arrival_patterns`.
/// Output: day-of-week median values keyed by employee ID.
Map<String, Map<int, double>> analyzePatterns(
    List<Map<String, dynamic>> rpcData) {
  final result = <String, Map<int, double>>{};
  for (final row in rpcData) {
    final empId = row['employee_id'] as String;
    final dow = (row['day_of_week'] as num).toInt();
    final median = (row['median_seconds'] as num).toDouble();
    result.putIfAbsent(empId, () => {});
    result[empId]![dow] = median;
  }
  return result;
}

/// Compute median from a list of doubles.
/// The list does not need to be pre-sorted — this function sorts internally.
double computeMedian(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = List<double>.from(values)..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return (sorted[mid - 1] + sorted[mid]) / 2;
}

/// Check if arrival time is late vs pattern.
/// [arrivalSeconds]: seconds since midnight of actual arrival.
/// [medianSeconds]: median arrival seconds since midnight (null = no pattern for day).
/// [thresholdMinutes]: how many minutes late triggers alert (default 5, exclusive).
bool isLate(double arrivalSeconds, double? medianSeconds,
    {int thresholdMinutes = 5}) {
  if (medianSeconds == null) return false;
  final diffMinutes = (arrivalSeconds - medianSeconds) / 60;
  return diffMinutes > thresholdMinutes;
}

/// Format notification body for a late-arrival alert.
/// Returns: "{name} tiba {minutesLate} menit lebih lambat dari biasanya di {dayName}"
String formatLateNotification(String name, int minutesLate, String dayName) {
  return '$name tiba $minutesLate menit lebih lambat dari biasanya di $dayName';
}

// ─────────────────────────────────────────────────────────────────────────────
// PatternDetectionService
// ─────────────────────────────────────────────────────────────────────────────

/// Service for detecting late-arrival patterns per employee per day-of-week.
///
/// Compares each masuk scan time against the employee's median arrival time
/// for that day of week (computed from last 30 days via get_arrival_patterns RPC).
///
/// If the employee arrives more than 5 minutes later than their usual pattern,
/// a local notification is sent to the device.
///
/// Pattern analysis runs in a background isolate via Flutter's compute() so
/// it never blocks the NFC scan flow (SMART-03).
class PatternDetectionService {
  PatternDetectionService._();
  static final instance = PatternDetectionService._();

  static const String _channelId = 'absensi_enakko_late_pattern';
  static const String _channelName = 'Keterlambatan Pola';
  static const int _notifId = 210;

  static const _dayNames = [
    'Minggu',
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  final FlutterLocalNotificationsPlugin _notifPlugin =
      FlutterLocalNotificationsPlugin();
  bool _notifInitialized = false;

  /// Cached patterns keyed by employeeId and day-of-week.
  Map<String, Map<int, double>>? _patterns;
  DateTime? _lastFetch;

  /// Employee name cache populated from RPC data.
  final Map<String, String> _employeeNames = {};

  // ── Notification init ───────────────────────────────────────────────────

  Future<void> _initNotifications() async {
    if (_notifInitialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notifPlugin.initialize(initSettings);
    _notifInitialized = true;
  }

  // ── Pattern cache ───────────────────────────────────────────────────────

  /// Fetch arrival patterns from Supabase and cache for 6 hours.
  /// Uses compute() isolate to process patterns off the main thread (SMART-03).
  Future<void> refreshPatterns(String outletId) async {
    if (!supabaseReady) return;
    if (_patterns != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(hours: 6)) {
      return; // use cache
    }
    try {
      final result = await SupabaseClientFactory.admin.rpc(
        'get_arrival_patterns',
        params: {'p_outlet_id': outletId, 'p_days': 30},
      );
      final data = (result as List?)?.cast<Map<String, dynamic>>() ?? [];

      // Cache employee names for notification text
      for (final row in data) {
        _employeeNames[row['employee_id'] as String] =
            row['employee_name'] as String;
      }

      // Run pattern analysis in background isolate (SMART-03)
      _patterns = await compute(analyzePatterns, data);
      _lastFetch = DateTime.now();
    } catch (e) {
      debugPrint('[PatternDetectionService] refreshPatterns failed: $e');
    }
  }

  // ── Late check ──────────────────────────────────────────────────────────

  /// Check if an employee's masuk scan is late relative to their arrival pattern.
  ///
  /// Call this AFTER a successful masuk NFC scan — fire-and-forget.
  /// This method is non-blocking: it refreshes pattern cache in background
  /// and only sends a notification if a late pattern is detected.
  ///
  /// Does nothing if supabaseReady is false, no pattern exists for the employee,
  /// or the employee has fewer than 5 historical data points for that day-of-week
  /// (enforced at DB level via HAVING COUNT(*) >= 5 in the RPC).
  Future<void> checkAndNotifyIfLate({
    required String employeeId,
    required String outletId,
    required DateTime scanTime,
  }) async {
    await refreshPatterns(outletId);
    if (_patterns == null) return;

    final empPatterns = _patterns![employeeId];
    if (empPatterns == null) return; // no pattern for this employee

    // Dart DateTime.weekday: 1=Mon..7=Sun → convert to PostgreSQL DOW: 0=Sun..6=Sat
    final dow = scanTime.weekday % 7;
    final medianSeconds = empPatterns[dow];
    if (medianSeconds == null) return; // fewer than 5 data points for this day

    final arrivalSeconds =
        scanTime.hour * 3600.0 + scanTime.minute * 60.0 + scanTime.second;
    if (!isLate(arrivalSeconds, medianSeconds)) return;

    final minutesLate = ((arrivalSeconds - medianSeconds) / 60).round();
    final empName = _employeeNames[employeeId] ?? 'Karyawan';
    final dayName = _dayNames[dow];

    await _initNotifications();
    await _notifPlugin.show(
      _notifId,
      'Keterlambatan Pola',
      formatLateNotification(empName, minutesLate, dayName),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );

    debugPrint(
      '[PatternDetectionService] late alert: $empName $minutesLate min late on $dayName',
    );
  }

  /// Invalidate the cached patterns (call on outlet change or logout).
  void clearCache() {
    _patterns = null;
    _lastFetch = null;
    _employeeNames.clear();
  }
}
