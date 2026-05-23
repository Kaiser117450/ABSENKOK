import 'dart:ui';

import 'package:absensi_enakko_flutter/core/constants.dart';
import 'package:absensi_enakko_flutter/services/face_detection_service.dart';
import 'package:absensi_enakko_flutter/widgets/face_capture_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

FaceDetectionResult _r({
  required FaceAlignment alignment,
  double leftEye = 0.9,
  double rightEye = 0.9,
}) =>
    FaceDetectionResult(
      hasFace: alignment != FaceAlignment.absent,
      faceCount: alignment == FaceAlignment.absent ? 0 : 1,
      alignment: alignment,
      leftEyeOpen: leftEye,
      rightEyeOpen: rightEye,
      boundingBox: Rect.zero,
      headEulerAngleY: 0,
    );

void main() {
  late FaceCaptureStateMachine fsm;
  late DateTime t0;
  DateTime laterMs(int ms) => t0.add(Duration(milliseconds: ms));

  setUp(() {
    fsm = FaceCaptureStateMachine();
    t0 = DateTime(2026, 5, 23, 7, 0, 0);
  });

  test('starts searching', () {
    expect(fsm.state, CaptureState.searching);
  });

  test('searching -> aligning on aligned', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    expect(fsm.state, CaptureState.aligning);
  });

  test('aligning -> searching when alignment drops', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    fsm.onDetection(_r(alignment: FaceAlignment.offCenter), laterMs(200));
    expect(fsm.state, CaptureState.searching);
  });

  test('aligning -> promptBlink after stableFaceMs', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 10),
    );
    expect(fsm.state, CaptureState.promptBlink);
  });

  test('blink within window -> capturing', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 10),
    );
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned, leftEye: 0.05, rightEye: 0.05),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 200),
    );
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned, leftEye: 0.95, rightEye: 0.95),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 400),
    );
    expect(fsm.state, CaptureState.capturing);
  });

  test('no blink within window -> retry', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 10),
    );
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned),
      laterMs(AppConstants.attendancePhotoStableFaceMs +
          AppConstants.attendancePhotoBlinkWindowMs +
          50),
    );
    expect(fsm.state, CaptureState.retry);
    expect(fsm.attempts, 1);
  });

  test('three failed attempts -> exhausted', () {
    void advanceOneFailedAttempt(int baseMs) {
      fsm.onDetection(_r(alignment: FaceAlignment.aligned), laterMs(baseMs));
      fsm.onDetection(
        _r(alignment: FaceAlignment.aligned),
        laterMs(baseMs + AppConstants.attendancePhotoStableFaceMs + 10),
      );
      fsm.onDetection(
        _r(alignment: FaceAlignment.aligned),
        laterMs(baseMs +
            AppConstants.attendancePhotoStableFaceMs +
            AppConstants.attendancePhotoBlinkWindowMs +
            50),
      );
    }

    advanceOneFailedAttempt(0);
    expect(fsm.state, CaptureState.retry);
    advanceOneFailedAttempt(10000);
    expect(fsm.state, CaptureState.retry);
    advanceOneFailedAttempt(20000);
    expect(fsm.state, CaptureState.exhausted);
  });

  test('alignment loss in promptBlink resets to searching', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 10),
    );
    fsm.onDetection(
      _r(alignment: FaceAlignment.offCenter),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 200),
    );
    expect(fsm.state, CaptureState.searching);
  });

  test('closed eyes only (no open transition) does not capture', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 10),
    );
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned, leftEye: 0.05, rightEye: 0.05),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 200),
    );
    fsm.onDetection(
      _r(alignment: FaceAlignment.aligned, leftEye: 0.05, rightEye: 0.05),
      laterMs(AppConstants.attendancePhotoStableFaceMs + 500),
    );
    expect(fsm.state, CaptureState.promptBlink);
  });

  test('reset returns to initial state', () {
    fsm.onDetection(_r(alignment: FaceAlignment.aligned), t0);
    fsm.reset();
    expect(fsm.state, CaptureState.searching);
    expect(fsm.attempts, 0);
  });
}
