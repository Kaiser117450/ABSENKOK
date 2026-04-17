import 'dart:async';

import 'package:absensi_enakko_flutter/services/nfc_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake driver that captures the lifecycle calls emitted by [NfcService]
/// and exposes a way for tests to fire discovery and error events
/// synchronously, without any dependency on the `nfc_manager` plugin or
/// a real [NfcTag].
class _FakeDriver implements NfcSessionDriver {
  final List<String> calls = <String>[];
  bool available = true;
  int startCount = 0;
  int stopCount = 0;

  Future<void> Function(String? Function() extractUid)? _onDiscovered;
  void Function(Object error)? _onError;

  /// If non-null, the next [startSession] call awaits this future before
  /// completing — lets tests pin a start call "in flight" and assert the
  /// service waits for it.
  Completer<void>? pendingStart;

  /// If non-null, the next [stopSession] call awaits this future before
  /// completing — lets tests pin a stop call "in flight" and assert the
  /// service waits for it.
  Completer<void>? pendingStop;

  bool get isActive => _onDiscovered != null;

  @override
  Future<bool> isAvailable() async {
    calls.add('isAvailable');
    return available;
  }

  @override
  Future<void> startSession({
    required Future<void> Function(String? Function() extractUid) onDiscovered,
    void Function(Object error)? onError,
  }) async {
    startCount++;
    calls.add('startSession#$startCount');
    _onDiscovered = onDiscovered;
    _onError = onError;
    final gate = pendingStart;
    if (gate != null) {
      pendingStart = null;
      await gate.future;
    }
  }

  @override
  Future<void> stopSession() async {
    stopCount++;
    calls.add('stopSession#$stopCount');
    final gate = pendingStop;
    if (gate != null) {
      pendingStop = null;
      await gate.future;
    }
    _onDiscovered = null;
    _onError = null;
  }

  /// Fire a discovery event whose UID extractor returns [uid]. When [uid]
  /// is null, mimics the "unsupported card" case.
  Future<void> fireDiscovery(String? uid) async {
    final handler = _onDiscovered;
    if (handler == null) {
      throw StateError('No active session; cannot fire discovery');
    }
    await handler(() => uid);
  }

  Future<void> fireError(Object error) async {
    _onError?.call(error);
    // Give any async cleanup inside the service a chance to schedule.
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeDriver driver;

  setUp(() {
    driver = _FakeDriver();
    NfcService.debugDriverOverride = driver;
  });

  tearDown(() {
    NfcService.debugDriverOverride = null;
  });

  group('NfcService defaults', () {
    test('isAvailable starts false before init()', () {
      expect(NfcService.isAvailable, isFalse);
    });

    test('init() returns driver availability and caches it', () async {
      driver.available = true;
      expect(await NfcService.init(), isTrue);
      expect(NfcService.isAvailable, isTrue);

      driver.available = false;
      expect(await NfcService.init(), isFalse);
      expect(NfcService.isAvailable, isFalse);
    });

    test('init() swallows driver errors and returns false', () async {
      NfcService.debugDriverOverride = _ThrowingAvailabilityDriver();
      expect(await NfcService.init(), isFalse);
      NfcService.debugDriverOverride = driver;
    });
  });

  group('startRegistrationListener', () {
    test('delivers a valid UID exactly once then stops the session',
        () async {
      final uids = <String>[];
      final errors = <Object>[];
      final cleanup = NfcService.startRegistrationListener(
        uids.add,
        errors.add,
      );

      // Allow the enqueued startSession to run.
      await Future<void>.delayed(Duration.zero);
      expect(driver.startCount, 1);

      await driver.fireDiscovery('AA:BB:CC:DD');
      // Drain the microtask / enqueued stop.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(uids, ['AA:BB:CC:DD']);
      expect(errors, isEmpty);
      expect(driver.stopCount, 1);
      expect(driver.isActive, isFalse);

      await cleanup();
      // Cleanup after a successful claim must not double-stop.
      expect(driver.stopCount, 1);
    });

    test('drops duplicate discovery events delivered for a single tap',
        () async {
      final uids = <String>[];
      final cleanup = NfcService.startRegistrationListener(
        uids.add,
        null,
      );
      await Future<void>.delayed(Duration.zero);

      // Android delivers duplicate onDiscovered callbacks back-to-back
      // before Dart's microtask queue can tear the session down. We
      // simulate that by firing three discoveries concurrently — each
      // call synchronously snapshots the still-live handler reference.
      // Only the first should win; the `claimed` guard inside the
      // service must drop the duplicates before the session stop runs.
      await Future.wait([
        driver.fireDiscovery('04:11:22:33'),
        driver.fireDiscovery('04:11:22:33'),
        driver.fireDiscovery('04:99:99:99'),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(uids, ['04:11:22:33']);
      await cleanup();
    });

    test('unsupported card fires onError AND tears the session down',
        () async {
      final uids = <String>[];
      final errors = <Object>[];
      final cleanup = NfcService.startRegistrationListener(
        uids.add,
        errors.add,
      );
      await Future<void>.delayed(Duration.zero);

      await driver.fireDiscovery(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(uids, isEmpty);
      expect(errors, hasLength(1));
      expect(errors.first, isA<Exception>());
      expect(driver.stopCount, 1);
      expect(driver.isActive, isFalse);

      await cleanup();
    });

    test('cleanup after unsupported card does not double-stop', () async {
      final errors = <Object>[];
      final cleanup = NfcService.startRegistrationListener(
        (_) {},
        errors.add,
      );
      await Future<void>.delayed(Duration.zero);

      await driver.fireDiscovery(null);
      await Future<void>.delayed(Duration.zero);

      await cleanup();
      expect(driver.stopCount, 1);
    });

    test('rapid stop → start serializes — new start waits for old stop',
        () async {
      // Session 1 — successful scan, claims session.
      final session1Uids = <String>[];
      final cleanup1 = NfcService.startRegistrationListener(
        session1Uids.add,
        null,
      );
      await Future<void>.delayed(Duration.zero);
      expect(driver.startCount, 1);

      // Pin the stop so cleanup1 is "in flight".
      final pendingStop = Completer<void>();
      driver.pendingStop = pendingStop;
      final cleanupFuture = cleanup1();

      // Synchronously start session 2 BEFORE session 1's stop has resolved.
      // This is the "Scan Ulang quickly after success" path.
      final session2Uids = <String>[];
      final cleanup2 = NfcService.startRegistrationListener(
        session2Uids.add,
        null,
      );

      // Yield the microtask queue a few times; session 2's start must not
      // have been dispatched yet because the stop is still pending.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(driver.startCount, 1,
          reason: 'Second start must not run before first stop resolves');

      // Release the stop — session 2's start is now free to execute.
      pendingStop.complete();
      await cleanupFuture;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(driver.startCount, 2);

      // Session 2 still works normally.
      await driver.fireDiscovery('04:A1:B2:C3');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(session1Uids, isEmpty);
      expect(session2Uids, ['04:A1:B2:C3']);

      await cleanup2();
    });

    test('cleanup before any discovery stops the session and drops callbacks',
        () async {
      final uids = <String>[];
      final errors = <Object>[];
      final cleanup = NfcService.startRegistrationListener(
        uids.add,
        errors.add,
      );
      await Future<void>.delayed(Duration.zero);

      await cleanup();
      expect(driver.stopCount, 1);

      // Session is dead; firing discovery must be impossible because the
      // driver has cleared its handler.
      expect(() => driver.fireDiscovery('04:00:00:00'),
          throwsA(isA<StateError>()));
      expect(uids, isEmpty);
      expect(errors, isEmpty);
    });

    test('driver onError before any scan surfaces as onError and stops',
        () async {
      final errors = <Object>[];
      final cleanup = NfcService.startRegistrationListener(
        (_) {},
        errors.add,
      );
      await Future<void>.delayed(Duration.zero);

      await driver.fireError(StateError('native boom'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.first, isA<StateError>());
      expect(driver.stopCount, 1);

      await cleanup();
    });
  });

  group('startListener (kiosk persistent session)', () {
    test('cleanup truly awaits the native stop', () async {
      final cleanup = NfcService.startListener((_) {}, null);
      await Future<void>.delayed(Duration.zero);
      expect(driver.startCount, 1);

      final pendingStop = Completer<void>();
      driver.pendingStop = pendingStop;

      var cleanupResolved = false;
      final cleanupFuture = cleanup().whenComplete(() {
        cleanupResolved = true;
      });

      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(cleanupResolved, isFalse,
          reason: 'cleanup must not resolve until stopSession resolves');

      pendingStop.complete();
      await cleanupFuture;
      expect(cleanupResolved, isTrue);
      expect(driver.stopCount, 1);
    });
  });
}

class _ThrowingAvailabilityDriver implements NfcSessionDriver {
  @override
  Future<bool> isAvailable() => Future.error(StateError('no nfc hw'));

  @override
  Future<void> startSession({
    required Future<void> Function(String? Function() extractUid) onDiscovered,
    void Function(Object error)? onError,
  }) async {}

  @override
  Future<void> stopSession() async {}
}
