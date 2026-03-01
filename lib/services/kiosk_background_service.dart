import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../models/kiosk_session.dart';
import '../models/overlay_pill_state.dart';

// ---------------------------------------------------------------------------
// Notification IDs
// ---------------------------------------------------------------------------
const int _kNotifIdPersistent =
    100; // legacy persistent notif ID (kept for cancel)
const int _kNotifIdScan = 101; // heads-up on NFC scan
const String _kChannelId =
    'absensi_enakko_kiosk'; // used for scan notification channel
const int _kOverlayWindowWidth = 380;
const int _kOverlayWindowHeight = 96;
const Duration _kOverlayActivationTimeout = Duration(milliseconds: 1600);
const Duration _kOverlayActivationPoll = Duration(milliseconds: 120);

enum OverlayShowResult { shown, permissionDenied, showFailed }

// ---------------------------------------------------------------------------
// KioskBackgroundService
//
// Controls the Android Foreground Service that keeps the kiosk alive
// in the background so NFC scans can happen without the app being open.
//
// Usage:
//   await KioskBackgroundService.start(session);  // in kiosk_idle_screen initState
//   await KioskBackgroundService.stop();           // in clearKioskSession
//   KioskBackgroundService.showScanNotification(employeeName);  // after NFC scan
// ---------------------------------------------------------------------------
class KioskBackgroundService {
  static final FlutterLocalNotificationsPlugin _notifPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _notifInitialized = false;
  static KioskSession? _session;
  static Timer? _rotateTimer;
  static bool _showingTime = false; // toggles between outlet name & time

  // MethodChannel → KioskNotificationHelper.kt untuk custom pill notification
  static const _notifChannel = MethodChannel('com.enakko.kiosk/notification');

  // ── Init local notifications ──────────────────────────────────────────────

  static Future<void> _initNotifications() async {
    if (_notifInitialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _notifPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Tap on scan notification → handled via payload routing
      },
    );

    _notifInitialized = true;
  }

  // ── Notification Permission ───────────────────────────────────────────────

  /// Request POST_NOTIFICATIONS permission (mandatory on Android 13+ / API 33+).
  /// Must be called in start() BEFORE any notification.notify() call.
  /// Without this, NotificationManagerCompat.notify() throws SecurityException silently.
  static Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid) return;
    try {
      final status = await FlutterForegroundTask.checkNotificationPermission();
      if (status == NotificationPermission.granted) {
        debugPrint('[BgService] notif permission: already granted');
        return;
      }
      final result =
          await FlutterForegroundTask.requestNotificationPermission();
      debugPrint('[BgService] notif permission after request: $result');
    } catch (e) {
      debugPrint('[BgService] requestNotificationPermission error: $e');
    }
  }

  // ── Foreground Task Setup ─────────────────────────────────────────────────

  static void _initForegroundTask(KioskSession session) {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        // Channel ID baru = importance baru berlaku (Android ignore perubahan ke channel lama)
        // Demoted ke LOW agar tersembunyi — custom pill notification (ID=300) yang tampil
        channelId: 'absensi_enakko_keepalive',
        channelName: 'Kiosk Background',
        channelDescription: 'Proses background kiosk aktif',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000), // 10s
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  // ── Start ─────────────────────────────────────────────────────────────────

  /// Start the foreground service with rotating notification content.
  /// Call from kiosk_idle_screen.initState — do NOT stop on dispose,
  /// so the service keeps running when app is backgrounded.
  static Future<OverlayShowResult> start(KioskSession session) async {
    _session = session;

    await _initNotifications();
    _initForegroundTask(session);

    // ① Request POST_NOTIFICATIONS permission FIRST (Android 13+)
    //    Without this, all notify() calls silently fail with SecurityException.
    await _requestNotificationPermission();

    // ② Request battery optimization bypass
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();

    // ③ Start foreground service (shows LOW-importance keepalive notification)
    final status = await FlutterForegroundTask.startService(
      serviceId: 200,
      notificationTitle: session.outletName,
      notificationText: 'Tempelkan kartu NFC untuk absensi',
      callback: _startCallback,
    );

    debugPrint('[BgService] foreground service start: $status');

    // ④ Tampilkan custom Live Activity notification (Grab-style, HIGH importance)
    await showLiveNotification(outletName: session.outletName);

    // Coba overlay juga (best-effort, bisa gagal di beberapa OEM)
    final idleOverlayState = _buildIdleOverlayState(
        outletName: session.outletName, at: DateTime.now());
    final overlayResult = await ensureOverlayVisible(idleOverlayState);
    debugPrint('[BgService] start ensureOverlayVisible result=$overlayResult');

    // Start rotating notification timer (setiap 5 detik untuk live clock)
    _rotateTimer?.cancel();
    _rotateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _rotateNotification();
    });

    return overlayResult;
  }

  // ── Stop ──────────────────────────────────────────────────────────────────

  /// Stop the foreground service. Call from clearKioskSession().
  static Future<void> stop() async {
    _rotateTimer?.cancel();
    _rotateTimer = null;
    _session = null;

    await FlutterForegroundTask.stopService();

    // Cancel persistent notification (legacy ID)
    await _notifPlugin.cancel(_kNotifIdPersistent);

    // Dismiss Live Activity notification
    await dismissLiveNotification();

    // Tutup floating overlay (best effort)
    await hideOverlayPill();

    debugPrint('[BgService] stopped');
  }

  // ── Public Live Notification Methods (Grab-style) ─────────────────────────

  /// Show the Live Activity notification. Can be called from anywhere.
  /// Primary: MethodChannel → KioskNotificationHelper.kt (custom RemoteViews / Grab-style).
  /// Fallback: flutter_local_notifications standard notification (if MethodChannel fails).
  static Future<void> showLiveNotification({String? outletName}) async {
    if (!Platform.isAndroid) return;
    await _initNotifications();

    final name = outletName ?? _session?.outletName ?? 'Absensi Enakko';

    // PRIMARY: custom RemoteViews notification via KioskNotificationHelper.kt
    // invokeMethod<bool> reads the Boolean Kotlin returns:
    //   true  = notification successfully posted
    //   false = SecurityException — POST_NOTIFICATIONS denied (triggers fallback)
    //   null  = channel unavailable / activity dead (triggers fallback)
    bool methodChannelOk = false;
    try {
      final result = await _notifChannel.invokeMethod<bool>('show', {
        'title': name,
        'body': 'Tempelkan kartu NFC untuk absensi',
      });
      methodChannelOk = result == true;
      debugPrint(
          '[BgService] showLiveNotification MethodChannel result: $result');
    } catch (e) {
      debugPrint('[BgService] showLiveNotification MethodChannel error: $e');
    }

    // Fallback: standard flutter_local_notifications (only if MethodChannel failed)
    if (!methodChannelOk) {
      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      const androidDetails = AndroidNotificationDetails(
        'absensi_enakko_pill',
        'Kiosk Status',
        channelDescription:
            'Status kiosk absensi aktif — notifikasi live real-time',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        showWhen: true,
        category: AndroidNotificationCategory.service,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
      );

      try {
        await _notifPlugin.show(
          300,
          name,
          'Kiosk aktif · $timeStr · Tempelkan kartu NFC',
          const NotificationDetails(android: androidDetails),
        );
        debugPrint('[BgService] showLiveNotification (fallback) OK: $name');
      } catch (e) {
        debugPrint('[BgService] showLiveNotification fallback error: $e');
      }
    }
  }

  /// Update the Live Activity notification with new body text.
  /// Primary: MethodChannel (custom RemoteViews). Fallback: flutter_local_notifications.
  static Future<void> updateLiveNotification(
      {String? outletName, String? body}) async {
    if (!Platform.isAndroid) return;
    await _initNotifications();

    final name = outletName ?? _session?.outletName ?? 'Absensi Enakko';
    final text = body ?? 'Tempelkan kartu NFC untuk absensi';

    // PRIMARY: custom RemoteViews update via MethodChannel (reads Boolean return)
    bool methodChannelOk = false;
    try {
      final result = await _notifChannel.invokeMethod<bool>('update', {
        'title': name,
        'body': text,
      });
      methodChannelOk = result == true;
    } catch (_) {}

    // Fallback: standard notification (only if MethodChannel failed)
    if (!methodChannelOk) {
      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      const androidDetails = AndroidNotificationDetails(
        'absensi_enakko_pill',
        'Kiosk Status',
        channelDescription:
            'Status kiosk absensi aktif — notifikasi live real-time',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        showWhen: true,
        category: AndroidNotificationCategory.service,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
      );

      try {
        await _notifPlugin.show(
          300,
          name,
          '$text · $timeStr',
          const NotificationDetails(android: androidDetails),
        );
      } catch (e) {
        debugPrint('[BgService] updateLiveNotification fallback error: $e');
      }
    }
  }

  /// Dismiss the Live Activity notification.
  static Future<void> dismissLiveNotification() async {
    if (!Platform.isAndroid) return;
    try {
      await _notifPlugin.cancel(300);
    } catch (_) {}
    try {
      await _notifChannel.invokeMethod('dismiss', {});
    } catch (_) {}
  }

  // ── Public Overlay Methods ────────────────────────────────────────────────

  /// Show the floating Dynamic Island pill overlay.
  /// Can be called from anywhere (e.g., app lifecycle observer).
  /// [outletName] is shown on the pill. If null, uses cached session name.
  static Future<OverlayShowResult> showOverlayPill({String? outletName}) async {
    final idleState = _buildIdleOverlayState(
      outletName: outletName ?? _session?.outletName,
      at: DateTime.now(),
    );
    final result = await ensureOverlayVisible(idleState);
    debugPrint('[BgService] showOverlayPill wrapper result=$result');
    return result;
  }

  static Future<OverlayShowResult> ensureOverlayVisible(
    OverlayPillState state,
  ) async {
    if (!Platform.isAndroid) {
      debugPrint(
        '[BgService] ensureOverlayVisible result=showFailed reason=unsupported-platform',
      );
      return OverlayShowResult.showFailed;
    }
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        debugPrint('[BgService] ensureOverlayVisible result=permissionDenied');
        return OverlayShowResult.permissionDenied;
      }

      final wasActive = await FlutterOverlayWindow.isActive();
      if (!wasActive) {
        // Primary attempt: compact floating window sized around the pill.
        await FlutterOverlayWindow.showOverlay(
          height: _kOverlayWindowHeight,
          width: _kOverlayWindowWidth,
          alignment: OverlayAlignment.topCenter,
          flag: OverlayFlag.focusPointer,
          enableDrag: false,
          positionGravity: PositionGravity.none,
          startPosition: const OverlayPosition(0, 0),
        );

        var active = await _waitForOverlayActive();
        if (!active) {
          // OEM fallback: some devices reject compact sizing on first open.
          debugPrint(
            '[BgService] ensureOverlayVisible compact show not active, retrying with matchParent fallback',
          );
          await FlutterOverlayWindow.showOverlay(
            height: WindowSize.matchParent,
            width: WindowSize.matchParent,
            alignment: OverlayAlignment.topCenter,
            flag: OverlayFlag.focusPointer,
            enableDrag: false,
            positionGravity: PositionGravity.none,
            startPosition: const OverlayPosition(0, 0),
          );
        }
      }

      final active = await _waitForOverlayActive();
      if (!active) {
        debugPrint(
          '[BgService] ensureOverlayVisible result=showFailed reason=inactive-after-show',
        );
        return OverlayShowResult.showFailed;
      }

      await FlutterOverlayWindow.shareData(state.toWirePayload());
      debugPrint(
        '[BgService] ensureOverlayVisible result=shown mode=${state.mode.name} wasActive=$wasActive',
      );
      return OverlayShowResult.shown;
    } catch (e) {
      debugPrint('[BgService] ensureOverlayVisible result=showFailed error=$e');
      return OverlayShowResult.showFailed;
    }
  }

  static Future<void> updateOverlayState(OverlayPillState state) async {
    if (!Platform.isAndroid) return;
    try {
      final active = await FlutterOverlayWindow.isActive();
      if (!active) {
        debugPrint('[BgService] updateOverlayState skipped=overlayInactive');
        return;
      }
      await FlutterOverlayWindow.shareData(state.toWirePayload());
      debugPrint(
          '[BgService] updateOverlayState pushed mode=${state.mode.name}');
    } catch (e) {
      debugPrint('[BgService] updateOverlayState error=$e');
    }
  }

  /// Hide the floating Dynamic Island pill overlay.
  static Future<void> hideOverlayPill() async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (e) {
      debugPrint('[BgService] hideOverlayPill error: $e');
    }
  }

  /// Request overlay permission from the user.
  /// Returns true if permission is already granted.
  static Future<bool> requestOverlayPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (granted) return true;
      await FlutterOverlayWindow.requestPermission();
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (e) {
      debugPrint('[BgService] requestOverlayPermission error: $e');
      return false;
    }
  }

  // ── Rotating notification ─────────────────────────────────────────────────

  static Future<void> _rotateNotification() async {
    final session = _session;
    if (session == null) return;

    _showingTime = !_showingTime;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final body = _showingTime ? timeStr : 'Tempelkan kartu NFC untuk absensi';

    // Update keepalive service text (low-priority, mostly background)
    FlutterForegroundTask.updateService(
      notificationTitle: session.outletName,
      notificationText: body,
    );

    // Update custom Live Activity notification (the Grab-style primary approach)
    await updateLiveNotification(outletName: session.outletName, body: body);

    // Update floating overlay data (best-effort, may fail on some OEMs)
    final idleOverlayState =
        _buildIdleOverlayState(outletName: session.outletName, at: now);
    await updateOverlayState(idleOverlayState);
  }

  static OverlayPillState _buildIdleOverlayState({
    String? outletName,
    DateTime? at,
  }) {
    final effectiveOutlet = (outletName ?? '').trim();
    final now = at ?? DateTime.now();
    return OverlayPillState(
      mode: OverlayPillMode.idle,
      outlet: effectiveOutlet.isEmpty
          ? OverlayPillState.defaultOutlet
          : effectiveOutlet,
      time: _formatClock(now),
      attendanceType: OverlayPillState.defaultAttendanceType,
      accentHex: OverlayPillState.defaultAccentHex,
      eventUntilEpochMs: 0,
      expanded: true,
    );
  }

  static String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static Future<bool> _waitForOverlayActive() async {
    final deadline = DateTime.now().add(_kOverlayActivationTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await FlutterOverlayWindow.isActive()) {
        return true;
      }
      await Future.delayed(_kOverlayActivationPoll);
    }
    return FlutterOverlayWindow.isActive();
  }

  // ── Scan heads-up notification ────────────────────────────────────────────

  /// Show a high-priority heads-up notification after NFC scan.
  /// Tapping it opens the app to /kiosk/scan (3 pilihan absen).
  static Future<void> showScanNotification(String employeeName) async {
    await _initNotifications();

    const androidDetails = AndroidNotificationDetails(
      '${_kChannelId}_scan',
      'Scan NFC Absensi',
      channelDescription: 'Notifikasi setelah scan NFC berhasil',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'NFC scan',
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: false,
      autoCancel: true,
      ongoing: false,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifPlugin.show(
      _kNotifIdScan,
      'Halo, $employeeName!',
      'Tap untuk memilih jenis absensi',
      details,
      payload: 'kiosk_scan',
    );
  }

  // ── Cancel scan notification ──────────────────────────────────────────────

  static Future<void> cancelScanNotification() async {
    await _notifPlugin.cancel(_kNotifIdScan);
  }
}

// ---------------------------------------------------------------------------
// Foreground task callback (runs in isolate)
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_KioskTaskHandler());
}

class _KioskTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[TaskHandler] onStart');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Called every 10s — no-op here, rotation handled in main isolate
    debugPrint('[TaskHandler] onRepeatEvent');
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('[TaskHandler] onDestroy');
  }
}
