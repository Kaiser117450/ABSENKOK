import 'dart:ui';

import 'package:absensi_enakko_flutter/services/face_detection_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = FaceDetectionService.instance;
  const frame = Size(720, 1280);

  Rect bbox(double widthRatio, {double offsetRatio = 0}) {
    final w = frame.width * widthRatio;
    final cx = frame.width / 2 + (frame.width * offsetRatio);
    return Rect.fromCenter(
      center: Offset(cx, frame.height / 2),
      width: w,
      height: w,
    );
  }

  test('returns absent when no face', () {
    expect(
      service.debugResolveAlignment(
        faceCount: 0,
        boundingBox: Rect.zero,
        headEulerY: 0,
        frameSize: frame,
      ),
      FaceAlignment.absent,
    );
  });

  test('returns tilted when euler > 15', () {
    expect(
      service.debugResolveAlignment(
        faceCount: 1,
        boundingBox: bbox(0.7),
        headEulerY: 20,
        frameSize: frame,
      ),
      FaceAlignment.tilted,
    );
  });

  test('returns tooSmall when width below 0.55', () {
    expect(
      service.debugResolveAlignment(
        faceCount: 1,
        boundingBox: bbox(0.40),
        headEulerY: 0,
        frameSize: frame,
      ),
      FaceAlignment.tooSmall,
    );
  });

  test('returns tooBig when width above 0.95', () {
    expect(
      service.debugResolveAlignment(
        faceCount: 1,
        boundingBox: bbox(0.97),
        headEulerY: 0,
        frameSize: frame,
      ),
      FaceAlignment.tooBig,
    );
  });

  test('returns offCenter when centre offset > 0.15', () {
    expect(
      service.debugResolveAlignment(
        faceCount: 1,
        boundingBox: bbox(0.7, offsetRatio: 0.2),
        headEulerY: 0,
        frameSize: frame,
      ),
      FaceAlignment.offCenter,
    );
  });

  test('returns aligned for ideal placement', () {
    expect(
      service.debugResolveAlignment(
        faceCount: 1,
        boundingBox: bbox(0.7),
        headEulerY: 5,
        frameSize: frame,
      ),
      FaceAlignment.aligned,
    );
  });

  test('bothEyesClosed when both probabilities < 0.30', () {
    final r = FaceDetectionResult(
      hasFace: true,
      faceCount: 1,
      alignment: FaceAlignment.aligned,
      leftEyeOpen: 0.2,
      rightEyeOpen: 0.15,
    );
    expect(r.bothEyesClosed, isTrue);
    expect(r.bothEyesOpen, isFalse);
  });

  test('bothEyesOpen when both probabilities > 0.70', () {
    final r = FaceDetectionResult(
      hasFace: true,
      faceCount: 1,
      alignment: FaceAlignment.aligned,
      leftEyeOpen: 0.85,
      rightEyeOpen: 0.9,
    );
    expect(r.bothEyesOpen, isTrue);
    expect(r.bothEyesClosed, isFalse);
  });
}
