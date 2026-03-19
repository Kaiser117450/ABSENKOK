import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../models/kiosk_session.dart';

/// Central Sentry helper for the Enakko kiosk app.
///
/// Responsibilities:
/// - [beforeSend]: filters benign NFC session noise so it never reaches Sentry.
/// - [captureBackgroundFailure]: reports final-retry background failures with
///   outlet/device context tags and a 15-minute per-fingerprint throttle.
class SentryService {
  // ── NFC noise filtering ──────────────────────────────────────────────────

  /// Lowercase substrings that identify benign NFC tag-lost exceptions.
  /// Any Sentry event whose exception message contains one of these is dropped.
  static const List<String> _nfcNoisePatterns = [
    'tag was lost',
    'tag connection lost',
    'taglostexception',
    'nfc session invalidated',
    'transceive fail',
    'tipe kartu nfc tidak didukung',
  ];

  /// Sentry `beforeSend` hook.
  ///
  /// Returns `null` (drops the event) if every matched exception is NFC noise.
  /// Returns the original event unchanged for all other exceptions.
  static FutureOr<SentryEvent?> beforeSend(
      SentryEvent event, Hint hint) {
    final exceptions = event.exceptions;
    if (exceptions == null || exceptions.isEmpty) return event;

    for (final ex in exceptions) {
      final msg = (ex.value ?? '').toLowerCase();
      if (_isNfcNoise(msg)) return null;
    }
    return event;
  }

  static bool _isNfcNoise(String message) {
    for (final pattern in _nfcNoisePatterns) {
      if (message.contains(pattern)) return true;
    }
    return false;
  }

  // ── Background failure capture ───────────────────────────────────────────

  static const Duration _throttleWindow = Duration(minutes: 15);
  static final Map<String, DateTime> _lastReportedAt = {};

  /// Report a background failure to Sentry with outlet/device context tags.
  ///
  /// Throttled to one report per 15-minute window per
  /// `operation:exceptionType` fingerprint to avoid alert fatigue.
  static Future<void> captureBackgroundFailure({
    required Object exception,
    required StackTrace stackTrace,
    required String operation,
    KioskSession? session,
  }) async {
    final fingerprint = '$operation:${exception.runtimeType}';
    if (!_shouldReport(fingerprint)) return;

    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('source', 'background');
        scope.setTag('operation', operation);
        if (session != null) {
          scope.setTag('outlet_id', session.outletId);
          scope.setTag('outlet_name', session.outletName);
          scope.setTag('device_id', session.deviceId);
        }
      },
    );
  }

  static bool _shouldReport(String fingerprint) {
    final last = _lastReportedAt[fingerprint];
    if (last != null &&
        DateTime.now().difference(last) < _throttleWindow) {
      return false;
    }
    _lastReportedAt[fingerprint] = DateTime.now();
    return true;
  }

  // ── Testing helpers ──────────────────────────────────────────────────────

  /// Resets throttle state. Only for use in tests.
  @visibleForTesting
  static void resetThrottleForTesting() {
    _lastReportedAt.clear();
  }

  /// Exposes [_shouldReport] for unit testing.
  @visibleForTesting
  static bool shouldReportForTesting(String fingerprint) {
    return _shouldReport(fingerprint);
  }
}
