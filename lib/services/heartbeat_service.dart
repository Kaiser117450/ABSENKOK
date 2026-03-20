import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show supabaseReady;
import '../models/kiosk_session.dart';
import 'device_identity_service.dart';
import 'sentry_service.dart';
import 'sqlite_service.dart';

/// Sends a heartbeat to the `kiosk_devices` table (via RPC) every 15 minutes.
/// Also updates `outlets` table heartbeat fields as a backward-compatible bridge
/// until Phase 32 refactors the admin dashboard to read from `kiosk_devices`.
///
/// Payload fields: last_heartbeat_at, battery_level, is_charging,
/// app_version, pending_sync_count.
///
/// Usage:
///   await HeartbeatService.start(session);  // in KioskBackgroundService.start()
///   HeartbeatService.stop();                // in KioskBackgroundService.stop()
class HeartbeatService {
  static Timer? _timer;
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  static KioskSession? _session;
  static DateTime? _lastSentAt;
  static String? _cachedVersion;
  static String? _deviceUuid;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Start the heartbeat service. Sends an immediate heartbeat, then
  /// schedules one every 15 minutes. Also listens for connectivity
  /// restore and retries with a 30-second debounce.
  static Future<void> start(KioskSession session) async {
    _session = session;

    // Get persistent installation UUID (never changes across logout)
    _deviceUuid = await DeviceIdentityService.getOrCreateDeviceUuid();

    // Immediate heartbeat on start
    await _sendHeartbeat();

    // Cancel any existing timer and schedule a new periodic one
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) {
      _sendHeartbeat();
    });

    // Cancel any existing connectivity subscription and subscribe anew
    _connectivitySub?.cancel();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection =
          results.any((r) => r != ConnectivityResult.none);
      if (!hasConnection) return;

      // 30-second debounce: skip if we sent recently
      final last = _lastSentAt;
      if (last != null &&
          DateTime.now().difference(last).inSeconds < 30) {
        return;
      }
      _sendHeartbeat();
    });

    debugPrint('[Heartbeat] started for outlet=${session.outletId}');
  }

  /// Stop the heartbeat service and release all resources.
  static void stop() {
    _timer?.cancel();
    _timer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _session = null;
    _deviceUuid = null;
    _lastSentAt = null;
    debugPrint('[Heartbeat] stopped');
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  static Future<void> _sendHeartbeat() async {
    if (_session == null) return;
    if (!supabaseReady) {
      debugPrint('[Heartbeat] skipped — supabase not ready');
      return;
    }

    try {
      final battery = await _readBattery();
      final appVersion = await _getAppVersion();
      final pendingCount = await SqliteService.countPendingLogs();

      final payload = <String, dynamic>{
        'last_heartbeat_at': DateTime.now().toUtc().toIso8601String(),
        'battery_level': battery.level,
        'is_charging': battery.isCharging,
        'pending_sync_count': pendingCount,
        'app_version': appVersion,
      };

      await _sendWithRetry(payload, _session!.outletId);
      _lastSentAt = DateTime.now();
      debugPrint('[Heartbeat] sent OK for outlet=${_session?.outletId}');
    } catch (e) {
      debugPrint('[Heartbeat] _sendHeartbeat error: $e');
    }
  }

  static Future<({int? level, bool? isCharging})> _readBattery() async {
    try {
      final battery = Battery();
      final level = await battery.batteryLevel;
      final state = await battery.batteryState;
      final isCharging =
          state == BatteryState.charging || state == BatteryState.full;
      return (level: level, isCharging: isCharging);
    } catch (e) {
      debugPrint('[Heartbeat] battery read failed: $e');
      return (level: null, isCharging: null);
    }
  }

  static Future<String> _getAppVersion() async {
    if (_cachedVersion != null) return _cachedVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedVersion = '${info.version}+${info.buildNumber}';
    } catch (e) {
      debugPrint('[Heartbeat] version read failed: $e');
      _cachedVersion = 'unknown';
    }
    return _cachedVersion!;
  }

  static Future<void> _sendWithRetry(
    Map<String, dynamic> payload,
    String outletId,
  ) async {
    // ── Primary: upsert into kiosk_devices via RPC ──
    if (_deviceUuid != null) {
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          await Supabase.instance.client.rpc(
            'upsert_kiosk_heartbeat',
            params: {
              'p_device_uuid': _deviceUuid,
              'p_outlet_id': outletId,
              'p_battery_level': payload['battery_level'],
              'p_is_charging': payload['is_charging'],
              'p_pending_sync_count': payload['pending_sync_count'],
              'p_app_version': payload['app_version'],
            },
          );
          debugPrint('[Heartbeat] RPC upsert OK for device=$_deviceUuid');
          break; // success
        } catch (e, stack) {
          if (attempt == 2) {
            debugPrint('[Heartbeat] RPC upsert failed after 3 attempts: $e');
            await SentryService.captureBackgroundFailure(
              exception: e,
              stackTrace: stack,
              operation: 'heartbeat_rpc',
              session: _session,
            );
          } else {
            final delaySeconds = 2 * (attempt + 1);
            debugPrint('[Heartbeat] RPC retry ${attempt + 1} in ${delaySeconds}s: $e');
            await Future.delayed(Duration(seconds: delaySeconds));
          }
        }
      }
    }

    // ── Bridge: also update outlets table (backward compat for admin dashboard) ──
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        await Supabase.instance.client
            .from('outlets')
            .update(payload)
            .eq('id', outletId);
        return; // success
      } catch (e, stack) {
        if (attempt == 2) {
          debugPrint('[Heartbeat] bridge update failed after 3 attempts: $e');
          await SentryService.captureBackgroundFailure(
            exception: e,
            stackTrace: stack,
            operation: 'heartbeat_bridge',
            session: _session,
          );
          return;
        }
        final delaySeconds = 2 * (attempt + 1); // 2s, 4s
        debugPrint(
            '[Heartbeat] bridge retry ${attempt + 1} in ${delaySeconds}s: $e');
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }
}
