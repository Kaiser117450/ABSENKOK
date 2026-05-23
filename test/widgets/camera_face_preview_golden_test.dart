import 'dart:math' as math;

import 'package:absensi_enakko_flutter/widgets/face_capture_state_machine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _OvalGuidePainter extends CustomPainter {
  final Color borderColor;
  final CaptureState state;
  const _OvalGuidePainter({required this.borderColor, required this.state});

  Rect _ovalRect(Size size) {
    final width = size.width * 0.68;
    final height = size.height * 0.58;
    final left = (size.width - width) / 2;
    final top = size.height * 0.14;
    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final oval = _ovalRect(size);
    final maskPath = Path()
      ..addRect(Offset.zero & size)
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    final stroke = state == CaptureState.promptBlink ||
            state == CaptureState.capturing ||
            state == CaptureState.done
        ? 5.0
        : 3.0;
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = borderColor,
    );
    if (state == CaptureState.aligning) {
      canvas.drawArc(
        oval.deflate(2),
        -math.pi / 2,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = borderColor.withValues(alpha: 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OvalGuidePainter old) =>
      old.borderColor != borderColor || old.state != state;
}

Widget _wrap(CaptureState s, Color c) => RepaintBoundary(
      child: SizedBox(
        width: 360,
        height: 480,
        child: CustomPaint(
          painter: _OvalGuidePainter(borderColor: c, state: s),
        ),
      ),
    );

void main() {
  testWidgets('oval searching golden', (tester) async {
    await tester.pumpWidget(_wrap(CaptureState.searching, Colors.white));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('goldens/oval_searching.png'),
    );
  });

  testWidgets('oval aligning golden', (tester) async {
    await tester.pumpWidget(_wrap(CaptureState.aligning, Colors.white));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('goldens/oval_aligning.png'),
    );
  });

  testWidgets('oval promptBlink golden', (tester) async {
    await tester.pumpWidget(_wrap(CaptureState.promptBlink, const Color(0xFF22C55E)));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('goldens/oval_prompt_blink.png'),
    );
  });

  testWidgets('oval retry golden', (tester) async {
    await tester.pumpWidget(_wrap(CaptureState.retry, Colors.amber));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('goldens/oval_retry.png'),
    );
  });
}
