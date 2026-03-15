import 'dart:async';
import 'dart:convert';

import 'package:absensi_enakko_flutter/overlay_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KioskOverlayUI', () {
    late StreamController<String> stream;

    setUp(() {
      stream = StreamController<String>.broadcast();
    });

    tearDown(() async {
      await stream.close();
    });

    Future<void> pumpOverlay(
      WidgetTester tester, {
      Color background = Colors.white,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColoredBox(
            color: background,
            child: KioskOverlayUI(
              dataStream: stream.stream,
              autoCollapseDelay: const Duration(hours: 1),
              clockTick: const Duration(hours: 1),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
      'idle payload renders outlet time and attendance accent indicator',
      (tester) async {
        await pumpOverlay(tester);

        stream.add(
          _payload(
            mode: 'idle',
            outlet: 'Gerai Braga',
            time: '09:30',
            attendanceType: 'pulang',
            accentHex: '#6B7280',
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        final outlet = tester.widget<Text>(
          find.byKey(const Key('overlay-pill-outlet')),
        );
        final attendance = tester.widget<Text>(
          find.byKey(const Key('overlay-pill-attendance')),
        );
        final time = tester.widget<Text>(
          find.byKey(const Key('overlay-pill-time')),
        );

        expect(outlet.data, 'Gerai Braga');
        expect(attendance.data, 'Pulang');
        expect(time.data, '09:30');
        expect(find.byKey(const Key('overlay-pill-accent')), findsOneWidget);
      },
    );

    testWidgets('event payload reverts to idle after timeout', (tester) async {
      await pumpOverlay(tester);

      stream.add(
        _payload(
          mode: 'idle',
          outlet: 'Gerai Dipatiukur',
          time: '08:00',
          attendanceType: 'masuk',
          accentHex: '#22C55E',
        ),
      );
      await tester.pump();

      stream.add(
        _payload(
          mode: 'event',
          outlet: 'Gerai Dipatiukur',
          time: '08:01',
          attendanceType: 'pulang',
          accentHex: '#6B7280',
          eventUntilEpochMs:
              DateTime.now().millisecondsSinceEpoch + 900,
        ),
      );
      await tester.pump();

      expect(find.text('Event aktif'), findsOneWidget);
      expect(find.text('Pulang'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      expect(find.text('Event aktif'), findsNothing);
      expect(find.text('Kiosk aktif'), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
    });

    testWidgets('tap toggles expanded and minimized layouts', (tester) async {
      await pumpOverlay(tester);

      stream.add(_payload());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('overlay-pill-outlet')), findsOneWidget);
      expect(
        find.byKey(const Key('overlay-pill-collapsed-status')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('overlay-pill-root')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('overlay-pill-outlet')), findsNothing);
      expect(
        find.byKey(const Key('overlay-pill-collapsed-status')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('overlay-pill-root')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('overlay-pill-outlet')), findsOneWidget);
      expect(
        find.byKey(const Key('overlay-pill-collapsed-status')),
        findsNothing,
      );
    });

    testWidgets('legacy delimiter payload renders without crash', (tester) async {
      await pumpOverlay(tester);

      stream.add('Legacy Outlet|10:15');
      await tester.pump();
      await tester.pumpAndSettle();

      final outlet = tester.widget<Text>(
        find.byKey(const Key('overlay-pill-outlet')),
      );
      final time = tester.widget<Text>(
        find.byKey(const Key('overlay-pill-time')),
      );
      expect(outlet.data, 'Legacy Outlet');
      expect(time.data, '10:15');
    });

    testWidgets(
      'readability remains visible on light backgrounds',
      (tester) async {
        const background = Colors.white;
        await pumpOverlay(tester, background: background);

        stream.add(_payload(accentHex: '#22C55E'));
        await tester.pump();

        _expectReadableContrast(tester);
      },
    );

    testWidgets(
      'readability remains visible on dark backgrounds',
      (tester) async {
        const background = Color(0xFF050505);
        await pumpOverlay(tester, background: background);

        stream.add(_payload(accentHex: '#22C55E'));
        await tester.pump();

        _expectReadableContrast(tester);
      },
    );

    testWidgets(
      'displayLabel payload renders custom text instead of enum label',
      (tester) async {
        await pumpOverlay(tester);

        stream.add(
          _payload(
            attendanceType: 'masuk',
            displayLabel: '🍽️ Budi istirahat',
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        final attendance = tester.widget<Text>(
          find.byKey(const Key('overlay-pill-attendance')),
        );
        expect(attendance.data, '🍽️ Budi istirahat');
        // Must NOT show the enum label 'Masuk'
        expect(find.text('Masuk'), findsNothing);
      },
    );

    testWidgets(
      'empty displayLabel falls back to attendanceType label',
      (tester) async {
        await pumpOverlay(tester);

        stream.add(
          _payload(
            attendanceType: 'pulang',
            displayLabel: '',
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        final attendance = tester.widget<Text>(
          find.byKey(const Key('overlay-pill-attendance')),
        );
        expect(attendance.data, 'Pulang');
      },
    );

    testWidgets(
      'displayLabel with break accent shows amber color',
      (tester) async {
        await pumpOverlay(tester);

        stream.add(
          _payload(
            attendanceType: 'break',
            accentHex: '#F59E0B',
            displayLabel: '🍽️ Sari istirahat',
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        final attendance = tester.widget<Text>(
          find.byKey(const Key('overlay-pill-attendance')),
        );
        expect(attendance.data, '🍽️ Sari istirahat');

        // Verify accent dot has amber color
        final accentDot = tester.widget<Container>(
          find.byKey(const Key('overlay-pill-accent')).first,
        );
        final dotColor =
            (accentDot.decoration as BoxDecoration?)?.color;
        // #F59E0B = 0xFFF59E0B
        expect(dotColor, const Color(0xFFF59E0B));
      },
    );

    testWidgets(
      'fun fact displayLabel shows in idle mode',
      (tester) async {
        await pumpOverlay(tester);

        stream.add(
          _payload(
            attendanceType: 'masuk',
            accentHex: '#22C55E',
            displayLabel: 'Hari ini 12/14 hadir 🎉',
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        final attendance = tester.widget<Text>(
          find.byKey(const Key('overlay-pill-attendance')),
        );
        expect(attendance.data, 'Hari ini 12/14 hadir 🎉');
      },
    );
  });
}

String _payload({
  String mode = 'idle',
  String outlet = 'Gerai Cihampelas',
  String time = '08:30',
  String attendanceType = 'masuk',
  String accentHex = '#22C55E',
  int eventUntilEpochMs = 0,
  String displayLabel = '',
}) {
  return jsonEncode({
    'v': 1,
    'mode': mode,
    'outlet': outlet,
    'time': time,
    'attendanceType': attendanceType,
    'accentHex': accentHex,
    'eventUntilEpochMs': eventUntilEpochMs,
    'expanded': true,
    'displayLabel': displayLabel,
  });
}

void _expectReadableContrast(WidgetTester tester) {
  const pillSurface = Color(0xFF1C1C1E);
  final outletText =
      tester.widget<Text>(find.byKey(const Key('overlay-pill-outlet')));
  final attendanceText =
      tester.widget<Text>(find.byKey(const Key('overlay-pill-attendance')));
  final accentDot = tester.widget<Container>(
    find.byKey(const Key('overlay-pill-accent')).first,
  );

  final outletColor = outletText.style?.color ?? Colors.white;
  final attendanceColor = attendanceText.style?.color ?? Colors.white;
  final accentColor =
      (accentDot.decoration as BoxDecoration?)?.color ?? Colors.white;

  expect(_contrastDistance(outletColor, pillSurface), greaterThan(0.75));
  expect(_contrastDistance(attendanceColor, pillSurface), greaterThan(0.65));
  expect(_contrastDistance(accentColor, pillSurface), greaterThan(0.25));
}

double _contrastDistance(Color a, Color b) {
  return (a.computeLuminance() - b.computeLuminance()).abs();
}
