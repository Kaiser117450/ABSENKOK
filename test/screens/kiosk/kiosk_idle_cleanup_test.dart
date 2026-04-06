import 'dart:async';

import 'package:absensi_enakko_flutter/screens/kiosk/kiosk_idle_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('triggerKioskIdleNfcCleanup invokes async cleanup immediately',
      () async {
    final completer = Completer<void>();
    var callCount = 0;

    triggerKioskIdleNfcCleanup(() async {
      callCount += 1;
      completer.complete();
    });

    await completer.future;
    expect(callCount, 1);
  });

  test('triggerKioskIdleNfcCleanup ignores null cleanup', () {
    triggerKioskIdleNfcCleanup(null);
  });
}
