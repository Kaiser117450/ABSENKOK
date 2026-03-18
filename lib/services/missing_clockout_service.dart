import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/supabase_client.dart';
import '../main.dart' show supabaseReady;

// ---------------------------------------------------------------------------
// MissingClockoutEntry — data model returned from RPC
// ---------------------------------------------------------------------------

/// Represents an employee who has scanned masuk but has not scanned pulang
/// after the configured threshold.
class MissingClockoutEntry {
  final String employeeId;
  final String employeeName;
  final String outletId;
  final DateTime masukTime;

  const MissingClockoutEntry({
    required this.employeeId,
    required this.employeeName,
    required this.outletId,
    required this.masukTime,
  });

  factory MissingClockoutEntry.fromJson(Map<String, dynamic> json) {
    return MissingClockoutEntry(
      employeeId: json['employee_id'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      outletId: json['outlet_id'] as String? ?? '',
      masukTime: json['masuk_time'] != null
          ? DateTime.parse(json['masuk_time'] as String)
          : DateTime.now(),
    );
  }
}

// ---------------------------------------------------------------------------
// MissingClockoutService
// ---------------------------------------------------------------------------

/// Periodic service that checks for employees who scanned masuk but have not
/// scanned pulang after a configurable threshold (default 10 hours).
///
/// Sends a single batched local notification per outlet:
///   Title: "Karyawan Belum Pulang"
///   Body:  "N karyawan belum scan pulang di {outlet_name}"
///
/// Usage:
///   MissingClockoutService.instance.startPeriodicCheck(
///     outletIds: [session.outletId],
///     outletNames: {session.outletId: session.outletName},
///   );
///   MissingClockoutService.instance.stopPeriodicCheck();
class MissingClockoutService {
  MissingClockoutService._();
  static final instance = MissingClockoutService._();

  static const int _notifIdBase = 200;
  static const String _channelId = 'absensi_enakko_missing_clockout';
  static const String _channelName = 'Karyawan Belum Pulang';
  static const Duration checkInterval = Duration(minutes: 30);

  final FlutterLocalNotificationsPlugin _notifPlugin =
      FlutterLocalNotificationsPlugin();
  bool _notifInitialized = false;
  Timer? _timer;

  // ── Notification init ────────────────────────────────────────────────────

  Future<void> _initNotifications() async {
    if (_notifInitialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notifPlugin.initialize(initSettings);
    _notifInitialized = true;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Start periodic missing clock-out checking.
  /// Runs immediately on start, then every [checkInterval] (30 minutes).
  /// Call from [KioskBackgroundService.start()].
  void startPeriodicCheck({
    required List<String> outletIds,
    required Map<String, String> outletNames,
  }) {
    _timer?.cancel();
    _timer = Timer.periodic(checkInterval, (_) {
      _checkAndNotify(outletIds: outletIds, outletNames: outletNames);
    });
    // Also run immediately on start
    _checkAndNotify(outletIds: outletIds, outletNames: outletNames);
  }

  /// Stop the periodic check and cancel pending timer.
  /// Call from [KioskBackgroundService.stop()].
  void stopPeriodicCheck() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Core check logic ─────────────────────────────────────────────────────

  Future<void> _checkAndNotify({
    required List<String> outletIds,
    required Map<String, String> outletNames,
  }) async {
    if (!supabaseReady) return;
    await _initNotifications();

    for (int i = 0; i < outletIds.length; i++) {
      final outletId = outletIds[i];
      try {
        final result = await SupabaseClientFactory.admin.rpc(
          'get_missing_clockouts',
          params: {'p_outlet_id': outletId, 'p_threshold_hours': 10},
        );
        final missing = (result as List?) ?? [];
        if (!shouldNotify(missing)) continue;

        final outletName = outletNames[outletId] ?? 'Outlet';
        final body = formatNotificationBody(missing.length, outletName);

        await _notifPlugin.show(
          _notifIdBase + i, // unique per outlet index
          'Karyawan Belum Pulang',
          body,
          NotificationDetails(
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
          '[MissingClockoutService] notif sent: ${missing.length} employees at $outletId',
        );
      } catch (e) {
        debugPrint(
          '[MissingClockoutService] check failed for $outletId: $e',
        );
      }
    }
  }

  // ── Pure helper functions (testable without Supabase) ────────────────────

  /// Build the notification body string.
  /// Format: "N karyawan belum scan pulang di {outletName}"
  static String formatNotificationBody(int count, String outletName) {
    return '$count karyawan belum scan pulang di $outletName';
  }

  /// Returns true when there are employees missing clock-out.
  static bool shouldNotify(List<dynamic> missingList) {
    return missingList.isNotEmpty;
  }

  /// Groups a list of [MissingClockoutEntry] by their [outletId].
  /// Returns a map from outletId to list of entries for that outlet.
  static Map<String, List<MissingClockoutEntry>> groupByOutlet(
    List<MissingClockoutEntry> entries,
  ) {
    final result = <String, List<MissingClockoutEntry>>{};
    for (final entry in entries) {
      result.putIfAbsent(entry.outletId, () => []).add(entry);
    }
    return result;
  }
}
