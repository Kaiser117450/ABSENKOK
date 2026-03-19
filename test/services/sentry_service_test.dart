import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:absensi_enakko_flutter/services/sentry_service.dart';

// Helper: creates a SentryEvent with a single exception whose value is [message].
SentryEvent _eventWithMessage(String message) {
  return SentryEvent(
    exceptions: [
      SentryException(
        type: 'TestException',
        value: message,
      ),
    ],
  );
}

void main() {
  group('beforeSend NFC filter', () {
    test('drops "Tag was lost" exception', () async {
      final event = _eventWithMessage('Tag was lost');
      final result = await SentryService.beforeSend(event, Hint());
      expect(result, isNull);
    });

    test('drops "taglostexception" (case-insensitive)', () async {
      final event = _eventWithMessage('TagLostException occurred');
      final result = await SentryService.beforeSend(event, Hint());
      expect(result, isNull);
    });

    test('drops "transceive fail" message', () async {
      final event = _eventWithMessage('transceive fail on card read');
      final result = await SentryService.beforeSend(event, Hint());
      expect(result, isNull);
    });

    test('drops "nfc session invalidated" message', () async {
      final event = _eventWithMessage('NFC session invalidated by user');
      final result = await SentryService.beforeSend(event, Hint());
      expect(result, isNull);
    });

    test('drops "tipe kartu nfc tidak didukung" message', () async {
      final event =
          _eventWithMessage('Tipe Kartu NFC Tidak Didukung pada perangkat ini');
      final result = await SentryService.beforeSend(event, Hint());
      expect(result, isNull);
    });

    test('drops "tag connection lost" message', () async {
      final event = _eventWithMessage('tag connection lost during read');
      final result = await SentryService.beforeSend(event, Hint());
      expect(result, isNull);
    });

    test('passes through a non-NFC exception', () async {
      final event = _eventWithMessage('database connection failed');
      final result = await SentryService.beforeSend(event, Hint());
      expect(result, same(event));
    });

    test('passes through event with empty exceptions list', () async {
      final event = SentryEvent(exceptions: []);
      final result = await SentryService.beforeSend(event, Hint());
      expect(result, same(event));
    });

    test('passes through event with null exceptions', () async {
      final event = SentryEvent();
      final result = await SentryService.beforeSend(event, Hint());
      expect(result, same(event));
    });
  });

  group('shouldReport throttle', () {
    setUp(() {
      // Reset throttle state between tests
      SentryService.resetThrottleForTesting();
    });

    test('returns true on first call for a fingerprint', () {
      final result = SentryService.shouldReportForTesting('heartbeat:SocketException');
      expect(result, isTrue);
    });

    test('returns false on second call within 15 minutes for same fingerprint',
        () {
      SentryService.shouldReportForTesting('heartbeat:SocketException');
      final result = SentryService.shouldReportForTesting('heartbeat:SocketException');
      expect(result, isFalse);
    });

    test(
        'returns true for a different fingerprint even if another is throttled',
        () {
      SentryService.shouldReportForTesting('heartbeat:SocketException');
      // same fingerprint → throttled
      expect(SentryService.shouldReportForTesting('heartbeat:SocketException'),
          isFalse);
      // different fingerprint → not throttled
      expect(
          SentryService.shouldReportForTesting('pollContent:TimeoutException'),
          isTrue);
    });
  });
}
